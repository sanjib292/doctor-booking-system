# Setup Guide

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Node.js | 20+ | [nodejs.org](https://nodejs.org) |
| Flutter | 3.22+ (stable) | [flutter.dev](https://flutter.dev) |
| PostgreSQL | 16+ | [postgresql.org](https://postgresql.org) |
| Docker | 24+ | [docker.com](https://docker.com) |

## Quick Setup (Development)

### 1. Start PostgreSQL (Docker)

```bash
cd docker
docker-compose -f docker-compose.dev.yml up -d
```

PgAdmin: http://localhost:5050 (admin@doctorbooking.com / admin)

### 2. Backend API Setup

```bash
cd apps/api

# Copy environment file
cp .env.example .env

# Edit .env — at minimum set:
# DATABASE_URL=postgresql://postgres:postgres@localhost:5432/doctor_booking
# JWT_ACCESS_SECRET=your-32-char-minimum-secret-here
# JWT_REFRESH_SECRET=your-32-char-minimum-secret-here

# Install dependencies
npm install

# Generate Prisma client
npx prisma generate

# Run migrations
npx prisma migrate dev --name init

# Seed database (creates admin + sample doctor)
npm run prisma:seed

# Start development server (auto-reloads)
npm run dev
```

API: http://localhost:3000  
Swagger: http://localhost:3000/api/v1/docs

### 3. Patient App Setup

```bash
cd apps/patient_app

# Get Flutter dependencies
flutter pub get

# Generate code (Freezed, JSON)
flutter pub run build_runner build --delete-conflicting-outputs

# Run on Android emulator
flutter run

# Or run with custom API URL
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

**Note**: `10.0.2.2` is Android emulator's alias for `localhost`.

### 4. Doctor App Setup

```bash
cd apps/doctor_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

Doctor credentials (from seed): `dr.sharma@doctorbooking.com / Doctor@123456`

### 5. Admin Panel Setup

```bash
cd apps/admin_panel
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

Admin credentials (from seed): `admin@doctorbooking.com / Admin@123456`

## Environment Variables Reference

See [apps/api/.env.example](../apps/api/.env.example) for all variables.

### Required for basic functionality:
- `DATABASE_URL` — PostgreSQL connection string
- `JWT_ACCESS_SECRET` — Min 32 characters
- `JWT_REFRESH_SECRET` — Min 32 characters

### Required for push notifications:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_PRIVATE_KEY`
- `FIREBASE_CLIENT_EMAIL`

### Required for image uploads:
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

## Running Tests

```bash
# Backend unit/integration tests
cd apps/api
npm test

# Flutter widget tests
cd apps/patient_app
flutter test

# With coverage
flutter test --coverage
```

## Common Issues

### OTP in development
In development, OTPs are logged to the console (not sent via SMS). Check the API terminal output.

### Android emulator can't reach API
Use `10.0.2.2` instead of `localhost`:
```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

### Prisma schema changes
After editing `prisma/schema.prisma`:
```bash
npx prisma migrate dev --name describe_your_change
npx prisma generate
```

### Flutter code generation
After editing Freezed/JSON models:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
