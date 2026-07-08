import { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { sendSuccess, sendCreated } from '../common/utils/response';
import { asyncHandler } from '../common/middleware/asyncHandler';

const authService = new AuthService();

export const sendOtp = asyncHandler(async (req: Request, res: Response) => {
  const result = await authService.sendOtp(req.body.phone);
  sendSuccess(res, result, 'OTP sent successfully');
});

export const verifyOtp = asyncHandler(async (req: Request, res: Response) => {
  const { phone, code, name, gender, age, fcmToken } = req.body;
  const result = await authService.verifyOtpAndLogin(phone, code, name, gender, age, fcmToken);
  const status = result.isNewUser ? 201 : 200;
  res.status(status).json({ success: true, data: result });
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
