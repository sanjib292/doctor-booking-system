<div align="center">

<img src="https://img.shields.io/badge/Flutter-3.22+-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
<img src="https://img.shields.io/badge/Node.js-20+-339933?style=for-the-badge&logo=nodedotjs&logoColor=white"/>
<img src="https://img.shields.io/badge/PostgreSQL-16+-4169E1?style=for-the-badge&logo=postgresql&logoColor=white"/>
<img src="https://img.shields.io/badge/TypeScript-5.5+-3178C6?style=for-the-badge&logo=typescript&logoColor=white"/>
<img src="https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white"/>

# 🏥 DoctorBook — Doctor Appointment Booking System

**A production-ready, full-stack doctor appointment booking platform.**  
Patients discover nearby doctors, book real-time appointments, and doctors + admins manage everything from dedicated apps.

[Features](#-features) · [Tech Stack](#-tech-stack) · [Quick Start](#-quick-start) · [Screenshots](#-app-screenshots) · [API Docs](#-api-documentation) · [Deployment](#-deployment)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Quick Start](#-quick-start)
- [Environment Variables](#-environment-variables)
- [API Documentation](#-api-documentation)
- [Database Schema](#-database-schema)
- [Architecture](#-architecture)
- [Deployment](#-deployment)
- [Testing](#-testing)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)

---

## 🌟 Overview

DoctorBook is a **complete, production-grade** doctor appointment booking ecosystem consisting of:

| App | Platform | Users |
|-----|----------|-------|
| **Patient App** | Flutter Android | Patients searching & booking doctors |
| **Doctor App** | Flutter Android | Doctors managing schedules & appointments |
| **Admin Panel** | Flutter Web | Admins managing the entire platform |
| **Backend API** | Node.js + TypeScript | Powers all three apps |

Built with **Clean Architecture**, **SOLID principles**, and designed to scale to **millions of users**.

---

## ✨ Features

### 👤 Patient App

#### Authentication
- 📱 **Frictionless OTP login** — phone number + 6-digit OTP
- 🔐 JWT access tokens + rotating refresh tokens
- 📝 Minimal registration — name, gender, age (all optional except name)

#### Doctor Discovery
- 📍 **GPS-based nearby doctor search** — auto-detects location on app open
- 🗺️ Configurable search radius (5 km, 10 km, 20 km, 50 km)
- 🏥 Browse by **specialty/category** (Cardiology, Neurology, Pediatrics, etc.)
- 🔍 **Smart search** — by name, specialty, or clinic
- 🎛️ **Advanced filters**: distance, rating, fee range, experience, gender
- 📊 **Sort by**: distance, rating, consultation fee, experience
- ❤️ **Favorites** — save doctors for quick access
- 🌆 **City search** — book for someone in a different city

#### Doctor Profiles
- Full profile: photo, qualifications, experience, about, languages
- Ratings & reviews with distribution breakdown
- Clinic details with **Google Maps** integration & navigation
- Clinic images gallery
- Real-time availability calendar

#### Booking Engine
- 📅 **Smart calendar** — shows only available dates
- ⏰ **Time slot grid** — grayed out unavailable slots
- 🔒 **2-minute slot hold** — live countdown timer prevents double-booking
- ✅ **Transactional booking** — atomic, race-condition-proof confirmation
- 📩 Instant booking confirmation with appointment ID
- 📝 Optional notes for the doctor

#### Appointment Management
- **Upcoming** — confirmed & pending appointments
- **History** — completed & cancelled appointments
- **Reschedule** — pick a new slot for existing appointments
- **Cancel** — with reason, slot instantly freed for others
- Status tracking: Confirmed → Checked In → In Consultation → Completed

#### Notifications
- 🔔 Push notifications (Firebase FCM)
- 📬 In-app notification center with read/unread status
- Booking confirmed, 24h reminder, 1h reminder, cancellation, reschedule

#### Reviews & Ratings
- ⭐ 1–5 star rating + comment
- Only available after **completed** appointments
- Rating distribution breakdown per doctor

#### Other
- 🌙 **Dark mode** support
- 💀 Skeleton loading screens
- 🔄 Pull-to-refresh everywhere
- 📵 Offline graceful degradation
- 🗑️ Account deletion (GDPR-friendly soft delete)

---

### 🩺 Doctor App

- 🔐 Email + password login (admin-provisioned accounts)
- 📊 **Today's dashboard** — appointment stats at a glance
- 📋 Appointment list with patient details
- Status updates: Checked In → In Consultation → Completed / No Show
- 📅 Schedule management — working hours, breaks
- 🏖️ Vacation / blocked date management
- 🔔 Push notifications for new bookings, cancellations, reviews

---

### 🖥️ Admin Panel (Flutter Web)

- 🔒 Admin authentication with role-based access (ADMIN / SUPER_ADMIN)
- 📊 **Dashboard KPIs** — total users, doctors, appointments, clinics
- 📈 **Charts** — appointments by status (pie chart), trends
- 👨‍⚕️ **Doctor management** — create, verify, activate/deactivate, view all
- 👥 **User management** — search, view, block/unblock
- 🏥 **Clinic management** — CRUD, coordinates, images, contact
- 📅 **Appointment oversight** — view all, cancel, reschedule
- 🏷️ **Category management** — specialties with icons and colors
- ⭐ **Review moderation** — show/hide reviews
- 📜 **Audit logs** — every admin action tracked
- 📱 **Responsive design** — full sidebar on desktop, rail on tablet, bottom nav on mobile

---

### ⚙️ Backend API

- 🔐 OTP authentication, JWT with refresh token rotation
- 📍 Haversine geo-distance calculation for nearby doctors
- 🔒 Race-condition-proof slot booking with DB transactions
- ⏱️ Cron jobs — 24h/1h reminders, auto-lock release, token/OTP cleanup
- 🌐 Socket.IO — real-time slot availability broadcast
- 📤 Cloudinary image upload with auto-optimization
- 📧 Nodemailer email support
- 🔥 Firebase Admin SDK for push notifications
- 📚 Swagger/OpenAPI documentation
- 🛡️ Helmet, CORS, rate limiting, Zod validation
- 📊 Structured logging (Winston)
- 🐳 Docker + Nginx production setup

---

## 🛠 Tech Stack

### Frontend (Flutter)

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Navigation & deep links |
| `dio` | HTTP client with interceptors |
| `firebase_messaging` | Push notifications (FCM) |
| `flutter_secure_storage` | Encrypted token storage |
| `hive_flutter` | Local data caching |
| `geolocator` | GPS location |
| `google_maps_flutter` | Map display |
| `cached_network_image` | Image caching |
| `table_calendar` | Appointment date picker |
| `pin_code_fields` | OTP input |
| `fl_chart` | Admin charts |
| `shimmer` | Skeleton loaders |
| `lottie` | Animations |
| `freezed` + `json_serializable` | Code generation |

### Backend (Node.js)

| Package | Purpose |
|---------|---------|
| `express` | HTTP server |
| `typescript` | Type safety |
| `prisma` | ORM + migrations |
| `zod` | Runtime validation |
| `jsonwebtoken` | JWT auth |
| `bcryptjs` | Password hashing |
| `firebase-admin` | FCM push notifications |
| `cloudinary` | Image storage & CDN |
| `socket.io` | Real-time updates |
| `cron` | Scheduled jobs |
| `nodemailer` | Email sending |
| `multer` | File uploads |
| `helmet` | HTTP security headers |
| `express-rate-limit` | API rate limiting |
| `swagger-jsdoc` | API documentation |
| `winston` | Structured logging |

### Infrastructure

| Tool | Purpose |
|------|---------|
| PostgreSQL 16 | Primary database |
| Docker + Compose | Containerization |
| Nginx | Reverse proxy + TLS |
| GitHub Actions | CI/CD |

---

## 📁 Project Structure

```
doctor-booking-system/                    ← Monorepo root
│
├── apps/
│   ├── patient_app/                      ← Flutter Android (Patient)
│   │   └── lib/
│   │       ├── core/
│   │       │   ├── theme/                ← Colors, typography, Material 3 themes
│   │       │   ├── router/               ← GoRouter with auth guard
│   │       │   ├── network/              ← Dio + auto token refresh interceptor
│   │       │   ├── storage/              ← Encrypted secure storage
│   │       │   └── widgets/              ← Reusable UI components
│   │       └── features/
│   │           ├── auth/                 ← OTP login flow
│   │           ├── home/                 ← Dashboard + categories
│   │           ├── doctors/              ← Search, filters, profile
│   │           ├── appointments/         ← Slot selection, booking, history
│   │           ├── profile/              ← User profile + settings
│   │           └── notifications/        ← Notification center
│   │
│   ├── doctor_app/                       ← Flutter Android (Doctor)
│   │   └── lib/
│   │       └── features/
│   │           ├── auth/                 ← Email/password login
│   │           ├── dashboard/            ← Today's appointments + stats
│   │           ├── appointments/         ← Full appointment management
│   │           ├── schedule/             ← Availability & vacation config
│   │           └── profile/              ← Doctor profile
│   │
│   ├── admin_panel/                      ← Flutter Web (Admin)
│   │   └── lib/
│   │       ├── core/widgets/             ← Responsive admin shell
│   │       └── features/
│   │           ├── dashboard/            ← KPIs + charts
│   │           ├── doctors/              ← Doctor CRUD + verification
│   │           ├── users/                ← User management
│   │           ├── clinics/              ← Clinic management
│   │           └── appointments/         ← Appointment oversight
│   │
│   └── api/                              ← Node.js Backend
│       ├── prisma/
│       │   ├── schema.prisma             ← 18-model DB schema
│       │   └── seed.ts                   ← Initial data seeder
│       └── src/
│           ├── auth/                     ← OTP, JWT, refresh tokens
│           ├── doctors/                  ← Search, profile, categories
│           ├── appointments/             ← Slot engine + booking
│           ├── users/                    ← Profile, favorites, notifications
│           ├── reviews/                  ← Reviews + rating recalculation
│           ├── admin/                    ← Admin CRUD operations
│           ├── jobs/                     ← Cron jobs (reminders, cleanup)
│           └── common/
│               ├── middleware/           ← Auth, validation, error handling
│               ├── utils/                ← JWT, hash, response, dates
│               ├── errors/               ← AppError class
│               └── types/                ← Pagination, Express types
│
├── packages/                             ← Shared Flutter packages (future)
│   ├── shared_models/
│   ├── shared_ui/
│   ├── shared_utils/
│   └── shared_constants/
│
├── docker/
│   ├── docker-compose.yml                ← Production stack
│   ├── docker-compose.dev.yml            ← Dev (DB + PgAdmin only)
│   └── nginx.conf                        ← Nginx reverse proxy config
│
├── docs/
│   ├── ARCHITECTURE.md                   ← System design + diagrams
│   ├── SETUP.md                          ← Local setup guide
│   └── DEPLOYMENT.md                     ← Production deployment guide
│
├── .github/workflows/ci.yml              ← GitHub Actions CI/CD
└── melos.yaml                            ← Monorepo Flutter workspace
```

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| **Node.js** | 20+ | [nodejs.org](https://nodejs.org) |
| **Flutter** | 3.22+ stable | [flutter.dev](https://docs.flutter.dev/get-started/install) |
| **Docker** | 24+ | [docker.com](https://docs.docker.com/get-docker/) |
| **Git** | 2.40+ | [git-scm.com](https://git-scm.com) |

---

### Step 1 — Clone the Repository

```bash
git clone https://github.com/SanjibSah007/doctor-booking-system.git
cd doctor-booking-system
```

---

### Step 2 — Start the Database

```bash
cd docker
docker compose -f docker-compose.dev.yml up -d
```

> **PgAdmin** (optional): http://localhost:5050  
> Login: `admin@doctorbooking.com` / `admin`  
> Connect to host `postgres`, user `postgres`, password `postgres`

---

### Step 3 — Configure & Run the API

```bash
cd apps/api

# 1. Copy and configure environment
cp .env.example .env
```

Open `.env` and set at minimum:
```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/doctor_booking
JWT_ACCESS_SECRET=your-super-secret-access-key-minimum-32-characters
JWT_REFRESH_SECRET=your-super-secret-refresh-key-minimum-32-characters
```

```bash
# 2. Install dependencies
npm install

# 3. Generate Prisma client
npx prisma generate

# 4. Run database migrations
npx prisma migrate dev --name init

# 5. Seed initial data
npm run prisma:seed

# 6. Start dev server (hot-reload)
npm run dev
```

✅ API running at: **http://localhost:3000**  
✅ Swagger UI at: **http://localhost:3000/api/v1/docs**

**Seeded credentials:**

| Role | Email | Password |
|------|-------|---------|
| Super Admin | `admin@doctorbooking.com` | `Admin@123456` |
| Sample Doctor | `dr.sharma@doctorbooking.com` | `Doctor@123456` |

---

### Step 4 — Run the Patient App

```bash
cd apps/patient_app

# Get dependencies
flutter pub get

# Generate code (Freezed, JSON serializable)
flutter pub run build_runner build --delete-conflicting-outputs

# Run on Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

> 💡 `10.0.2.2` is Android emulator's alias for your machine's `localhost`.  
> For a physical device, use your machine's local IP: e.g. `192.168.1.x`

**Development tip**: OTPs are printed to the API server console — no SMS provider needed.

---

### Step 5 — Run the Doctor App

```bash
cd apps/doctor_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

Login with: `dr.sharma@doctorbooking.com` / `Doctor@123456`

---

### Step 6 — Run the Admin Panel

```bash
cd apps/admin_panel
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

Login with: `admin@doctorbooking.com` / `Admin@123456`

---

## 🔧 Environment Variables

Full reference — `apps/api/.env.example`:

```env
# ── Application ─────────────────────────────────────────
NODE_ENV=development
PORT=3000
API_VERSION=v1

# ── Database ─────────────────────────────────────────────
DATABASE_URL=postgresql://postgres:password@localhost:5432/doctor_booking

# ── JWT (generate with: openssl rand -base64 48) ─────────
JWT_ACCESS_SECRET=minimum-32-characters-change-in-production
JWT_REFRESH_SECRET=minimum-32-characters-change-in-production
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# ── Firebase (optional — needed for push notifications) ──
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@project.iam.gserviceaccount.com

# ── Cloudinary (optional — needed for image uploads) ─────
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret

# ── Email / SMTP (optional) ───────────────────────────────
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# ── Rate Limiting ─────────────────────────────────────────
RATE_LIMIT_WINDOW_MS=900000     # 15 minutes
RATE_LIMIT_MAX_REQUESTS=100

# ── Slot Locking ─────────────────────────────────────────
SLOT_LOCK_TTL=120               # seconds (2 minutes)
```

---

## 📚 API Documentation

Interactive Swagger UI (development only):  
**http://localhost:3000/api/v1/docs**

### Endpoint Summary

| Module | Endpoints |
|--------|-----------|
| **Auth** | `POST /auth/patient/send-otp`, `POST /auth/patient/verify-otp`, `POST /auth/doctor/login`, `POST /auth/admin/login`, `POST /auth/refresh`, `POST /auth/logout` |
| **Users** | `GET/PATCH /users/me`, `PATCH /users/me/location`, `GET/POST /users/me/favorites/:doctorId`, `GET/PATCH /users/me/notifications` |
| **Doctors** | `GET /doctors` (search+filter), `GET /doctors/:id`, `GET /doctors/categories`, `GET/PATCH /doctors/me/profile` |
| **Appointments** | `GET /appointments/slots/:doctorId/:clinicId`, `POST /appointments/slots/lock`, `POST /appointments`, `GET /appointments/my`, `POST /appointments/:id/cancel`, `POST /appointments/:id/reschedule`, `PATCH /appointments/:id/status` |
| **Reviews** | `POST /reviews`, `GET /reviews/doctor/:doctorId` |
| **Admin** | `GET /admin/dashboard`, full CRUD on doctors/users/clinics/categories, audit logs, review moderation |

### Standard Response Format

```json
{
  "success": true,
  "message": "Operation description",
  "data": { ... },
  "meta": {
    "total": 100,
    "page": 1,
    "limit": 20,
    "totalPages": 5,
    "hasNext": true,
    "hasPrev": false
  }
}
```

### Error Response Format

```json
{
  "success": false,
  "error": {
    "code": "SLOT_NOT_AVAILABLE",
    "message": "Slot is no longer available",
    "details": {}
  }
}
```

---

## 🗄️ Database Schema

18 PostgreSQL models managed by Prisma ORM:

```
Users ──────────────────────────────────── Appointments
  │                                              │
  ├── Favorites ────────────────── Doctors ──────┤
  ├── Notifications                    │         │
  └── RefreshTokens                    ├── DoctorCategories ── Categories
                                       ├── DoctorClinics ────── Clinics
Admins                                 ├── DoctorAvailabilities
  ├── AuditLogs                        ├── BlockedDates
  └── RefreshTokens                    ├── DoctorVacations
                                       └── DoctorNotifications
TimeSlots ◄─── Appointments ───► Reviews
OtpCodes                       AppointmentStatusHistory
AppSettings
```

### Key Design Decisions

| Decision | Reason |
|----------|--------|
| **UUID primary keys** | Prevent enumeration attacks |
| **Soft deletes** on users/doctors | Data retention, audit trail |
| **Slot locking table** | Prevents race conditions without Redis |
| **AppointmentStatusHistory** | Full audit trail of every status change |
| **Composite unique on TimeSlot** | `(doctorId, clinicId, date, startTime)` — DB-level duplicate prevention |
| **Indexed lat/lng on users** | Future geospatial queries |

---

## 🏗️ Architecture

### Booking Engine Flow

```
Patient selects slot
       │
       ▼
POST /slots/lock
  → DB: TimeSlot.status = LOCKED, lockExpiresAt = now+120s
  → UI: 2-minute countdown timer starts
       │
       ▼ (within 2 minutes)
POST /appointments
  → DB Transaction:
      1. SELECT slot WHERE id = ? FOR UPDATE
      2. Verify status = LOCKED AND lockedBy = userId
      3. UPDATE slot SET status = BOOKED
      4. INSERT appointment (CONFIRMED)
      5. INSERT appointmentStatusHistory
  → Emit socket event → all other patients see slot gone
  → Schedule FCM reminders
       │
       ▼
Booking Confirmed ✅
```

### Notification Schedule

```
┌────────────────────────────────────────────────────┐
│                  Cron Jobs                          │
│                                                     │
│  Every 1 min  → Release expired slot locks         │
│  Every hour   → Send 24h appointment reminders     │
│  Every 15min  → Send 1h appointment reminders      │
│  Daily 00:00  → Clean expired OTP codes            │
│  Daily 02:00  → Clean revoked refresh tokens       │
└────────────────────────────────────────────────────┘
```

### Security Layers

```
Request → CORS → Helmet → Rate Limit → JWT Auth → Role Check → Zod Validation → Controller → Prisma (parameterized SQL)
```

---

## 🚢 Deployment

### Production with Docker

```bash
# On your server
git clone https://github.com/SanjibSah007/doctor-booking-system.git
cd doctor-booking-system/docker

# Set environment
export POSTGRES_PASSWORD=your-secure-password
# Edit apps/api/.env with production values

# Deploy
docker compose up -d --build

# Migrate database
docker exec doctor-booking-api npx prisma migrate deploy

# Seed (first deploy only)
docker exec doctor-booking-api node dist/prisma/seed.js
```

### Production Flutter Builds

```bash
# Patient App APK
cd apps/patient_app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1

# Doctor App APK
cd apps/doctor_app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1

# Admin Panel Web
cd apps/admin_panel
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
# Upload build/web/ to your hosting
```

### CI/CD (GitHub Actions)

The pipeline at `.github/workflows/ci.yml` automatically:

1. ✅ Runs TypeScript type checking
2. ✅ Runs ESLint on backend code
3. ✅ Runs API tests against real PostgreSQL
4. ✅ Runs `flutter analyze` on all apps
5. ✅ Builds and pushes Docker image to Docker Hub (on `main` push)

---

## 🧪 Testing

```bash
# Backend unit + integration tests
cd apps/api
npm test

# With coverage report
npm run test:coverage

# Watch mode
npm run test:watch

# Flutter widget tests
cd apps/patient_app
flutter test

# Flutter test with coverage
flutter test --coverage
```

Test coverage targets: **60%** branches, functions, lines, statements.

---

## 🗺️ Roadmap

### Phase 1 — Core (✅ Complete)
- [x] Project setup, monorepo structure
- [x] Authentication (OTP, JWT, refresh tokens)
- [x] Doctor discovery with geo-search
- [x] Booking engine with race-condition prevention
- [x] Patient, Doctor, and Admin apps
- [x] Push notifications (FCM)
- [x] Docker + CI/CD

### Phase 2 — Enhanced UX (In Progress)
- [ ] Google Sign-In for patients
- [ ] Google Maps integration (map view of nearby doctors)
- [ ] Clinic image gallery
- [ ] Doctor availability calendar (patient-facing)
- [ ] Patient medical history / notes
- [ ] Multi-language support (i18n)
- [ ] Accessibility improvements

### Phase 3 — Monetization & Growth
- [ ] **Payment gateway** (Razorpay / Stripe)
- [ ] Subscription plans for doctors
- [ ] Appointment invoice PDF generation
- [ ] Referral system

### Phase 4 — Telemedicine
- [ ] **Video consultations** (Agora / Jitsi)
- [ ] **Digital prescriptions** (PDF, signed)
- [ ] Chat between patient and doctor
- [ ] Prescription renewal requests

### Phase 5 — Enterprise
- [ ] **Hospital management** — multi-doctor, multi-department
- [ ] **Lab test booking**
- [ ] **Medicine delivery** integration
- [ ] **Health records** / FHIR integration
- [ ] **AI-powered doctor recommendations**
- [ ] **Insurance integration**
- [ ] Family member profiles

---

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

```bash
# Fork & clone
git clone https://github.com/your-username/doctor-booking-system.git

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes, add tests
# ...

# Commit (conventional commits)
git commit -m "feat: add telemedicine video call feature"

# Push and open PR
git push origin feature/your-feature-name
```

### Commit Convention

| Prefix | When to use |
|--------|-------------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation |
| `style:` | Formatting |
| `refactor:` | Code restructure |
| `test:` | Tests |
| `chore:` | Build/tooling |

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 👤 Author

**Sanjib Sah**  
📧 sanjib@bankiholding.com  
🏢 Amby Technologies

---

<div align="center">

Built with ❤️ using Flutter & Node.js

⭐ **Star this repo if you found it useful!** ⭐

</div>
