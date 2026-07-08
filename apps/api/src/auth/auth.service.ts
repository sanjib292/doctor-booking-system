import { prisma } from '../config/database';
import { AppError } from '../common/errors/AppError';
import { generateOtp, hashPassword, comparePassword } from '../common/utils/hash';
import { generateTokenPair, verifyRefreshToken } from '../common/utils/jwt';
import { Role } from '@prisma/client';
import { env } from '../config/env';
import { logger } from '../common/utils/logger';

const OTP_EXPIRY_MINUTES = 10;
const MAX_OTP_ATTEMPTS = 5;

export class AuthService {
  async sendOtp(phone: string): Promise<{ expiresIn: number }> {
    // Invalidate existing OTPs
    await prisma.otpCode.updateMany({
      where: { phone, isUsed: false },
      data: { isUsed: true },
    });

    const code = generateOtp(6);
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

    await prisma.otpCode.create({
      data: { phone, code, expiresAt },
    });

    // In production: send via SMS provider
    logger.info(`OTP for ${phone}: ${code}`);

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
      if (!name) throw AppError.badRequest('Name required for new users', 'NAME_REQUIRED');
      isNewUser = true;
      user = await prisma.user.create({
        data: { phone, name, gender: (gender as any) ?? null, age, fcmToken, role: Role.PATIENT },
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

    const tokens = generateTokenPair(payload);
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
}
