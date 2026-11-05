from __future__ import annotations

"""
Router dedicado de Wearables (`/api/v1/wearables/*`) sin mocks ni valores por defecto.
Delega y expone el escaneo real de capturas de pantalla (`POST /wearables/scan-screen`)
y la sincronización diaria (`GET /wearables/today`, `POST /wearables/sync`) hacia `daily_readiness` y `wearable_metrics`.
"""

from app.api.v1.biometrics import (
    get_today_wearable_metrics,
    router,
    scan_whoop_screen_metrics,
    sync_wearable_metrics,
)

__all__ = [
    "router",
    "get_today_wearable_metrics",
    "scan_whoop_screen_metrics",
    "sync_wearable_metrics",
]
