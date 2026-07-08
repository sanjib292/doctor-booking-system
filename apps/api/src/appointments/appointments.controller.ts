import { Request, Response } from 'express';
import { AppointmentsService } from './appointments.service';
import { sendSuccess, sendCreated } from '../common/utils/response';
import { asyncHandler } from '../common/middleware/asyncHandler';
import { AppError } from '../common/errors/AppError';
import { AppointmentStatus } from '@prisma/client';

const service = new AppointmentsService();

export const getAvailableSlots = asyncHandler(async (req: Request, res: Response) => {
  const { doctorId, clinicId } = req.params;
  const { date } = req.query;
  if (!date) throw AppError.badRequest('date query parameter required');
  const slots = await service.getAvailableSlots(doctorId, clinicId, date as string);
  sendSuccess(res, slots);
});

export const lockSlot = asyncHandler(async (req: Request, res: Response) => {
  await service.lockSlot(req.body.slotId, req.user!.id);
  sendSuccess(res, null, 'Slot locked for 2 minutes');
});

export const releaseSlotLock = asyncHandler(async (req: Request, res: Response) => {
  await service.releaseSlotLock(req.body.slotId, req.user!.id);
  sendSuccess(res, null, 'Slot lock released');
});

export const bookAppointment = asyncHandler(async (req: Request, res: Response) => {
  const { doctorId, clinicId, slotId, notes } = req.body;
  const appointment = await service.bookAppointment(req.user!.id, doctorId, clinicId, slotId, notes);
  sendCreated(res, appointment, 'Appointment booked successfully');
});

export const cancelAppointment = asyncHandler(async (req: Request, res: Response) => {
  const { reason } = req.body;
  const role = req.user!.role;
  const updated = await service.cancelAppointment(req.params.id, req.user!.id, reason, role);
  sendSuccess(res, updated, 'Appointment cancelled');
});

export const rescheduleAppointment = asyncHandler(async (req: Request, res: Response) => {
  const { newSlotId, notes } = req.body;
  const appointment = await service.rescheduleAppointment(req.params.id, req.user!.id, newSlotId, notes);
  sendCreated(res, appointment, 'Appointment rescheduled');
});

export const getPatientAppointments = asyncHandler(async (req: Request, res: Response) => {
  const status = req.query.status
    ? (req.query.status as string).split(',').map((s) => s as AppointmentStatus)
    : undefined;
  const result = await service.getPatientAppointments(
    req.user!.id,
    status,
    Number(req.query.page ?? 1),
    Number(req.query.limit ?? 20),
  );
  sendSuccess(res, result.data, undefined, 200, result.meta);
});

export const getDoctorAppointments = asyncHandler(async (req: Request, res: Response) => {
  const status = req.query.status
    ? (req.query.status as string).split(',').map((s) => s as AppointmentStatus)
    : undefined;
  const result = await service.getDoctorAppointments(
    req.user!.id,
    req.query.date as string,
    status,
    Number(req.query.page ?? 1),
    Number(req.query.limit ?? 50),
  );
  sendSuccess(res, result.data, undefined, 200, result.meta);
});

export const updateAppointmentStatus = asyncHandler(async (req: Request, res: Response) => {
  const updated = await service.updateAppointmentStatus(
    req.params.id,
    req.user!.id,
    req.body.status as AppointmentStatus,
  );
  sendSuccess(res, updated, 'Status updated');
});
