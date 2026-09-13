import { Router } from 'express';
import * as controller from './users.controller';
import { authenticate, authorize } from '../common/middleware/auth.middleware';

const router = Router();

router.get('/me', authenticate, authorize('PATIENT'), controller.getProfile);
router.patch('/me', authenticate, authorize('PATIENT'), controller.updateProfile);
router.patch('/me/location', authenticate, authorize('PATIENT'), controller.updateLocation);
router.delete('/me', authenticate, authorize('PATIENT'), controller.deleteAccount);

router.get('/me/favorites', authenticate, authorize('PATIENT'), controller.getFavorites);
router.post('/me/favorites/:doctorId', authenticate, authorize('PATIENT'), controller.toggleFavorite);

router.get('/me/notifications', authenticate, authorize('PATIENT'), controller.getNotifications);
router.patch('/me/notifications/read', authenticate, authorize('PATIENT'), controller.markNotificationsRead);

// Medical history (Phase 2)
router.get('/me/medical-history', authenticate, authorize('PATIENT'), controller.getMedicalHistory);
router.post('/me/medical-history', authenticate, authorize('PATIENT'), controller.createMedicalRecord);
router.patch('/me/medical-history/:recordId', authenticate, authorize('PATIENT'), controller.updateMedicalRecord);
router.delete('/me/medical-history/:recordId', authenticate, authorize('PATIENT'), controller.deleteMedicalRecord);

export default router;
