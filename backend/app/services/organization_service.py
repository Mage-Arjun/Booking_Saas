import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.core.logging import logger
from app.models.organization import MembershipRole, Organization, OrganizationMembership
from app.models.user import User


async def create_organization(
    db: AsyncSession, name: str, slug: str, owner_id: uuid.UUID, description: str | None = None
) -> Organization:
    existing = await db.execute(select(Organization).where(Organization.slug == slug))
    if existing.scalar_one_or_none():
        raise ConflictError("Organization slug already taken")

    org = Organization(
        name=name, slug=slug, description=description, owner_id=owner_id
    )
    db.add(org)
    await db.flush()

    # Add creator as OWNER
    membership = OrganizationMembership(
        organization_id=org.id,
        user_id=owner_id,
        role=MembershipRole.OWNER,
    )
    db.add(membership)
    await db.flush()

    logger.info("org.create", org_id=str(org.id), owner_id=str(owner_id))
    return org


async def get_organization(db: AsyncSession, org_id: uuid.UUID) -> Organization:
    org = await db.get(Organization, org_id)
    if org is None:
        raise NotFoundError("Organization not found")
    return org


async def update_organization(
    db: AsyncSession, org_id: uuid.UUID, name: str | None, description: str | None
) -> Organization:
    org = await get_organization(db, org_id)
    if name is not None:
        org.name = name
    if description is not None:
        org.description = description
    await db.flush()
    return org


async def get_membership(
    db: AsyncSession, org_id: uuid.UUID, user_id: uuid.UUID
) -> OrganizationMembership | None:
    result = await db.execute(
        select(OrganizationMembership).where(
            OrganizationMembership.organization_id == org_id,
            OrganizationMembership.user_id == user_id,
        )
    )
    return result.scalar_one_or_none()


async def add_member(
    db: AsyncSession,
    org_id: uuid.UUID,
    user_id: uuid.UUID,
    role: MembershipRole,
    actor_id: uuid.UUID,
) -> OrganizationMembership:
    # Verify actor has permission (OWNER or ADMIN)
    actor_membership = await get_membership(db, org_id, actor_id)
    if actor_membership is None or actor_membership.role not in (
        MembershipRole.OWNER,
        MembershipRole.ADMIN,
    ):
        raise ForbiddenError("Insufficient permissions to add members")

    # Check target user exists
    user = await db.get(User, user_id)
    if user is None:
        raise NotFoundError("User not found")

    # Check if already a member
    existing = await get_membership(db, org_id, user_id)
    if existing:
        raise ConflictError("User is already a member of this organization")

    membership = OrganizationMembership(
        organization_id=org_id,
        user_id=user_id,
        role=role,
    )
    db.add(membership)
    await db.flush()
    logger.info("org.member_add", org_id=str(org_id), user_id=str(user_id), role=role.value)
    return membership


async def remove_member(
    db: AsyncSession,
    org_id: uuid.UUID,
    user_id: uuid.UUID,
    actor_id: uuid.UUID,
) -> None:
    # Only OWNER can remove members
    actor_membership = await get_membership(db, org_id, actor_id)
    if actor_membership is None or actor_membership.role != MembershipRole.OWNER:
        raise ForbiddenError("Only organization owner can remove members")

    # Cannot remove owner
    if user_id == actor_id:
        raise ForbiddenError("Cannot remove yourself as owner")

    membership = await get_membership(db, org_id, user_id)
    if membership is None:
        raise NotFoundError("Member not found")

    await db.delete(membership)
    await db.flush()
    logger.info("org.member_remove", org_id=str(org_id), user_id=str(user_id))


async def get_members(
    db: AsyncSession, org_id: uuid.UUID
) -> list[OrganizationMembership]:
    result = await db.execute(
        select(OrganizationMembership).where(
            OrganizationMembership.organization_id == org_id
        )
    )
    return list(result.scalars().all())


async def verify_org_membership(
    db: AsyncSession,
    user_id: uuid.UUID,
    org_id: uuid.UUID,
    required_roles: set[MembershipRole] | None = None,
) -> OrganizationMembership:
    membership = await get_membership(db, org_id, user_id)
    if membership is None:
        raise ForbiddenError("Not a member of this organization")
    if required_roles and membership.role not in required_roles:
        raise ForbiddenError("Insufficient permissions")
    return membership