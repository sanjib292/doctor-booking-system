import { prisma } from '../config/database';
import { AppError } from '../common/errors/AppError';
import { generateOtp, hashPassword, comparePassword } from '../common/utils/hash';
import { generateTokenPair, verifyRefreshToken } from '../common/utils/jwt';
import { Role } from '@prisma/client';
import { env } from '../config/env';
import { logger } from '../common/utils/logger';
import { OAuth2Client } from 'google-auth-library';

const OTP_EXPIRY_MINUTES = 10;
const MAX_OTP_ATTEMPTS = 5;

export class AuthService {
  async registerPatient(
    name: string,
    email: string,
    phone: string,
    password: string,
    gender?: string,
    age?: number,
    fcmToken?: string,
  ): Promise<{ accessToken: string; refreshToken: string; user: object }> {
    const [byPhone, byEmail] = await Promise.all([
      prisma.user.findUnique({ where: { phone } }),
      prisma.user.findUnique({ where: { email } }),
    ]);
    if (byPhone) throw AppError.conflict('Phone number is already registered');
    if (byEmail) throw AppError.conflict('Email is already registered');

    const passwordHash = await hashPassword(password);

    const user = await prisma.user.create({
      data: {
        phone,
        email,
        name,
        passwordHash,
        role: Role.PATIENT,
        ...(gender ? { gender: gender as any } : {}),
        ...(age !== undefined && age !== null ? { age } : {}),
        ...(fcmToken ? { fcmToken } : {}),
      },
    });

    const tokens = generateTokenPair({ id: user.id, role: user.role, phone: user.phone });
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await prisma.refreshToken.create({ data: { token: tokens.refreshToken, userId: user.id, expiresAt } });
    const { passwordHash: _ph, ...safeUser } = user as any;
    return { ...tokens, user: safeUser };
  }

  async sendOtp(phone: string): Promise<{ expiresIn: number }> {
    // Only allow OTP for existing registered patients
    const existingUser = await prisma.user.findUnique({ where: { phone } });
    if (!existingUser) throw AppError.notFound('Phone number not registered. Please contact support.');
    if (existingUser.isBlocked) throw AppError.forbidden('Account is blocked');

    // Invalidate existing OTPs
    await prisma.otpCode.updateMany({
      where: { phone, isUsed: false },
      data: { isUsed: true },
    });

    const smsConfigured = !!(process.env.TWILIO_ACCOUNT_SID || process.env.SMS_API_KEY);
    const code = smsConfigured ? generateOtp() : '123456';
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

    await prisma.otpCode.create({
      data: { phone, code, expiresAt },
    });

    logger.info(`OTP for ${phone}: ${code} (hardcoded for testing)`);

    return { expiresIn: OTP_EXPIRY_MINUTES * 60 };
  }

  async verifyOtpAndLogin(
    phone: string,
    code: string,
    name?: string,
    gender?: string,
    age?: number,
    fcmToken?: string,
  ): Promise<{ accessToken: string; refreshToken: string; user: object; isNewUser: boolean }> {
    const otp = await prisma.otpCode.findFirst({
      where: { phone, isUsed: false },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) throw AppError.badRequest('OTP not found or expired', 'OTP_NOT_FOUND');
    if (otp.attempts >= MAX_OTP_ATTEMPTS) throw AppError.badRequest('Too many attempts', 'OTP_LOCKED');
    if (otp.expiresAt < new Date()) throw AppError.badRequest('OTP has expired', 'OTP_EXPIRED');

    if (otp.code !== code) {
      await prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw AppError.badRequest('Invalid OTP', 'OTP_INVALID');
    }

    await prisma.otpCode.update({ where: { id: otp.id }, data: { isUsed: true } });

    let isNewUser = false;
    let user = await prisma.user.findUnique({ where: { phone } });

    if (!user) {
      isNewUser = true;
      user = await prisma.user.create({
        data: {
          phone,
          name: name ?? 'New Patient',
          role: Role.PATIENT,
          ...(gender ? { gender: gender as any } : {}),
          ...(age !== undefined && age !== null ? { age } : {}),
          ...(fcmToken ? { fcmToken } : {}),
        },
      });
    } else if (fcmToken && user.fcmToken !== fcmToken) {
      user = await prisma.user.update({ where: { id: user.id }, data: { fcmToken } });
    }

    if (user.isBlocked) throw AppError.forbidden('Account is blocked');

    const tokens = generateTokenPair({ id: user.id, role: user.role, phone: user.phone });
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    await prisma.refreshToken.create({
      data: { token: tokens.refreshToken, userId: user.id, expiresAt },
    });

    const { passwordHash: _ph, ...safeUser } = user as any;
    return { ...tokens, user: safeUser, isNewUser };
  }

  async loginWithPassword(
    identifier: string,
    password: string,
    fcmToken?: string,
  ): Promise<{ accessToken: string; refreshToken: string; user: object }> {
    const isPhone = /^\+?[0-9]{10,15}$/.test(identifier.replace(/\s/g, ''));
    let user = null;
    if (isPhone) {
      // Try as-is first, then with +91 prefix (registration always stores with country code)
      user = await prisma.user.findUnique({ where: { phone: identifier } });
      if (!user && !identifier.startsWith('+')) {
        user = await prisma.user.findUnique({ where: { phone: `+91${identifier}` } });
      }
    } else {
      user = await prisma.user.findUnique({ where: { email: identifier } });
    }

    if (!user || user.role !== Role.PATIENT) throw AppError.unauthorized('Invalid credentials');
    if (user.isBlocked) throw AppError.forbidden('Account is blocked');
    if (!user.passwordHash) throw AppError.badRequest('This account uses OTP login. Please use OTP to sign in.');

    const valid = await comparePassword(password, user.passwordHash);
    if (!valid) throw AppError.unauthorized('Invalid credentials');

    if (fcmToken && user.fcmToken !== fcmToken) {
      await prisma.user.update({ where: { id: user.id }, data: { fcmToken } });
    }

    const tokens = generateTokenPair({ id: user.id, role: user.role, phone: user.phone });
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await prisma.refreshToken.create({
      data: { token: tokens.refreshToken, userId: user.id, expiresAt },
    });

    const { passwordHash: _ph, ...safeUser } = user as any;
    return { ...tokens, user: safeUser };
  }

  async doctorLogin(
    email: string,
    password: string,
    fcmToken?: string,
  ): Promise<{ accessToken: string; refreshToken: string; doctor: object }> {
    const doctor = await prisma.doctor.findUnique({ where: { email } });
    if (!doctor) throw AppError.unauthorized('Invalid credentials');
    if (!doctor.isActive) throw AppError.forbidden('Account is inactive');

    const valid = await comparePassword(password, doctor.passwordHash);
    if (!valid) throw AppError.unauthorized('Invalid credentials');

    if (fcmToken && doctor.fcmToken !== fcmToken) {
      await prisma.doctor.update({ where: { id: doctor.id }, data: { fcmToken } });
    }

    const tokens = generateTokenPair({ id: doctor.id, role: Role.DOCTOR, email: doctor.email });
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    await prisma.refreshToken.create({
      data: { token: tokens.refreshToken, doctorId: doctor.id, expiresAt },
    });

    const { passwordHash, ...safeDoctor } = doctor;
    return { ...tokens, doctor: safeDoctor };
  }

  async adminLogin(
    email: string,
    password: string,
  ): Promise<{ accessToken: string; refreshToken: string; admin: object }> {
    const admin = await prisma.admin.findUnique({ where: { email } });
    if (!admin) throw AppError.unauthorized('Invalid credentials');
    if (!admin.isActive) throw AppError.forbidden('Account is inactive');

    const valid = await comparePassword(password, admin.passwordHash);
    if (!valid) throw AppError.unauthorized('Invalid credentials');

    const tokens = generateTokenPair({ id: admin.id, role: admin.role, email: admin.email });
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    await prisma.refreshToken.create({
      data: { token: tokens.refreshToken, adminId: admin.id, expiresAt },
    });

    const { passwordHash, ...safeAdmin } = admin;
    return { ...tokens, admin: safeAdmin };
  }

  async refreshTokens(
    refreshToken: string,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const payload = verifyRefreshToken(refreshToken);

    const stored = await prisma.refreshToken.findUnique({ where: { token: refreshToken } });
    if (!stored || stored.isRevoked || stored.expiresAt < new Date()) {
      throw AppError.unauthorized('Refresh token is invalid or expired');
    }

    await prisma.refreshToken.update({ where: { id: stored.id }, data: { isRevoked: true } });

    // Strip JWT claims (exp, iat) so generateTokenPair can set fresh ones
    const { exp: _exp, iat: _iat, ...cleanPayload } = payload as any;
    const tokens = generateTokenPair(cleanPayload);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    await prisma.refreshToken.create({
      data: {
        token: tokens.refreshToken,
        userId: stored.userId ?? undefined,
        doctorId: stored.doctorId ?? undefined,
        adminId: stored.adminId ?? undefined,
        expiresAt,
      },
    });

    return tokens;
  }

  async logout(refreshToken: string): Promise<void> {
    await prisma.refreshToken.updateMany({
      where: { token: refreshToken },
      data: { isRevoked: true },
    });
  }

  // ─── Google Sign-In (Phase 2) ──────────────────────────────────────
  async googleSignIn(
    idToken: string,
    fcmToken?: string,
  ): Promise<{ accessToken: string; refreshToken: string; user: object; isNewUser: boolean }> {
    const clientId = env.GOOGLE_CLIENT_ID;
    if (!clientId) throw AppError.badRequest('Google Sign-In is not configured on this server');

    const client = new OAuth2Client(clientId);
    let payload: any;
    try {
      const ticket = await client.verifyIdToken({ idToken, audience: clientId });
      payload = ticket.getPayload();
    } catch {
      throw AppError.unauthorized('Invalid Google token');
    }

    if (!payload?.email) throw AppError.badRequest('Google token missing email');

    const googleId = payload.sub as string;
    const email = payload.email as string;
    const name = (payload.name as string) || email.split('@')[0];
    const avatarUrl = payload.picture as string | undefined;

    let isNewUser = false;
    let user = await prisma.user.findFirst({
      where: { OR: [{ email }, { phone: `google:${googleId}` }] },
    });

    if (!user) {
      isNewUser = true;
      user = await prisma.user.create({
        data: {
          phone: `google:${googleId}`,
          email,
          name,
          avatarUrl,
          fcmToken,
          role: Role.PATIENT,
        },
      });
    } else {
      // Update avatar / fcmToken if changed
      const updates: Record<string, any> = {};
      if (avatarUrl && user.avatarUrl !== avatarUrl) updates.avatarUrl = avatarUrl;
      if (fcmToken && user.fcmToken !== fcmToken) updates.fcmToken = fcmToken;
      if (Object.keys(updates).length) {
        user = await prisma.user.update({ where: { id: user.id }, data: updates });
      }
    }

    if (user.isBlocked) throw AppError.forbidden('Account is blocked');

    const tokens = generateTokenPair({ id: user.id, role: user.role, phone: user.phone });
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await prisma.refreshToken.create({
      data: { token: tokens.refreshToken, userId: user.id, expiresAt },
    });

    const { passwordHash: _ph, ...safeUser } = user as any;
    return { ...tokens, user: safeUser, isNewUser };
  }

  // ─── Seed / reset known accounts ──────────────────────────────────
  async initSeed(): Promise<object> {
    const [adminHash, doctorHash] = await Promise.all([
      hashPassword('Admin@123456'),
      hashPassword('Doctor@123456'),
    ]);

    // ── Admin ────────────────────────────────────────────────────────
    const admin = await prisma.admin.upsert({
      where: { email: 'admin@doctorbooking.com' },
      update: { passwordHash: adminHash, name: 'Super Admin' },
      create: { email: 'admin@doctorbooking.com', passwordHash: adminHash, name: 'Super Admin', role: 'SUPER_ADMIN' as any },
    });

    // ── Doctors ──────────────────────────────────────────────────────
    const doctor1 = await prisma.doctor.upsert({
      where: { email: 'dr.sharma@doctorbooking.com' },
      update: { passwordHash: doctorHash, isActive: true, verificationStatus: 'VERIFIED' as any },
      create: {
        email: 'dr.sharma@doctorbooking.com',
        passwordHash: doctorHash,
        name: 'Rajesh Sharma',
        phone: '+91-9876543211',
        gender: 'MALE' as any,
        about: 'Senior Cardiologist with 15+ years of experience in interventional cardiology.',
        qualifications: ['MBBS', 'MD (Cardiology)', 'DM (Cardiology)'],
        experienceYears: 15,
        languages: ['English', 'Hindi'],
        verificationStatus: 'VERIFIED' as any,
        verifiedAt: new Date(),
        isActive: true,
        averageRating: 4.8,
        totalReviews: 127,
      },
    });

    const doctor2 = await prisma.doctor.upsert({
      where: { email: 'dr.priya@doctorbooking.com' },
      update: { passwordHash: doctorHash, isActive: true, verificationStatus: 'VERIFIED' as any },
      create: {
        email: 'dr.priya@doctorbooking.com',
        passwordHash: doctorHash,
        name: 'Priya Nair',
        phone: '+91-9876543212',
        gender: 'FEMALE' as any,
        about: 'Specialist in Neurology with focus on movement disorders and epilepsy.',
        qualifications: ['MBBS', 'MD (Neurology)', 'DM (Neurology)'],
        experienceYears: 12,
        languages: ['English', 'Hindi', 'Malayalam'],
        verificationStatus: 'VERIFIED' as any,
        verifiedAt: new Date(),
        isActive: true,
        averageRating: 4.6,
        totalReviews: 89,
      },
    });

    // ── Categories ───────────────────────────────────────────────────
    let cardioCat = await prisma.category.findFirst({ where: { name: 'Cardiology' } });
    if (!cardioCat) cardioCat = await prisma.category.create({
      data: { name: 'Cardiology', slug: 'cardiology', color: '#FF5252', isActive: true, sortOrder: 1 },
    });

    let neuroCat = await prisma.category.findFirst({ where: { name: 'Neurology' } });
    if (!neuroCat) neuroCat = await prisma.category.create({
      data: { name: 'Neurology', slug: 'neurology', color: '#448AFF', isActive: true, sortOrder: 2 },
    });

    let generalCat = await prisma.category.findFirst({ where: { name: 'General Physician' } });
    if (!generalCat) generalCat = await prisma.category.create({
      data: { name: 'General Physician', slug: 'general-physician', color: '#4CAF50', isActive: true, sortOrder: 3 },
    });

    let dermCat = await prisma.category.findFirst({ where: { name: 'Dermatology' } });
    if (!dermCat) dermCat = await prisma.category.create({
      data: { name: 'Dermatology', slug: 'dermatology', color: '#FF9800', isActive: true, sortOrder: 4 },
    });

    let orthoCat = await prisma.category.findFirst({ where: { name: 'Orthopedics' } });
    if (!orthoCat) orthoCat = await prisma.category.create({
      data: { name: 'Orthopedics', slug: 'orthopedics', color: '#9C27B0', isActive: true, sortOrder: 5 },
    });

    let pediatCat = await prisma.category.findFirst({ where: { name: 'Pediatrics' } });
    if (!pediatCat) pediatCat = await prisma.category.create({
      data: { name: 'Pediatrics', slug: 'pediatrics', color: '#00BCD4', isActive: true, sortOrder: 6 },
    });

    // ── Clinics ──────────────────────────────────────────────────────
    let clinic1 = await prisma.clinic.findFirst({ where: { name: 'Apollo Heart Clinic' } });
    if (!clinic1) clinic1 = await prisma.clinic.create({
      data: {
        name: 'Apollo Heart Clinic',
        addressLine1: '123 MG Road, Andheri West',
        city: 'Mumbai',
        state: 'Maharashtra',
        phone: '+91-2226543210',
        lat: 19.1197,
        lng: 72.8467,
        images: [],
        isActive: true,
      },
    });

    let clinic2 = await prisma.clinic.findFirst({ where: { name: 'City Neuro Centre' } });
    if (!clinic2) clinic2 = await prisma.clinic.create({
      data: {
        name: 'City Neuro Centre',
        addressLine1: '456 Brigade Road, Indiranagar',
        city: 'Bangalore',
        state: 'Karnataka',
        phone: '+91-8026543210',
        lat: 12.9719,
        lng: 77.6412,
        images: [],
        isActive: true,
      },
    });

    // ── Doctor-Clinic Associations ────────────────────────────────────
    const dc1 = await prisma.doctorClinic.findFirst({ where: { doctorId: (doctor1 as any).id, clinicId: (clinic1 as any).id } });
    if (!dc1) await prisma.doctorClinic.create({
      data: { doctorId: (doctor1 as any).id, clinicId: (clinic1 as any).id, isPrimary: true, consultationFee: 800, isActive: true },
    });

    const dc2 = await prisma.doctorClinic.findFirst({ where: { doctorId: (doctor2 as any).id, clinicId: (clinic2 as any).id } });
    if (!dc2) await prisma.doctorClinic.create({
      data: { doctorId: (doctor2 as any).id, clinicId: (clinic2 as any).id, isPrimary: true, consultationFee: 700, isActive: true },
    });

    // ── Doctor-Category Associations ──────────────────────────────────
    const dcat1 = await prisma.doctorCategory.findFirst({ where: { doctorId: (doctor1 as any).id, categoryId: (cardioCat as any).id } });
    if (!dcat1) await prisma.doctorCategory.create({
      data: { doctorId: (doctor1 as any).id, categoryId: (cardioCat as any).id, isPrimary: true },
    });

    const dcat2 = await prisma.doctorCategory.findFirst({ where: { doctorId: (doctor2 as any).id, categoryId: (neuroCat as any).id } });
    if (!dcat2) await prisma.doctorCategory.create({
      data: { doctorId: (doctor2 as any).id, categoryId: (neuroCat as any).id, isPrimary: true },
    });

    // ── Doctor Availability (Mon-Sat for both doctors) ────────────────
    const weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'] as const;
    for (const day of weekdays) {
      const av1 = await prisma.doctorAvailability.findFirst({ where: { doctorId: (doctor1 as any).id, dayOfWeek: day as any } });
      if (!av1) await prisma.doctorAvailability.create({
        data: { doctorId: (doctor1 as any).id, dayOfWeek: day as any, startTime: '09:00', endTime: '17:00', slotDurationMinutes: 30, isActive: true },
      });

      const av2 = await prisma.doctorAvailability.findFirst({ where: { doctorId: (doctor2 as any).id, dayOfWeek: day as any } });
      if (!av2) await prisma.doctorAvailability.create({
        data: { doctorId: (doctor2 as any).id, dayOfWeek: day as any, startTime: '10:00', endTime: '18:00', slotDurationMinutes: 30, isActive: true },
      });
    }

    return {
      admin: (admin as any).email,
      doctors: [(doctor1 as any).email, (doctor2 as any).email],
      categories: ['Cardiology', 'Neurology', 'General Physician', 'Dermatology', 'Orthopedics', 'Pediatrics'],
      clinics: [(clinic1 as any).name, (clinic2 as any).name],
      passwords: { admin: 'Admin@123456', doctors: 'Doctor@123456' },
    };
  }
}
