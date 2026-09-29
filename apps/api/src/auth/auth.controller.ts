import { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { sendSuccess, sendCreated } from '../common/utils/response';
import { asyncHandler } from '../common/middleware/asyncHandler';

const authService = new AuthService();

export const registerPatient = asyncHandler(async (req: Request, res: Response) => {
  const { name, email, phone, password, gender, age, fcmToken } = req.body;
  const result = await authService.registerPatient(name, email, password, phone, gender, age, fcmToken);
  sendCreated(res, result, 'Account created successfully.');
});

export const sendOtp = asyncHandler(async (req: Request, res: Response) => {
  const result = await authService.sendOtp(req.body.email);
  sendSuccess(res, result, 'OTP sent successfully');
});

export const verifyOtp = asyncHandler(async (req: Request, res: Response) => {
  const { email, code, fcmToken } = req.body;
  const result = await authService.verifyOtpAndLogin(email, code, fcmToken);
  sendSuccess(res, result, 'Login successful');
});

export const loginWithPassword = asyncHandler(async (req: Request, res: Response) => {
  const { identifier, password, fcmToken } = req.body;
  const result = await authService.loginWithPassword(identifier, password, fcmToken);
  sendSuccess(res, result, 'Login successful');
});

export const doctorLogin = asyncHandler(async (req: Request, res: Response) => {
  const { email, password, fcmToken } = req.body;
  const result = await authService.doctorLogin(email, password, fcmToken);
  sendSuccess(res, result, 'Login successful');
});

export const adminLogin = asyncHandler(async (req: Request, res: Response) => {
  const { email, password } = req.body;
  const result = await authService.adminLogin(email, password);
  sendSuccess(res, result, 'Login successful');
});

export const refreshToken = asyncHandler(async (req: Request, res: Response) => {
  const result = await authService.refreshTokens(req.body.refreshToken);
  sendSuccess(res, result);
});

export const logout = asyncHandler(async (req: Request, res: Response) => {
  await authService.logout(req.body.refreshToken);
  sendSuccess(res, null, 'Logged out successfully');
});

export const googleSignIn = asyncHandler(async (req: Request, res: Response) => {
  const { idToken, fcmToken } = req.body;
  const result = await authService.googleSignIn(idToken, fcmToken);
  const status = result.isNewUser ? 201 : 200;
  res.status(status).json({ success: true, data: result });
});

export const initSeed = asyncHandler(async (_req: Request, res: Response) => {
  const result = await authService.initSeed();
  sendCreated(res, result, 'Seed completed');
});
