import { describe, it, expect, beforeEach, afterAll } from '@jest/globals';
import request from 'supertest';
import app from '../index';
import { prisma } from '../config/database';

describe('Auth API', () => {
  const testPhone = '+919999999999';

  beforeEach(async () => {
    await prisma.otpCode.deleteMany({ where: { phone: testPhone } });
    await prisma.user.deleteMany({ where: { phone: testPhone } });
  });

  afterAll(async () => {
    await prisma.otpCode.deleteMany({ where: { phone: testPhone } });
    await prisma.user.deleteMany({ where: { phone: testPhone } });
    await prisma.$disconnect();
  });

  describe('POST /api/v1/auth/patient/send-otp', () => {
    it('should send OTP successfully', async () => {
      const res = await request(app)
        .post('/api/v1/auth/patient/send-otp')
        .send({ phone: testPhone });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.expiresIn).toBeGreaterThan(0);
    });

    it('should reject invalid phone number', async () => {
      const res = await request(app)
        .post('/api/v1/auth/patient/send-otp')
        .send({ phone: '123' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('POST /api/v1/auth/patient/verify-otp', () => {
    it('should create new user on first login', async () => {
      // Create OTP
      await prisma.otpCode.create({
        data: {
          phone: testPhone,
          code: '123456',
          expiresAt: new Date(Date.now() + 10 * 60 * 1000),
        },
      });

      const res = await request(app)
        .post('/api/v1/auth/patient/verify-otp')
        .send({ phone: testPhone, code: '123456', name: 'Test User' });

      expect(res.status).toBe(201);
      expect(res.body.data.isNewUser).toBe(true);
      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
    });

    it('should reject wrong OTP', async () => {
      await prisma.otpCode.create({
        data: {
          phone: testPhone,
          code: '123456',
          expiresAt: new Date(Date.now() + 10 * 60 * 1000),
        },
      });

      const res = await request(app)
        .post('/api/v1/auth/patient/verify-otp')
        .send({ phone: testPhone, code: '000000' });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('OTP_INVALID');
    });

    it('should reject expired OTP', async () => {
      await prisma.otpCode.create({
        data: {
          phone: testPhone,
          code: '123456',
          expiresAt: new Date(Date.now() - 1000),
        },
      });

      const res = await request(app)
        .post('/api/v1/auth/patient/verify-otp')
        .send({ phone: testPhone, code: '123456' });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('OTP_EXPIRED');
    });
  });
});
