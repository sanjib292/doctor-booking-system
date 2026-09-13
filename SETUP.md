# DoctorBooking — Setup & Testing Guide

**Amby Technologies** · Phase 1 + 2 complete

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Backend — Deploy to Railway](#backend--deploy-to-railway)
3. [Backend — Run Locally](#backend--run-locally)
4. [Flutter Patient App — Run on Android Device](#flutter-patient-app--run-on-android-device)
5. [Test Credentials](#test-credentials)
6. [Testing on Real Android Device](#testing-on-real-android-device)
7. [API Reference](#api-reference)
8. [Phase 2 Features](#phase-2-features)
9. [Troubleshooting](#troubleshooting)

---

## Project Overview

| Layer | Tech | Notes |
|---|---|---|
| Backend API | Node.js + TypeScript + Express | `apps/api` |
| Database | PostgreSQL 16 | Auto-migrated on startup |
| ORM | Prisma schema + pg shim | No binary download needed |
| Patient App | Flutter 3.22+ | `apps/patient_app` |
| Doctor App | Flutter 3.22+ | `apps/doctor_app` |
| Admin Panel | Flutter Web | `apps/admin_panel` |
| Maps | OpenStreetMap via flutter_map | **No API key required** |
| Auth | Phone OTP (hardcoded 123456) + JWT | SMS disabled for dev |

---

## Backend — Deploy to Railway

### Step 1 — Connect GitHub

1. Go to [railway.app](https://railway.app) and sign in with GitHub
2. Click **New Project → Deploy from GitHub repo**
3. Select `sanjib292/doctor-booking-system`
4. Railway will detect `railway.toml` at the repo root and use the `apps/api/Dockerfile`

### Step 2 — Add PostgreSQL

1. In your Railway project, click **+ New** → **Database** → **PostgreSQL**
2. Railway automatically sets `DATABASE_URL` as an environment variable — the API reads it directly

### Step 3 — Set Environment Variables

In the Railway project → **Variables** tab, add:

```
NODE_ENV=production
PORT=3000
JWT_ACCESS_SECRET=<generate: node -e "console.log(require('crypto').randomBytes(64).toString('hex'))">
JWT_REFRESH_SECRET=<generate a different one>
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
CORS_ORIGINS=*
LOG_LEVEL=info
```

Optional (leave blank to disable):
```
GOOGLE_CLIENT_ID=      # for Google Sign-In (Phase 2)
FIREBASE_PROJECT_ID=   # for push notifications
CLOUDINARY_CLOUD_NAME= # for photo uploads
```

### Step 4 — Deploy

Click **Deploy**. Railway builds the Docker image, runs the migrate script (creates all tables + seeds admin + categories), then starts the API.

**Health check:** `https://your-app.up.railway.app/api/v1/health`

### Step 5 — Note your Railway URL

Your API will be at something like `https://doctor-booking-production.up.railway.app`.
You'll need this URL in the Flutter app config.

---

## Backend — Run Locally

### Prerequisites

- Node.js 20+
- PostgreSQL 16+
- Yarn (`npm install -g yarn`)

### Setup

```bash
# 1. Clone and enter api directory
git clone https://github.com/sanjib292/doctor-booking-system
cd doctor-booking-system/apps/api

# 2. Create database
createuser -s doctorapp
psql -c "ALTER USER doctorapp WITH PASSWORD 'postgres123';"
createdb -O doctorapp doctor_booking

# 3. Install dependencies (use yarn — npm has a version conflict with swagger-parser)
yarn install --ignore-scripts

# 4. Create .env
cp .env.example .env
# Edit .env and set:
#   DATABASE_URL=postgresql://doctorapp:postgres123@localhost:5432/doctor_booking
#   JWT_ACCESS_SECRET=any-long-random-string
#   JWT_REFRESH_SECRET=different-long-random-string

# 5. Apply schema + seed
npx tsx src/scripts/migrate.ts

# 6. Start the API
npx tsx src/index.ts
```

The API is now running at **http://localhost:3000**

---

## Flutter Patient App — Run on Android Device

### Prerequisites

- Flutter 3.22+ (`flutter --version` to check)
- Android Studio or Android SDK
- A physical Android device or emulator with USB debugging enabled

### Step 1 — Install Flutter

```bash
# macOS (Homebrew)
brew install --cask flutter

# Verify
flutter doctor
# Fix any issues it reports before continuing
```

### Step 2 — Clone and install

```bash
cd doctor-booking-system/apps/patient_app
flutter pub get
```

### Step 3 — Configure the API URL

Edit `lib/core/constants/api_constants.dart`:

```dart
// For Android Emulator (talking to local Mac API):
const String baseUrl = 'http://10.0.2.2:3000/api/v1';

// For real Android device (talking to Railway):
const String baseUrl = 'https://your-app.up.railway.app/api/v1';

// For real device + local API (use ngrok):
// ngrok http 3000   →   copy the https URL
const String baseUrl = 'https://xxxx.ngrok-free.app/api/v1';
```

### Step 4 — No maps API key needed

The app uses **OpenStreetMap** via the `flutter_map` package — completely free, no API key, no Google Cloud setup required.

### Step 5 — Connect device and run

```bash
# List available devices
flutter devices

# Run on a specific device
flutter run -d <device-id>

# Or just:
flutter run     # picks the only connected device
```

### Step 6 — Enable USB debugging on Android

1. Go to **Settings → About phone**
2. Tap **Build number** 7 times to enable Developer options
3. Go to **Settings → Developer options**
4. Enable **USB debugging**
5. Connect phone via USB → accept the "Allow USB debugging" popup on the phone

---

## Test Credentials

### Admin Panel
| Field | Value |
|---|---|
| Email | `admin@doctorbooking.com` |
| Password | `Admin@123456` |
| Role | SUPER_ADMIN |

### Doctor Login
| | Doctor 1 | Doctor 2 |
|---|---|---|
| Email | `dr.sharma@doctorbooking.com` | `dr.priya@doctorbooking.com` |
| Password | `Doctor@123456` | `Doctor@123456` |
| Specialty | Cardiology | Dermatology |
| Hours | Mon–Fri 9am–5pm | Mon–Sat 10am–6pm |
| Fee | ₹800 | ₹600 |
| Rating | 4.8 ★ | 4.6 ★ |

### Patient OTP Login

**OTP is hardcoded to `123456` for all phone numbers during development.**

No SMS provider is needed. The full flow works as normal:

1. Enter any valid phone number (e.g. `+919999999999`)
2. Tap **Send OTP**
3. Enter `123456` as the OTP
4. You're logged in (or registered as a new patient on first login)

---

## Testing on Real Android Device

### Full test flow

```
1. Open patient app on your Android device
2. Tap "Login with Phone"
3. Enter: +919999999999
4. Tap "Send OTP"  →  OTP screen appears
5. Enter: 123456
6. Tap "Verify"  →  Home screen loads
7. Browse doctors  →  Dr. Sharma and Dr. Priya appear
8. Tap a doctor  →  Profile with availability calendar + clinic gallery
9. Tap "View on Map"  →  OpenStreetMap with doctor markers (no API key needed)
10. Tap "Book Appointment"  →  Select date + slot
11. Go to Profile  →  Medical History  →  Add a record
```

### API quick-tests (curl)

```bash
BASE=https://your-app.up.railway.app/api/v1   # or http://localhost:3000/api/v1

# Health
curl $BASE/../health

# Send OTP
curl -X POST $BASE/auth/patient/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone":"+919999999999"}'

# Verify OTP (always 123456)
curl -X POST $BASE/auth/patient/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"phone":"+919999999999","code":"123456","name":"Test Patient"}'
# → returns { accessToken, refreshToken, user }

# Save the accessToken, then:
TOKEN=<paste accessToken here>

# List doctors
curl "$BASE/doctors" -H "Authorization: Bearer $TOKEN"

# Doctor availability calendar
curl "$BASE/doctors/<doctorId>/availability" -H "Authorization: Bearer $TOKEN"

# Medical history
curl "$BASE/users/me/medical-history" -H "Authorization: Bearer $TOKEN"

# Add medical record
curl -X POST "$BASE/users/me/medical-history" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Hypertension","type":"CONDITION","details":"Stage 1, on medication"}'
```

---

## API Reference

### Base URL
```
Production:  https://your-app.up.railway.app/api/v1
Local dev:   http://localhost:3000/api/v1
```

### Auth
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/patient/send-otp` | — | Send OTP (returns 123456 in dev) |
| POST | `/auth/patient/verify-otp` | — | Verify OTP, get JWT tokens |
| POST | `/auth/patient/google` | — | Google Sign-In with ID token |
| POST | `/auth/patient/refresh` | — | Refresh access token |
| POST | `/auth/patient/logout` | Bearer | Revoke refresh token |
| POST | `/auth/doctor/login` | — | Doctor email+password login |
| POST | `/auth/admin/login` | — | Admin email+password login |

### Doctors
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/doctors` | Bearer | List + filter (category, city, rating) |
| GET | `/doctors/:id` | Bearer | Doctor profile |
| GET | `/doctors/:id/slots` | Bearer | Available time slots for a date |
| GET | `/doctors/:id/availability` | Bearer | Weekly availability schedule (Phase 2) |
| GET | `/doctors/:id/reviews` | Bearer | Patient reviews |

### Appointments
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/appointments` | Bearer | Book appointment |
| GET | `/appointments` | Bearer | My appointments |
| GET | `/appointments/:id` | Bearer | Appointment detail |
| PUT | `/appointments/:id/cancel` | Bearer | Cancel appointment |
| POST | `/appointments/:id/review` | Bearer | Leave a review |

### Patient — Medical History (Phase 2)
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/users/me/medical-history` | Bearer | List records |
| POST | `/users/me/medical-history` | Bearer | Add record |
| PUT | `/users/me/medical-history/:id` | Bearer | Update record |
| DELETE | `/users/me/medical-history/:id` | Bearer | Delete record |

**Record types:** `CONDITION`, `ALLERGY`, `MEDICATION`, `SURGERY`, `VACCINATION`, `NOTE`

### Categories
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/categories` | — | All active categories (10 seeded) |
| GET | `/categories/:slug` | — | Category by slug |

---

## Phase 2 Features

| Feature | Status | Notes |
|---|---|---|
| Google Sign-In | ✅ Done | Needs `GOOGLE_CLIENT_ID` env var in production |
| OpenStreetMap doctor map | ✅ Done | No API key, free forever |
| Clinic image gallery | ✅ Done | Horizontal PageView in doctor profile |
| Availability calendar | ✅ Done | Weekday grid on patient profile view |
| Medical history CRUD | ✅ Done | 6 record types, full CRUD |
| Multi-language (EN + HI) | ✅ Done | 40+ i18n keys, toggle in app settings |
| Accessibility | ✅ Done | Semantics widgets, focus order, screen reader support |

---

## Troubleshooting

### "connection refused" from Android device to local API
The Android emulator uses `10.0.2.2` to reach `localhost` on your Mac. A real device needs to be on the same WiFi and use your Mac's local IP (e.g. `192.168.x.x:3000`), or use ngrok.

### OTP not working
The OTP is always `123456` — make sure you're calling `/auth/patient/send-otp` first (it creates the DB record), then `/auth/patient/verify-otp` with `123456`.

### Flutter pub get fails
Make sure you're on Flutter 3.22+. Run `flutter upgrade` if needed.

### Railway deploy fails: DATABASE_URL not set
Make sure you added the PostgreSQL plugin in Railway — it auto-sets `DATABASE_URL`. Don't set it manually unless using an external DB.

### Can't reach Railway URL from Flutter app
Check that `CORS_ORIGINS` is set to `*` (or your specific domain) in Railway environment variables.

---

*DoctorBooking · Amby Technologies · September 2026*
