# Booking SaaS — Implementation Plan

> **Philosophy:** Small scope, serious engineering.
> Build one brick at a time. Every brick must be solid before the next is laid.

---

## Overview

| Attribute | Value |
|---|---|
| Product | Multi-tenant appointment booking SaaS / marketplace |
| Mobile | Flutter (Android + iOS) |
| Backend | Python / FastAPI |
| Database | PostgreSQL via SQLAlchemy 2.x + Alembic |
| Architecture | Modular Monolith |
| Infrastructure | Docker / Docker Compose (local) |

---

## Release Map

| Release | Phases | Goal |
|---|---|---|
| Internal Alpha | 0 – 2 | Secure representation of users, providers, orgs, admins |
| Functional MVP | 3 – 5 | Customer can discover a provider and book an appointment |
| Commercial MVP | 6 – 8 | Real businesses can use the platform and pay for it |
| Platform Expansion | 9 – 10+ | Evolve into a broader service-engagement platform |

---

## Phase 0 — Foundation

**Goal:** Prove the full stack is wired together end-to-end.

### Backend
- [ ] Initialise FastAPI project with clean module structure
- [ ] Connect FastAPI to PostgreSQL via SQLAlchemy 2.x (async)
- [ ] Set up Alembic for database migrations
- [ ] Create first migration (empty schema, proves migrations run)
- [ ] Implement `GET /health` endpoint (returns `200 OK` with version info)
- [ ] Configure environment variable management (`.env`, no secrets in source)
- [ ] Add structured logging baseline

### Infrastructure
- [ ] Create `docker-compose.yml` with PostgreSQL service
- [ ] Configure persistent Docker volume for PostgreSQL data
- [ ] Document local setup steps in `README` or `CONTRIBUTING.md`

### Mobile
- [ ] Initialise Flutter project (`flutter create`)
- [ ] Create typed API client wrapper (e.g., `lib/core/api/api_client.dart`)
- [ ] Wire client to call `GET /health` and display response
- [ ] Confirm app runs on Android emulator
- [ ] Confirm app runs on iOS simulator

### Proof of Completion
```
Android / iOS  →  FastAPI  →  PostgreSQL
```
No hardcoded data. No fake network calls. Real HTTP. Real DB connection.

---

## Phase 1 — Identity & Access

**Goal:** Secure registration, login, and role-based access control.

### Domain Design
- [ ] Define `User` model with fields: `id`, `email`, `hashed_password`, `role`, `is_active`, `is_verified`, `created_at`, `updated_at`
- [ ] Define roles enum: `CLIENT`, `PROVIDER`, `ADMIN`
- [ ] Separate `role` (who you are) from `permissions` (what you can do) from `org membership` (where you belong)

### Database
- [ ] Migration: `users` table with constraints (unique email, non-null role)
- [ ] Store passwords using `bcrypt` — never plaintext

### Backend — Authentication
- [ ] `POST /auth/register` — create account, hash password, assign role
- [ ] `POST /auth/login` — verify credentials, issue JWT (access + refresh tokens)
- [ ] `POST /auth/logout` — invalidate/revoke token
- [ ] `POST /auth/refresh` — issue new access token from refresh token
- [ ] Email verification flow (send token, `GET /auth/verify-email?token=...`)
- [ ] Password reset flow (`POST /auth/forgot-password`, `POST /auth/reset-password`)

### Backend — Authorization
- [ ] JWT verification middleware / dependency
- [ ] Role-based permission guards (`require_role(CLIENT)`, `require_role(PROVIDER)`, etc.)
- [ ] `GET /users/me` — returns authenticated user's own profile

### Security Requirements
- [ ] Passwords hashed with `bcrypt` (cost factor ≥ 12)
- [ ] JWTs signed with a secure secret; short expiry on access tokens
- [ ] No sensitive information in JWT payload beyond user ID + role
- [ ] Rate limiting on `/auth/login` and `/auth/register`
- [ ] Backend enforces all authorization — never trust client role claims

### Mobile
- [ ] Registration screen (email, password, role selection)
- [ ] Login screen
- [ ] Persist tokens securely (`flutter_secure_storage`)
- [ ] Token refresh logic (transparent to the user)
- [ ] Route to role-appropriate home screen after login:
  - `CLIENT` → Client dashboard
  - `PROVIDER` → Provider dashboard
  - `ADMIN` → Admin dashboard
- [ ] Logout action clears tokens

### Tests
- [ ] Valid registration creates user
- [ ] Duplicate email returns `409`
- [ ] Login with wrong password returns `401`
- [ ] Expired token returns `401`
- [ ] Accessing protected route without token returns `401`
- [ ] `CLIENT` cannot access `PROVIDER`-only route
- [ ] `PROVIDER` cannot access `ADMIN`-only route

---

## Phase 2 — Organizations & Provider Setup

**Goal:** Multi-tenant structure. Providers belong to organizations. Data isolation enforced.

### Domain Design
- [ ] `Organization` — a business entity on the platform
- [ ] `ProviderProfile` — professional profile linked to a User + Organization
- [ ] Membership model: a User (with PROVIDER role) belongs to an Organization
- [ ] An Organization can have multiple Providers

### Database
- [ ] Migration: `organizations` table
- [ ] Migration: `provider_profiles` table (FK to `users`, FK to `organizations`)
- [ ] Migration: `organization_memberships` table
- [ ] Row-level isolation: all queries scoped to `organization_id` where relevant

### Backend
- [ ] `POST /organizations` — create organization (ADMIN or founding PROVIDER)
- [ ] `GET /organizations/{id}` — get org details
- [ ] `POST /providers/profile` — create provider profile (PROVIDER role)
- [ ] `GET /providers/{id}` — get public provider profile
- [ ] `PATCH /providers/{id}` — update own profile (owner only)
- [ ] Provider categories (e.g., Medical, Legal, Education — generic, extensible)
- [ ] Location / address data on provider profile

### Multi-Tenancy Enforcement
- [ ] Every backend operation that touches org-scoped data must verify `organization_id`
- [ ] A PROVIDER in Org A must **never** be able to read Org B's private data
- [ ] Write tests that explicitly attempt cross-organization access

### Mobile
- [ ] Organization creation flow (for founding provider / admin)
- [ ] Provider profile setup screens
- [ ] Provider dashboard skeleton
- [ ] Display provider profile on public-facing screens

### Tests
- [ ] Provider in Org A cannot fetch Org B's private provider data
- [ ] Only org members can access org management endpoints
- [ ] Creating a provider profile requires PROVIDER role

---

## Phase 3 — Services & Scheduling

**Goal:** Providers define what they offer and when they are available. Availability engine produces real open slots.

### Domain Design
- [ ] `Service` — what a provider offers (name, description, duration, price, currency)
- [ ] `AvailabilityRule` — recurring working hours (day of week, start time, end time)
- [ ] `BlockedPeriod` — specific date ranges when provider is unavailable
- [ ] `Holiday` — platform-level or provider-level holiday rules
- [ ] Booking buffer (padding before/after appointments)
- [ ] Minimum notice (how far in advance a booking must be made)
- [ ] Maximum advance booking window

### Database
- [ ] Migration: `services` table
- [ ] Migration: `availability_rules` table
- [ ] Migration: `blocked_periods` table
- [ ] All timestamps stored in UTC

### Availability Engine (Backend-Authoritative)
- [ ] Algorithm input: working hours + service duration + existing bookings + blocked periods + buffers + notice + window + timezone
- [ ] Algorithm output: list of bookable `{start, end}` slots
- [ ] Engine lives entirely in the backend — Flutter only displays what the backend returns
- [ ] `GET /providers/{id}/availability?date=YYYY-MM-DD&service_id=...` returns available slots

### Timezone Strategy
- [ ] All timestamps stored as UTC in the database
- [ ] `timezone` field stored alongside relevant timestamps (provider timezone, booking timezone)
- [ ] Availability engine computes slots in provider timezone, returns UTC to client
- [ ] Flutter presents times in device/user timezone

### Backend
- [ ] `POST /services` — create service (PROVIDER)
- [ ] `GET /providers/{id}/services` — list provider's services
- [ ] `PATCH /services/{id}` — update service (owner only)
- [ ] `DELETE /services/{id}` — deactivate service
- [ ] `POST /availability/rules` — create working hour rule (PROVIDER)
- [ ] `POST /availability/blocked` — block a period (PROVIDER)
- [ ] `GET /providers/{id}/availability` — return computed available slots

### Mobile
- [ ] Provider: service management screens (create, edit, list)
- [ ] Provider: availability configuration screens (working hours, blocked periods)
- [ ] Customer: view provider's available services
- [ ] Customer: view available appointment slots (calendar/list view)

### Tests
- [ ] Slots outside working hours are not returned
- [ ] Blocked periods remove slots
- [ ] Buffer time prevents back-to-back bookings from overlapping
- [ ] Minimum notice removes slots too close to now
- [ ] Maximum advance booking hides distant future slots
- [ ] Daylight-saving transition: correct UTC conversion
- [ ] Provider and customer in different timezones see the same real-world moment

---

## Phase 4 — Marketplace & Booking

**Goal:** A customer can find a provider and create a booking. Double booking is impossible.

### Domain Design
- [ ] `Booking` — central business object
  - `id`, `client_id`, `provider_id`, `service_id`
  - `start_time` (UTC), `end_time` (UTC)
  - `timezone_context` (the timezone in which the booking was created)
  - `status` (PENDING | CONFIRMED | CANCELLED | COMPLETED | NO_SHOW)
  - `created_at`, `updated_at`
- [ ] `fulfillment_method`: IN_PERSON | ONLINE | PHONE (schema-ready, no video yet)

### Database
- [ ] Migration: `bookings` table
- [ ] **Database-level constraint** or advisory lock to prevent double booking
- [ ] Index on `(provider_id, start_time, end_time, status)` for concurrency queries

### Double-Booking Protection
- [ ] Use `SELECT ... FOR UPDATE` or `serializable` isolation when creating a booking
- [ ] Reject booking if provider already has a CONFIRMED/PENDING booking overlapping the slot
- [ ] Test two concurrent requests for the same slot — only one must succeed

### Backend
- [ ] `GET /providers` — list providers (paginated, filterable by category/location)
- [ ] `GET /providers/{id}` — public provider profile
- [ ] `POST /bookings` — create booking (CLIENT role)
  - Validate slot is still available
  - Validate service belongs to provider
  - Atomic transaction: check + insert
  - Return `PENDING` or `CONFIRMED` status
- [ ] `GET /bookings/{id}` — booking detail (CLIENT who owns it, or PROVIDER)

### Mobile
- [ ] Provider discovery / search screen
- [ ] Filter by category, location (optional in this phase)
- [ ] Provider profile screen (public view)
- [ ] Service selection screen
- [ ] Availability / slot picker screen
- [ ] Booking confirmation screen (shows booking details)
- [ ] Success / error feedback

### Tests
- [ ] Concurrent booking requests for same slot: exactly one succeeds
- [ ] Booking with invalid service ID rejected
- [ ] Booking for unavailable slot rejected
- [ ] CLIENT cannot create booking on behalf of another CLIENT
- [ ] PROVIDER cannot create a booking using the customer booking endpoint

---

## Phase 5 — Booking Operations

**Goal:** Full appointment lifecycle management. Both client and provider can manage bookings.

### Booking Status Transitions
```
PENDING → CONFIRMED → COMPLETED
                   ↘ NO_SHOW
       → CANCELLED
CONFIRMED → CANCELLED (within policy)
CONFIRMED → RESCHEDULED → new booking
```

### Backend
- [ ] `GET /bookings` — list bookings for current user (CLIENT: own bookings; PROVIDER: their appointments)
- [ ] `PATCH /bookings/{id}/cancel` — cancel booking (CLIENT within policy; PROVIDER always)
- [ ] `PATCH /bookings/{id}/confirm` — confirm booking (PROVIDER)
- [ ] `PATCH /bookings/{id}/complete` — mark completed (PROVIDER)
- [ ] `PATCH /bookings/{id}/no-show` — mark no-show (PROVIDER)
- [ ] `POST /bookings/{id}/reschedule` — reschedule (CLIENT within policy; new slot required)
- [ ] Cancellation policy configuration per provider (notice period, restrictions)
- [ ] Provider calendar view endpoint (`GET /providers/me/calendar?from=...&to=...`)

### Mobile
- [ ] Client: upcoming bookings screen
- [ ] Client: past bookings screen
- [ ] Client: booking detail with cancel / reschedule options
- [ ] Provider: calendar view of appointments
- [ ] Provider: booking management (confirm, complete, no-show, cancel)
- [ ] Provider: customer info on booking detail screen

### Tests
- [ ] Client cannot cancel after cancellation window closes
- [ ] Provider can cancel any booking
- [ ] Rescheduling creates new booking atomically, cancels old one
- [ ] Completed booking cannot be cancelled
- [ ] No-show can only be set after appointment time has passed

---

## Phase 6 — Trust & Notifications

**Goal:** Reviews and notifications. Platform becomes observable to admins.

### Reviews
- [ ] `Review` domain: `booking_id`, `client_id`, `provider_id`, `rating`, `comment`, `created_at`
- [ ] Review eligibility: only COMPLETED bookings, only once per booking
- [ ] `POST /reviews` — submit review (CLIENT, post-completion)
- [ ] `GET /providers/{id}/reviews` — list provider reviews (public)
- [ ] Admin: flag / moderate reviews

### Notifications
- [ ] Notification model: `type`, `recipient_id`, `payload`, `sent_at`, `read_at`
- [ ] Booking created → notify provider
- [ ] Booking confirmed → notify client
- [ ] Booking cancelled → notify other party
- [ ] Appointment reminder (configurable: e.g., 24h + 1h before)
- [ ] Start with email notifications; infrastructure-ready for push notifications later

### Audit Logs
- [ ] Log sensitive operations: login, role changes, booking state changes, org changes
- [ ] Audit entries are immutable (append-only)

### Administration
- [ ] `GET /admin/users` — list all users (ADMIN)
- [ ] `PATCH /admin/users/{id}` — activate/deactivate user
- [ ] `GET /admin/organizations` — list all orgs
- [ ] `GET /admin/bookings` — operational overview
- [ ] `GET /admin/reviews` — moderate reviews
- [ ] `GET /admin/audit-logs` — inspect audit trail

### Mobile
- [ ] Client: review submission screen (post-appointment)
- [ ] Client: view reviews on provider profile
- [ ] In-app notification list for client and provider
- [ ] Admin screens (basic operational views — admin may eventually move to web)

---

## Phase 7 — SaaS & Monetization

**Goal:** Billing infrastructure. Businesses can subscribe and pay.

> Commercial rules must be validated through market research before implementation.

### Domain Design
- [ ] `SubscriptionPlan` — tier definition (name, price, limits, features)
- [ ] `Subscription` — org-level subscription (plan, status, billing cycle, renewal date)
- [ ] Feature entitlements tied to plan (e.g., max providers, booking volume)
- [ ] Trial period support

### Backend
- [ ] `GET /subscriptions/plans` — list available plans (public)
- [ ] `POST /subscriptions` — subscribe org to plan
- [ ] `PATCH /subscriptions/{id}` — upgrade / downgrade
- [ ] `DELETE /subscriptions/{id}` — cancel subscription
- [ ] Billing integration (Stripe recommended — choose provider based on market)
- [ ] Webhook handler for payment events
- [ ] Invoice generation

### Entitlement Enforcement
- [ ] Check subscription status before allowing org to create new providers / bookings
- [ ] Graceful degradation when trial expires or payment fails

---

## Phase 8 — Production Launch

**Goal:** Harden for real users. Production infrastructure. Full test coverage.

### Infrastructure
- [ ] Production hosting (cloud provider TBD based on business decision)
- [ ] HTTPS enforced everywhere
- [ ] Database backups (automated, tested)
- [ ] Staging environment mirrors production
- [ ] CI/CD pipeline (lint → test → build → deploy to staging → promote to prod)
- [ ] Secret management (environment-based, never in source)

### Observability
- [ ] Structured JSON logging (FastAPI + Uvicorn)
- [ ] Error tracking (e.g., Sentry)
- [ ] Health check endpoint for load balancer probes
- [ ] Metrics (request latency, error rates, booking volume)
- [ ] Alerts for elevated error rates, slow queries, failed jobs

### Testing (Full Suite)
- [ ] Unit tests — pure business logic, availability engine, state transitions
- [ ] Integration tests — API endpoints with real DB (test database)
- [ ] Concurrency tests — double-booking race condition (explicit)
- [ ] Security tests — unauthorized access, cross-tenant access, injection
- [ ] Flutter widget tests
- [ ] Flutter integration tests on Android emulator
- [ ] Flutter integration tests on iOS simulator
- [ ] End-to-end tests — registration → booking → completion flow

### Database
- [ ] Migration process documented and tested against production backup
- [ ] Disaster recovery procedure documented and rehearsed

---

## Phase 9 — Online Meetings

**Goal:** Add virtual appointment fulfillment without touching the core booking engine.

### Architecture
```
Booking
├── fulfillment_method: ONLINE
└── Meeting (linked entity, separate lifecycle)
      └── Video infrastructure (third-party, e.g., Daily.co, Whereby, Zoom)
```
- The booking engine remains agnostic of video mechanics
- Meeting is created post-booking-confirmation as a side effect
- Meeting join links delivered via notification system

---

## Phase 10 — Platform Expansion

> Features are driven by customer demand and business evidence, not technical ambition.

### Scheduling
- Recurring appointments
- Group appointments
- Waitlists
- Resources / rooms
- Packages / memberships

### Commerce
- Payments at booking (Stripe)
- Refunds
- Provider payouts
- Coupons / discounts
- Tax handling
- Invoices to clients

### Intelligence
- Personalized provider recommendations
- Smart search
- Scheduling optimization
- Business insights dashboard

### Integrations
- Google Calendar sync
- Apple Calendar sync
- Outlook Calendar sync
- Webhooks (outbound event streams)
- Public API for third-party developers

---

## Engineering Principles (Non-Negotiable)

| # | Principle |
|---|---|
| 1 | Backend is always authoritative for business rules |
| 2 | Authorization enforced server-side on every request |
| 3 | Database integrity via constraints, not just app logic |
| 4 | Generic core — no hardcoded profession-specific logic |
| 5 | Modular monolith — extract services only when justified |
| 6 | Production-minded from day one |
| 7 | Build vertically — each feature spans Flutter → API → DB → API → Flutter |
| 8 | Document important decisions (why, not just what) |
| 9 | Prefer explicit, readable code over clever abstractions |
| 10 | Do not solve imaginary problems |

---

## Definition of Done (Per Feature)

A feature is not complete until every box is checked:

```
□ Domain model defined
□ Database migration created and tested
□ Backend logic implemented
□ Authorization implemented and tested
□ Input validation implemented
□ API endpoint implemented
□ Backend tests written (unit + integration)
□ Flutter UI implemented
□ Android tested
□ iOS tested
□ Error states handled in UI
□ Loading states handled in UI
□ Logging added for important operations
□ Documentation updated
□ Code reviewed
□ Git commit created
```

---

## Security Checklist (Every Phase)

- [ ] Passwords hashed with `bcrypt`
- [ ] JWTs short-lived; refresh tokens rotated
- [ ] No sensitive data in JWT payload or logs
- [ ] Rate limiting on auth endpoints
- [ ] Input validated and sanitised server-side
- [ ] Tenant isolation verified with cross-org access tests
- [ ] `SELECT FOR UPDATE` / serializable isolation for concurrency-sensitive writes
- [ ] Secrets in environment variables, not source code
- [ ] HTTPS in all non-local environments
- [ ] Audit log for sensitive operations

---

## First Steps (Start Here)

1. Create repository with conventional branch structure (`main`, `develop`)
2. Scaffold FastAPI project — modular folder layout:
   ```
   backend/
   ├── app/
   │   ├── main.py
   │   ├── core/          (config, security, db)
   │   ├── auth/
   │   ├── users/
   │   ├── organizations/
   │   ├── providers/
   │   ├── services/
   │   ├── availability/
   │   ├── bookings/
   │   ├── reviews/
   │   ├── notifications/
   │   └── admin/
   ├── alembic/
   ├── tests/
   └── docker-compose.yml
   ```
3. Scaffold Flutter project — feature-based folder layout:
   ```
   mobile/
   └── lib/
       ├── core/          (api client, router, theme)
       ├── auth/
       ├── client/
       ├── provider/
       ├── admin/
       ├── bookings/
       ├── services/
       ├── notifications/
       └── shared/
   ```
4. Start Docker Compose with PostgreSQL
5. Implement health endpoint
6. Confirm Flutter calls health endpoint on both Android and iOS

> **That is brick one. Lay it solid.**
