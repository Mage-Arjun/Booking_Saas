import uuid
from typing import Annotated

from fastapi import APIRouter, Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import (
    get_current_user,
    get_current_user_from_refresh,
)
from app.core.exceptions import InvalidTokenError
from app.core.logging import logger
from app.core.rate_limit import rate_limit_login_dependency, rate_limit_register_dependency
from app.core.security import decode_token, hash_password
from app.models.user import User
from app.schemas.auth import (
    ForgotPasswordRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
    VerifyEmailRequest,
)
from app.schemas.user import UserProfileResponse, UserResponse
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer()


@router.post("/register", response_model=UserResponse, status_code=201)
async def register(
    payload: RegisterRequest,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(rate_limit_register_dependency),
):
    user = await auth_service.register_user(
        db, email=payload.email, password=payload.password, role=payload.role
    )
    return user


@router.post("/login", response_model=TokenResponse)
async def login(
    payload: LoginRequest,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(rate_limit_login_dependency),
):
    user, access_token, refresh_token = await auth_service.authenticate_user(
        db, email=payload.email, password=payload.password
    )
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/logout")
async def logout(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
    db: AsyncSession = Depends(get_db),
):
    await auth_service.logout(db, credentials.credentials)
    return {"detail": "Logged out successfully"}


@router.post("/refresh", response_model=TokenResponse)
async def refresh(
    refresh_token: str = Depends(get_current_user_from_refresh),
    db: AsyncSession = Depends(get_db),
):
    user, access_token, new_refresh = await auth_service.rotate_refresh_token(
        db, refresh_token
    )
    return TokenResponse(access_token=access_token, refresh_token=new_refresh)


@router.get("/verify-email")
async def verify_email(payload: VerifyEmailRequest, db: AsyncSession = Depends(get_db)):
    try:
        decoded = decode_token(payload.token)
        if decoded.get("type") != "email_verify":
            raise InvalidTokenError("Invalid verification token")
        user_id = decoded["sub"]
    except Exception:
        raise InvalidTokenError("Invalid or expired token")

    user = await db.get(User, uuid.UUID(user_id))
    if user is None:
        raise InvalidTokenError("User not found")

    user.is_verified = True
    await db.flush()
    return {"detail": "Email verified successfully"}


@router.post("/forgot-password")
async def forgot_password(
    payload: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()
    if user:
        logger.info("auth.forgot_password", user_id=str(user.id))
    return {"detail": "If the email exists, a reset link has been sent"}


@router.post("/reset-password")
async def reset_password(
    payload: ResetPasswordRequest, db: AsyncSession = Depends(get_db)
):
    try:
        decoded = decode_token(payload.token)
        if decoded.get("type") != "password_reset":
            raise InvalidTokenError("Invalid reset token")
        user_id = decoded["sub"]
    except Exception:
        raise InvalidTokenError("Invalid or expired token")

    user = await db.get(User, uuid.UUID(user_id))
    if user is None:
        raise InvalidTokenError("User not found")

    user.hashed_password = hash_password(payload.new_password)
    await db.flush()
    logger.info("auth.reset_password", user_id=str(user.id))
    return {"detail": "Password reset successfully"}


@router.get("/me", response_model=UserProfileResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user
