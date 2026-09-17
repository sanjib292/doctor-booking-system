import { Router } from 'express';
import * as controller from './doctors.controller';
import { authenticate, authorize, optionalAuth } from '../common/middleware/auth.middleware';

const router = Router();

// Public routes
router.get('/categories', controller.getCategories);
router.get('/', optionalAuth, controller.searchDoctors);

// Doctor-only routes (must be before /:id to avoid Express matching 'me' as an id)
router.get('/me/profile', authenticate, authorize('DOCTOR'), controller.getDoctorProfile);
router.patch('/me/profile', authenticate, authorize('DOCTOR'), controller.updateDoctorProfile);

// Parameterised public routes
router.get('/:id/availability', controller.getDoctorAvailability);
router.get('/:id', optionalAuth, controller.getDoctorById);

export default router;
