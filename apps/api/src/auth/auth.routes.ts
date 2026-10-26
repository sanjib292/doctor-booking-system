import { Router } from 'express';
import * as controller from './auth.controller';
import { validate } from '../common/middleware/validate';
import {
  sendOtpSchema,
  verifyOtpSchema,
  registerPatientSchema,
  doctorLoginSchema,
  adminLoginSchema,
  refreshTokenSchema,
  patientLoginSchema,
} from './auth.schema';

const router = Router();

/**
 * @swagger
 * /auth/patient/send-otp:
 *   post:
 *     summary: Send OTP to patient phone
 *     tags: [Auth]
 */
router.post('/patient/register', validate(registerPatientSchema), controller.registerPatient);
router.post('/patient/login', validate(patientLoginSchema), controller.loginWithPassword);
router.post('/patient/send-otp', validate(sendOtpSchema), controller.sendOtp);

/**
 * @swagger
 * /auth/patient/verify-otp:
 *   post:
 *     summary: Verify OTP and login/register patient
 *     tags: [Auth]
 */
router.post('/patient/verify-otp', validate(verifyOtpSchema), controller.verifyOtp);

/**
 * @swagger
 * /auth/doctor/login:
 *   post:
 *     summary: Doctor login with email/password
 *     tags: [Auth]
 */
router.post('/doctor/login', validate(doctorLoginSchema), controller.doctorLogin);

/**
 * @swagger
 * /auth/admin/login:
 *   post:
 *     summary: Admin login with email/password
 *     tags: [Auth]
 */
router.post('/admin/login', validate(adminLoginSchema), controller.adminLogin);

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     summary: Refresh access token
 *     tags: [Auth]
 */
router.post('/refresh', validate(refreshTokenSchema), controller.refreshToken);

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: Logout and revoke refresh token
 *     tags: [Auth]
 */
router.post('/logout', validate(refreshTokenSchema), controller.logout);

/**
 * @swagger
 * /auth/patient/google:
 *   post:
 *     summary: Google Sign-In for patients (Phase 2)
 *     tags: [Auth]
 */
router.post('/patient/google', controller.googleSignIn);

export default router;
