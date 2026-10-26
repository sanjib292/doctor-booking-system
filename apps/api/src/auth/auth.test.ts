import { describe, it, expect, beforeAll, afterAll } from '@jest/globals';
import request from 'supertest';
import app from '../index';
import { prisma } from '../config/database';

describe('Auth API', () => {
  const email = `auth-test-${Date.now()}@example.com`;
  const password = 'TestPass123';

  beforeAll(async () => {
    await request(app)
      .post('/api/v1/auth/patient/register')
      .send({ name: 'Auth Tester', email, password });
  });

  afterAll(async () => {
    await prisma.otpCode.deleteMany({ where: { email } });
    await prisma.user.deleteMany({ where: { email } });
    await prisma.$disconnect();
  });

  describe('POST /api/v1/auth/patient/register', () => {
    it('rejects a duplicate email', async () => {
      const res = await request(app)
        .post('/api/v1/auth/patient/register')
        .send({ name: 'Auth Tester', email, password });

      expect(res.status).toBe(409);
      expect(res.body.success).toBe(false);
    });
  });

  describe('POST /api/v1/auth/patient/login', () => {
    it('logs in with the correct password', async () => {
      const res = await request(app)
        .post('/api/v1/auth/patient/login')
        .send({ identifier: email, password });

      expect(res.status).toBe(200);
      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
      expect(res.body.data.user.passwordHash).toBeUndefined();
    });

    it('rejects a wrong password', async () => {
      const res = await request(app)
        .post('/api/v1/auth/patient/login')
        .send({ identifier: email, password: 'WrongPass999' });

      expect(res.status).toBe(401);
    });

    it('rejects an unknown account', async () => {
      const res = await request(app)
        .post('/api/v1/auth/patient/login')
        .send({ identifier: 'nobody@example.com', password });

      expect(res.status).toBe(401);
    });
  });

  describe('POST /api/v1/auth/patient/send-otp', () => {
    it('rejects an invalid email', async () => {
      const res = await request(app)
        .post('/api/v1/auth/patient/send-otp')
        .send({ email: 'not-an-email' });

      expect(res.status).toBe(400);
    });

    it('returns 404 for an unregistered email', async () => {
      const res = await request(app)
        .post('/api/v1/auth/patient/send-otp')
        .send({ email: 'nobody@example.com' });

      expect(res.status).toBe(404);
    });

    it('returns 503 when no email provider is configured', async () => {
      const res = await request(app)
        .post('/api/v1/auth/patient/send-otp')
        .send({ email });

      expect(res.status).toBe(503);
      expect(res.body.error.code).toBe('EMAIL_NOT_CONFIGURED');
    });
  });

  describe('POST /api/v1/auth/patient/verify-otp', () => {
    const freshOtp = async (code: string, expiresAt: Date) => {
      await prisma.otpCode.updateMany({ where: { email, isUsed: false }, data: { isUsed: true } });
      await prisma.otpCode.create({ data: { email, code, expiresAt } });
    };

    it('rejects an invalid OTP', async () => {
      await freshOtp('123456', new Date(Date.now() + 10 * 60 * 1000));

      const res = await request(app)
        .post('/api/v1/auth/patient/verify-otp')
        .send({ email, code: '000000' });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('OTP_INVALID');
    });

    it('rejects an expired OTP', async () => {
      await freshOtp('123456', new Date(Date.now() - 1000));

      const res = await request(app)
        .post('/api/v1/auth/patient/verify-otp')
        .send({ email, code: '123456' });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('OTP_EXPIRED');
    });

    it('logs in with a valid OTP', async () => {
      await freshOtp('654321', new Date(Date.now() + 10 * 60 * 1000));

      const res = await request(app)
        .post('/api/v1/auth/patient/verify-otp')
        .send({ email, code: '654321' });

      expect(res.status).toBe(200);
      expect(res.body.data.accessToken).toBeDefined();
    });
  });
});
