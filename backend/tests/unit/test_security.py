from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)


def test_hash_password_returns_bcrypt_hash():
    hashed = hash_password("password123")
    assert hashed.startswith("$2b$")
    assert hashed != "password123"


def test_verify_password_roundtrip():
    hashed = hash_password("password123")
    assert verify_password("password123", hashed) is True
    assert verify_password("wrong", hashed) is False


def test_hash_password_cost_factor_is_12():
    hashed = hash_password("password123")
    # bcrypt hash format: $2b$12$...
    assert hashed.split("$")[2] == "12"


def test_access_token_payload_contains_user_id_and_role():
    token = create_access_token("user-123", "CLIENT")
    payload = decode_token(token)
    assert payload["sub"] == "user-123"
    assert payload["role"] == "CLIENT"
    assert payload["type"] == "access"


def test_refresh_token_returns_token_and_jti():
    token, jti = create_refresh_token("user-123")
    payload = decode_token(token)
    assert payload["jti"] == jti
    assert payload["type"] == "refresh"
    assert payload["sub"] == "user-123"
