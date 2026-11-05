from __future__ import annotations

"""
Endpoints de Autenticación, Perfil Fisiológico y Onboarding (`/api/v1/auth`).
"""

import logging
import traceback
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger("apexmetrix_auth")

from app.core.config import get_settings
from app.core.database import get_db
from app.core.elo_engine import ExerciseCategory, Formula1RM, RankedTier
from app.core.security import (
    bearer_scheme,
    create_access_token,
    decode_and_verify_jwt,
    get_current_user,
    hash_password,
    rate_limit_dependency,
    revoke_token_jti,
    verify_password,
)
from app.models.entities import (
    Exercise,
    RankedPoint,
    RoutineTemplate,
    RoutineTemplateExercise,
    User,
)
from app.schemas.auth import (
    PasswordResetDirectRequest,
    ProfileSetupUpdateRequest,
    TokenResponse,
    UserLoginRequest,
    UserProfileResponse,
    UserRegisterRequest,
    calculate_age_years,
    mask_email,
)

router = APIRouter(prefix="/auth", tags=["Authentication & Profile"])


async def _get_or_create_ranked_point(
    db: AsyncSession, user: User
) -> RankedPoint:
    settings = get_settings()
    stmt = select(RankedPoint).where(
        RankedPoint.user_id == user.id,
        RankedPoint.season_id == settings.DEFAULT_SEASON_ID,
    )
    rp = (await db.execute(stmt)).scalar_one_or_none()
    if rp is None:
        rp = RankedPoint(
            user_id=user.id,
            season_id=settings.DEFAULT_SEASON_ID,
            current_elo=1200,
            peak_elo=1200,
            tier=RankedTier.PLATA,
        )
        db.add(rp)
        await db.flush()
    return rp


async def _seed_default_weekly_routines_if_empty(
    db: AsyncSession, user: User
) -> None:
    """
    Las plantillas estáticas por defecto fueron eliminadas.
    El 100% de la planificación semanal (5 días x 6 ejercicios) es generada
    dinámicamente por Gemini 2.5 Flash en `POST /api/v1/routines/generate-ai`.
    """
    return None


def _to_user_profile(
    user: User, ranked: Optional[RankedPoint] = None
) -> UserProfileResponse:
    elo = int(ranked.current_elo) if ranked is not None else 1200
    tier_val = (
        ranked.tier.value
        if (ranked is not None and isinstance(ranked.tier, RankedTier))
        else (str(ranked.tier) if ranked is not None else "Plata")
    )
    return UserProfileResponse(
        id=user.id,
        username=user.username,
        full_name=user.full_name,
        masked_email=mask_email(user.email),
        birth_date=user.birth_date,
        age_years=calculate_age_years(user.birth_date),
        biological_sex=user.biological_sex,
        height_cm=float(user.height_cm) if user.height_cm is not None else None,
        training_goal=user.training_goal,
        preferred_wearable=user.preferred_wearable,
        unit_system=user.unit_system,
        onboarding_completed=bool(user.onboarding_completed),
        current_elo=elo,
        current_tier=tier_val,
        is_active=user.is_active,
        created_at=user.created_at,
    )


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_user(
    payload: UserRegisterRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    _rl: Annotated[None, Depends(rate_limit_dependency)],
) -> TokenResponse:
    """
    Registra un nuevo usuario en PostgreSQL de forma transaccional,
    inicializa atómicamente su registro en `ranked_points` (1200 ELO - Plata, temporada '2026-S4')
    y crea su plantilla semanal base editable.
    """
    try:
        settings = get_settings()
        clean_username = payload.username.strip()
        clean_email = payload.email.lower().strip()

        existing_stmt = select(User).where(
            or_(User.username == clean_username, User.email == clean_email)
        )
        existing_user = (await db.execute(existing_stmt)).scalar_one_or_none()
        if existing_user is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="El nombre de usuario o correo electrónico ya está registrado.",
            )

        onboarding_done = bool(payload.full_name and payload.birth_date)
        new_user = User(
            username=clean_username,
            email=clean_email,
            password_hash=hash_password(payload.password),
            full_name=payload.full_name,
            birth_date=payload.birth_date,
            biological_sex=payload.biological_sex,
            height_cm=payload.height_cm,
            training_goal=payload.training_goal,
            preferred_wearable=payload.preferred_wearable,
            unit_system=payload.unit_system,
            onboarding_completed=onboarding_done,
        )
        db.add(new_user)
        await db.flush()

        # Inserción atómica del registro inicial en ranked_points dentro de la misma transacción
        season_id = settings.DEFAULT_SEASON_ID or "2026-S4"
        ranked = RankedPoint(
            user_id=new_user.id,
            season_id=season_id,
            current_elo=1200,
            peak_elo=1200,
            tier=RankedTier.PLATA,
        )
        db.add(ranked)
        await db.flush()

        await _seed_default_weekly_routines_if_empty(db, new_user)

        await db.commit()
        await db.refresh(new_user)

        token = create_access_token(
            subject=new_user.id,
            extra_claims={
                "unit_system": new_user.unit_system.value,
                "sex": new_user.biological_sex.value,
            },
        )
        return TokenResponse(
            access_token=token,
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=_to_user_profile(new_user, ranked),
        )
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        traceback.print_exc()
        logger.exception("Error durante el registro de usuario (%s): %s", payload.username, e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error al registrar usuario: {str(e)}",
        ) from e


@router.post(
    "/login",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
)
async def login_user(
    payload: UserLoginRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    _rl: Annotated[None, Depends(rate_limit_dependency)],
) -> TokenResponse:
    try:
        settings = get_settings()
        identifier = payload.username_or_email.strip()
        stmt = select(User).where(
            or_(User.username == identifier, User.email == identifier.lower()),
            User.is_active.is_(True),
        )
        user = (await db.execute(stmt)).scalar_one_or_none()
        if user is None or not verify_password(payload.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales inválidas.",
            )

        ranked = await _get_or_create_ranked_point(db, user)
        await _seed_default_weekly_routines_if_empty(db, user)
        await db.commit()

        token = create_access_token(
            subject=user.id,
            extra_claims={
                "unit_system": user.unit_system.value,
                "sex": user.biological_sex.value,
            },
        )
        return TokenResponse(
            access_token=token,
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=_to_user_profile(user, ranked),
        )
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        traceback.print_exc()
        logger.exception("Error en login_user: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error al iniciar sesión: {str(e)}",
        ) from e


@router.put(
    "/profile",
    response_model=UserProfileResponse,
    status_code=status.HTTP_200_OK,
)
@router.post(
    "/profile",
    response_model=UserProfileResponse,
    status_code=status.HTTP_200_OK,
)
async def update_user_profile(
    payload: ProfileSetupUpdateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> UserProfileResponse:
    """
    Actualiza el perfil fisiológico y de onboarding del atleta en Render PostgreSQL.
    """
    try:
        if payload.username and payload.username.strip() != current_user.username:
            new_uname = payload.username.strip()
            taken = (
                await db.execute(
                    select(User.id).where(
                        User.username == new_uname,
                        User.id != current_user.id,
                    )
                )
            ).scalar_one_or_none()
            if taken is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Ese username ya está en uso por otro atleta.",
                )
            current_user.username = new_uname

        current_user.full_name = payload.full_name.strip()
        current_user.birth_date = payload.birth_date
        current_user.biological_sex = payload.biological_sex
        current_user.height_cm = payload.height_cm
        current_user.training_goal = payload.training_goal
        current_user.preferred_wearable = payload.preferred_wearable
        current_user.unit_system = payload.unit_system
        current_user.onboarding_completed = True

        ranked = await _get_or_create_ranked_point(db, current_user)
        await _seed_default_weekly_routines_if_empty(db, current_user)

        await db.commit()
        await db.refresh(current_user)
        return _to_user_profile(current_user, ranked)
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        traceback.print_exc()
        logger.exception("Error actualizando perfil: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error al actualizar perfil: {str(e)}",
        ) from e


@router.post("/logout", status_code=status.HTTP_200_OK)
async def logout_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    _current_user: Annotated[User, Depends(get_current_user)],
) -> dict[str, str]:
    claims = decode_and_verify_jwt(credentials.credentials)
    jti = claims.get("jti")
    if jti:
        revoke_token_jti(str(jti))
    return {"status": "logged_out"}


@router.get("/me", response_model=UserProfileResponse, status_code=status.HTTP_200_OK)
async def get_my_profile(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> UserProfileResponse:
    ranked = await _get_or_create_ranked_point(db, current_user)
    await db.commit()
    return _to_user_profile(current_user, ranked)


@router.post(
    "/reset-password",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
)
@router.post(
    "/forgot-password-direct",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
)
async def reset_password_direct(
    payload: PasswordResetDirectRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    _rl: Annotated[None, Depends(rate_limit_dependency)],
) -> TokenResponse:
    """
    Permite restablecer la contraseña ingresando el correo electrónico (o username)
    del atleta registrado en PostgreSQL y emite un nuevo JWT persistente.
    """
    try:
        settings = get_settings()
        identifier = payload.email.strip()
        stmt = select(User).where(
            or_(
                User.email == identifier.lower(),
                User.username == identifier,
            ),
            User.is_active.is_(True),
        )
        user = (await db.execute(stmt)).scalar_one_or_none()
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No se encontró ninguna cuenta activa con ese correo electrónico o username.",
            )

        user.password_hash = hash_password(payload.new_password)
        ranked = await _get_or_create_ranked_point(db, user)
        await db.commit()
        await db.refresh(user)

        token = create_access_token(
            subject=user.id,
            extra_claims={
                "unit_system": user.unit_system.value,
                "sex": user.biological_sex.value,
            },
        )
        return TokenResponse(
            access_token=token,
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=_to_user_profile(user, ranked),
        )
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        traceback.print_exc()
        logger.exception("Error en reset_password_direct: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No se pudo restablecer la contraseña: {str(e)}",
        ) from e
