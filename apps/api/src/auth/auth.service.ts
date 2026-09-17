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
    const existing = await prisma.user.findFirst({
      where: { OR: [{ phone }, { email }] },
    });
    if (existing?.phone === phone) throw AppError.conflict('Phone number is already registered');
    if (existing?.email === email) throw AppError.conflict('Email is already registered');

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
    await prisma.refreshToken.create({
      data: { token: tokens.refreshToken, userId: user.id, expiresAt },
    });

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

    // Development mode: OTP is always 123456 for easy testing
    // In production: replace with real SMS provider (MSG91, Twilio, etc.)
    const code = '123456';
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

    const { ...safeUser } = user;
    return { ...tokens, user: safeUser, isNewUser };
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
}
