import uuid

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.exceptions import ForbiddenError, InvalidTokenError
from app.core.security import decode_token
from app.models.refresh_token import RefreshToken
from app.models.user import User, UserRole

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    try:
        payload = decode_token(credentials.credentials)
        if payload.get("type") != "access":
            raise InvalidTokenError("Invalid token type")
        user_id = payload["sub"]
    except JWTError:
        raise InvalidTokenError("Invalid or expired token")
    except KeyError:
        raise InvalidTokenError("Invalid token payload")

    user = await db.get(User, uuid.UUID(user_id))
    if user is None or not user.is_active:
        raise InvalidTokenError("User not found or inactive")
    return user


async def get_current_user_from_refresh(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> str:
    try:
        payload = decode_token(credentials.credentials)
        if payload.get("type") != "refresh":
            raise InvalidTokenError("Invalid token type")
        jti = payload["jti"]
    except JWTError:
        raise InvalidTokenError("Invalid or expired token")
    except KeyError:
        raise InvalidTokenError("Invalid token payload")

    result = await db.execute(select(RefreshToken).where(RefreshToken.jti == jti))
    token_record = result.scalar_one_or_none()
    if token_record is None or token_record.is_revoked:
        raise InvalidTokenError("Token revoked or not found")
    return credentials.credentials


def require_role(*roles: UserRole):
    """Factory: require_role(UserRole.ADMIN) returns a FastAPI dependency."""

    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in roles:
            raise ForbiddenError("Insufficient permissions")
        return current_user

    return role_checker
