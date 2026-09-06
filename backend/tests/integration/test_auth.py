import pytest

from app.models.user import User, UserRole


@pytest.mark.asyncio
async def test_register_creates_user(client):
    response = await client.post(
        "/auth/register",
        json={"email": "newuser@test.com", "password": "password123", "role": "CLIENT"},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "newuser@test.com"
    assert data["role"] == "CLIENT"
    assert data["is_active"] is True
    assert "hashed_password" not in data


@pytest.mark.asyncio
async def test_register_duplicate_email_returns_409(client):
    payload = {"email": "dup@test.com", "password": "password123"}
    await client.post("/auth/register", json=payload)
    response = await client.post("/auth/register", json=payload)
    assert response.status_code == 409
    assert response.json()["code"] == "CONFLICT"


@pytest.mark.asyncio
async def test_login_returns_tokens(client):
    await client.post(
        "/auth/register",
        json={"email": "login@test.com", "password": "password123"},
    )
    response = await client.post(
        "/auth/login",
        json={"email": "login@test.com", "password": "password123"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data


@pytest.mark.asyncio
async def test_login_wrong_password_returns_401(client):
    await client.post(
        "/auth/register",
        json={"email": "wrongpw@test.com", "password": "password123"},
    )
    response = await client.post(
        "/auth/login",
        json={"email": "wrongpw@test.com", "password": "incorrect"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_protected_route_without_token_returns_401(client):
    response = await client.get("/auth/me")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_me_with_valid_token_returns_profile(client):
    await client.post(
        "/auth/register",
        json={"email": "me@test.com", "password": "password123"},
    )
    login = await client.post(
        "/auth/login",
        json={"email": "me@test.com", "password": "password123"},
    )
    token = login.json()["access_token"]
    response = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["email"] == "me@test.com"


@pytest.mark.asyncio
async def test_refresh_rotation_returns_new_tokens(client):
    await client.post(
        "/auth/register",
        json={"email": "rot@test.com", "password": "password123"},
    )
    login = await client.post(
        "/auth/login",
        json={"email": "rot@test.com", "password": "password123"},
    )
    tokens = login.json()
    response = await client.post(
        "/auth/refresh",
        headers={"Authorization": f"Bearer {tokens['refresh_token']}"},
    )
    assert response.status_code == 200
    assert "access_token" in response.json()


@pytest.mark.asyncio
async def test_logout_invalidates_refresh_token(client):
    await client.post(
        "/auth/register",
        json={"email": "logout@test.com", "password": "password123"},
    )
    login = await client.post(
        "/auth/login",
        json={"email": "logout@test.com", "password": "password123"},
    )
    tokens = login.json()
    refresh_header = {"Authorization": f"Bearer {tokens['refresh_token']}"}
    await client.post("/auth/logout", headers=refresh_header)
    response = await client.post("/auth/refresh", headers=refresh_header)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_role_based_access_control(client):
    await client.post(
        "/auth/register",
        json={"email": "admin@test.com", "password": "password123", "role": "ADMIN"},
    )
    login = await client.post(
        "/auth/login",
        json={"email": "admin@test.com", "password": "password123"},
    )
    token = login.json()["access_token"]
    response = await client.get(
        "/auth/me", headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    assert response.json()["role"] == "ADMIN"
