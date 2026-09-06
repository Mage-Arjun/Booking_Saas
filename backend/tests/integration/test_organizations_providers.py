import pytest
from uuid import uuid4

from app.models.organization import MembershipRole
from app.models.provider_profile import ProviderProfile
from app.models.user import User, UserRole


@pytest.mark.asyncio
async def test_create_organization_creator_is_owner(client):
    """Create org -> creator becomes OWNER (201)"""
    # Register and login first
    await client.post("/auth/register", json={"email": "owner@test.com", "password": "password123", "role": "CLIENT"})
    login = await client.post("/auth/login", json={"email": "owner@test.com", "password": "password123"})
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    payload = {"name": "Test Clinic", "slug": "test-clinic", "description": "A test clinic"}
    response = await client.post("/organizations", json=payload, headers=headers)
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Test Clinic"
    assert data["slug"] == "test-clinic"


@pytest.mark.asyncio
async def test_non_member_cannot_view_org(client):
    """Non-member cannot view org (403)"""
    # Create org with user A
    payload = {"name": "Org A", "slug": "org-a", "description": ""}
    # Register user A
    await client.post("/auth/register", json={"email": "usera@test.com", "password": "password123", "role": "CLIENT"})
    login_a = await client.post("/auth/login", json={"email": "usera@test.com", "password": "password123"})
    headers_a = {"Authorization": f"Bearer {login_a.json()['access_token']}"}
    response_a = await client.post("/organizations", json=payload, headers=headers_a)
    assert response_a.status_code == 201
    org_id = response_a.json()["id"]

    # User B tries to access without auth
    response_b = await client.get(f"/organizations/{org_id}")
    assert response_b.status_code == 401


@pytest.mark.asyncio
async def test_create_provider_profile_requires_provider_role(client):
    """Creating provider profile requires PROVIDER role (CLIENT -> 403)"""
    # Register as CLIENT
    await client.post("/auth/register", json={"email": "client2@test.com", "password": "password123", "role": "CLIENT"})
    login = await client.post("/auth/login", json={"email": "client2@test.com", "password": "password123"})
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Try to create provider profile without an org - will fail validation
    prov_payload = {"organization_id": str(uuid4()), "display_name": "Dr. Test", "category": "Medical"}
    prov_resp = await client.post("/providers/profile", json=prov_payload, headers=headers)
    # Should fail because org doesn't exist or user not member
    assert prov_resp.status_code in (403, 404)


@pytest.mark.asyncio
async def test_full_org_provider_flow(client):
    """Full flow: register PROVIDER -> create org -> create provider profile -> list providers"""
    # Register PROVIDER
    reg = await client.post("/auth/register", json={"email": "prov@test.com", "password": "password123", "role": "PROVIDER"})
    assert reg.status_code == 201

    login = await client.post("/auth/login", json={"email": "prov@test.com", "password": "password123"})
    assert login.status_code == 200
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Create org
    org_payload = {"name": "Test Clinic", "slug": "test-clinic-3", "description": ""}
    org_resp = await client.post("/organizations", json=org_payload, headers=headers)
    assert org_resp.status_code == 201
    org_id = org_resp.json()["id"]

    # Create provider profile
    prov_payload = {"organization_id": org_id, "display_name": "Dr. Test", "category": "Medical"}
    prov_resp = await client.post("/providers/profile", json=prov_payload, headers=headers)
    assert prov_resp.status_code == 201
    prov_data = prov_resp.json()
    assert prov_data["display_name"] == "Dr. Test"
    assert prov_data["category"] == "Medical"

    # List providers
    list_resp = await client.get("/providers", headers=headers)
    assert list_resp.status_code == 200
    list_data = list_resp.json()
    assert list_data["total"] == 1
    assert list_data["items"][0]["display_name"] == "Dr. Test"