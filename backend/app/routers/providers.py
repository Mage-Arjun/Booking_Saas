import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.pagination import PaginatedResponse, PaginationParams
from app.models.user import User
from app.schemas.provider import (
    ProviderListResponse,
    ProviderProfileCreate,
    ProviderProfileResponse,
    ProviderProfileUpdate,
)
from app.services import provider_service

router = APIRouter(prefix="/providers", tags=["providers"])


@router.post(
    "/profile",
    response_model=ProviderProfileResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_provider_profile(
    payload: ProviderProfileCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    profile = await provider_service.create_provider_profile(
        db,
        user_id=current_user.id,
        organization_id=payload.organization_id,
        display_name=payload.display_name,
        bio=payload.bio,
        category=payload.category,
        location=payload.location,
        timezone=payload.timezone,
        booking_buffer_before_minutes=payload.booking_buffer_before_minutes,
        booking_buffer_after_minutes=payload.booking_buffer_after_minutes,
        minimum_notice_hours=payload.minimum_notice_hours,
        max_advance_days=payload.max_advance_days,
        cancellation_notice_hours=payload.cancellation_notice_hours,
        allow_same_day_cancellation=payload.allow_same_day_cancellation,
    )
    return profile


@router.get("", response_model=PaginatedResponse[ProviderListResponse])
async def list_providers(
    pagination: PaginationParams = Depends(),
    category: str | None = Query(None),
    organization_id: uuid.UUID | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    providers = await provider_service.list_providers(
        db,
        skip=pagination.skip,
        limit=pagination.limit,
        category=category,
        organization_id=organization_id,
    )
    total = await provider_service.count_providers(
        db, category=category, organization_id=organization_id
    )
    return PaginatedResponse(
        total=total,
        items=providers,
        skip=pagination.skip,
        limit=pagination.limit,
    )


@router.get("/{provider_id}", response_model=ProviderProfileResponse)
async def get_provider(
    provider_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    return await provider_service.get_provider_profile(db, provider_id)


@router.patch("/{provider_id}", response_model=ProviderProfileResponse)
async def update_provider_profile(
    provider_id: uuid.UUID,
    payload: ProviderProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await provider_service.verify_provider_ownership(db, provider_id, current_user.id)
    update_data = payload.model_dump(exclude_unset=True)
    profile = await provider_service.update_provider_profile(
        db, provider_id, current_user.id, **update_data
    )
    return profile