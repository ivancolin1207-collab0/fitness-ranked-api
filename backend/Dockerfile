FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /srv/app

# Instalar dependencias del sistema mínimas y crear usuario sin privilegios
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 10001 appgroup \
    && useradd -u 10001 -g appgroup -s /sbin/nologin -M appuser

COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

COPY app ./app

RUN chown -R appuser:appgroup /srv/app
USER appuser

EXPOSE 8000

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --proxy-headers"]
