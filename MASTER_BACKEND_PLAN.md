# Booking SaaS — Master Backend Implementation Plan

> **Single source of truth for backend.**
> Synthesizes README.md, PLAN.md, and BACKEND_PLAN.md.
> Philosophy: *Small scope, serious engineering. One brick at a time. Every brick solid before the next.*

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Technology Stack](#2-technology-stack)
3. [Engineering Rules (Non-Negotiable)](#3-engineering-rules-non-negotiable)
4. [Security Baseline](#4-security-baseline)
5. [Phase 0 — Foundation](#5-phase-0--foundation)
6. [Phase 1 — Identity & Access](#6-phase-1--identity--access)
7. [Phase 2 — Organizations & Provider Setup](#7-phase-2--organizations--provider-setup)
8. [Phase 3 — Services & Scheduling](#8-phase-3--services--scheduling)
9. [Phase 4 — Marketplace & Booking](#9-phase-4--marketplace--booking)
10. [Phase 5 — Booking Operations](#10-phase-5--booking-operations)
11. [Phase 6 — Trust & Notifications](#11-phase-6--trust--notifications)
12. [Phase 7 — SaaS & Monetization](#12-phase-7--saas--monetization)
13. [Phase 8 — Production Launch](#13-phase-8--production-launch)
14. [Phase 9 — Online Meetings](#14-phase-9--online-meetings)
15. [Phase 10 — Platform Expansion](#15-phase-10--platform-expansion)
16. [Cross-Cutting Concerns](#16-cross-cutting-concerns)
17. [Release Timeline](#17-release-timeline)

---

## 1. Architecture Overview

### 1.1 Pattern: Modular Monolith

A single FastAPI application with domain-separated modules. Each domain owns its models, schemas, services, and routers. All modules share one PostgreSQL database and one process.

```
backend/
├── app/
│   ├── main.py                    # App factory, lifespan, middleware, router registration
│   ├── core/
│   │   ├── config.py              # pydantic-settings: all environment variables
│   │   ├── database.py            # SQLAlchemy async engine + session factory
│   │   ├── security.py            # JWT encode/decode, password hashing
│   │   ├── deps.py                # Shared FastAPI dependencies (get_db, get_current_user)
│   │   ├── exceptions.py          # Custom exception hierarchy + FastAPI handlers
│   │   ├── logging.py             # structlog structured JSON logging
│   │   └── pagination.py          # Reusable pagination params + generic response
│   ├── models/                    # SQLAlchemy ORM models (centralized for Alembic)
│   │   ├── base.py                # DeclarativeBase + TimestampMixin
│   │   ├── user.py
│   │   ├── organization.py
│   │   ├── provider_profile.py
│   │   ├── service.py
│   │   ├── availability.py
│   │   ├── booking.py
│   │   ├── review.py
│   │   ├── notification.py
│   │   ├── audit_log.py
│   │   └── subscription.py
│   ├── schemas/                   # Pydantic v2 request/response schemas
│   │   ├── auth.py
│   │   ├── user.py
│   │   ├── organization.py
│   │   ├── provider.py
│   │   ├── service.py
│   │   ├── availability.py
│   │   ├── booking.py
│   │   ├── review.py
│   │   ├── notification.py
│   │   └── admin.py
│   ├── services/                  # Business logic — no HTTP concerns
│   │   ├── auth_service.py
│   │   ├── user_service.py
│   │   ├── organization_service.py
│   │   ├── provider_service.py
│   │   ├── service_service.py
│   │   ├── availability_engine.py  # Core slot computation algorithm
│   │   ├── booking_service.py      # Double-booking protection lives here
│   │   ├── review_service.py
│   │   ├── notification_service.py
│   │   └── admin_service.py
│   └── routers/                   # FastAPI routers — thin HTTP controllers only
│       ├── health.py
│       ├── auth.py
│       ├── users.py
│       ├── organizations.py
│       ├── providers.py
│       ├── services.py
│       ├── availability.py
│       ├── bookings.py
│       ├── reviews.py
│       ├── notifications.py
│       └── admin.py
├── alembic/
│   ├── env.py                     # Imports Base + all models for autogenerate
│   ├── script.py.mako
│   └── versions/
├── alembic.ini
├── tests/
│   ├── conftest.py                # Async test DB setup, shared fixtures
│   ├── unit/
│   │   ├── test_availability_engine.py
│   │   ├── test_booking_state_machine.py
│   │   └── test_password_hashing.py
│   ├── integration/
│   │   ├── test_auth.py
│   │   ├── test_bookings.py
│   │   ├── test_organizations.py
│   │   ├── test_providers.py
│   │   └── test_concurrent_bookings.py
│   └── fixtures/
│       ├── users.py
│       └── organizations.py
├── pyproject.toml
├── requirements.txt
├── .env.example
└── docker-compose.yml
```

### 1.2 Layer Rules

| Layer | Responsibility | Rule |
|-------|---------------|------|
| **Routers** | Parse HTTP request, call one service method, return HTTP response | Zero business logic |
| **Services** | Own all business logic | Testable without HTTP |
| **Models** | SQLAlchemy ORM mapping | No business logic |
| **Schemas** | Pydantic v2 API contract | Never expose SQLAlchemy internals |
| **Core** | Shared infrastructure | Config, DB, security, deps |

---

## 2. Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | FastAPI | ≥ 0.115.0 |
| Server | Uvicorn | ≥ 0.30.0 |
| ORM | SQLAlchemy (async) | ≥ 2.0.0 |
| DB Driver | asyncpg | ≥ 0.29.0 |
| Database | PostgreSQL | 16 |
| Migrations | Alembic | ≥ 1.13.0 |
| Config | pydantic-settings | ≥ 2.0.0 |
| Validation | Pydantic v2 | ≥ 2.0.0 |
| Auth | python-jose[cryptography] | ≥ 3.3.0 |
| Hashing | passlib[bcrypt] | ≥ 1.7.4 |
| HTTP Test Client | httpx | ≥ 0.27.0 |
| Logging | structlog | ≥ 24.0.0 |
| Testing | pytest + pytest-asyncio | ≥ 8.0.0 / 0.23.0 |
| Linting | ruff | latest |
| Type Checking | mypy | latest |
| Python | CPython | 3.12 |

**requirements.txt:**
```
fastapi>=0.115.0
uvicorn[standard]>=0.30.0
sqlalchemy[asyncio]>=2.0.0
asyncpg>=0.29.0
alembic>=1.13.0
pydantic-settings>=2.0.0
pydantic[email]>=2.0.0
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
httpx>=0.27.0
structlog>=24.0.0
pytest>=8.0.0
pytest-asyncio>=0.23.0
ruff
mypy
```

---

## 3. Engineering Rules (Non-Negotiable)

1. Every endpoint touching org-scoped data MUST filter by `organization_id`.
2. No business logic in route handlers. Services own the logic.
3. All passwords bcrypt-hashed with cost ≥ 12.
4. JWT payload contains only `user_id` and `role`. No email, no permissions.
5. Every mutation is wrapped in a transaction. No partial writes.
6. Every list endpoint has pagination. No unbounded queries.
7. Every error returns a consistent JSON structure `{"detail": "...", "code": "..."}`.
8. Every migration has a rollback path.
9. Every feature has tests before it is considered done.
10. No secrets in source code. Ever.
11. All timestamps stored as UTC (`TIMESTAMPTZ`).
12. The availability engine lives entirely in the backend. Flutter only displays what the engine returns.

---

## 4. Security Baseline

Applied from Phase 0 onwards. These are not optional:

| Concern | Implementation |
|---------|---------------|
| Password hashing | bcrypt, cost factor 12 |
| Access token | JWT, 30 min expiry, contains `user_id` + `role` only |
| Refresh token | JWT, 7 days, rotated on every use |
| Token revocation | DB-backed `refresh_tokens` table with `is_revoked` flag — survives multi-process deployments |
| Rate limiting | `/auth/login`: 5/min/IP; `/auth/register`: 3/min/IP — in-process sliding window initially |
| Tenant isolation | `organization_id` filter in every org-scoped service call |
| Input validation | Pydantic v2 on all request bodies; FastAPI validates query params |
| Error responses | No stack traces, no internal details exposed to client |
| HTTPS | Enforced in all non-local environments |
| Audit logging | Login, logout, role changes, booking state changes, org changes |

---

## 5. Phase 0 — Foundation

**Goal:** FastAPI connects to PostgreSQL. Migrations run. Health endpoint returns 200.

**Proof:**
```
Flutter → FastAPI (health) → PostgreSQL (connection verified)
```

### 5.1 Docker Compose

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: booking_user
      POSTGRES_PASSWORD: booking_password
      POSTGRES_DB: booking_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
volumes:
  postgres_data:
```

### 5.2 Configuration (`core/config.py`)

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    app_name: str = "Booking SaaS"
    app_version: str = "0.1.0"
    debug: bool = False

    database_url: str
    secret_key: str           # No default — MUST be set in .env
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
    allowed_origins: list[str] = ["http://localhost:3000"]

settings = Settings()
```

### 5.3 Database (`core/database.py`)

```python
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.core.config import settings

engine = create_async_engine(settings.database_url, echo=settings.debug)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def get_db():
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

### 5.4 Base Model (`models/base.py`)

```python
import uuid
from datetime import datetime
from sqlalchemy import DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase):
    pass

class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
```

### 5.5 Health Endpoint (`routers/health.py`)

```python
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.config import settings

router = APIRouter()

@router.get("/health")
async def health(db: AsyncSession = Depends(get_db)):
    try:
        await db.execute(select(1))
        db_ok = True
    except Exception:
        db_ok = False
    return {
        "status": "healthy" if db_ok else "degraded",
        "database": "ok" if db_ok else "error",
        "version": settings.app_version,
    }
```

### 5.6 Alembic Setup

```bash
alembic init alembic
# Edit alembic.ini: sqlalchemy.url = use settings.database_url
# Edit alembic/env.py: import Base + all models for autogenerate
alembic revision --autogenerate -m "initial"
alembic upgrade head
```

### 5.7 Checklist

- [ ] `docker-compose.yml` with PostgreSQL
- [ ] `core/config.py` with pydantic-settings
- [ ] `core/database.py` async engine
- [ ] `models/base.py` with `TimestampMixin`
- [ ] `GET /health` returns 200 + DB ping
- [ ] Alembic configured and first migration runs
- [ ] App starts with `uvicorn app.main:app --reload`

---

## 6. Phase 1 — Identity & Access

**Goal:** Registration, login, JWT auth, RBAC, refresh token revocation.

### 6.1 Database Schema

```sql
CREATE TYPE user_role AS ENUM ('CLIENT', 'PROVIDER', 'ADMIN');

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT NOT NULL UNIQUE,
    hashed_password TEXT NOT NULL,
    role            user_role NOT NULL DEFAULT 'CLIENT',
    is_active       BOOLEAN NOT NULL DEFAULT true,
    is_verified     BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_email ON users (email);

-- DB-backed token revocation (works in multi-process, multi-server deployments)
CREATE TABLE refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    jti         TEXT NOT NULL UNIQUE,        -- JWT "jti" claim uniquely identifies the token
    is_revoked  BOOLEAN NOT NULL DEFAULT false,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_refresh_tokens_jti  ON refresh_tokens (jti);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens (user_id, is_revoked);
```

### 6.2 SQLAlchemy Models

```python
# models/user.py
import enum, uuid
from sqlalchemy import String, Boolean, Enum
from sqlalchemy.orm import Mapped, mapped_column
from app.models.base import Base, TimestampMixin

class UserRole(str, enum.Enum):
    CLIENT   = "CLIENT"
    PROVIDER = "PROVIDER"
    ADMIN    = "ADMIN"

class User(TimestampMixin, Base):
    __tablename__ = "users"
    id:              Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email:           Mapped[str]       = mapped_column(String, unique=True, nullable=False, index=True)
    hashed_password: Mapped[str]       = mapped_column(String, nullable=False)
    role:            Mapped[UserRole]  = mapped_column(Enum(UserRole), nullable=False, default=UserRole.CLIENT)
    is_active:       Mapped[bool]      = mapped_column(Boolean, nullable=False, default=True)
    is_verified:     Mapped[bool]      = mapped_column(Boolean, nullable=False, default=False)

# models/refresh_token.py
class RefreshToken(Base):
    __tablename__ = "refresh_tokens"
    id:         Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id:    Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    jti:        Mapped[str]       = mapped_column(String, unique=True, nullable=False)
    is_revoked: Mapped[bool]      = mapped_column(Boolean, nullable=False, default=False)
    expires_at: Mapped[datetime]  = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime]  = mapped_column(DateTime(timezone=True), server_default=func.now())
```

### 6.3 Security (`core/security.py`)

```python
import uuid
from datetime import datetime, timedelta, timezone
from passlib.context import CryptContext
from jose import jwt, JWTError
from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def create_access_token(user_id: str, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    return jwt.encode(
        {"sub": user_id, "role": role, "exp": expire, "type": "access"},
        settings.secret_key, algorithm=settings.jwt_algorithm,
    )

def create_refresh_token(user_id: str) -> tuple[str, str]:
    """Returns (signed_token, jti). Store jti in DB for revocation tracking."""
    jti = str(uuid.uuid4())
    expire = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    token = jwt.encode(
        {"sub": user_id, "exp": expire, "type": "refresh", "jti": jti},
        settings.secret_key, algorithm=settings.jwt_algorithm,
    )
    return token, jti

def decode_token(token: str) -> dict:
    """Decode and validate JWT. Raises JWTError on failure."""
    return jwt.decode(token, settings.secret_key, algorithms=[settings.jwt_algorithm])
```

### 6.4 Dependencies (`core/deps.py`)

```python
import uuid
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from jose import JWTError
from app.core.database import get_db
from app.core.security import decode_token
from app.models.user import User, UserRole
from app.models.refresh_token import RefreshToken

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    try:
        payload = decode_token(credentials.credentials)
        if payload.get("type") != "access":
            raise HTTPException(status_code=401, detail="Invalid token type")
        user_id = payload["sub"]
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user = await db.get(User, uuid.UUID(user_id))
    if user is None or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or inactive")
    return user

def require_role(*roles: UserRole):
    """Factory: require_role(UserRole.ADMIN) returns a FastAPI dependency."""
    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return current_user
    return role_checker
```

### 6.5 API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/auth/register` | No | Create account |
| `POST` | `/auth/login` | No | Access + refresh tokens |
| `POST` | `/auth/logout` | Yes (refresh token) | Mark refresh token `is_revoked=true` |
| `POST` | `/auth/refresh` | Yes (refresh token) | Rotate refresh; issue new pair |
| `GET` | `/auth/verify-email?token=...` | No | Verify email |
| `POST` | `/auth/forgot-password` | No | Send reset email |
| `POST` | `/auth/reset-password` | No | Reset with token |
| `GET` | `/users/me` | Yes (access token) | Own profile |

### 6.6 Logout / Refresh Token Rotation Logic

```python
# services/auth_service.py

async def logout(db: AsyncSession, refresh_token: str) -> None:
    payload = decode_token(refresh_token)
    jti = payload.get("jti")
    result = await db.execute(
        select(RefreshToken).where(RefreshToken.jti == jti)
    )
    token_record = result.scalar_one_or_none()
    if token_record and not token_record.is_revoked:
        token_record.is_revoked = True
        # committed by get_db session manager

async def rotate_refresh_token(db: AsyncSession, old_refresh_token: str) -> tuple[str, str]:
    """Revoke old refresh token, issue new access + refresh pair."""
    payload = decode_token(old_refresh_token)
    if payload.get("type") != "refresh":
        raise InvalidTokenError("Not a refresh token")

    jti = payload["jti"]
    record = await db.execute(
        select(RefreshToken).where(RefreshToken.jti == jti)
    )
    token_record = record.scalar_one_or_none()
    if token_record is None or token_record.is_revoked:
        raise InvalidTokenError("Token revoked or not found")

    # Revoke old
    token_record.is_revoked = True

    # Issue new pair
    user_id = payload["sub"]
    user = await db.get(User, uuid.UUID(user_id))
    access_token = create_access_token(str(user.id), user.role)
    new_refresh, new_jti = create_refresh_token(str(user.id))

    db.add(RefreshToken(
        user_id=user.id, jti=new_jti,
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days),
    ))
    return access_token, new_refresh
```

### 6.7 Tests

| Test | Expected |
|------|----------|
| Register valid data | 201 |
| Register duplicate email | 409 |
| Login correct credentials | 200, tokens returned |
| Login wrong password | 401 |
| Protected route without token | 401 |
| Expired access token | 401 |
| CLIENT cannot access PROVIDER route | 403 |
| ADMIN can access ADMIN route | 200 |
| Refresh token rotation | 200, new tokens |
| Refresh with revoked token | 401 |
| Logout then use refresh token | 401 |

---

## 7. Phase 2 — Organizations & Provider Setup

**Goal:** Multi-tenant structure. Providers belong to organizations. Data isolation enforced.

### 7.1 Database Schema

```sql
CREATE TABLE organizations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    slug        TEXT NOT NULL UNIQUE,
    description TEXT,
    owner_id    UUID NOT NULL REFERENCES users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TYPE membership_role AS ENUM ('OWNER', 'ADMIN', 'MEMBER');

CREATE TABLE organization_memberships (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role            membership_role NOT NULL DEFAULT 'MEMBER',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organization_id, user_id)
);

CREATE TABLE provider_profiles (
    id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                       UUID NOT NULL REFERENCES users(id),
    organization_id               UUID NOT NULL REFERENCES organizations(id),
    display_name                  TEXT NOT NULL,
    bio                           TEXT,
    category                      TEXT,           -- "Medical", "Legal", "Education" — generic
    location                      JSONB,          -- {address, city, state, country, lat, lng}
    timezone                      TEXT NOT NULL DEFAULT 'UTC',
    is_active                     BOOLEAN NOT NULL DEFAULT true,
    booking_buffer_before_minutes INTEGER NOT NULL DEFAULT 0,
    booking_buffer_after_minutes  INTEGER NOT NULL DEFAULT 0,
    minimum_notice_hours          INTEGER NOT NULL DEFAULT 1,
    max_advance_days              INTEGER NOT NULL DEFAULT 30,
    cancellation_notice_hours     INTEGER NOT NULL DEFAULT 24,
    allow_same_day_cancellation   BOOLEAN NOT NULL DEFAULT false,
    created_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, organization_id)             -- One profile per user per org
);
```

### 7.2 Multi-Tenancy Enforcement Pattern

Every service method touching org-scoped data receives `organization_id` and filters by it. No exceptions.

```python
# services/provider_service.py

async def get_provider_in_org(
    db: AsyncSession,
    organization_id: uuid.UUID,
    provider_id: uuid.UUID,
) -> ProviderProfile | None:
    """Fetch provider ONLY within the given org. Never without the org filter."""
    result = await db.execute(
        select(ProviderProfile).where(
            ProviderProfile.id == provider_id,
            ProviderProfile.organization_id == organization_id,  # CRITICAL
        )
    )
    return result.scalar_one_or_none()

async def verify_org_membership(
    db: AsyncSession,
    user_id: uuid.UUID,
    organization_id: uuid.UUID,
) -> OrganizationMembership | None:
    result = await db.execute(
        select(OrganizationMembership).where(
            OrganizationMembership.user_id == user_id,
            OrganizationMembership.organization_id == organization_id,
        )
    )
    return result.scalar_one_or_none()
```

### 7.3 API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `POST` | `/organizations` | Yes | Any | Create org (creator becomes OWNER) |
| `GET` | `/organizations/{id}` | Yes | Org member | Get org details |
| `PATCH` | `/organizations/{id}` | Yes | Org OWNER/ADMIN | Update org |
| `POST` | `/organizations/{id}/members` | Yes | Org OWNER/ADMIN | Add member |
| `DELETE` | `/organizations/{id}/members/{user_id}` | Yes | Org OWNER | Remove member |
| `POST` | `/providers/profile` | Yes | PROVIDER | Create provider profile |
| `GET` | `/providers/{id}` | No | — | Public provider profile |
| `PATCH` | `/providers/{id}` | Yes | Profile owner | Update own profile |
| `GET` | `/providers` | No | — | List providers (paginated, filterable) |

### 7.4 Tests

| Test | Expected |
|------|----------|
| Create org → user becomes OWNER | 201 |
| Org member can view org | 200 |
| Non-member cannot view org | 403 |
| Provider in Org A reads Org B private data | 403 |
| MEMBER tries to add member | 403 |
| Creating provider profile requires PROVIDER role | 403 for CLIENT |

---

## 8. Phase 3 — Services & Scheduling

**Goal:** Providers define services and availability. Availability engine produces real bookable slots.

### 8.1 Database Schema

```sql
CREATE TABLE services (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id      UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    organization_id  UUID NOT NULL REFERENCES organizations(id),
    name             TEXT NOT NULL,
    description      TEXT,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    price            NUMERIC(10, 2),
    currency         TEXT NOT NULL DEFAULT 'USD',
    is_active        BOOLEAN NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE availability_rules (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),  -- 0 = Sunday
    start_time  TIME NOT NULL,
    end_time    TIME NOT NULL,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (start_time < end_time)
);

CREATE TABLE blocked_periods (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    start_time  TIMESTAMPTZ NOT NULL,
    end_time    TIMESTAMPTZ NOT NULL,
    reason      TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (start_time < end_time)
);
```

### 8.2 Availability Engine Algorithm

The most critical backend component. Lives entirely in `services/availability_engine.py`.

```python
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo
import uuid
from sqlalchemy.ext.asyncio import AsyncSession

@dataclass
class Slot:
    start_utc: datetime
    end_utc: datetime

async def compute_available_slots(
    db: AsyncSession,
    provider_id: uuid.UUID,
    service_id: uuid.UUID,
    requested_date: date,
) -> list[Slot]:
    """
    Compute bookable slots for a provider on a given date.

    Step 1:  Load provider config (timezone, buffers, notice, max_advance)
    Step 2:  Load service (duration_minutes)
    Step 3:  Load availability_rules for requested_date.weekday()
    Step 4:  Load existing PENDING/CONFIRMED bookings overlapping the date
    Step 5:  Load blocked_periods overlapping the date
    Step 6:  Generate candidate slots from working hours at duration_minutes intervals
    Step 7:  Subtract booked intervals (expanded outward by buffer_before + buffer_after)
    Step 8:  Subtract blocked_period intervals
    Step 9:  Filter: drop slots where start_utc < now + minimum_notice_hours
    Step 10: Filter: drop slots where start_utc > now + max_advance_days
    Step 11: Return [{start_utc, end_utc}]
    """
```

### 8.3 Timezone Strategy

```
Storage:     ALL timestamps → UTC in PostgreSQL (TIMESTAMPTZ)
Provider:    timezone field on provider_profiles ("America/New_York")
Engine:      zoneinfo.ZoneInfo for DST-correct conversion
             Working hours applied in provider timezone → converted to UTC
API output:  UTC timestamps only
Flutter:     Converts UTC → device timezone for display
```

> **Why not store in local time?** UTC is unambiguous. DST transitions, daylight saving, and cross-timezone scheduling all become tractable when UTC is the single canonical reference.

### 8.4 API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `POST` | `/services` | Yes | PROVIDER | Create service |
| `GET` | `/providers/{id}/services` | No | — | List provider services |
| `PATCH` | `/services/{id}` | Yes | Service owner | Update service |
| `DELETE` | `/services/{id}` | Yes | Service owner | Deactivate service |
| `POST` | `/availability/rules` | Yes | PROVIDER | Create working hour rule |
| `GET` | `/providers/{id}/availability` | No | — | Computed available slots |
| `POST` | `/availability/blocked` | Yes | PROVIDER | Block a period |
| `GET` | `/providers/{id}/blocked` | Yes | Profile owner | List blocked periods |
| `DELETE` | `/availability/blocked/{id}` | Yes | Profile owner | Remove blocked period |

**GET /providers/{id}/availability params:**
- `date` (required): `YYYY-MM-DD`
- `service_id` (required): UUID

### 8.5 Tests

| Test | Expected |
|------|----------|
| Slots outside working hours not returned | Pass |
| Blocked period removes overlapping slots | Pass |
| Buffer prevents back-to-back overlap | Pass |
| Minimum notice removes near-future slots | Pass |
| Maximum advance hides distant slots | Pass |
| DST transition: correct UTC conversion | Pass |
| Provider and client in different timezones see same real-world moment | Pass |
| No service → 404 | Pass |

---

## 9. Phase 4 — Marketplace & Booking

**Goal:** Customer discovers a provider and creates a booking. Double booking is impossible.

### 9.1 Database Schema

```sql
CREATE TYPE booking_status AS ENUM (
    'PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED', 'NO_SHOW'
);

-- Note: RESCHEDULED is NOT a status. Rescheduling creates a new booking
-- and cancels the old one atomically. Keeps the state machine simple.

CREATE TYPE fulfillment_method AS ENUM ('IN_PERSON', 'ONLINE', 'PHONE');

CREATE TABLE bookings (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id          UUID NOT NULL REFERENCES users(id),
    provider_id        UUID NOT NULL REFERENCES provider_profiles(id),
    service_id         UUID NOT NULL REFERENCES services(id),
    organization_id    UUID NOT NULL REFERENCES organizations(id),
    start_time         TIMESTAMPTZ NOT NULL,
    end_time           TIMESTAMPTZ NOT NULL,
    timezone_context   TEXT NOT NULL,           -- timezone when booking was created
    status             booking_status NOT NULL DEFAULT 'PENDING',
    fulfillment_method fulfillment_method NOT NULL DEFAULT 'IN_PERSON',
    notes              TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (start_time < end_time)
);

-- Partial index: only ACTIVE bookings scanned for conflicts (fast)
CREATE INDEX idx_bookings_provider_overlap
    ON bookings (provider_id, start_time, end_time)
    WHERE status IN ('PENDING', 'CONFIRMED');

CREATE INDEX idx_bookings_client       ON bookings (client_id, start_time DESC);
CREATE INDEX idx_bookings_provider_cal ON bookings (provider_id, start_time DESC);
```

### 9.2 Double-Booking Protection

The most critical business rule. Two concurrent requests for the same slot must not both succeed.

**Strategy: `SELECT ... FOR UPDATE` within a transaction**

```python
# services/booking_service.py

async def create_booking(
    db: AsyncSession,
    client_id: uuid.UUID,
    provider_id: uuid.UUID,
    service_id: uuid.UUID,
    start_time: datetime,
    end_time: datetime,
    timezone_context: str,
    fulfillment_method: str = "IN_PERSON",
) -> Booking:
    # 1. Validate service belongs to provider
    service = await db.get(Service, service_id)
    if not service or service.provider_id != provider_id:
        raise NotFoundError("Service not found for this provider")

    # 2. Validate times match service duration
    expected_end = start_time + timedelta(minutes=service.duration_minutes)
    if abs((end_time - expected_end).total_seconds()) > 60:
        raise ValidationError("end_time does not match service duration")

    # 3. Lock overlapping ACTIVE bookings — prevents race conditions
    existing = await db.execute(
        select(Booking)
        .where(
            Booking.provider_id == provider_id,
            Booking.status.in_([BookingStatus.PENDING, BookingStatus.CONFIRMED]),
            Booking.start_time < end_time,
            Booking.end_time > start_time,
        )
        .with_for_update()   # Row-level lock — serializes concurrent requests
    )
    if existing.scalars().all():
        raise BookingConflictError("Provider is not available for this time slot")

    # 4. Insert — committed by get_db session manager
    booking = Booking(
        client_id=client_id,
        provider_id=provider_id,
        service_id=service_id,
        organization_id=service.organization_id,
        start_time=start_time,
        end_time=end_time,
        timezone_context=timezone_context,
        fulfillment_method=fulfillment_method,
        status=BookingStatus.PENDING,
    )
    db.add(booking)
    await db.flush()
    return booking
```

**Why `SELECT FOR UPDATE` and not serializable isolation:**
- `SELECT FOR UPDATE` is explicit: "lock these specific rows before writing"
- Serializable isolation causes more transaction retries and is harder to debug
- Both are correct approaches; `FOR UPDATE` is more conventional for this pattern in PostgreSQL

### 9.3 POST /bookings Validation Checklist

1. Service belongs to the specified provider
2. `end_time` matches `start_time + service.duration_minutes`
3. Slot has no conflict (double-booking check)
4. `start_time` is in the future + satisfies minimum notice
5. `client_id` from JWT matches the booking (no booking on behalf of others)

### 9.4 API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `GET` | `/providers` | No | — | List providers (paginated, filterable) |
| `GET` | `/providers/{id}` | No | — | Public provider profile |
| `POST` | `/bookings` | Yes | CLIENT | Create booking |
| `GET` | `/bookings/{id}` | Yes | Owner or Provider | Booking detail |

**POST /bookings request body:**
```json
{
  "provider_id": "uuid",
  "service_id": "uuid",
  "start_time": "2026-09-15T14:00:00Z",
  "timezone_context": "America/New_York",
  "fulfillment_method": "IN_PERSON",
  "notes": "optional"
}
```

### 9.5 Tests

| Test | Expected |
|------|----------|
| Concurrent requests for same slot: exactly one succeeds | Pass |
| Booking with invalid service ID | 400 |
| Booking for unavailable slot | 409 |
| CLIENT cannot book on behalf of another CLIENT | 403 |
| PROVIDER cannot use client booking endpoint | 403 |
| Booking respects service duration | Pass |

---

## 10. Phase 5 — Booking Operations

**Goal:** Full appointment lifecycle. Both client and provider manage bookings.

### 10.1 State Machine

```
PENDING   → CONFIRMED  (PROVIDER)
PENDING   → CANCELLED  (CLIENT or PROVIDER)
CONFIRMED → COMPLETED  (PROVIDER, after appointment time)
CONFIRMED → CANCELLED  (CLIENT: within cancellation policy; PROVIDER: always)
CONFIRMED → NO_SHOW    (PROVIDER, after appointment time)
CONFIRMED → [reschedule] → new PENDING booking created + old CANCELLED atomically
```

> **Design decision:** `RESCHEDULED` is NOT a booking status. Rescheduling is implemented as:
> 1. Create new booking (passes double-booking check)
> 2. Cancel old booking
> Both steps in a single transaction.

### 10.2 State Transition Enforcement

```python
# services/booking_service.py

VALID_TRANSITIONS: dict[BookingStatus, set[BookingStatus]] = {
    BookingStatus.PENDING:    {BookingStatus.CONFIRMED, BookingStatus.CANCELLED},
    BookingStatus.CONFIRMED:  {BookingStatus.COMPLETED, BookingStatus.CANCELLED, BookingStatus.NO_SHOW},
    BookingStatus.COMPLETED:  set(),   # terminal
    BookingStatus.CANCELLED:  set(),   # terminal
    BookingStatus.NO_SHOW:    set(),   # terminal
}

def assert_valid_transition(current: BookingStatus, next_status: BookingStatus) -> None:
    if next_status not in VALID_TRANSITIONS.get(current, set()):
        raise ValidationError(f"Cannot transition from {current} to {next_status}")
```

### 10.3 Cancellation Policy

```python
async def can_client_cancel(booking: Booking, provider: ProviderProfile) -> bool:
    now = datetime.now(timezone.utc)
    hours_until_booking = (booking.start_time - now).total_seconds() / 3600
    if not provider.allow_same_day_cancellation and hours_until_booking < 24:
        return False
    return hours_until_booking >= provider.cancellation_notice_hours
```

### 10.4 API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `GET` | `/bookings` | Yes | CLIENT/PROVIDER | List own bookings |
| `GET` | `/bookings/{id}` | Yes | Owner or Provider | Booking detail |
| `PATCH` | `/bookings/{id}/confirm` | Yes | PROVIDER | Confirm |
| `PATCH` | `/bookings/{id}/complete` | Yes | PROVIDER | Mark completed |
| `PATCH` | `/bookings/{id}/cancel` | Yes | CLIENT/PROVIDER | Cancel |
| `PATCH` | `/bookings/{id}/no-show` | Yes | PROVIDER | Mark no-show |
| `POST` | `/bookings/{id}/reschedule` | Yes | CLIENT | New slot (atomic) |
| `GET` | `/providers/me/calendar` | Yes | PROVIDER | Calendar view |
| `PATCH` | `/providers/me/cancellation-policy` | Yes | PROVIDER | Update policy |

**GET /providers/me/calendar params:** `from=YYYY-MM-DD&to=YYYY-MM-DD`

### 10.5 Tests

| Test | Expected |
|------|----------|
| Client cannot cancel after window closes | 403 |
| Provider can cancel any booking | 200 |
| Rescheduling creates new booking + cancels old atomically | 200 |
| Completed booking cannot be cancelled | 400 |
| NO_SHOW only settable after appointment time | 400 |
| Calendar returns bookings in date range | 200 |
| Invalid state transition rejected | 400 |

---

## 11. Phase 6 — Trust & Notifications

**Goal:** Reviews, notifications, audit logs, admin operations.

### 11.1 Reviews Schema

```sql
CREATE TABLE reviews (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id      UUID NOT NULL UNIQUE REFERENCES bookings(id),  -- one review per booking
    client_id       UUID NOT NULL REFERENCES users(id),
    provider_id     UUID NOT NULL REFERENCES provider_profiles(id),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    rating          INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment         TEXT,
    is_flagged      BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_reviews_provider ON reviews (provider_id, created_at DESC);
```

**Eligibility:**
1. Only CLIENT who made the booking can review
2. Only COMPLETED bookings can be reviewed
3. One review per booking (`UNIQUE` on `booking_id`)

### 11.2 Notifications Schema

```sql
CREATE TYPE notification_type AS ENUM (
    'BOOKING_CREATED', 'BOOKING_CONFIRMED', 'BOOKING_CANCELLED',
    'BOOKING_REMINDER_24H', 'BOOKING_REMINDER_1H',
    'REVIEW_RECEIVED', 'SYSTEM'
);

CREATE TABLE notifications (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES users(id),
    type         notification_type NOT NULL,
    payload      JSONB NOT NULL,          -- flexible, type-specific data
    is_read      BOOLEAN NOT NULL DEFAULT false,
    sent_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at      TIMESTAMPTZ
);

CREATE INDEX idx_notifications_recipient ON notifications (recipient_id, is_read, sent_at DESC);
```

**Triggers:**
- Booking created → notify PROVIDER
- Booking confirmed → notify CLIENT
- Booking cancelled → notify other party
- 24h before → notify both CLIENT and PROVIDER
- 1h before → notify both CLIENT and PROVIDER

**Delivery:** Start with email (SMTP or transactional email service). Infrastructure-ready for push notifications.

**Background jobs:** APScheduler (in-process) for reminder scheduling. No Redis required initially. Ensure job failures are logged with `structlog`.

### 11.3 Audit Log Schema

```sql
CREATE TABLE audit_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id    UUID REFERENCES users(id),   -- NULL for system actions
    action      TEXT NOT NULL,               -- "user.login", "booking.confirmed"
    entity_type TEXT,                        -- "Booking", "User"
    entity_id   UUID,
    metadata    JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only: never update or delete audit log records

CREATE INDEX idx_audit_logs_actor  ON audit_logs (actor_id, created_at DESC);
CREATE INDEX idx_audit_logs_entity ON audit_logs (entity_type, entity_id);
```

**What gets audited:**
- Login / logout
- Role changes
- Booking state changes
- Organization changes
- Provider profile changes
- Review flagging / moderation
- Admin actions

### 11.4 Admin Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `GET` | `/admin/users` | Yes | ADMIN | List all users (paginated) |
| `PATCH` | `/admin/users/{id}` | Yes | ADMIN | Activate/deactivate |
| `GET` | `/admin/organizations` | Yes | ADMIN | List all orgs |
| `GET` | `/admin/bookings` | Yes | ADMIN | Operational overview |
| `GET` | `/admin/reviews` | Yes | ADMIN | Review moderation queue |
| `PATCH` | `/admin/reviews/{id}/flag` | Yes | ADMIN | Flag/unflag |
| `GET` | `/admin/audit-logs` | Yes | ADMIN | Audit trail |

### 11.5 Tests

| Test | Expected |
|------|----------|
| Review only on COMPLETED booking | 400 if not completed |
| Duplicate review on same booking | 409 |
| Non-client cannot review | 403 |
| Notifications created on booking events | Pass |
| Audit log entry created on login | Pass |
| Admin can list users | 200 |
| Non-admin cannot access admin endpoints | 403 |

---

## 12. Phase 7 — SaaS & Monetization

**Goal:** Subscription plans, billing, feature entitlements.

> Commercial rules must be validated through market research before implementing pricing. The schema and enforcement logic are built now; pricing values come later.

### 12.1 Database Schema

```sql
CREATE TABLE subscription_plans (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                  TEXT NOT NULL UNIQUE,
    description           TEXT,
    price_monthly         NUMERIC(10, 2) NOT NULL,
    price_yearly          NUMERIC(10, 2),
    currency              TEXT NOT NULL DEFAULT 'USD',
    max_providers         INTEGER,
    max_bookings_monthly  INTEGER,
    features              JSONB NOT NULL DEFAULT '{}',
    is_active             BOOLEAN NOT NULL DEFAULT true,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TYPE subscription_status AS ENUM (
    'TRIALING', 'ACTIVE', 'PAST_DUE', 'CANCELED', 'UNPAID'
);

CREATE TABLE subscriptions (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id        UUID NOT NULL REFERENCES organizations(id),
    plan_id                UUID NOT NULL REFERENCES subscription_plans(id),
    status                 subscription_status NOT NULL DEFAULT 'TRIALING',
    billing_cycle          TEXT NOT NULL DEFAULT 'monthly',
    current_period_start   TIMESTAMPTZ NOT NULL,
    current_period_end     TIMESTAMPTZ NOT NULL,
    trial_ends_at          TIMESTAMPTZ,
    stripe_subscription_id TEXT,
    stripe_event_id        TEXT,      -- idempotency: track last processed Stripe event
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 12.2 Entitlement Enforcement

```python
async def check_can_create_provider(
    db: AsyncSession,
    organization_id: uuid.UUID,
) -> None:
    subscription = await get_active_subscription(db, organization_id)
    if subscription is None:
        raise ForbiddenError("No active subscription")
    if subscription.status == SubscriptionStatus.TRIALING:
        if subscription.trial_ends_at < datetime.now(timezone.utc):
            raise ForbiddenError("Trial has expired")
    plan = await db.get(SubscriptionPlan, subscription.plan_id)
    if plan.max_providers is not None:
        count = await count_active_providers(db, organization_id)
        if count >= plan.max_providers:
            raise ForbiddenError("Provider limit reached for your plan")
```

### 12.3 Stripe Integration

- Stripe Checkout for subscription creation
- `stripe.Webhook.construct_event` for signature verification
- Idempotent webhook handlers: check `stripe_event_id` before processing
- Handle: `invoice.paid`, `invoice.payment_failed`, `customer.subscription.deleted`

### 12.4 API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `GET` | `/subscriptions/plans` | No | — | List available plans |
| `POST` | `/subscriptions` | Yes | Org OWNER | Subscribe org |
| `PATCH` | `/subscriptions/{id}` | Yes | Org OWNER | Upgrade/downgrade |
| `DELETE` | `/subscriptions/{id}` | Yes | Org OWNER | Cancel |
| `POST` | `/webhooks/stripe` | No (sig verified) | — | Stripe webhook |

### 12.5 Tests

| Test | Expected |
|------|----------|
| Org without subscription cannot create provider | 403 |
| Org at provider limit cannot create more | 403 |
| Expired trial degrades gracefully | 403 |
| Stripe webhook with invalid signature | 401 |
| Duplicate Stripe event processed once | idempotent |

---

## 13. Phase 8 — Production Launch

**Goal:** Harden for real users.

### 13.1 Infrastructure

```
Production:
├── Cloud (Railway / Render / AWS / GCP — decision based on ops complexity)
├── PostgreSQL (managed: RDS, Cloud SQL, Neon, or Supabase)
├── FastAPI (behind reverse proxy / load balancer)
├── HTTPS (cloud-managed certificate)
└── CI/CD (GitHub Actions)
```

### 13.2 CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test
        ports: ["5432:5432"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: "3.12"}
      - run: pip install -r requirements.txt
      - run: alembic upgrade head
        env:
          DATABASE_URL: postgresql+asyncpg://test:test@localhost:5432/test
      - run: pytest --cov=app --cov-report=xml -v
      - run: ruff check app/
      - run: mypy app/
```

### 13.3 Testing Matrix

| Type | Scope | Tools |
|------|-------|-------|
| Unit | Availability engine, state machine, hashing | pytest |
| Integration | API endpoints with real test DB | pytest + httpx |
| Concurrency | Double-booking race condition | pytest + asyncio.gather |
| Security | Cross-tenant, unauthorized access, injection | pytest |
| Load | Booking volume stress test | locust or k6 (optional) |

### 13.4 Observability

```python
import structlog
logger = structlog.get_logger()

# Logging convention — every significant operation:
logger.info("auth.register",        email=email, role=role)
logger.info("booking.created",      booking_id=str(b.id), provider_id=str(p.id))
logger.warning("booking.conflict",  provider_id=str(p.id), slot=str(start_time))
logger.info("booking.confirmed",    booking_id=str(b.id))
logger.error("stripe.webhook_fail", stripe_event=event_id, error=str(e))
```

- **Error tracking:** Sentry (`sentry-sdk[fastapi]`)
- **Metrics:** Request latency, error rate, booking volume (Prometheus or cloud-native)
- **Alerts:** Elevated error rates, slow queries, failed background jobs

### 13.5 Database Production Checklist

- [ ] Migrations tested against production backup
- [ ] Automated backup configured and restore tested
- [ ] `pool_size` and `max_overflow` configured on engine
- [ ] Statement timeout set (prevent runaway queries)
- [ ] Idle transaction timeout set
- [ ] `pg_stat_statements` enabled for query analysis
- [ ] Read replica considered (when booking volume warrants it)

---

## 14. Phase 9 — Online Meetings

**Goal:** Virtual appointment fulfillment without touching the booking engine.

**Architecture principle:** The booking engine does not know about video. A meeting is created as a side effect after booking confirmation.

### 14.1 Schema

```sql
CREATE TABLE meetings (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id  UUID NOT NULL UNIQUE REFERENCES bookings(id),
    provider_id UUID NOT NULL REFERENCES provider_profiles(id),
    meeting_url TEXT,
    meeting_id  TEXT,
    provider    TEXT NOT NULL,   -- 'daily', 'zoom', 'whereby'
    status      TEXT NOT NULL DEFAULT 'scheduled',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 14.2 Integration Flow

```
Booking confirmed
      │
      ▼
fulfillment_method == ONLINE?
      │
      Yes
      │
      ▼
Call video provider API → create room
      │
      ▼
Store Meeting record
      │
      ▼
Send join link via notification (email + in-app)
```

---

## 15. Phase 10 — Platform Expansion

Features introduced in response to customer demand and business evidence — not technical ambition.

| Area | Features | New Tables |
|------|----------|-----------|
| **Scheduling** | Recurring appointments | `recurring_rules` |
| | Group appointments | `booking_participants` |
| | Waitlists | `waitlist_entries` |
| | Resources/rooms | `resources`, `resource_bookings` |
| | Packages/memberships | `packages`, `package_subscriptions` |
| **Commerce** | Payments at booking | `payments` |
| | Refunds | `refunds` |
| | Provider payouts | `payouts` |
| | Coupons/discounts | `coupons`, `coupon_usage` |
| | Tax handling | `tax_rates` |
| | Invoices | `invoices`, `invoice_items` |
| **Intelligence** | Provider recommendations | — (query-based) |
| | Smart search | PostgreSQL `tsvector` |
| | Business analytics | Aggregation queries |
| **Integrations** | Google Calendar | OAuth2 + Google Calendar API |
| | Apple Calendar | CalDAV |
| | Outlook | Microsoft Graph API |
| | Outbound webhooks | `webhook_subscriptions`, queue |
| | Public API | API key table + rate limiting |

---

## 16. Cross-Cutting Concerns

### 16.1 Error Hierarchy

```python
# core/exceptions.py

class AppError(Exception):
    status_code = 500
    code = "INTERNAL_ERROR"
    detail = "Internal server error"

class NotFoundError(AppError):
    status_code = 404
    code = "NOT_FOUND"
    detail = "Resource not found"

class ConflictError(AppError):
    status_code = 409
    code = "CONFLICT"
    detail = "Resource conflict"

class BookingConflictError(ConflictError):
    code = "BOOKING_CONFLICT"
    detail = "Provider is not available for this time slot"

class ForbiddenError(AppError):
    status_code = 403
    code = "FORBIDDEN"
    detail = "Not authorized"

class InvalidTokenError(AppError):
    status_code = 401
    code = "INVALID_TOKEN"
    detail = "Invalid or revoked token"

class ValidationError(AppError):
    status_code = 422
    code = "VALIDATION_ERROR"
    detail = "Validation failed"
```

**All registered in `main.py` as FastAPI exception handlers. Consistent error response:**
```json
{"detail": "Provider is not available for this time slot", "code": "BOOKING_CONFLICT"}
```

### 16.2 Pagination

```python
# core/pagination.py
from typing import Generic, TypeVar
from pydantic import BaseModel
from fastapi import Query

T = TypeVar("T")

class PaginationParams:
    def __init__(
        self,
        skip: int = Query(0, ge=0),
        limit: int = Query(20, ge=1, le=100),
    ):
        self.skip = skip
        self.limit = limit

class PaginatedResponse(BaseModel, Generic[T]):
    total: int
    items: list[T]
    skip: int
    limit: int
```

### 16.3 Environment Variables

```env
# .env.example
DATABASE_URL=postgresql+asyncpg://booking_user:booking_password@localhost:5432/booking_dev
SECRET_KEY=replace-with-long-random-secret-minimum-32-chars
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7
ALLOWED_ORIGINS=["http://localhost:3000"]
DEBUG=true
```

### 16.4 Git Branch Strategy

```
main          ← production (branch protection required)
  └── develop ← integration branch
       ├── feature/phase-0-foundation
       ├── feature/phase-1-auth
       ├── feature/phase-2-orgs
       ├── feature/phase-3-scheduling
       └── ...
```

---

## 17. Release Timeline

| Phase | Description | Estimated Duration |
|-------|-------------|-------------------|
| 0 | Foundation | 1–2 days |
| 1 | Identity & Access | 3–5 days |
| 2 | Organizations & Providers | 3–5 days |
| 3 | Services & Scheduling | 5–7 days |
| 4 | Marketplace & Booking | 5–7 days |
| 5 | Booking Operations | 3–5 days |
| 6 | Trust & Notifications | 5–7 days |
| 7 | SaaS & Monetization | 5–7 days |
| 8 | Production Launch | 5–10 days |
| **Internal Alpha (0–2)** | | **~10 days** |
| **Functional MVP (0–5)** | | **~27 days** |
| **Commercial MVP (0–8)** | | **~46 days** |

---

> **This is the blueprint. Execute one phase at a time.**
> **Every phase must be solid before the next begins.**
> *The first product does not need to do everything. It needs to do booking exceptionally well.*
