from __future__ import annotations

"""
Cliente Oficial WHOOP Developer Cloud OAuth 2.0 (`https://api.prod.whoop.com`).
Permite vincular la cuenta de WHOOP del atleta una sola vez y sincronizar
automáticamente Recovery (%), Strain (0-21), Sleep (%), HRV (RMSSD ms) y RHR (bpm)
en segundo plano al abrir la app sin depender de capturas ni de Health Connect.
"""

import asyncio
import base64
import hashlib
import hmac
import json
import logging
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings

logger = logging.getLogger("apexmetrix_whoop_cloud")

WHOOP_OAUTH_AUTH_URL = "https://api.prod.whoop.com/oauth/oauth2/auth"
WHOOP_OAUTH_TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token"
WHOOP_API_BASE_URL = "https://api.prod.whoop.com/developer"
WHOOP_SCOPES = "read:recovery read:cycles read:sleep read:workout read:profile offline"


async def ensure_whoop_oauth_table(db: AsyncSession) -> None:
    """Crea la tabla `whoop_oauth_tokens` si aún no existe en PostgreSQL."""
    try:
        async with db.begin_nested():
            await db.execute(
                text(
                    """
                    CREATE TABLE IF NOT EXISTS whoop_oauth_tokens (
                        user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                        access_token TEXT NOT NULL,
                        refresh_token TEXT,
                        expires_at TIMESTAMPTZ NOT NULL,
                        whoop_user_id VARCHAR(64),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
            )
    except Exception as exc:
        logger.warning("Aviso verificando tabla whoop_oauth_tokens: %s", exc)


def is_whoop_oauth_configured() -> bool:
    settings = get_settings()
    return bool(
        settings.WHOOP_CLIENT_ID.strip() and settings.WHOOP_CLIENT_SECRET.strip()
    )


def build_signed_oauth_state(user_id: UUID) -> str:
    """Genera un parámetro `state` firmado con HMAC-SHA256 que identifica al `user_id`."""
    settings = get_settings()
    ts = int(time.time())
    payload = f"{user_id}:{ts}"
    sig = hmac.new(
        settings.SECRET_KEY.encode("utf-8"),
        payload.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()[:24]
    raw = f"{payload}:{sig}".encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def verify_signed_oauth_state(state: str) -> UUID:
    """Verifica el `state` recibido en el callback de OAuth 2.0 y extrae `user_id`."""
    settings = get_settings()
    try:
        padding = "=" * ((4 - len(state) % 4) % 4)
        decoded = base64.urlsafe_b64decode((state + padding).encode("ascii")).decode(
            "utf-8"
        )
        uid_str, ts_str, received_sig = decoded.split(":", 2)
        payload = f"{uid_str}:{ts_str}"
        expected_sig = hmac.new(
            settings.SECRET_KEY.encode("utf-8"),
            payload.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()[:24]
        if not hmac.compare_digest(received_sig, expected_sig):
            raise ValueError("Firma de state OAuth inválida.")
        if abs(int(time.time()) - int(ts_str)) > 3600:
            raise ValueError("La sesión de autorización OAuth expiró.")
        return UUID(uid_str)
    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Parámetro state OAuth inválido o expirado: {exc}",
        ) from exc


def build_whoop_authorization_url(user_id: UUID, redirect_uri: Optional[str] = None) -> str:
    settings = get_settings()
    if not is_whoop_oauth_configured():
        raise HTTPException(
            status_code=400,
            detail=(
                "WHOOP Cloud OAuth aún no tiene configuradas las variables "
                "WHOOP_CLIENT_ID y WHOOP_CLIENT_SECRET en Render."
            ),
        )
    state = build_signed_oauth_state(user_id)
    target_redirect = (redirect_uri or settings.WHOOP_REDIRECT_URI).strip()
    params = urllib.parse.urlencode(
        {
            "client_id": settings.WHOOP_CLIENT_ID.strip(),
            "redirect_uri": target_redirect,
            "response_type": "code",
            "scope": WHOOP_SCOPES,
            "state": state,
        }
    )
    return f"{WHOOP_OAUTH_AUTH_URL}?{params}"


def _post_oauth_token_sync(form_data: dict[str, str]) -> dict[str, Any]:
    encoded = urllib.parse.urlencode(form_data).encode("utf-8")
    req = urllib.request.Request(
        WHOOP_OAUTH_TOKEN_URL,
        data=encoded,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
            "User-Agent": "ApexMetrix/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as err:
        body = err.read().decode("utf-8", errors="replace")
        raise HTTPException(
            status_code=400,
            detail=f"WHOOP OAuth token error ({err.code}): {body}",
        ) from err
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"No se pudo conectar con WHOOP OAuth ({WHOOP_OAUTH_TOKEN_URL}): {exc}",
        ) from exc


def _get_whoop_api_sync(path: str, access_token: str) -> Optional[dict[str, Any]]:
    url = f"{WHOOP_API_BASE_URL}{path}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
            "User-Agent": "ApexMetrix/1.0",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=18) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as err:
        if err.code == 401:
            raise
        logger.warning("WHOOP API %s devolvió HTTP %s", path, err.code)
        return None
    except Exception as exc:
        logger.warning("Fallo consultando WHOOP API %s: %s", path, exc)
        return None


async def exchange_code_and_store_tokens(
    db: AsyncSession,
    *,
    user_id: UUID,
    code: str,
    redirect_uri: Optional[str] = None,
) -> dict[str, Any]:
    settings = get_settings()
    await ensure_whoop_oauth_table(db)
    target_redirect = (redirect_uri or settings.WHOOP_REDIRECT_URI).strip()

    token_data = await asyncio.to_thread(
        _post_oauth_token_sync,
        {
            "grant_type": "authorization_code",
            "code": code.strip(),
            "client_id": settings.WHOOP_CLIENT_ID.strip(),
            "client_secret": settings.WHOOP_CLIENT_SECRET.strip(),
            "redirect_uri": target_redirect,
        },
    )

    access_token = str(token_data.get("access_token") or "").strip()
    if not access_token:
        raise HTTPException(
            status_code=400,
            detail="WHOOP OAuth no devolvió un access_token válido.",
        )
    refresh_token = str(token_data.get("refresh_token") or "").strip() or None
    expires_in = int(token_data.get("expires_in") or 3600)
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=max(300, expires_in))

    await db.execute(
        text(
            """
            INSERT INTO whoop_oauth_tokens (user_id, access_token, refresh_token, expires_at, updated_at)
            VALUES (:uid, :acc, :ref, :exp, NOW())
            ON CONFLICT (user_id) DO UPDATE SET
                access_token = EXCLUDED.access_token,
                refresh_token = COALESCE(EXCLUDED.refresh_token, whoop_oauth_tokens.refresh_token),
                expires_at = EXCLUDED.expires_at,
                updated_at = NOW()
            """
        ),
        {
            "uid": user_id,
            "acc": access_token,
            "ref": refresh_token,
            "exp": expires_at,
        },
    )
    await db.commit()
    return token_data


async def get_user_whoop_oauth_status(
    db: AsyncSession, user_id: UUID
) -> dict[str, Any]:
    await ensure_whoop_oauth_table(db)
    row = None
    try:
        async with db.begin_nested():
            row = (
                await db.execute(
                    text(
                        """
                        SELECT expires_at, updated_at, refresh_token IS NOT NULL AS has_refresh
                        FROM whoop_oauth_tokens
                        WHERE user_id = :uid
                        """
                    ),
                    {"uid": user_id},
                )
            ).first()
    except Exception:
        row = None

    configured = is_whoop_oauth_configured()
    auth_url = build_whoop_authorization_url(user_id) if configured else None
    return {
        "oauth_configured": configured,
        "linked": row is not None,
        "expires_at": row[0].isoformat() if (row and row[0]) else None,
        "updated_at": row[1].isoformat() if (row and row[1]) else None,
        "has_refresh_token": bool(row[2]) if row else False,
        "authorize_url": auth_url,
    }


async def _get_valid_access_token(db: AsyncSession, user_id: UUID) -> str:
    await ensure_whoop_oauth_table(db)
    row = (
        await db.execute(
            text(
                """
                SELECT access_token, refresh_token, expires_at
                FROM whoop_oauth_tokens
                WHERE user_id = :uid
                """
            ),
            {"uid": user_id},
        )
    ).first()
    if row is None:
        raise HTTPException(
            status_code=404,
            detail="El usuario aún no ha vinculado su cuenta con WHOOP Cloud OAuth.",
        )

    access_token = str(row[0])
    refresh_token = str(row[1]) if row[1] else None
    expires_at: Optional[datetime] = row[2]

    now_utc = datetime.now(timezone.utc)
    if (
        expires_at is not None
        and expires_at <= now_utc + timedelta(minutes=5)
        and refresh_token
        and is_whoop_oauth_configured()
    ):
        settings = get_settings()
        refreshed = await asyncio.to_thread(
            _post_oauth_token_sync,
            {
                "grant_type": "refresh_token",
                "refresh_token": refresh_token,
                "client_id": settings.WHOOP_CLIENT_ID.strip(),
                "client_secret": settings.WHOOP_CLIENT_SECRET.strip(),
                "scope": WHOOP_SCOPES,
            },
        )
        new_access = str(refreshed.get("access_token") or "").strip()
        new_refresh = str(refreshed.get("refresh_token") or refresh_token).strip()
        new_exp = now_utc + timedelta(seconds=int(refreshed.get("expires_in") or 3600))
        if new_access:
            access_token = new_access
            await db.execute(
                text(
                    """
                    UPDATE whoop_oauth_tokens
                    SET access_token = :acc, refresh_token = :ref, expires_at = :exp, updated_at = NOW()
                    WHERE user_id = :uid
                    """
                ),
                {
                    "uid": user_id,
                    "acc": new_access,
                    "ref": new_refresh,
                    "exp": new_exp,
                },
            )
            await db.commit()

    return access_token


async def fetch_whoop_cloud_metrics(
    db: AsyncSession, user_id: UUID
) -> dict[str, Any]:
    """
    Descarga Recovery, Cycle (Strain) y Sleep más recientes desde `api.prod.whoop.com/developer/v1/*`
    para el usuario autenticado.
    """
    access_token = await _get_valid_access_token(db, user_id)

    rec_json, cycle_json, sleep_json = await asyncio.gather(
        asyncio.to_thread(_get_whoop_api_sync, "/v1/recovery?limit=1", access_token),
        asyncio.to_thread(_get_whoop_api_sync, "/v1/cycle?limit=1", access_token),
        asyncio.to_thread(
            _get_whoop_api_sync, "/v1/activity/sleep?limit=1", access_token
        ),
    )

    rec_records = (rec_json or {}).get("records") or []
    cycle_records = (cycle_json or {}).get("records") or []
    sleep_records = (sleep_json or {}).get("records") or []

    rec_score_obj = (rec_records[0].get("score") or {}) if rec_records else {}
    cycle_score_obj = (cycle_records[0].get("score") or {}) if cycle_records else {}
    sleep_score_obj = (sleep_records[0].get("score") or {}) if sleep_records else {}
    stage_summary = sleep_score_obj.get("stage_summary") or {}

    recovery_score = float(rec_score_obj.get("recovery_score") or 0.0)
    resting_hr = int(round(float(rec_score_obj.get("resting_heart_rate") or 0)))
    hrv_ms = round(float(rec_score_obj.get("hrv_rmssd_milli") or 0.0), 1)

    strain_score = round(float(cycle_score_obj.get("strain") or 0.0), 1)
    avg_hr = int(round(float(cycle_score_obj.get("average_heart_rate") or resting_hr or 0)))
    max_hr = int(round(float(cycle_score_obj.get("max_heart_rate") or max(avg_hr + 20, avg_hr))))

    sleep_pct = round(
        float(sleep_score_obj.get("sleep_performance_percentage") or 0.0), 0
    )
    in_bed_milli = float(stage_summary.get("total_in_bed_time_milli") or 0.0)
    awake_milli = float(stage_summary.get("total_awake_time_milli") or 0.0)
    asleep_milli = max(0.0, in_bed_milli - awake_milli)
    sleep_hours = (
        round(asleep_milli / 3_600_000.0, 2)
        if asleep_milli > 0
        else (round((sleep_pct / 100.0) * 8.0, 2) if sleep_pct > 0 else 0.0)
    )

    if recovery_score <= 0 and strain_score <= 0 and sleep_pct <= 0:
        raise HTTPException(
            status_code=404,
            detail="WHOOP Cloud API no reportó ciclos ni recuperación registrados hoy.",
        )

    return {
        "sleep_pct": max(0.0, min(100.0, sleep_pct)),
        "sleep_performance_pct": max(0.0, min(100.0, sleep_pct)),
        "recovery_score": max(0.0, min(100.0, recovery_score)),
        "strain_score": max(0.0, min(21.0, strain_score)),
        "stress_level": 0.0,
        "stress_category": "BAJO" if recovery_score >= 67 else ("MEDIO" if recovery_score >= 34 else "ALTO"),
        "sleep_hours": sleep_hours,
        "resting_hr": resting_hr,
        "hrv_ms": hrv_ms,
        "avg_hr": avg_hr,
        "max_hr": max_hr,
    }
