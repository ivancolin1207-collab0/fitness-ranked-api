from __future__ import annotations

"""
Router dedicado de Inteligencia Artificial (`POST /api/v1/ai/chat`)
para el Director de Rendimiento / Centro Táctico de ApexMetrix.
"""

from app.api.v1.biometrics import chat_with_gemini_coach, router
from app.services.gemini_service import generate_coach_chat_reply

__all__ = ["router", "chat_with_gemini_coach", "generate_coach_chat_reply"]
