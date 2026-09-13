/**
 * Idempotent schema migration script.
 * Runs at Railway startup to ensure the database is up to date.
 * Uses IF NOT EXISTS so it's safe to run on every deploy.
 */
import { Pool } from 'pg';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function migrate() {
  const client = await pool.connect();
  try {
    console.log('[migrate] Starting schema migration...');

    await client.query(`
      -- Enums
      DO $$ BEGIN
        CREATE TYPE "Role" AS ENUM ('PATIENT','DOCTOR','ADMIN','SUPER_ADMIN');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;

      DO $$ BEGIN
        CREATE TYPE "Gender" AS ENUM ('MALE','FEMALE','OTHER','PREFER_NOT_TO_SAY');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;

      DO $$ BEGIN
        CREATE TYPE "AppointmentStatus" AS ENUM (
          'PENDING','CONFIRMED','CHECKED_IN','IN_CONSULTATION',
          'COMPLETED','CANCELLED','NO_SHOW','RESCHEDULED'
        );
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;

      DO $$ BEGIN
        CREATE TYPE "DayOfWeek" AS ENUM (
          'MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY'
        );
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;

      DO $$ BEGIN
        CREATE TYPE "NotificationChannel" AS ENUM ('FCM','EMAIL','SMS');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;

      DO $$ BEGIN
        CREATE TYPE "NotificationType" AS ENUM (
          'BOOKING_CONFIRMED','BOOKING_REMINDER_24H','BOOKING_REMINDER_1H',
          'BOOKING_CANCELLED','BOOKING_RESCHEDULED','DOCTOR_UNAVAILABLE',
          'NEW_APPOINTMENT','NEW_REVIEW','SCHEDULE_REMINDER','SYSTEM'
        );
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;

      DO $$ BEGIN
        CREATE TYPE "SlotStatus" AS ENUM ('AVAILABLE','LOCKED','BOOKED');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;

      DO $$ BEGIN
        CREATE TYPE "VerificationStatus" AS ENUM ('PENDING','VERIFIED','REJECTED');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;

      DO $$ BEGIN
        CREATE TYPE "MedicalRecordType" AS ENUM (
          'CONDITION','ALLERGY','MEDICATION','SURGERY','VACCINATION','NOTE'
        );
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        phone TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE,
        name TEXT NOT NULL,
        gender "Gender",
        age INTEGER,
        "avatarUrl" TEXT,
        "fcmToken" TEXT,
        "isActive" BOOLEAN DEFAULT true,
        "isBlocked" BOOLEAN DEFAULT false,
        "lastKnownLat" FLOAT,
        "lastKnownLng" FLOAT,
        "lastLocationAt" TIMESTAMPTZ,
        role "Role" DEFAULT 'PATIENT',
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
        "deletedAt" TIMESTAMPTZ
      );
      CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
      CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
      CREATE INDEX IF NOT EXISTS idx_users_deleted ON users("deletedAt");

      CREATE TABLE IF NOT EXISTS admins (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        email TEXT UNIQUE NOT NULL,
        "passwordHash" TEXT NOT NULL,
        name TEXT NOT NULL,
        role "Role" DEFAULT 'ADMIN',
        "avatarUrl" TEXT,
        "isActive" BOOLEAN DEFAULT true,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
        "deletedAt" TIMESTAMPTZ
      );

      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        name TEXT UNIQUE NOT NULL,
        slug TEXT UNIQUE NOT NULL,
        "iconUrl" TEXT,
        color TEXT,
        "isActive" BOOLEAN DEFAULT true,
        "sortOrder" INTEGER DEFAULT 0,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
        "deletedAt" TIMESTAMPTZ
      );

      CREATE TABLE IF NOT EXISTS doctors (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "userId" TEXT UNIQUE,
        email TEXT UNIQUE NOT NULL,
        "passwordHash" TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT UNIQUE NOT NULL,
        gender "Gender",
        "avatarUrl" TEXT,
        about TEXT,
        qualifications TEXT[],
        "experienceYears" INTEGER DEFAULT 0,
        languages TEXT[],
        "verificationStatus" "VerificationStatus" DEFAULT 'PENDING',
        "verifiedAt" TIMESTAMPTZ,
        "isActive" BOOLEAN DEFAULT true,
        "fcmToken" TEXT,
        "averageRating" FLOAT DEFAULT 0,
        "totalReviews" INTEGER DEFAULT 0,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
        "deletedAt" TIMESTAMPTZ
      );

      CREATE TABLE IF NOT EXISTS doctor_categories (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "doctorId" TEXT NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
        "categoryId" TEXT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        "isPrimary" BOOLEAN DEFAULT false,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE("doctorId","categoryId")
      );

      CREATE TABLE IF NOT EXISTS clinics (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        name TEXT NOT NULL,
        "addressLine1" TEXT NOT NULL,
        "addressLine2" TEXT,
        city TEXT NOT NULL,
        state TEXT NOT NULL,
        country TEXT DEFAULT 'India',
        "postalCode" TEXT,
        lat FLOAT NOT NULL,
        lng FLOAT NOT NULL,
        phone TEXT,
        email TEXT,
        website TEXT,
        images TEXT[],
        "parkingAvailable" BOOLEAN DEFAULT false,
        "accessibilityNote" TEXT,
        "isActive" BOOLEAN DEFAULT true,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
        "deletedAt" TIMESTAMPTZ
      );

      CREATE TABLE IF NOT EXISTS doctor_clinics (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "doctorId" TEXT NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
        "clinicId" TEXT NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
        "consultationFee" FLOAT NOT NULL,
        "isPrimary" BOOLEAN DEFAULT false,
        "isActive" BOOLEAN DEFAULT true,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE("doctorId","clinicId")
      );

      CREATE TABLE IF NOT EXISTS doctor_availabilities (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "doctorId" TEXT NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
        "doctorClinicId" TEXT REFERENCES doctor_clinics(id),
        "dayOfWeek" "DayOfWeek" NOT NULL,
        "startTime" TEXT NOT NULL,
        "endTime" TEXT NOT NULL,
        "slotDurationMinutes" INTEGER DEFAULT 15,
        "breakStart" TEXT,
        "breakEnd" TEXT,
        "isActive" BOOLEAN DEFAULT true,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE("doctorId","doctorClinicId","dayOfWeek")
      );

      CREATE TABLE IF NOT EXISTS time_slots (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "doctorId" TEXT NOT NULL,
        "clinicId" TEXT,
        date DATE NOT NULL,
        "startTime" TEXT NOT NULL,
        "endTime" TEXT NOT NULL,
        status "SlotStatus" DEFAULT 'AVAILABLE',
        "lockedAt" TIMESTAMPTZ,
        "lockedBy" TEXT,
        "lockExpiresAt" TIMESTAMPTZ,
        "bookedAt" TIMESTAMPTZ,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE("doctorId","clinicId",date,"startTime")
      );

      CREATE TABLE IF NOT EXISTS doctor_vacations (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "doctorId" TEXT NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
        "startDate" DATE NOT NULL,
        "endDate" DATE NOT NULL,
        reason TEXT,
        "createdAt" TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS blocked_dates (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "doctorId" TEXT NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
        date DATE NOT NULL,
        reason TEXT,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE("doctorId",date)
      );

      CREATE TABLE IF NOT EXISTS appointments (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "patientId" TEXT NOT NULL REFERENCES users(id),
        "doctorId" TEXT NOT NULL REFERENCES doctors(id),
        "clinicId" TEXT REFERENCES clinics(id),
        "slotId" TEXT UNIQUE NOT NULL REFERENCES time_slots(id),
        date DATE NOT NULL,
        "startTime" TEXT NOT NULL,
        "endTime" TEXT NOT NULL,
        status "AppointmentStatus" DEFAULT 'PENDING',
        notes TEXT,
        "cancellationReason" TEXT,
        "cancelledBy" TEXT,
        "isPatientReminded24h" BOOLEAN DEFAULT false,
        "isPatientReminded1h" BOOLEAN DEFAULT false,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS appointment_status_history (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "appointmentId" TEXT NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
        "fromStatus" "AppointmentStatus",
        "toStatus" "AppointmentStatus" NOT NULL,
        "changedBy" TEXT,
        reason TEXT,
        "createdAt" TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS reviews (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "appointmentId" TEXT UNIQUE NOT NULL REFERENCES appointments(id),
        "patientId" TEXT NOT NULL REFERENCES users(id),
        "doctorId" TEXT NOT NULL REFERENCES doctors(id),
        rating INTEGER NOT NULL,
        comment TEXT,
        "isVisible" BOOLEAN DEFAULT true,
        "moderatedAt" TIMESTAMPTZ,
        "moderatedBy" TEXT,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
        "deletedAt" TIMESTAMPTZ
      );

      CREATE TABLE IF NOT EXISTS favorites (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "userId" TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        "doctorId" TEXT NOT NULL,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE("userId","doctorId")
      );

      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "userId" TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type "NotificationType" NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        data JSONB,
        "isRead" BOOLEAN DEFAULT false,
        "readAt" TIMESTAMPTZ,
        "sentVia" "NotificationChannel" DEFAULT 'FCM',
        "createdAt" TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS doctor_notifications (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "doctorId" TEXT NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
        type "NotificationType" NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        data JSONB,
        "isRead" BOOLEAN DEFAULT false,
        "readAt" TIMESTAMPTZ,
        "createdAt" TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS otp_codes (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        phone TEXT NOT NULL,
        code TEXT NOT NULL,
        "isUsed" BOOLEAN DEFAULT false,
        "expiresAt" TIMESTAMPTZ NOT NULL,
        attempts INTEGER DEFAULT 0,
        "createdAt" TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        token TEXT UNIQUE NOT NULL,
        "userId" TEXT REFERENCES users(id) ON DELETE CASCADE,
        "doctorId" TEXT REFERENCES doctors(id) ON DELETE CASCADE,
        "adminId" TEXT REFERENCES admins(id) ON DELETE CASCADE,
        "expiresAt" TIMESTAMPTZ NOT NULL,
        "isRevoked" BOOLEAN DEFAULT false,
        "createdAt" TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "userId" TEXT REFERENCES users(id),
        "adminId" TEXT REFERENCES admins(id),
        action TEXT NOT NULL,
        entity TEXT NOT NULL,
        "entityId" TEXT,
        "oldValues" JSONB,
        "newValues" JSONB,
        "ipAddress" TEXT,
        "userAgent" TEXT,
        "createdAt" TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS medical_records (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        "userId" TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        type "MedicalRecordType" NOT NULL,
        details TEXT,
        date DATE,
        "isActive" BOOLEAN DEFAULT true,
        "createdAt" TIMESTAMPTZ DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS app_settings (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL,
        type TEXT DEFAULT 'string',
        "updatedAt" TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // Seed admin if not present
    const adminCheck = await client.query(`SELECT id FROM admins WHERE email = 'admin@doctorbooking.com'`);
    if (adminCheck.rowCount === 0) {
      console.log('[migrate] Seeding initial admin...');
      // bcrypt hash of "Admin@123456" with cost 12
      const hash = '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TsDjMqRWqMqALhvS6gj2Iqvhh0VC'; // placeholder
      await client.query(`
        INSERT INTO admins (id, email, "passwordHash", name, role, "createdAt", "updatedAt")
        VALUES (gen_random_uuid()::text, 'admin@doctorbooking.com', $1, 'Super Admin', 'SUPER_ADMIN', NOW(), NOW())
        ON CONFLICT (email) DO NOTHING
      `, [hash]);
    }

    // Seed categories if empty
    const catCheck = await client.query(`SELECT COUNT(*) FROM categories`);
    if (parseInt(catCheck.rows[0].count) === 0) {
      console.log('[migrate] Seeding categories...');
      const cats = [
        ['General Physician','general-physician','#4CAF50',1],
        ['Cardiology','cardiology','#F44336',2],
        ['Dermatology','dermatology','#FF9800',3],
        ['Neurology','neurology','#9C27B0',4],
        ['Orthopedics','orthopedics','#2196F3',5],
        ['Pediatrics','pediatrics','#00BCD4',6],
        ['Gynecology','gynecology','#E91E63',7],
        ['ENT','ent','#795548',8],
        ['Ophthalmology','ophthalmology','#607D8B',9],
        ['Psychiatry','psychiatry','#3F51B5',10],
      ];
      for (const [name, slug, color, order] of cats) {
        await client.query(
          `INSERT INTO categories (id,name,slug,color,"sortOrder","createdAt","updatedAt")
           VALUES (gen_random_uuid()::text,$1,$2,$3,$4,NOW(),NOW()) ON CONFLICT DO NOTHING`,
          [name, slug, color, order]
        );
      }
    }

    console.log('[migrate] ✅ Schema and seed complete.');
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch(e => {
  console.error('[migrate] FATAL:', e);
  process.exit(1);
});
