import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import ConflictError, ForbiddenError, InvalidTokenError, NotFoundError
from app.core.logging import logger
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models.refresh_token import RefreshToken
from app.models.user import User, UserRole


async def register_user(
    db: AsyncSession,
    email: str,
    password: str,
    role: str = "CLIENT",
) -> User:
    normalized_email = email.strip().lower()
    existing = await db.execute(select(User).where(User.email == normalized_email))
    if existing.scalar_one_or_none():
        raise ConflictError("Email already registered")

    valid_roles = {r.value for r in UserRole}
    if role not in valid_roles:
        raise ForbiddenError(f"Invalid role: {role}")

    user = User(
        email=normalized_email,
        hashed_password=hash_password(password),
        role=UserRole(role),
        is_active=True,
        is_verified=False,
    )
    db.add(user)
    await db.flush()
    logger.info("auth.register", user_id=str(user.id), role=user.role.value)
    return user


async def authenticate_user(
    db: AsyncSession, email: str, password: str
) -> tuple[User, str, str]:
    normalized_email = email.strip().lower()
    result = await db.execute(select(User).where(User.email == normalized_email))
    user = result.scalar_one_or_none()
    if user is None or not verify_password(password, user.hashed_password):
        raise InvalidTokenError("Invalid email or password")

    access_token = create_access_token(str(user.id), user.role.value)
    refresh_token_str, jti = create_refresh_token(str(user.id))

    db.add(
        RefreshToken(
            user_id=user.id,
            jti=jti,
            expires_at=datetime.now(UTC)
            + timedelta(days=settings.refresh_token_expire_days),
        )
    )
    await db.flush()
    logger.info("auth.login", user_id=str(user.id))
    return user, access_token, refresh_token_str


async def logout(db: AsyncSession, refresh_token: str) -> None:
    payload = decode_token(refresh_token)
    jti = payload.get("jti")
    result = await db.execute(select(RefreshToken).where(RefreshToken.jti == jti))
    token_record = result.scalar_one_or_none()
    if token_record and not token_record.is_revoked:
        token_record.is_revoked = True
        logger.info("auth.logout", jti=jti)


async def rotate_refresh_token(
    db: AsyncSession, old_refresh_token: str
) -> tuple[User, str, str]:
    payload = decode_token(old_refresh_token)
    if payload.get("type") != "refresh":
        raise InvalidTokenError("Not a refresh token")

    jti = payload["jti"]
    result = await db.execute(select(RefreshToken).where(RefreshToken.jti == jti))
    token_record = result.scalar_one_or_none()
    if token_record is None or token_record.is_revoked:
        raise InvalidTokenError("Token revoked or not found")

    token_record.is_revoked = True

    user_id = payload["sub"]
    user = await db.get(User, uuid.UUID(user_id))
    if user is None or not user.is_active:
        raise InvalidTokenError("User not found or inactive")

    access_token = create_access_token(str(user.id), user.role.value)
    new_refresh, new_jti = create_refresh_token(str(user.id))

    db.add(
        RefreshToken(
            user_id=user.id,
            jti=new_jti,
            expires_at=datetime.now(UTC)
            + timedelta(days=settings.refresh_token_expire_days),
        )
    )
    await db.flush()
    logger.info("auth.refresh", user_id=str(user.id))
    return user, access_token, new_refresh


async def get_user_by_id(db: AsyncSession, user_id: uuid.UUID) -> User:
    user = await db.get(User, user_id)
    if user is None:
        raise NotFoundError("User not found")
    return user
