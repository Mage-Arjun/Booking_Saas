import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.pagination import PaginatedResponse, PaginationParams
from app.models.organization import MembershipRole
from app.models.user import User
from app.schemas.organization import (
    OrganizationCreate,
    OrganizationMemberAdd,
    OrganizationMemberResponse,
    OrganizationResponse,
    OrganizationUpdate,
)
from app.schemas.provider import ProviderListResponse
from app.services import organization_service, provider_service

router = APIRouter(prefix="/organizations", tags=["organizations"])


@router.post("", response_model=OrganizationResponse, status_code=status.HTTP_201_CREATED)
async def create_organization(
    payload: OrganizationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    org = await organization_service.create_organization(
        db,
        name=payload.name,
        slug=payload.slug,
        owner_id=current_user.id,
        description=payload.description,
    )
    return org


@router.get("/{org_id}", response_model=OrganizationResponse)
async def get_organization(
    org_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await organization_service.verify_org_membership(db, current_user.id, org_id)
    org = await organization_service.get_organization(db, org_id)
    return org


@router.patch("/{org_id}", response_model=OrganizationResponse)
async def update_organization(
    org_id: uuid.UUID,
    payload: OrganizationUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await organization_service.verify_org_membership(
        db, current_user.id, org_id, {MembershipRole.OWNER, MembershipRole.ADMIN}
    )
    org = await organization_service.update_organization(
        db, org_id, name=payload.name, description=payload.description
    )
    return org


@router.post(
    "/{org_id}/members",
    response_model=OrganizationMemberResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_member(
    org_id: uuid.UUID,
    payload: OrganizationMemberAdd,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    membership = await organization_service.add_member(
        db, org_id, payload.user_id, MembershipRole(payload.role), current_user.id
    )
    return membership


@router.delete("/{org_id}/members/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_member(
    org_id: uuid.UUID,
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await organization_service.remove_member(db, org_id, user_id, current_user.id)


@router.get("/{org_id}/members", response_model=PaginatedResponse[OrganizationMemberResponse])
async def list_members(
    org_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    pagination: PaginationParams = Depends(),
):
    await organization_service.verify_org_membership(db, current_user.id, org_id)
    members = await organization_service.get_members(db, org_id)
    return PaginatedResponse(
        total=len(members),
        items=members[pagination.skip : pagination.skip + pagination.limit],
        skip=pagination.skip,
        limit=pagination.limit,
    )


@router.get("/{org_id}/providers", response_model=PaginatedResponse[ProviderListResponse])
async def list_org_providers(
    org_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    pagination: PaginationParams = Depends(),
):
    await organization_service.verify_org_membership(db, current_user.id, org_id)
    providers = await provider_service.list_providers(
        db, skip=pagination.skip, limit=pagination.limit, organization_id=org_id
    )
    total = await provider_service.count_providers(db, organization_id=org_id)
    return PaginatedResponse(
        total=total,
        items=providers,
        skip=pagination.skip,
        limit=pagination.limit,
    )