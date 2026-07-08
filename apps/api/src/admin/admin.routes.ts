import { Router, Request, Response } from 'express';
import { authenticate, authorize } from '../common/middleware/auth.middleware';
import { AdminService } from './admin.service';
import { asyncHandler } from '../common/middleware/asyncHandler';
import { sendSuccess, sendCreated } from '../common/utils/response';
import { VerificationStatus } from '@prisma/client';

const router = Router();
const service = new AdminService();

// All admin routes require authentication
router.use(authenticate, authorize('ADMIN', 'SUPER_ADMIN'));

// Dashboard
router.get('/dashboard', asyncHandler(async (_req, res) => {
  const stats = await service.getDashboardStats();
  sendSuccess(res, stats);
}));

// Doctor management
router.get('/doctors', asyncHandler(async (req: Request, res: Response) => {
  const result = await service.getDoctors(
    Number(req.query.page ?? 1), Number(req.query.limit ?? 20),
    req.query.search as string, req.query.status as VerificationStatus,
  );
  sendSuccess(res, result.data, undefined, 200, result.meta);
}));

router.post('/doctors', asyncHandler(async (req: Request, res: Response) => {
  const doctor = await service.createDoctor(req.body);
  sendCreated(res, doctor, 'Doctor created');
}));

router.patch('/doctors/:id/verify', asyncHandler(async (req: Request, res: Response) => {
  const doctor = await service.verifyDoctor(req.params.id, req.body.status, req.user!.id);
  sendSuccess(res, doctor, 'Doctor verification updated');
}));

router.patch('/doctors/:id/toggle-active', asyncHandler(async (req: Request, res: Response) => {
  const doctor = await service.toggleDoctorActive(req.params.id, req.user!.id);
  sendSuccess(res, doctor);
}));

// User management
router.get('/users', asyncHandler(async (req: Request, res: Response) => {
  const result = await service.getUsers(
    Number(req.query.page ?? 1), Number(req.query.limit ?? 20), req.query.search as string,
  );
  sendSuccess(res, result.data, undefined, 200, result.meta);
}));

router.patch('/users/:id/toggle-block', asyncHandler(async (req: Request, res: Response) => {
  const user = await service.toggleUserBlock(req.params.id, req.user!.id);
  sendSuccess(res, user);
}));

// Clinic management
router.get('/clinics', asyncHandler(async (req: Request, res: Response) => {
  const result = await service.getClinics(
    Number(req.query.page ?? 1), Number(req.query.limit ?? 20), req.query.city as string,
  );
  sendSuccess(res, result.data, undefined, 200, result.meta);
}));

router.post('/clinics', asyncHandler(async (req: Request, res: Response) => {
  const clinic = await service.createClinic(req.body);
  sendCreated(res, clinic, 'Clinic created');
}));

router.patch('/clinics/:id', asyncHandler(async (req: Request, res: Response) => {
  const clinic = await service.updateClinic(req.params.id, req.body);
  sendSuccess(res, clinic, 'Clinic updated');
}));

// Category management
router.post('/categories', asyncHandler(async (req: Request, res: Response) => {
  const cat = await service.createCategory(req.body.name, req.body.iconUrl, req.body.color);
  sendCreated(res, cat);
}));

router.patch('/categories/:id', asyncHandler(async (req: Request, res: Response) => {
  const cat = await service.updateCategory(req.params.id, req.body);
  sendSuccess(res, cat);
}));

router.delete('/categories/:id', asyncHandler(async (req: Request, res: Response) => {
  await service.deleteCategory(req.params.id);
  sendSuccess(res, null, 'Category deleted');
}));

// Reviews moderation
router.patch('/reviews/:id/moderate', asyncHandler(async (req: Request, res: Response) => {
  const review = await service.moderateReview(req.params.id, req.body.isVisible, req.user!.id);
  sendSuccess(res, review);
}));

// Audit logs
router.get('/audit-logs', asyncHandler(async (req: Request, res: Response) => {
  const result = await service.getAuditLogs(Number(req.query.page ?? 1), Number(req.query.limit ?? 50));
  sendSuccess(res, result.data, undefined, 200, result.meta);
}));

export default router;
