from __future__ import annotations

"""
Módulo de endpoints de Wearables y Escaneo de Capturas de Pantalla WHOOP (`POST /api/v1/wearables/scan-screen`).
Re-exporta las funciones registradas en el router v1 de Biometría y Wearables.
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
    "sync_wearable_metrics",
    "scan_whoop_screen_metrics",
]
