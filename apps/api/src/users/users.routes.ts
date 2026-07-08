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

export default router;
