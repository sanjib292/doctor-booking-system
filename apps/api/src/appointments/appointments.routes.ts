import { Router } from 'express';
import * as controller from './appointments.controller';
import { authenticate, authorize } from '../common/middleware/auth.middleware';

const router = Router();

// Slot availability (patient + doctor)
router.get('/slots/:doctorId/:clinicId', authenticate, controller.getAvailableSlots);
router.post('/slots/lock', authenticate, authorize('PATIENT'), controller.lockSlot);
router.post('/slots/release', authenticate, authorize('PATIENT'), controller.releaseSlotLock);

// Patient appointment management
router.post('/', authenticate, authorize('PATIENT'), controller.bookAppointment);
router.get('/my', authenticate, authorize('PATIENT'), controller.getPatientAppointments);
router.post('/:id/reschedule', authenticate, authorize('PATIENT'), controller.rescheduleAppointment);

// Doctor appointment management
router.get('/doctor/list', authenticate, authorize('DOCTOR'), controller.getDoctorAppointments);
router.patch('/:id/status', authenticate, authorize('DOCTOR'), controller.updateAppointmentStatus);

// Single appointment lookup (patient sees own, doctor sees own, admin sees any)
router.get('/:id', authenticate, authorize('PATIENT', 'DOCTOR', 'ADMIN'), controller.getAppointmentById);

// Cancel (patient or doctor)
router.post('/:id/cancel', authenticate, authorize('PATIENT', 'DOCTOR', 'ADMIN'), controller.cancelAppointment);

export default router;
