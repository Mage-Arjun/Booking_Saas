# Booking SaaS Platform

A production-oriented, multi-tenant SaaS platform for discovering service providers, managing availability, and booking appointments.

The platform is designed to work across multiple service industries rather than being tied to a single profession.

A customer might book:

- a financial advisor
- a doctor
- a teacher
- a consultant
- a lawyer
- a personal trainer
- a therapist
- a salon professional
- or any other appointment-based service provider

The initial product focuses exclusively on **appointment booking and scheduling**.

Online meetings, payments, advanced analytics, AI features, and other capabilities are deliberately deferred until the core booking platform is stable.

---

## 1. Product Vision

The goal is to build a general-purpose booking infrastructure that can serve both as:

1. A **marketplace**, where customers discover and book providers.
2. A **booking SaaS**, where businesses and independent providers manage their own booking operations and share booking pages with customers.

The underlying platform should not assume that every provider is a doctor, advisor, teacher, or any other specific profession.

The core relationship is:

```text
Customer
    │
    │ books
    ▼
Provider
    │
    ├── Services
    ├── Availability
    └── Bookings
```

The product is therefore built around generic concepts such as:

- Customer
- Provider
- Organization
- Service
- Availability
- Booking
- Review

Industry-specific functionality can be introduced later without contaminating the core booking engine.

---

# 2. Current Product Scope

## V1 — Core Booking Platform

### Customer

Customers can:

- create an account
- authenticate securely
- discover providers
- search and filter providers
- view provider profiles
- view available services
- view provider availability
- select an appointment slot
- create bookings
- view upcoming bookings
- view historical bookings
- cancel bookings
- reschedule bookings where permitted
- receive booking notifications
- review completed appointments

### Provider

Providers can:

- create an account
- create and manage their profile
- belong to an organization
- create services
- configure service duration
- configure pricing
- configure availability
- define scheduling rules
- view their calendar
- manage bookings
- view customer information
- view appointment history
- receive reviews
- manage their business profile

### Administrator

Administrators operate the platform itself.

They can eventually:

- manage users
- manage organizations
- manage providers
- verify providers
- oversee bookings
- moderate reviews
- manage platform configuration
- access operational reports
- inspect audit logs
- manage subscriptions
- manage billing-related operations

---

# 3. Roles

The platform has three primary roles.

```text
CLIENT
PROVIDER
ADMIN
```

## CLIENT

The person booking a service.

Examples:

```text
Patient
Student
Client
Customer
Member
```

The role is intentionally called `CLIENT` internally to keep the domain generic.

---

## PROVIDER

The person or professional providing a bookable service.

Examples:

```text
Doctor
Advisor
Teacher
Consultant
Lawyer
Trainer
Therapist
```

The provider is not hardcoded to any profession.

---

## ADMIN

The platform operator.

An administrator manages the SaaS platform rather than acting as a normal provider or customer.

---

# 4. Important Domain Principle

Roles, permissions, and organization membership are separate concepts.

A user's role answers:

> What type of platform participant is this?

Permissions answer:

> What is this user allowed to do?

Organization membership answers:

> Which business or organization does this user belong to?

These concepts should not be unnecessarily coupled.

---

# 5. Multi-Tenancy

This is a SaaS platform, so multiple businesses must be able to use the same infrastructure securely.

Example:

```text
Booking Platform
│
├── ABC Clinic
│   ├── Dr. A
│   ├── Dr. B
│   └── Dr. C
│
├── XYZ Consulting
│   ├── Advisor A
│   └── Advisor B
│
└── ABC Academy
    ├── Teacher A
    ├── Teacher B
    └── Teacher C
```

Each organization's data must be isolated.

A provider or administrator associated with one organization must never be able to access another organization's private information without explicit authorization.

Multi-tenancy is therefore both:

- a business requirement
- a security requirement

---

# 6. Marketplace and Direct Booking

The platform is designed to eventually support two booking paths.

## Marketplace

A customer discovers a provider through the platform.

```text
Customer
    ↓
Search
    ↓
Provider
    ↓
Service
    ↓
Availability
    ↓
Booking
```

## Direct Booking

A business can have a dedicated booking page.

```text
Business
    ↓
Public Booking Page
    ↓
Customer
    ↓
Service
    ↓
Availability
    ↓
Booking
```

These two experiences should share the same underlying booking infrastructure.

This distinction is important because a booking platform should not assume that every appointment originates from marketplace discovery.

---

# 7. Core Domain Model

The initial domain consists of:

```text
User
Organization
Client Profile
Provider Profile
Service
Availability
Booking
Review
Notification
Subscription
```

The core relationships look approximately like this:

```text
                    User
                     │
          ┌──────────┼──────────┐
          │          │          │
       Client     Provider     Admin
                     │
              ┌──────┴──────┐
              │             │
          Organization   Services
                            │
                       Availability
                            │
                         Booking
                       ┌────┴────┐
                       │         │
                    Client    Provider
                       │
                     Review
```

The exact database schema will evolve during implementation.

---

# 8. Booking Model

Booking is the central business object.

Conceptually:

```text
Booking
├── ID
├── Customer
├── Provider
├── Service
├── Start time
├── End time
├── Timezone context
├── Status
├── Created at
└── Updated at
```

Initial booking states:

```text
PENDING
CONFIRMED
CANCELLED
COMPLETED
NO_SHOW
```

Additional states may be introduced if the business requires them.

---

# 9. Availability Engine

Availability is more than a list of free times.

The system must consider:

```text
Provider working hours
        +
Service duration
        +
Existing bookings
        +
Blocked periods
        +
Days off
        +
Holidays
        +
Booking buffers
        +
Minimum notice
        +
Maximum advance booking
        +
Timezone
        ↓
Available appointment slots
```

The availability engine must be implemented on the backend.

The Flutter application may display availability, but it is not the authority on whether a slot is actually available.

---

# 10. Double-Booking Protection

Preventing double bookings is a critical business requirement.

For example:

```text
Customer A ──┐
             ├── 10:00 AM ── Provider
Customer B ──┘
```

Two customers attempting to reserve the same slot concurrently must not both succeed.

The solution must involve proper backend transaction/concurrency handling and database-level protection where appropriate.

This will be explicitly tested.

---

# 11. Timezone Strategy

Appointments involve real-world time, so timezone handling is a first-class concern.

The system should:

- store canonical timestamps consistently
- preserve the relevant timezone context
- calculate availability correctly
- convert times for the user's local presentation
- avoid relying on device-local time as the source of truth

UTC will be used as the canonical storage/reference standard, with timezone-aware conversion for presentation and scheduling logic.

Timezone handling will be tested around:

- daylight-saving transitions
- users in different timezones
- providers and customers in different regions
- appointment creation
- rescheduling
- cancellation windows

---

# 12. Technology Stack

## Mobile

**Flutter / Dart**

One codebase will target:

```text
Android
iOS
```

Development will happen against both platforms from the beginning rather than building one platform first and porting later.

---

## Backend

**Python / FastAPI**

FastAPI provides the HTTP API consumed by the Flutter application.

The backend is responsible for:

- authentication
- authorization
- validation
- business rules
- scheduling
- booking
- notifications
- database access
- platform operations

---

## Database

**PostgreSQL**

PostgreSQL is the system of record for persistent application data.

The Flutter application does not connect directly to PostgreSQL.

The intended flow is:

```text
Flutter
   ↓
HTTPS
   ↓
FastAPI
   ↓
SQLAlchemy
   ↓
PostgreSQL
```

---

## ORM

**SQLAlchemy 2.x**

SQLAlchemy will provide the application/database mapping layer.

The project favors explicit, understandable database interactions rather than hiding important business behavior behind excessive abstraction.

---

## Database Migrations

**Alembic**

Schema changes will be managed through versioned migrations.

Database structure should never depend on manually modifying production tables.

---

## Local Infrastructure

**Docker / Docker Compose**

Docker will primarily provide local infrastructure such as PostgreSQL.

The initial development environment does not need a large collection of containers.

For example:

```text
CachyOS
│
├── Flutter
├── FastAPI
│
└── Docker
    └── PostgreSQL
```

Additional infrastructure such as Redis will be introduced only when there is a concrete requirement.

---

# 13. Architecture

The initial backend will be a **modular monolith**.

This is intentional.

The project will not begin with microservices.

Conceptually:

```text
FastAPI Application
│
├── Authentication
├── Users
├── Organizations
├── Clients
├── Providers
├── Services
├── Availability
├── Bookings
├── Reviews
├── Notifications
├── Administration
└── Subscriptions
```

The modules share a single backend application and database while maintaining clear domain boundaries.

If a future module genuinely needs to become an independent service, it can be extracted later.

The architecture should optimize for:

- correctness
- maintainability
- observability
- security
- understandable code

rather than architectural complexity for its own sake.

---

# 14. Mobile Architecture

Flutter will be structured around clear feature/domain boundaries rather than a giant collection of screens.

Conceptually:

```text
mobile/
│
├── authentication/
├── client/
├── provider/
├── admin/
├── providers/
├── services/
├── bookings/
├── profile/
├── notifications/
└── shared/
```

The exact Flutter architecture will be finalized during Phase 0 based on the needs of the application.

The client should not contain authoritative business rules.

For example:

```text
Flutter:
"Show these available slots."

Backend:
"These are actually available."
```

---

# 15. API Principles

The backend will expose a versioned, documented API.

Example endpoint groups:

```text
/auth
/users
/organizations
/providers
/services
/availability
/bookings
/reviews
/notifications
/admin
/subscriptions
```

Examples:

```text
POST /auth/register
POST /auth/login
POST /auth/logout

GET /users/me

GET /providers
GET /providers/{id}

GET /providers/{id}/services
GET /providers/{id}/availability

POST /bookings
GET /bookings
GET /bookings/{id}

POST /reviews
```

Exact endpoint naming will be determined while implementing each domain.

---

# 16. Security Principles

Security is part of the architecture, not a final polishing step.

The system must implement:

- secure password hashing
- secure authentication/session handling
- server-side authorization
- input validation
- tenant isolation
- rate limiting where appropriate
- secure secrets management
- HTTPS in production
- safe file handling
- database access controls
- audit logging for sensitive operations
- appropriate error handling without leaking sensitive information

The frontend hiding a button is never considered authorization.

The backend must independently verify every protected operation.

---

# 17. Authentication vs Authorization

These are separate.

### Authentication

> Who are you?

### Authorization

> Are you allowed to perform this operation?

Example:

```text
Authenticated CLIENT
    ↓
POST /bookings
    ↓
Allowed
```

But:

```text
Authenticated CLIENT
    ↓
Delete another user's account
    ↓
Denied
```

Authorization must be enforced server-side.

---

# 18. Data Philosophy

The application should not depend on hardcoded fake users or fake business data.

Bad:

```text
if email == "client@test.com":
    show_client_dashboard()
```

Development data should instead live in a development database through controlled seed/fixture mechanisms.

The application should communicate with the same APIs and database structures that will eventually be used in production.

This keeps development behavior close to real production behavior.

---

# 19. Development Environment

The initial local environment will run on the developer's machine.

Typical architecture:

```text
Developer Machine
│
├── Flutter
│   ├── Android
│   └── iOS
│
├── FastAPI
│
└── Docker
    └── PostgreSQL
```

Docker images and volumes are persistent on disk.

Restarting the Docker daemon or rebooting the machine does not inherently recreate images or delete database volumes.

Persistent database storage will use Docker volumes.

---

# 20. Development Philosophy

This is a real commercial product.

It is also being developed brick by brick for learning and maintainability.

Those goals are not contradictory.

The project follows:

> **Small scope, serious engineering.**

We intentionally build a small amount of functionality at a time, but we do not intentionally build disposable architecture.

We avoid:

- hardcoded business logic
- fake production behavior
- unnecessary microservices
- premature optimization
- unnecessary infrastructure
- copy-pasted code
- unexplained abstractions
- security shortcuts
- database hacks
- "we'll fix it later" decisions around core architecture

At the same time, we avoid:

- building features before they are needed
- introducing infrastructure without a concrete requirement
- solving hypothetical scaling problems before users exist
- creating abstractions merely because they sound sophisticated

Every architectural decision should have a reason.

---

# 21. Development Workflow

Each feature is built as a vertical slice.

```text
Requirement
    ↓
Domain design
    ↓
Database design
    ↓
Backend implementation
    ↓
Backend tests
    ↓
API integration
    ↓
Flutter implementation
    ↓
Android testing
    ↓
iOS testing
    ↓
End-to-end testing
    ↓
Documentation
    ↓
Git commit
```

The frontend and backend are therefore developed simultaneously.

---

# 22. Product Roadmap

## Phase 0 — Foundation

Establish:

- repository
- development environment
- Flutter application
- FastAPI application
- PostgreSQL
- Docker
- API conventions
- database conventions
- architectural decisions
- testing foundations

First technical proof:

```text
Flutter
   ↓
FastAPI
   ↓
PostgreSQL
```

---

## Phase 1 — Identity & Access

Build:

- registration
- login
- logout
- authentication
- session/token handling
- password security
- email verification
- role handling
- authorization

Roles:

```text
CLIENT
PROVIDER
ADMIN
```

---

## Phase 2 — Organizations & Provider Setup

Build:

- organizations
- organization membership
- provider profiles
- business profiles
- provider categories
- locations
- verification foundations

Establish secure tenant isolation.

---

## Phase 3 — Services & Scheduling

Build:

- services
- service duration
- pricing
- provider availability
- working hours
- breaks
- blocked periods
- holidays
- booking buffers
- booking rules
- timezone handling

Build and test the availability engine.

---

## Phase 4 — Marketplace & Booking

Build:

- provider discovery
- search
- filtering
- provider profiles
- service selection
- availability display
- booking creation
- booking confirmation

Critical requirement:

**No double booking.**

---

## Phase 5 — Booking Operations

Build:

- client booking history
- provider calendar
- booking management
- cancellation
- rescheduling
- no-show handling
- configurable booking policies

At the end of this phase, the platform should support the complete basic appointment lifecycle.

---

## Phase 6 — Trust & Notifications

Build:

- reviews
- review eligibility
- moderation
- booking notifications
- appointment reminders
- audit logs
- administrative operations

---

## Phase 7 — SaaS & Monetization

Build:

- subscription model
- plans
- feature entitlements
- usage limits
- billing integration
- invoices
- trials
- upgrades
- downgrades
- subscription cancellation

Pricing and commercial rules will be determined through actual business research rather than technical assumptions.

---

## Phase 8 — Production Launch

Harden the system for real customers.

Build/configure:

- production infrastructure
- HTTPS
- backups
- monitoring
- error tracking
- structured logging
- CI/CD
- staging
- security controls
- database migration process
- disaster recovery procedures

Testing includes:

- unit tests
- integration tests
- API tests
- concurrency tests
- security tests
- Flutter tests
- Android testing
- iOS testing
- end-to-end testing

---

## Phase 9 — Online Meetings

Online meetings are intentionally postponed.

The booking system will already support the concept of fulfillment methods.

Eventually:

```text
Booking
│
├── IN_PERSON
├── ONLINE
└── PHONE
```

An online booking can create an associated meeting:

```text
Booking
   ↓
Meeting
   ↓
Video infrastructure
```

The platform should preferably integrate established video infrastructure rather than immediately attempting to build a global video conferencing system from scratch.

---

## Phase 10 — Platform Expansion

Potential future capabilities include:

### Scheduling

- recurring appointments
- group appointments
- resources
- rooms
- waitlists
- packages
- memberships

### Commerce

- payments
- refunds
- provider payouts
- coupons
- taxes
- invoices

### Intelligence

- recommendations
- smart search
- scheduling optimization
- AI assistants
- business insights

### Integrations

- Google Calendar
- Apple Calendar
- Outlook
- CRM systems
- accounting systems
- webhooks
- public API

These features should be driven by customer demand and business evidence.

---

# 23. Release Strategy

The phases map to four major releases.

## Internal Alpha

```text
Phases 0–2
```

Question:

> Can the platform securely represent users, providers, organizations, and administrators?

---

## Functional MVP

```text
Phases 3–5
```

Question:

> Can a customer discover a provider and successfully book an appointment?

---

## Commercial MVP

```text
Phases 6–8
```

Question:

> Can real businesses use the platform reliably and pay for it?

---

## Platform Expansion

```text
Phases 9–10+
```

Question:

> Can the booking platform evolve into a broader service-engagement platform?

---

# 24. Testing Philosophy

Tests are not added only before launch.

Critical business rules should be tested when they are introduced.

Particular attention should be given to:

### Authentication

- invalid credentials
- expired sessions
- unauthorized access
- role restrictions

### Multi-tenancy

- cross-organization access attempts
- organization membership
- provider isolation

### Scheduling

- overlapping availability
- blocked periods
- timezone changes
- daylight-saving transitions
- minimum notice
- maximum advance booking

### Booking

- duplicate booking attempts
- concurrent booking requests
- cancellation rules
- rescheduling rules
- invalid services
- unavailable providers

Booking concurrency is particularly important because a race condition can create real business problems.

---

# 25. Observability

A production SaaS cannot depend on developers manually inspecting database records whenever something breaks.

The platform should eventually provide:

```text
Logs
Metrics
Errors
Audit Events
Health Checks
```

Important operations should be traceable.

For example:

```text
Customer
   ↓
Created booking
   ↓
Booking ID
   ↓
Provider
   ↓
Status changed
   ↓
Notification sent
```

This makes production debugging possible.

---

# 26. Administration

The administrator experience is operationally different from the client/provider experiences.

Initially, the admin functionality can exist within the same overall product architecture.

However, the long-term plan should allow the admin interface to become a dedicated web application if that provides a better operational experience.

The architecture should not assume that administrators will permanently manage the platform from a mobile phone.

---

# 27. Future Online Meeting Architecture

The booking system should remain independent from the video system.

Conceptually:

```text
Booking
│
├── Customer
├── Provider
├── Service
├── Time
└── Fulfillment Method
          │
          └── ONLINE
                ↓
              Meeting
                ↓
        Video infrastructure
```

This means the booking engine does not need to understand the internal mechanics of video communication.

That separation allows online meetings to be introduced without rewriting the core scheduling system.

---

# 28. Business Model

The long-term product is intended to operate as SaaS.

Potential customers include:

- individual professionals
- small businesses
- clinics
- consulting firms
- educational businesses
- service organizations
- larger organizations

Potential revenue models include:

```text
Subscription
Transaction fee
Hybrid
Enterprise pricing
```

The final commercial model should be determined through market validation.

The technical architecture should support subscription-based SaaS without forcing a particular pricing strategy prematurely.

---

# 29. Non-Goals

The project will deliberately avoid implementing everything at once.

The following are not initial priorities:

- custom video conferencing infrastructure
- microservice architecture
- AI recommendation systems
- complex payment infrastructure
- advanced CRM
- enterprise analytics
- global-scale infrastructure
- unnecessary caching
- unnecessary distributed systems

Complexity should be introduced when justified by:

1. product requirements
2. customer demand
3. measurable technical constraints
4. operational requirements

---

# 30. Engineering Principles

### 1. Backend is authoritative

The client application is never the source of truth for business rules.

### 2. Security is enforced server-side

UI restrictions are not security controls.

### 3. Database integrity matters

Important business invariants should be protected at the appropriate database/application layers.

### 4. Generic core, specialized extensions

The booking engine should work across industries.

### 5. Modular monolith first

Start simple enough to understand.

Extract services only when there is a real reason.

### 6. Production-minded from day one

Development shortcuts must not become architectural dependencies.

### 7. Build vertically

Each completed feature should work from:

```text
Flutter → API → Database → API → Flutter
```

### 8. Document important decisions

Future developers should understand not only what was built, but why.

### 9. Prefer explicit code

Code should teach the maintainer how the system works.

### 10. Do not solve imaginary problems

Engineering effort should follow actual product needs.

---

# 31. Project Definition of Done

A feature is not considered complete merely because its screen exists.

A feature should generally satisfy:

```text
□ Domain model defined
□ Database changes implemented
□ Migration created
□ Backend logic implemented
□ Authorization implemented
□ Validation implemented
□ API endpoint implemented
□ Backend tests written
□ Flutter integration implemented
□ Android tested
□ iOS tested
□ Error states handled
□ Loading states handled
□ Logging considered
□ Documentation updated
□ Code reviewed
□ Git commit created
```

The exact checklist can evolve as the project matures.

---

# 32. Initial Development Milestone

The first milestone is intentionally tiny.

```text
Flutter
    ↓
Login
    ↓
FastAPI
    ↓
Authentication
    ↓
PostgreSQL
    ↓
User role
    ↓
┌──────────────┬──────────────┐
│              │              │
CLIENT      PROVIDER        ADMIN
│              │              │
Client UI   Provider UI    Admin UI
```

This must work on:

```text
Android
iOS
```

using real backend communication and real database records.

No hardcoded users.

No fake authentication.

No simulated API.

No database logic hidden inside Flutter.

---

# 33. First Implementation Target

The first code should not be the booking engine.

The first brick is:

```text
1. Repository
2. Flutter project
3. FastAPI project
4. PostgreSQL
5. Docker Compose
6. Development configuration
7. Health endpoint
8. Flutter API client
9. Database connection
10. First migration
```

Then we prove:

```text
Android ──┐
          ├──→ FastAPI ──→ PostgreSQL
iOS ──────┘
```

Once that foundation is stable, authentication becomes the next brick.

---

# 34. Long-Term Product Vision

The ultimate platform can evolve from:

```text
Appointment Booking
```

into:

```text
                    SERVICE PLATFORM
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
      Booking          Meetings          Commerce
        │                 │                 │
    Scheduling          Video          Payments
        │                 │                 │
        └─────────────────┼─────────────────┘
                          │
                     Businesses
                          │
                       Customers
```

But the foundation remains the same:

> **Connect customers with service providers and make scheduling that relationship reliable.**

The first product does not need to do everything.

It needs to do **booking exceptionally well**.