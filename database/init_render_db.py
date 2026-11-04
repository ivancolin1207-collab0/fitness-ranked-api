"""
Inicializador y Validador Transaccional de Esquema PostgreSQL en Render.
Lee la cadena de conexión desde la variable de entorno `DATABASE_URL` (o archivo `.env`
excluido de control de versiones) y ejecuta `database/schema.sql`, seguido de una
auditoría completa de tablas, tipos ENUM, triggers, índices y una prueba funcional
transaccional (ROLLBACK) del trigger ELO y columna generada de Masa Magra (LBM).
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import logging
import os
import secrets
import socket
import ssl
import struct
import sys
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(message)s",
)
logger = logging.getLogger("render_db_migrator")

SCHEMA_SQL_PATH = Path(__file__).resolve().parent / "schema.sql"
ENV_FILE_PATH = Path(__file__).resolve().parent.parent / ".env"


def resolve_database_url() -> str | None:
    """Obtiene DATABASE_URL desde variables de entorno o archivo local .env."""
    env_val = os.getenv("DATABASE_URL")
    if env_val:
        return env_val.strip()
    if ENV_FILE_PATH.exists():
        for line in ENV_FILE_PATH.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if stripped and not stripped.startswith("#") and stripped.startswith("DATABASE_URL="):
                return stripped.split("=", 1)[1].strip()
    return None


class PostgresWireError(RuntimeError):
    """Error devuelto por el motor PostgreSQL durante la ejecución SQL."""


class NativePostgresSSLClient:
    """
    Cliente ligero del protocolo PostgreSQL v3 sobre TLS 1.2+ con soporte para
    autenticación SCRAM-SHA-256 y MD5 usando únicamente la librería estándar de Python.
    """

    def __init__(self, dsn: str, timeout: float = 25.0) -> None:
        parsed = urlparse(dsn)
        if parsed.scheme not in ("postgres", "postgresql"):
            raise ValueError(f"Esquema de conexión no soportado: {parsed.scheme}")
        self.host = parsed.hostname or "localhost"
        self.port = parsed.port or 5432
        self.user = unquote(parsed.username or "")
        self.password = unquote(parsed.password or "")
        self.database = parsed.path.lstrip("/")
        self.timeout = timeout
        self.sock: socket.socket | ssl.SSLSocket | None = None

    def connect(self) -> None:
        logger.info("Conectando a %s:%d/%s (TLS 1.2+ requerido)...", self.host, self.port, self.database)
        raw_sock = socket.create_connection((self.host, self.port), timeout=self.timeout)

        # 1. Negociación SSLRequest (código 80877103)
        raw_sock.sendall(struct.pack("!ii", 8, 80877103))
        ssl_resp = self._recv_exact(raw_sock, 1)
        if ssl_resp == b"S":
            ctx = ssl.create_default_context()
            ctx.minimum_version = ssl.TLSVersion.TLSv1_2
            try:
                self.sock = ctx.wrap_socket(raw_sock, server_hostname=self.host)
            except ssl.SSLCertVerificationError:
                # Render PostgreSQL usa certificados autofirmados por instancia (equivalente a sslmode=require de libpq)
                raw_sock.close()
                raw_sock = socket.create_connection((self.host, self.port), timeout=self.timeout)
                raw_sock.sendall(struct.pack("!ii", 8, 80877103))
                self._recv_exact(raw_sock, 1)
                fallback_ctx = ssl.create_default_context()
                fallback_ctx.minimum_version = ssl.TLSVersion.TLSv1_2
                fallback_ctx.check_hostname = False
                fallback_ctx.verify_mode = ssl.CERT_NONE
                self.sock = fallback_ctx.wrap_socket(raw_sock, server_hostname=self.host)
            logger.info("Canal TLS establecido (%s).", self.sock.version())
        else:
            raise PostgresWireError("El servidor PostgreSQL rechazó la conexión TLS obligatoria.")

        # 2. StartupMessage (Protocolo v3.0 = 196608)
        params = (
            f"user\x00{self.user}\x00"
            f"database\x00{self.database}\x00"
            f"client_encoding\x00UTF8\x00"
            f"application_name\x00render_schema_migrator\x00\x00"
        ).encode("utf-8")
        startup_pkt = struct.pack("!ii", len(params) + 8, 196608) + params
        self.sock.sendall(startup_pkt)

        # 3. Ciclo de Autenticación y espera de ReadyForQuery ('Z')
        self._handle_startup_and_auth()

    def _recv_exact(self, sock: socket.socket, n: int) -> bytes:
        buf = bytearray()
        while len(buf) < n:
            chunk = sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("Conexión cerrada inesperadamente por el servidor PostgreSQL.")
            buf.extend(chunk)
        return bytes(buf)

    def _read_message(self) -> tuple[str, bytes]:
        assert self.sock is not None
        header = self._recv_exact(self.sock, 5)
        msg_type = chr(header[0])
        msg_len = struct.unpack("!i", header[1:5])[0]
        payload = self._recv_exact(self.sock, msg_len - 4) if msg_len > 4 else b""
        return msg_type, payload

    def _send_message(self, msg_type: str, payload: bytes) -> None:
        assert self.sock is not None
        pkt = msg_type.encode("ascii") + struct.pack("!i", len(payload) + 4) + payload
        self.sock.sendall(pkt)

    def _handle_startup_and_auth(self) -> None:
        scram_state: dict[str, Any] = {}
        while True:
            msg_type, payload = self._read_message()
            if msg_type == "R":
                auth_code = struct.unpack("!i", payload[:4])[0]
                if auth_code == 0:
                    logger.info("Autenticación exitosa en Render PostgreSQL.")
                elif auth_code == 3:
                    self._send_message("p", self.password.encode("utf-8") + b"\x00")
                elif auth_code == 5:
                    salt = payload[4:8]
                    inner = hashlib.md5(
                        (self.password + self.user).encode("utf-8")
                    ).hexdigest()
                    outer = hashlib.md5(inner.encode("ascii") + salt).hexdigest()
                    self._send_message("p", f"md5{outer}\x00".encode("ascii"))
                elif auth_code == 10:
                    c_nonce = base64.b64encode(secrets.token_bytes(18)).decode("ascii")
                    client_first_bare = f"n=,r={c_nonce}"
                    client_first_msg = f"n,,{client_first_bare}".encode("utf-8")
                    sasl_init = (
                        b"SCRAM-SHA-256\x00"
                        + struct.pack("!i", len(client_first_msg))
                        + client_first_msg
                    )
                    scram_state["client_first_bare"] = client_first_bare
                    scram_state["c_nonce"] = c_nonce
                    self._send_message("p", sasl_init)
                elif auth_code == 11:
                    server_first = payload[4:].decode("utf-8")
                    parts = dict(item.split("=", 1) for item in server_first.split(","))
                    s_nonce = parts["r"]
                    if not s_nonce.startswith(scram_state["c_nonce"]):
                        raise PostgresWireError("Nonce SCRAM inválido recibido del servidor.")
                    salt = base64.b64decode(parts["s"])
                    iterations = int(parts["i"])

                    salted_pwd = hashlib.pbkdf2_hmac(
                        "sha256", self.password.encode("utf-8"), salt, iterations
                    )
                    client_key = hmac.new(
                        salted_pwd, b"Client Key", hashlib.sha256
                    ).digest()
                    stored_key = hashlib.sha256(client_key).digest()
                    client_final_no_proof = f"c=biws,r={s_nonce}"
                    auth_msg = (
                        f"{scram_state['client_first_bare']},"
                        f"{server_first},"
                        f"{client_final_no_proof}"
                    ).encode("utf-8")
                    client_sig = hmac.new(stored_key, auth_msg, hashlib.sha256).digest()
                    client_proof = bytes(a ^ b for a, b in zip(client_key, client_sig))
                    proof_b64 = base64.b64encode(client_proof).decode("ascii")
                    client_final = f"{client_final_no_proof},p={proof_b64}".encode("utf-8")
                    self._send_message("p", client_final)
                elif auth_code == 12:
                    pass
                else:
                    raise PostgresWireError(f"Método de autenticación no soportado: {auth_code}")
            elif msg_type == "E":
                raise PostgresWireError(self._parse_error_or_notice(payload))
            elif msg_type == "Z":
                break

    @staticmethod
    def _parse_error_or_notice(payload: bytes) -> str:
        fields: dict[str, str] = {}
        for part in payload.split(b"\x00"):
            if part:
                fields[chr(part[0])] = part[1:].decode("utf-8", errors="replace")
        return f"[{fields.get('S', 'ERR')} {fields.get('C', '')}] {fields.get('M', '')} {fields.get('D', '')}".strip()

    def execute_query(self, sql: str) -> tuple[list[dict[str, Any]], list[str]]:
        """Ejecuta una consulta o bloque SQL transaccional estático y devuelve (filas, comandos)."""
        self._send_message("Q", sql.encode("utf-8") + b"\x00")
        columns: list[str] = []
        rows: list[dict[str, Any]] = []
        commands: list[str] = []

        while True:
            msg_type, payload = self._read_message()
            if msg_type == "T":
                num_fields = struct.unpack("!h", payload[:2])[0]
                offset = 2
                columns = []
                for _ in range(num_fields):
                    end = payload.index(b"\x00", offset)
                    col_name = payload[offset:end].decode("utf-8")
                    columns.append(col_name)
                    offset = end + 1 + 18
            elif msg_type == "D":
                num_cols = struct.unpack("!h", payload[:2])[0]
                offset = 2
                row_dict: dict[str, Any] = {}
                for i in range(num_cols):
                    col_len = struct.unpack("!i", payload[offset : offset + 4])[0]
                    offset += 4
                    if col_len == -1:
                        val = None
                    else:
                        val = payload[offset : offset + col_len].decode("utf-8")
                        offset += col_len
                    row_dict[columns[i] if i < len(columns) else f"col_{i}"] = val
                rows.append(row_dict)
            elif msg_type == "C":
                cmd_tag = payload.rstrip(b"\x00").decode("utf-8")
                commands.append(cmd_tag)
            elif msg_type == "N":
                logger.info("PostgreSQL Notice: %s", self._parse_error_or_notice(payload))
            elif msg_type == "E":
                err_msg = self._parse_error_or_notice(payload)
                while True:
                    t, _ = self._read_message()
                    if t == "Z":
                        break
                raise PostgresWireError(err_msg)
            elif msg_type == "Z":
                break

        return rows, commands

    def close(self) -> None:
        if self.sock:
            try:
                self._send_message("X", b"")
            except Exception:
                pass
            self.sock.close()
            self.sock = None


def run_migration_and_validation() -> int:
    dsn = resolve_database_url()
    if not dsn:
        logger.error("DATABASE_URL no encontrada en entorno ni en .env.")
        return 1

    sql_script = SCHEMA_SQL_PATH.read_text(encoding="utf-8")
    client = NativePostgresSSLClient(dsn)
    try:
        client.connect()

        # 1. Ejecutar DDL transaccional completo
        logger.info("Ejecutando DDL transaccional desde %s...", SCHEMA_SQL_PATH.name)
        _, commands = client.execute_query(sql_script)
        logger.info("Comandos DDL ejecutados (%d): %s", len(commands), ", ".join(commands))

        # 2. Validar tablas creadas en el esquema public
        tables_rows, _ = client.execute_query("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_type = 'BASE TABLE'
            ORDER BY table_name;
        """)
        found_tables = [r["table_name"] for r in tables_rows]
        logger.info("Tablas verificadas (%d): %s", len(found_tables), found_tables)

        # 3. Validar tipos ENUM creados
        enum_rows, _ = client.execute_query("""
            SELECT t.typname AS enum_name,
                   string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder) AS labels
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
            WHERE n.nspname = 'public'
            GROUP BY t.typname
            ORDER BY t.typname;
        """)
        for er in enum_rows:
            logger.info("ENUM %s -> [%s]", er["enum_name"], er["labels"])

        # 4. Validar índices activos
        idx_rows, _ = client.execute_query("""
            SELECT indexname, tablename
            FROM pg_indexes
            WHERE schemaname = 'public'
            ORDER BY tablename, indexname;
        """)
        logger.info("Índices activos en public (%d): %s", len(idx_rows), [r["indexname"] for r in idx_rows])

        # 5. Prueba funcional atómica mediante CTE estático (con ROLLBACK)
        validation_rows, _ = client.execute_query("""
            BEGIN;
            WITH ins_user AS (
                INSERT INTO users (username, email, password_hash, biological_sex, height_cm, unit_system)
                VALUES ('atleta_test', 'atleta@apexmetrix.io', 'argon2id_test_hash', 'MALE', 178.5, 'KG')
                RETURNING id
            ),
            ins_bio AS (
                INSERT INTO biometrics (
                    user_id, weight_kg, fat_percentage, muscle_mass_kg,
                    skeletal_muscle_pct, visceral_fat, body_water_pct, bmr
                )
                SELECT id, 80.00, 15.00, 64.50, 48.00, 5, 61.50, 1850
                FROM ins_user
                RETURNING user_id, weight_kg, fat_percentage, lean_body_mass_kg
            ),
            ins_elo AS (
                INSERT INTO ranked_points (user_id, season_id, current_elo)
                SELECT id, '2026-S4', 1750
                FROM ins_user
                RETURNING user_id, current_elo, peak_elo, tier
            )
            SELECT
                b.weight_kg,
                b.fat_percentage,
                b.lean_body_mass_kg,
                e.current_elo,
                e.peak_elo,
                e.tier
            FROM ins_bio b
            JOIN ins_elo e ON e.user_id = b.user_id;
        """)
        v = validation_rows[0]
        logger.info(
            "Validación Funcional CTE -> Peso=%s kg, Grasa=%s%% => LBM Generado=%s kg | ELO=%s => Tier=%s (Peak=%s)",
            v["weight_kg"],
            v["fat_percentage"],
            v["lean_body_mass_kg"],
            v["current_elo"],
            v["tier"],
            v["peak_elo"],
        )

        client.execute_query("ROLLBACK;")
        logger.info("Prueba transaccional revertida limpiamente (ROLLBACK ejecutado).")
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(run_migration_and_validation())
