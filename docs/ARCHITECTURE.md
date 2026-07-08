# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                       Clients                            │
│  ┌───────────┐  ┌───────────┐  ┌──────────────────────┐ │
│  │ Patient   │  │  Doctor   │  │   Admin Panel        │ │
│  │ Flutter   │  │  Flutter  │  │   Flutter Web        │ │
│  │ Android   │  │  Android  │  │                      │ │
│  └─────┬─────┘  └─────┬─────┘  └──────────┬───────────┘ │
└────────┼──────────────┼───────────────────┼─────────────┘
         │              │                   │
         └──────────────┼───────────────────┘
                        │ HTTPS / WebSocket
                        ▼
         ┌──────────────────────────────────┐
         │          Nginx (Reverse Proxy)    │
         │     - TLS Termination             │
         │     - Rate Limiting               │
         │     - WebSocket Upgrade           │
         └──────────────┬───────────────────┘
                        │
                        ▼
         ┌──────────────────────────────────┐
         │         Node.js API Server        │
         │    Express + TypeScript            │
         │    Port 3000                       │
         │                                   │
         │  ┌─────────────────────────────┐  │
         │  │         Features             │  │
         │  │  auth | doctors | appts     │  │
         │  │  users | reviews | admin    │  │
         │  └─────────────┬───────────────┘  │
         │                │                  │
         │  ┌─────────────▼───────────────┐  │
         │  │      Prisma ORM              │  │
         │  └─────────────┬───────────────┘  │
         └────────────────┼──────────────────┘
                          │
              ┌───────────┼───────────┐
              │           │           │
              ▼           ▼           ▼
       ┌──────────┐ ┌──────────┐ ┌──────────┐
       │PostgreSQL│ │Cloudinary│ │ Firebase │
       │  (data)  │ │ (images) │ │  (FCM)   │
       └──────────┘ └──────────┘ └──────────┘
```

## Backend Architecture

Clean, layered architecture:

```
src/
├── auth/
│   ├── auth.routes.ts      # Route definitions + Swagger docs
│   ├── auth.controller.ts  # HTTP handlers
│   ├── auth.service.ts     # Business logic
│   └── auth.schema.ts      # Zod validation schemas
├── common/
│   ├── middleware/         # Auth, validation, error handling
│   ├── utils/              # JWT, hash, response helpers
│   ├── errors/             # AppError class
│   └── types/              # TypeScript types, pagination
├── config/                 # DB, Firebase, Cloudinary, Swagger
└── jobs/                   # Cron jobs (reminders, cleanup)
```

## Flutter Architecture

Feature-first structure with Clean Architecture layers:

```
lib/
├── core/
│   ├── theme/          # Colors, typography, themes
│   ├── router/         # GoRouter configuration
│   ├── network/        # Dio + interceptors
│   ├── storage/        # Secure storage
│   └── widgets/        # Reusable components
└── features/
    └── feature_name/
        ├── data/           # API calls, DTOs
        ├── domain/         # Entities, use cases
        └── presentation/
            ├── screens/    # UI screens
            ├── providers/  # Riverpod providers
            └── widgets/    # Feature-specific widgets
```

## Database Design Principles

- **UUIDs** for all primary keys (prevent enumeration)
- **Soft deletes** on critical entities (users, doctors)
- **Audit logging** for all admin actions
- **Proper indexing** on all foreign keys and query fields
- **Transactions** for all multi-step operations (booking, cancel)
- **Optimistic concurrency** via Prisma `$transaction` for slot booking

## Security Architecture

```
Request
  → CORS check
  → Helmet headers
  → Rate limiter
  → JWT auth middleware
  → Role authorization
  → Zod validation
  → Controller
  → Service (business logic)
  → Prisma (SQL-injection safe via parameterized queries)
  → Response
```

## Real-time Architecture (Socket.IO)

Used selectively for:
- **Slot availability updates**: When a slot is locked/booked, emit to room `slots:{doctorId}:{date}`
- Room: `slots:<doctorId>:<date>` — all patients viewing that doctor's slots that day

## Booking Engine

The slot booking system prevents race conditions through:

1. **Temporary slot lock** (120 seconds): Patient locks a slot before booking
2. **Database transaction**: The actual booking uses a `$transaction` to atomically:
   - Verify slot is still available/locked by this user
   - Update slot status to BOOKED
   - Create appointment record
   - Create status history
3. **Cron job**: Releases expired locks every minute
4. **Unique constraint**: `doctorId + clinicId + date + startTime` prevents duplicates

## Notification Strategy

```
Cron (hourly) → Find appointments needing 24h reminder
              → Send FCM via firebase-admin
              → Store in notifications table
              → Mark appointment as reminded

Cron (15min)  → Find appointments needing 1h reminder
              → Same flow

Event-driven  → On booking/cancel/reschedule
(in service)  → Send immediate FCM
              → Create notification record
```
