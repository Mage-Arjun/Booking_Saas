import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.core.logging import logger
from app.models.organization import OrganizationMembership
from app.models.provider_profile import ProviderProfile
from app.models.user import User, UserRole


async def create_provider_profile(
    db: AsyncSession,
    user_id: uuid.UUID,
    organization_id: uuid.UUID,
    display_name: str,
    bio: str | None = None,
    category: str | None = None,
    location: dict | None = None,
    timezone: str = "UTC",
    booking_buffer_before_minutes: int = 0,
    booking_buffer_after_minutes: int = 0,
    minimum_notice_hours: int = 1,
    max_advance_days: int = 30,
    cancellation_notice_hours: int = 24,
    allow_same_day_cancellation: bool = False,
) -> ProviderProfile:
    # Verify user exists and has PROVIDER role
    user = await db.get(User, user_id)
    if user is None:
        raise NotFoundError("User not found")
    if user.role != UserRole.PROVIDER:
        raise ForbiddenError("User must have PROVIDER role to create provider profile")

    # Verify user is member of the organization
    membership = await db.execute(
        select(OrganizationMembership).where(
            OrganizationMembership.organization_id == organization_id,
            OrganizationMembership.user_id == user_id,
        )
    )
    if membership.scalar_one_or_none() is None:
        raise ForbiddenError("User is not a member of this organization")

    # Check if profile already exists
    existing = await db.execute(
        select(ProviderProfile).where(
            ProviderProfile.user_id == user_id,
            ProviderProfile.organization_id == organization_id,
        )
    )
    if existing.scalar_one_or_none():
        raise ConflictError("Provider profile already exists for this user in this organization")

    profile = ProviderProfile(
        user_id=user_id,
        organization_id=organization_id,
        display_name=display_name,
        bio=bio,
        category=category,
        location=location,
        timezone=timezone,
        booking_buffer_before_minutes=booking_buffer_before_minutes,
        booking_buffer_after_minutes=booking_buffer_after_minutes,
        minimum_notice_hours=minimum_notice_hours,
        max_advance_days=max_advance_days,
        cancellation_notice_hours=cancellation_notice_hours,
        allow_same_day_cancellation=allow_same_day_cancellation,
    )
    db.add(profile)
    await db.flush()
    logger.info(
        "provider.create",
        profile_id=str(profile.id),
        user_id=str(user_id),
        org_id=str(organization_id),
    )
    return profile


async def get_provider_profile(db: AsyncSession, profile_id: uuid.UUID) -> ProviderProfile:
    profile = await db.get(ProviderProfile, profile_id)
    if profile is None:
        raise NotFoundError("Provider profile not found")
    return profile


async def get_provider_in_org(
    db: AsyncSession, organization_id: uuid.UUID, profile_id: uuid.UUID
) -> ProviderProfile | None:
    result = await db.execute(
        select(ProviderProfile).where(
            ProviderProfile.id == profile_id,
            ProviderProfile.organization_id == organization_id,
        )
    )
    return result.scalar_one_or_none()


async def update_provider_profile(
    db: AsyncSession,
    profile_id: uuid.UUID,
    user_id: uuid.UUID,
    **kwargs,
) -> ProviderProfile:
    profile = await get_provider_profile(db, profile_id)
    if profile.user_id != user_id:
        raise ForbiddenError("Can only update your own provider profile")

    for key, value in kwargs.items():
        if value is not None:
            setattr(profile, key, value)
    await db.flush()
    return profile


async def list_providers(
    db: AsyncSession,
    skip: int = 0,
    limit: int = 20,
    category: str | None = None,
    organization_id: uuid.UUID | None = None,
) -> list[ProviderProfile]:
    query = select(ProviderProfile).where(ProviderProfile.is_active)
    if category:
        query = query.where(ProviderProfile.category == category)
    if organization_id:
        query = query.where(ProviderProfile.organization_id == organization_id)
    query = query.offset(skip).limit(limit).order_by(ProviderProfile.created_at.desc())
    result = await db.execute(query)
    return list(result.scalars().all())


async def count_providers(
    db: AsyncSession,
    category: str | None = None,
    organization_id: uuid.UUID | None = None,
) -> int:
    query = select(ProviderProfile).where(ProviderProfile.is_active)
    if category:
        query = query.where(ProviderProfile.category == category)
    if organization_id:
        query = query.where(ProviderProfile.organization_id == organization_id)
    result = await db.execute(query)
    return len(list(result.scalars().all()))


async def verify_provider_ownership(
    db: AsyncSession,
    profile_id: uuid.UUID,
    user_id: uuid.UUID,
) -> ProviderProfile:
    profile = await get_provider_profile(db, profile_id)
    if profile.user_id != user_id:
        raise ForbiddenError("Not your provider profile")
    return profile