# Booking SaaS — Backend Implementation Plan

> Derived from PLAN.md and README.md. Covers every backend decision, schema, endpoint, and implementation detail across Phases 0–10.

---

## 1. Architecture Overview

### 1.1 Pattern: Modular Monolith

A single FastAPI application with domain-separated modules. Each module owns its models, schemas, services, and routers. Modules share one PostgreSQL database and one process.

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                    # App factory, lifespan, middleware
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py              # pydantic-settings: env vars
│   │   ├── database.py            # SQLAlchemy async engine + session
│   │   ├── security.py            # JWT encode/decode, password hashing
│   │   ├── deps.py                # Shared dependencies (get_db, get_current_user)
│   │   ├── exceptions.py          # Custom exception classes + handlers
│   │   ├── logging.py             # Structured JSON logging setup
│   │   └── pagination.py          # Reusable pagination params
│   ├── models/
│   │   ├── __init__.py            # Base + import all models for Alembic auto-discovery
│   │   ├── base.py                # SQLAlchemy DeclarativeBase
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
│   │   ├── __init__.py
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
│   ├── services/                  # Business logic layer
│   │   ├── __init__.py
│   │   ├── auth_service.py
│   │   ├── user_service.py
│   │   ├── organization_service.py
│   │   ├── provider_service.py
│   │   ├── service_service.py
│   │   ├── availability_engine.py # Core availability algorithm
│   │   ├── booking_service.py     # Double-booking protection lives here
│   │   ├── review_service.py
│   │   ├── notification_service.py
│   │   └── admin_service.py
│   └── routers/                   # FastAPI routers (thin controllers)
│       ├── __init__.py
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
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
├── alembic.ini
├── tests/
│   ├── conftest.py
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
└── .gitignore
```

### 1.2 Why This Structure

- **Each domain is a folder, not a separate app.** No microservice overhead, no service discovery, no network hops.
- **Models are centralized in `models/`.** Alembic needs all models in one place for autogeneration.
- **Schemas are separate from models.** Pydantic v2 schemas (API contract) never leak SQLAlchemy internals.
- **Services contain all business logic.** Routers are thin controllers that parse requests, call services, and return responses.
- **Routers are thin.** No business logic in route handlers. Logic is testable without HTTP.

---

## 2. Phase 0 — Foundation

**Goal:** FastAPI connects to PostgreSQL. Migrations run. Health endpoint returns 200.

### 2.1 Docker Compose

```yaml
# docker-compose.yml
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

### 2.2 Project Configuration (`core/config.py`)

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    app_name: str = "Booking SaaS"
    app_version: str = "0.1.0"
    debug: bool = False

    # Database
    database_url: str = "postgresql+asyncpg://booking_user:booking_password@localhost:5432/booking_dev"

    # JWT
    secret_key: str           # MUST be set in .env — no default in production
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    # CORS
    allowed_origins: list[str] = ["http://localhost:3000"]

settings = Settings()
```

### 2.3 Database Setup (`core/database.py`)

```python
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.models.base import Base

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

### 2.4 Base Model (`models/base.py`)

```python
import uuid
from datetime import datetime, timezone
from sqlalchemy import DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase):
    pass

class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
```

### 2.5 Health Endpoint (`routers/health.py`)

```python
from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
async def health():
    return {
        "status": "ok",
        "version": settings.app_version,
    }
```

### 2.6 Alembic Setup

- `alembic init alembic`
- Configure `alembic.ini` to use `settings.database_url`
- Configure `env.py` to import `Base` so autogenerate detects all models
- First migration: empty schema (proves Alembic works)

### 2.7 Requirements

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
```

### 2.8 Proof of Completion

```
Flutter → FastAPI (health endpoint) → PostgreSQL (connection verified)
```

---

## 3. Phase 1 — Identity & Access

**Goal:** Registration, login, JWT auth, role-based access control.

### 3.1 Database Schema

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
```

### 3.2 SQLAlchemy Model

```python
import enum
import uuid
from sqlalchemy import String, Boolean, Enum
from sqlalchemy.orm import Mapped, mapped_column
from app.models.base import Base, TimestampMixin

class UserRole(str, enum.Enum):
    CLIENT = "CLIENT"
    PROVIDER = "PROVIDER"
    ADMIN = "ADMIN"

class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False, index=True)
    hashed_password: Mapped[str] = mapped_column(String, nullable=False)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), nullable=False, default=UserRole.CLIENT)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
```

### 3.3 API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `POST` | `/auth/register` | No | — | Create account |
| `POST` | `/auth/login` | No | — | Get access + refresh tokens |
| `POST` | `/auth/logout` | Yes | Any | Revoke refresh token |
| `POST` | `/auth/refresh` | Yes (refresh) | Any | Rotate refresh, get new access |
| `GET` | `/auth/verify-email?token=...` | No | — | Verify email address |
| `POST` | `/auth/forgot-password` | No | — | Send reset email |
| `POST` | `/auth/reset-password` | No | — | Reset with token |
| `GET` | `/users/me` | Yes | Any | Get own profile |

### 3.4 Security Implementation

```python
# core/security.py
from passlib.context import CryptContext
from jose import jwt, JWTError
from datetime import datetime, timedelta, timezone

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def create_access_token(user_id: str, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    return jwt.encode(
        {"sub": user_id, "role": role, "exp": expire, "type": "access"},
        settings.secret_key,
        algorithm=settings.jwt_algorithm,
    )

def create_refresh_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    return jwt.encode(
        {"sub": user_id, "exp": expire, "type": "refresh"},
        settings.secret_key,
        algorithm=settings.jwt_algorithm,
    )

def decode_token(token: str) -> dict:
    """Decode and validate a JWT. Raises JWTError on failure."""
    return jwt.decode(token, settings.secret_key, algorithms=[settings.jwt_algorithm])
```

### 3.5 Dependency Injection (`core/deps.py`)

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from jose import JWTError

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
        raise HTTPException(status_code=401, detail="Invalid token")

    user = await db.get(User, uuid.UUID(user_id))
    if user is None or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or inactive")
    return user

def require_role(*roles: UserRole):
    """Dependency factory: require_role(UserRole.ADMIN, UserRole.PROVIDER)"""
    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return current_user
    return role_checker
```

### 3.6 Token Storage Strategy

- Access token: short-lived (30 min), stored in memory on client
- Refresh token: longer-lived (7 days), stored securely on client
- Refresh token rotation: every refresh issues a new refresh token, old one is invalidated
- Logout: invalidate refresh token server-side (store token jti in a revoked_tokens table, or use a short-lived in-memory blacklist)

### 3.7 Rate Limiting

- `/auth/login`: 5 attempts per minute per IP
- `/auth/register`: 3 attempts per minute per IP
- Implementation: in-memory sliding window counter (start simple, move to Redis later if needed)

### 3.8 Tests

| Test | Expected |
|------|----------|
| Register with valid data | 201, user created |
| Register with duplicate email | 409 |
| Login with correct credentials | 200, tokens returned |
| Login with wrong password | 401 |
| Access protected route without token | 401 |
| Access with expired token | 401 |
| CLIENT cannot access PROVIDER route | 403 |
| ADMIN can access ADMIN route | 200 |
| Refresh token rotation works | 200, new tokens |
| Refresh with revoked token | 401 |

---

## 4. Phase 2 — Organizations & Provider Setup

**Goal:** Multi-tenant structure. Providers belong to organizations. Data isolation enforced.

### 4.1 Database Schema

```sql
CREATE TABLE organizations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    slug        TEXT NOT NULL UNIQUE,       -- URL-friendly identifier
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
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    display_name    TEXT NOT NULL,
    bio             TEXT,
    category        TEXT,                      -- e.g., "Medical", "Legal", "Education"
    location        JSONB,                     -- { address, city, state, country, lat, lng }
    timezone        TEXT NOT NULL DEFAULT 'UTC',
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, organization_id)         -- One profile per user per org
);
```

### 4.2 Multi-Tenancy Enforcement Strategy

Every query touching org-scoped data MUST filter by `organization_id`. This is enforced at the service layer.

```python
# Service layer pattern
async def get_org_provider_profile(
    db: AsyncSession,
    organization_id: uuid.UUID,
    provider_id: uuid.UUID,
) -> ProviderProfile | None:
    """Fetch a provider profile ONLY within the given organization."""
    result = await db.execute(
        select(ProviderProfile)
        .where(
            ProviderProfile.id == provider_id,
            ProviderProfile.organization_id == organization_id,  # CRITICAL: tenant filter
        )
    )
    return result.scalar_one_or_none()
```

**Authorization pattern:**
1. User authenticates → JWT contains `user_id` and `role`
2. Endpoint receives request
3. Service verifies: does this user have an `organization_membership` for the target org?
4. If yes → proceed. If no → 403.

### 4.3 API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `POST` | `/organizations` | Yes | Any (becomes OWNER) | Create org |
| `GET` | `/organizations/{id}` | Yes | Org member | Get org details |
| `PATCH` | `/organizations/{id}` | Yes | OWNER/ADMIN | Update org |
| `POST` | `/providers/profile` | Yes | PROVIDER | Create profile |
| `GET` | `/providers/{id}` | No | — | Public provider profile |
| `PATCH` | `/providers/{id}` | Yes | Owner of profile | Update profile |
| `GET` | `/providers` | No | — | List providers (public) |
| `POST` | `/organizations/{id}/members` | Yes | OWNER/ADMIN | Add member |
| `DELETE` | `/organizations/{id}/members/{user_id}` | Yes | OWNER | Remove member |

### 4.4 Tests

| Test | Expected |
|------|----------|
| Create org → user becomes OWNER | 201 |
| Org member can view org | 200 |
| Non-member cannot view org | 403 |
| Provider in Org A cannot read Org B private data | 403 |
| Only OWNER/ADMIN can add members | 203 for MEMBER |
| Creating provider profile requires PROVIDER role | 403 for CLIENT |

---

## 5. Phase 3 — Services & Scheduling

**Goal:** Providers define services and availability. Backend availability engine produces real bookable slots.

### 5.1 Database Schema

```sql
CREATE TABLE services (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id     UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id),
    name            TEXT NOT NULL,
    description     TEXT,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    price           NUMERIC(10, 2),
    currency        TEXT DEFAULT 'USD',
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE availability_rules (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id     UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    day_of_week     INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),  -- 0=Sunday
    start_time      TIME NOT NULL,
    end_time        TIME NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (start_time < end_time)
);

CREATE TABLE blocked_periods (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id     UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    start_time      TIMESTAMPTZ NOT NULL,
    end_time        TIMESTAMPTZ NOT NULL,
    reason          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (start_time < end_time)
);

-- Scheduling configuration on provider_profiles
ALTER TABLE provider_profiles ADD COLUMN booking_buffer_before_minutes INTEGER DEFAULT 0;
ALTER TABLE provider_profiles ADD COLUMN booking_buffer_after_minutes INTEGER DEFAULT 0;
ALTER TABLE provider_profiles ADD COLUMN minimum_notice_hours INTEGER DEFAULT 1;
ALTER TABLE provider_profiles ADD COLUMN max_advance_days INTEGER DEFAULT 30;
```

### 5.2 Availability Engine Algorithm

The availability engine is the most complex backend component. It lives entirely in the backend — Flutter only displays what the engine returns.

**Input:**
- Provider timezone
- Service duration (minutes)
- Working hours (availability_rules for the relevant day of week)
- Existing bookings (CONFIRMED + PENDING) for the date range
- Blocked periods overlapping the date range
- Booking buffers (before/after)
- Minimum notice (hours from now)
- Maximum advance booking (days from now)
- Requested date

**Algorithm:**

```python
# services/availability_engine.py

async def compute_available_slots(
    db: AsyncSession,
    provider_id: uuid.UUID,
    service_id: uuid.UUID,
    date: datetime.date,
    provider_tz: str,
) -> list[Slot]:
    """
    Compute available bookable slots for a provider on a given date.
    
    Steps:
    1. Get working hours for the day_of_week
    2. Get existing bookings for the date
    3. Get blocked periods overlapping the date
    4. Get service duration
    5. Get provider buffer/notice/window config
    6. Generate candidate slots from working hours
    7. Subtract booked intervals
    8. Subtract blocked intervals
    9. Apply buffer time (expand bookings outward by buffer)
    10. Apply minimum notice filter
    11. Apply maximum advance filter
    12. Return remaining slots as {start_utc, end_utc}
    """
```

**Key design decisions:**
- All computation happens in provider timezone for the working hours
- Results are returned as UTC timestamps to the client
- Client (Flutter) converts to display timezone for presentation
- The engine handles DST transitions correctly by using `zoneinfo.ZoneInfo`

### 5.3 Timezone Strategy

```
Storage:       All timestamps → UTC in database
Provider:      timezone field on provider_profiles (e.g., "America/New_York")
Computation:   Working hours applied in provider timezone, results converted to UTC
Client:        Receives UTC, converts to device timezone for display
```

### 5.4 API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `POST` | `/services` | Yes | PROVIDER | Create service |
| `GET` | `/providers/{id}/services` | No | — | List provider services |
| `PATCH` | `/services/{id}` | Yes | Owner | Update service |
| `DELETE` | `/services/{id}` | Yes | Owner | Deactivate service |
| `POST` | `/availability/rules` | Yes | PROVIDER | Create working hour rule |
| `GET` | `/providers/{id}/availability` | No | — | Get available slots |
| `POST` | `/availability/blocked` | Yes | PROVIDER | Block a period |
| `GET` | `/providers/{id}/blocked` | Yes | Owner | List blocked periods |
| `DELETE` | `/availability/blocked/{id}` | Yes | Owner | Remove blocked period |

**GET /providers/{id}/availability Query Params:**
- `date` (required): `YYYY-MM-DD`
- `service_id` (required): UUID of the service
- `timezone` (optional): client timezone for display (does not affect computation)

### 5.5 Tests

| Test | Expected |
|------|----------|
| Slots outside working hours not returned | Pass |
| Blocked periods remove slots | Pass |
| Buffer time prevents back-to-back overlap | Pass |
| Minimum notice removes slots too close to now | Pass |
| Maximum advance hides distant future slots | Pass |
| DST transition: correct UTC conversion | Pass |
| Provider and client in different timezones see same real moment | Pass |
| No service → 404 | Pass |
| Invalid provider → 404 | Pass |

---

## 6. Phase 4 — Marketplace & Booking

**Goal:** Customer discovers provider and creates booking. Double booking is impossible.

### 6.1 Database Schema

```sql
CREATE TYPE booking_status AS ENUM (
    'PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED', 'NO_SHOW'
);

CREATE TYPE fulfillment_method AS ENUM ('IN_PERSON', 'ONLINE', 'PHONE');

CREATE TABLE bookings (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id           UUID NOT NULL REFERENCES users(id),
    provider_id         UUID NOT NULL REFERENCES provider_profiles(id),
    service_id          UUID NOT NULL REFERENCES services(id),
    organization_id     UUID NOT NULL REFERENCES organizations(id),
    start_time          TIMESTAMPTZ NOT NULL,
    end_time            TIMESTAMPTZ NOT NULL,
    timezone_context    TEXT NOT NULL,            -- timezone in which booking was created
    status              booking_status NOT NULL DEFAULT 'PENDING',
    fulfillment_method  fulfillment_method NOT NULL DEFAULT 'IN_PERSON',
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (start_time < end_time)
);

-- Index for double-booking check: find overlapping bookings for a provider
CREATE INDEX idx_bookings_provider_overlap
    ON bookings (provider_id, start_time, end_time)
    WHERE status IN ('PENDING', 'CONFIRMED');

-- Index for client booking history
CREATE INDEX idx_bookings_client
    ON bookings (client_id, start_time DESC);

-- Index for provider calendar
CREATE INDEX idx_bookings_provider_calendar
    ON bookings (provider_id, start_time DESC);
```

### 6.2 Double-Booking Protection

This is the most critical business rule. Two concurrent requests for the same slot must not both succeed.

**Strategy: `SELECT ... FOR UPDATE` within a serializable transaction**

```python
# services/booking_service.py

async def create_booking(
    db: AsyncSession,
    client_id: uuid.UUID,
    provider_id: uuid.UUID,
    service_id: uuid.UUID,
    start_time: datetime,
    end_time: datetime,
) -> Booking:
    """
    Create a booking with double-booking protection.
    
    Uses SELECT FOR UPDATE to lock the provider's bookings for the
    overlapping time range, then checks for conflicts.
    """
    # 1. Lock existing bookings for this provider in the overlapping window
    existing = await db.execute(
        select(Booking)
        .where(
            Booking.provider_id == provider_id,
            Booking.status.in_([BookingStatus.PENDING, BookingStatus.CONFIRMED]),
            Booking.start_time < end_time,
            Booking.end_time > start_time,
        )
        .with_for_update()  # Row-level lock
    )
    conflicts = existing.scalars().all()

    if conflicts:
        raise BookingConflictError("Provider is not available for this time slot")

    # 2. Insert the booking
    booking = Booking(
        client_id=client_id,
        provider_id=provider_id,
        service_id=service_id,
        start_time=start_time,
        end_time=end_time,
        status=BookingStatus.PENDING,
    )
    db.add(booking)
    await db.flush()
    return booking
```

**Why `SELECT FOR UPDATE` over serializable isolation:**
- Serializable isolation causes more retries and is harder to reason about
- `SELECT FOR UPDATE` is explicit: "lock these rows before writing"
- Both approaches work; `FOR UPDATE` is more conventional for this pattern in PostgreSQL

### 6.3 API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `GET` | `/providers` | No | — | List providers (paginated, filterable) |
| `GET` | `/providers/{id}` | No | — | Public provider profile |
| `POST` | `/bookings` | Yes | CLIENT | Create booking |
| `GET` | `/bookings/{id}` | Yes | Owner/Provider | Booking detail |

**POST /bookings Request:**
```json
{
  "provider_id": "uuid",
  "service_id": "uuid",
  "start_time": "2026-09-15T14:00:00Z",
  "timezone_context": "America/New_York"
}
```

**POST /bookings Validation:**
1. Service belongs to provider
2. Start/end times match service duration
3. Slot is available (no conflicts)
4. Client is CLIENT role
5. Slot hasn't passed

### 6.4 Tests

| Test | Expected |
|------|----------|
| Concurrent booking requests: exactly one succeeds | Pass |
| Booking with invalid service ID rejected | 400 |
| Booking for unavailable slot rejected | 400 |
| CLIENT cannot create booking on behalf of another CLIENT | 403 |
| PROVIDER cannot use client booking endpoint | 403 |
| Booking respects service duration | Pass |

---

## 7. Phase 5 — Booking Operations

**Goal:** Full appointment lifecycle management.

### 7.1 State Machine

```
PENDING → CONFIRMED → COMPLETED
                   ↘ NO_SHOW
       → CANCELLED
CONFIRMED → CANCELLED (within policy)
CONFIRMED → RESCHEDULED → new booking created
```

**State transition rules:**
- PENDING → CONFIRMED: Provider confirms
- PENDING → CANCELLED: Client or Provider cancels
- CONFIRMED → COMPLETED: Provider marks complete
- CONFIRMED → CANCELLED: Client cancels (within policy) or Provider cancels (always allowed)
- CONFIRMED → NO_SHOW: Provider marks no-show (only after appointment time has passed)
- CONFIRMED → RESCHEDULED: Client reschedules (creates new booking, cancels old)

### 7.2 API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `GET` | `/bookings` | Yes | CLIENT/PROVIDER | List own bookings |
| `GET` | `/bookings/{id}` | Yes | Owner/Provider | Booking detail |
| `PATCH` | `/bookings/{id}/confirm` | Yes | PROVIDER | Confirm booking |
| `PATCH` | `/bookings/{id}/complete` | Yes | PROVIDER | Mark completed |
| `PATCH` | `/bookings/{id}/cancel` | Yes | CLIENT/PROVIDER | Cancel booking |
| `PATCH` | `/bookings/{id}/no-show` | Yes | PROVIDER | Mark no-show |
| `POST` | `/bookings/{id}/reschedule` | Yes | CLIENT | Reschedule (new slot) |
| `GET` | `/providers/me/calendar` | Yes | PROVIDER | Calendar view |
| `PATCH` | `/providers/me/cancellation-policy` | Yes | PROVIDER | Update cancellation policy |

### 7.3 Cancellation Policy

```sql
ALTER TABLE provider_profiles ADD COLUMN cancellation_notice_hours INTEGER DEFAULT 24;
ALTER TABLE provider_profiles ADD COLUMN allow_same_day_cancellation BOOLEAN DEFAULT false;
```

**Logic:**
- Client can cancel if: current time + cancellation_notice_hours < booking start_time
- Provider can always cancel
- Rescheduling: same rules as cancel (for the old booking) + create new booking (must pass double-booking check)

### 7.4 Calendar View

`GET /providers/me/calendar?from=2026-09-01&to=2026-09-30`

Returns all bookings for the authenticated provider within the date range, including:
- Client name
- Service name
- Start/end times (UTC + timezone context)
- Status

### 7.5 Tests

| Test | Expected |
|------|----------|
| Client cannot cancel after cancellation window closes | 403 |
| Provider can cancel any booking | 200 |
| Rescheduling creates new booking atomically, cancels old | 200 + 200 |
| Completed booking cannot be cancelled | 400 |
| No-show can only be set after appointment time has passed | 400 |
| Calendar returns bookings in date range | 200 |

---

## 8. Phase 6 — Trust & Notifications

**Goal:** Reviews, notifications, audit logs, admin operations.

### 8.1 Reviews Schema

```sql
CREATE TABLE reviews (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id      UUID NOT NULL UNIQUE REFERENCES bookings(id),  -- One review per booking
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

**Eligibility rules:**
- Only the client who made the booking can review
- Only COMPLETED bookings can be reviewed
- Only one review per booking (enforced by UNIQUE on booking_id)

### 8.2 Notifications Schema

```sql
CREATE TYPE notification_type AS ENUM (
    'BOOKING_CREATED',
    'BOOKING_CONFIRMED',
    'BOOKING_CANCELLED',
    'BOOKING_REMINDER_24H',
    'BOOKING_REMINDER_1H',
    'REVIEW_RECEIVED',
    'SYSTEM'
);

CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id    UUID NOT NULL REFERENCES users(id),
    type            notification_type NOT NULL,
    payload         JSONB NOT NULL,
    is_read         BOOLEAN NOT NULL DEFAULT false,
    sent_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at         TIMESTAMPTZ
);

CREATE INDEX idx_notifications_recipient ON notifications (recipient_id, is_read, sent_at DESC);
```

**Notification triggers:**
- Booking created → notify provider
- Booking confirmed → notify client
- Booking cancelled → notify other party
- Appointment reminder → 24h and 1h before (requires background job)

**Delivery:** Start with email (via SMTP or transactional email service). Infrastructure-ready for push notifications later.

### 8.3 Audit Logs Schema

```sql
CREATE TABLE audit_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id        UUID REFERENCES users(id),  -- NULL for system actions
    action          TEXT NOT NULL,               -- e.g., "user.login", "booking.confirmed"
    entity_type     TEXT,                        -- e.g., "User", "Booking"
    entity_id       UUID,
    metadata        JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_actor ON audit_logs (actor_id, created_at DESC);
CREATE INDEX idx_audit_logs_entity ON audit_logs (entity_type, entity_id);
```

**What gets audited:**
- Login/logout
- Role changes
- Booking state changes
- Organization changes
- Provider profile changes
- Review flagging/moderation

### 8.4 Admin API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `GET` | `/admin/users` | Yes | ADMIN | List all users |
| `PATCH` | `/admin/users/{id}` | Yes | ADMIN | Activate/deactivate user |
| `GET` | `/admin/organizations` | Yes | ADMIN | List all orgs |
| `GET` | `/admin/bookings` | Yes | ADMIN | Operational overview |
| `GET` | `/admin/reviews` | Yes | ADMIN | Moderate reviews |
| `PATCH` | `/admin/reviews/{id}/flag` | Yes | ADMIN | Flag/unflag review |
| `GET` | `/admin/audit-logs` | Yes | ADMIN | Inspect audit trail |

### 8.5 Background Jobs (Phase 6)

For appointment reminders, we need a background task system. Start simple:

**Option A: APScheduler (in-process)**
- Runs inside FastAPI process
- Good for development and early production
- Simple setup, no additional infrastructure

**Option B: Celery + Redis (later)**
- More robust for production scale
- Requires Redis broker
- Introduce when appointment volume warrants it

**Start with Option A.** Switch when you have a concrete reason.

### 8.6 Tests

| Test | Expected |
|------|----------|
| Review only on COMPLETED booking | 400 if not completed |
| Only one review per booking | 409 on duplicate |
| Non-client cannot review | 403 |
| Notifications created on booking events | Pass |
| Audit log entry on login | Pass |
| Admin can list users | 200 |
| Non-admin cannot access admin endpoints | 403 |

---

## 9. Phase 7 — SaaS & Monetization

**Goal:** Subscription plans, billing, feature entitlements.

### 9.1 Database Schema

```sql
CREATE TABLE subscription_plans (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                TEXT NOT NULL UNIQUE,
    description         TEXT,
    price_monthly       NUMERIC(10, 2) NOT NULL,
    price_yearly        NUMERIC(10, 2),
    currency            TEXT NOT NULL DEFAULT 'USD',
    max_providers       INTEGER,
    max_bookings_monthly INTEGER,
    features            JSONB NOT NULL DEFAULT '{}',
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TYPE subscription_status AS ENUM (
    'TRIALING', 'ACTIVE', 'PAST_DUE', 'CANCELED', 'UNPAID'
);

CREATE TABLE subscriptions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     UUID NOT NULL REFERENCES organizations(id),
    plan_id             UUID NOT NULL REFERENCES subscription_plans(id),
    status              subscription_status NOT NULL DEFAULT 'TRIALING',
    billing_cycle       TEXT NOT NULL DEFAULT 'monthly',  -- 'monthly' or 'yearly'
    current_period_start TIMESTAMPTZ NOT NULL,
    current_period_end   TIMESTAMPTZ NOT NULL,
    trial_ends_at       TIMESTAMPTZ,
    stripe_subscription_id TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 9.2 Entitlement Enforcement

```python
async def check_entitlement(
    db: AsyncSession,
    organization_id: uuid.UUID,
    feature: str,
) -> bool:
    """Check if an org is entitled to perform an action based on their subscription."""
    subscription = await get_active_subscription(db, organization_id)
    if subscription is None:
        return False  # No subscription = no access
    if subscription.status == 'TRIALING' and subscription.trial_ends_at < datetime.now(timezone.utc):
        return False  # Trial expired
    plan = subscription.plan
    # Check feature-specific limits
    if feature == 'create_provider':
        return await count_org_providers(db, organization_id) < plan.max_providers
    # ... other features
    return True
```

### 9.3 API Endpoints

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| `GET` | `/subscriptions/plans` | No | — | List available plans |
| `POST` | `/subscriptions` | Yes | OWNER | Subscribe org to plan |
| `PATCH` | `/subscriptions/{id}` | Yes | OWNER | Upgrade/downgrade |
| `DELETE` | `/subscriptions/{id}` | Yes | OWNER | Cancel subscription |
| `POST` | `/webhooks/stripe` | No (verified) | — | Stripe webhook handler |

### 9.4 Stripe Integration

- Stripe Checkout for subscription creation
- Stripe webhooks for payment events (payment_intent.succeeded, invoice.paid, etc.)
- Webhook signature verification for security
- Idempotent webhook handling (check if event already processed)

### 9.5 Tests

| Test | Expected |
|------|----------|
| Free org cannot exceed provider limit | 403 |
| Subscribed org can create providers within limits | 200 |
| Expired trial degrades gracefully | 403 |
| Webhook signature verification rejects invalid | 401 |
| Upgrade/downgrade updates plan | 200 |

---

## 10. Phase 8 — Production Launch

**Goal:** Harden for real users.

### 10.1 Infrastructure

```
Production:
├── Cloud Provider (TBD — AWS / GCP / DigitalOcean / Railway)
├── PostgreSQL (managed service recommended)
├── FastAPI (behind reverse proxy / load balancer)
├── HTTPS (Let's Encrypt or cloud-managed)
└── CI/CD (GitHub Actions)
```

### 10.2 Observability

**Structured Logging (every phase):**
```python
import structlog

logger = structlog.get_logger()

# Usage
logger.info("booking_created", booking_id=str(booking.id), provider_id=str(provider.id))
logger.warning("booking_conflict", provider_id=str(provider.id), attempted_slot=str(start_time))
logger.error("payment_webhook_failed", stripe_id=stripe_id, error=str(e))
```

**Error Tracking:**
- Sentry for exception tracking
- Capture all unhandled exceptions
- Release tagging for version correlation

**Health Check:**
```python
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

### 10.3 CI/CD Pipeline

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
        with: { python-version: "3.12" }
      - run: pip install -r requirements.txt
      - run: alembic upgrade head
      - run: pytest --cov=app --cov-report=xml -v
      - run: ruff check app/
      - run: mypy app/
```

### 10.4 Testing Strategy Summary

| Type | Scope | Tools |
|------|-------|-------|
| Unit | Pure business logic (availability engine, state machine) | pytest |
| Integration | API endpoints with real DB | pytest + httpx + test DB |
| Concurrency | Double-booking race condition | pytest + parallel async requests |
| Security | Unauthorized access, cross-tenant, injection | pytest |
| Load | Concurrent booking stress test | locust or k6 (optional) |

### 10.5 Database Production Checklist

- [ ] Migrations tested against production backup
- [ ] Backups automated and tested (restore procedure documented)
- [ ] Connection pooling configured (pool_size, max_overflow)
- [ ] Statement timeout set (prevent runaway queries)
- [ ] Idle transaction timeout set
- [ ] pg_stat_statements enabled for query analysis
- [ ] Read replica setup considered (when needed)

---

## 11. Phase 9 — Online Meetings

**Goal:** Virtual appointments without touching the booking engine.

### 11.1 Architecture

```
Booking (fulfillment_method: ONLINE)
    │
    └── Meeting (separate entity, separate lifecycle)
            │
            └── Video infrastructure (Daily.co / Whereby / Zoom)
```

### 11.2 Schema

```sql
CREATE TABLE meetings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id      UUID NOT NULL UNIQUE REFERENCES bookings(id),
    provider_id     UUID NOT NULL REFERENCES provider_profiles(id),
    meeting_url     TEXT,                      -- Join URL from provider
    meeting_id      TEXT,                      -- External meeting ID
    provider        TEXT NOT NULL,             -- 'daily', 'zoom', 'whereby'
    status          TEXT NOT NULL DEFAULT 'scheduled',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Key design:** The booking engine does not know about video. A meeting is created as a side effect after booking confirmation. Meeting join links are delivered via the notification system.

### 11.3 Integration Pattern

1. Booking confirmed → check fulfillment_method
2. If ONLINE → call video provider API to create room
3. Store meeting record
4. Send join link via notification (email + in-app)

---

## 12. Phase 10 — Platform Expansion

**Goal:** Advanced features driven by customer demand.

### 12.1 Scheduling Expansion

| Feature | New Tables | Complexity |
|---------|-----------|------------|
| Recurring appointments | `recurring_rules` | High |
| Group appointments | `booking_participants` | Medium |
| Waitlists | `waitlist_entries` | Medium |
| Resources/rooms | `resources`, `resource_bookings` | Medium |
| Packages/memberships | `packages`, `package_subscriptions` | Medium |

### 12.2 Commerce Expansion

| Feature | New Tables | Complexity |
|---------|-----------|------------|
| Payments at booking | `payments` | Medium |
| Refunds | `refunds` | Low |
| Provider payouts | `payouts` | High |
| Coupons/discounts | `coupons`, `coupon_usage` | Medium |
| Tax handling | `tax_rates` | Medium |
| Invoices | `invoices`, `invoice_items` | Medium |

### 12.3 Intelligence Expansion

- Provider recommendations: based on booking history, ratings, location
- Smart search: full-text search with PostgreSQL `tsvector`
- Scheduling optimization: suggest optimal working hours based on demand
- Business insights: aggregate analytics on bookings, revenue, ratings

### 12.4 Integrations

| Integration | Pattern |
|-------------|---------|
| Google Calendar | OAuth2 + CalDAV or Google Calendar API |
| Apple Calendar | CalDAV (requires Apple Developer account) |
| Outlook | Microsoft Graph API |
| Webhooks | Outbound event system (queue → HTTP POST) |
| Public API | API key authentication, rate limiting |

---

## 13. Cross-Cutting Concerns

### 13.1 Error Handling

```python
# core/exceptions.py

class AppError(Exception):
    """Base application error."""
    status_code = 500
    detail = "Internal server error"

class NotFoundError(AppError):
    status_code = 404
    detail = "Resource not found"

class ConflictError(AppError):
    status_code = 409
    detail = "Resource conflict"

class BookingConflictError(ConflictError):
    detail = "Provider is not available for this time slot"

class ForbiddenError(AppError):
    status_code = 403
    detail = "Not authorized"

class ValidationError(AppError):
    status_code = 422
    detail = "Validation failed"
```

Registered as exception handlers in `main.py` to return consistent JSON error responses.

### 13.2 Pagination

```python
# core/pagination.py
from fastapi import Query
from pydantic import BaseModel

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

All list endpoints use cursor-based pagination (by `created_at` or `id`) for large datasets, offset-based for smaller ones.

### 13.3 Logging Convention

```python
# Every significant operation gets a structured log entry
logger.info("auth.register", email=email, role=role)
logger.info("booking.created", booking_id=str(booking.id), provider_id=str(provider.id))
logger.warning("booking.conflict", provider_id=str(provider.id))
logger.info("booking.confirmed", booking_id=str(booking.id))
logger.error("stripe.webhook_failed", stripe_event_id=event_id, error=str(e))
```

### 13.4 Environment Variables

```env
# .env.example (no secrets, just structure)
DATABASE_URL=postgresql+asyncpg://booking_user:booking_password@localhost:5432/booking_dev
SECRET_KEY=your-secret-key-here
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7
ALLOWED_ORIGINS=["http://localhost:3000"]
DEBUG=true
```

### 13.5 Git Branch Strategy

```
main          ← production
  └── develop ← integration branch
       ├── feature/phase-0-foundation
       ├── feature/phase-1-auth
       ├── feature/phase-2-orgs
       └── ...
```

---

## 14. Implementation Order (Priority Sequence)

### Internal Alpha (Phases 0–2)

1. **Phase 0** (1–2 days): Docker, FastAPI scaffold, PostgreSQL, health endpoint
2. **Phase 1** (3–5 days): User model, registration, login, JWT, role guards
3. **Phase 2** (3–5 days): Organizations, memberships, provider profiles, multi-tenancy

### Functional MVP (Phases 3–5)

4. **Phase 3** (5–7 days): Services, availability rules, availability engine, blocked periods
5. **Phase 4** (5–7 days): Bookings, double-booking protection, provider discovery, marketplace
6. **Phase 5** (3–5 days): Booking lifecycle, cancellation, rescheduling, calendar view

### Commercial MVP (Phases 6–8)

7. **Phase 6** (5–7 days): Reviews, notifications, audit logs, admin endpoints
8. **Phase 7** (5–7 days): Subscriptions, Stripe integration, webhooks, entitlements
9. **Phase 8** (5–10 days): Production hardening, CI/CD, monitoring, full test suite

### Platform Expansion (Phases 9–10)

10. **Phase 9** (3–5 days): Meeting model, video provider integration
11. **Phase 10** (ongoing): Driven by customer demand

---

## 15. Non-Negotiable Rules

1. Every endpoint that touches org-scoped data must verify `organization_id`.
2. No business logic in route handlers. Services own the logic.
3. All passwords are bcrypt-hashed with cost >= 12.
4. JWT payload contains only user_id and role. No email, no permissions.
5. Every mutation is wrapped in a transaction. No partial writes.
6. Every list endpoint has pagination. No unbounded queries.
7. Every error returns a consistent JSON structure.
8. Every migration has a rollback path.
9. Every feature has tests before it is considered done.
10. No secrets in source code. Ever.

---

> **This is the blueprint. Execute one phase at a time. Every phase must be solid before the next begins.**
