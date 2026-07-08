import { Router } from 'express';
import * as controller from './doctors.controller';
import { authenticate, authorize, optionalAuth } from '../common/middleware/auth.middleware';

const router = Router();

// Public routes
router.get('/categories', controller.getCategories);
router.get('/', optionalAuth, controller.searchDoctors);
router.get('/:id', optionalAuth, controller.getDoctorById);

// Doctor-only routes
router.get('/me/profile', authenticate, authorize('DOCTOR'), controller.getDoctorProfile);
router.patch('/me/profile', authenticate, authorize('DOCTOR'), controller.updateDoctorProfile);

export default router;
