import { AppointmentStatus, Prisma, SlotStatus } from '@prisma/client';
import { prisma } from '../config/database';
import { AppError } from '../common/errors/AppError';
import { env } from '../config/env';
import { buildPagination, buildPaginatedResult } from '../common/types/pagination';
import { addMinutes, format, parseISO, isAfter, isBefore, eachMinuteOfInterval } from '../common/utils/dateUtils';

export class AppointmentsService {
  // ─── Slot Generation ────────────────────────────────────────────────────

  async getAvailableSlots(doctorId: string, clinicId: string, date: string) {
    const targetDate = new Date(date);
    const dayOfWeek = this.getDayName(targetDate.getDay());

    // Check doctor availability for this day
    const availability = await prisma.doctorAvailability.findFirst({
      where: { doctorId, dayOfWeek: dayOfWeek as any, isActive: true },
    });
    if (!availability) return [];

    // Check vacation/blocked
    const isBlocked = await prisma.blockedDate.findFirst({
      where: { doctorId, date: targetDate },
    });
    if (isBlocked) return [];

    const vacation = await prisma.doctorVacation.findFirst({
      where: {
        doctorId,
        startDate: { lte: targetDate },
        endDate: { gte: targetDate },
      },
    });
    if (vacation) return [];

    // Generate time slots for the day
    const slots = this.generateSlots(
      availability.startTime,
      availability.endTime,
      availability.slotDurationMinutes,
      availability.breakStart ?? undefined,
      availability.breakEnd ?? undefined,
    );

    // Upsert all generated slots in DB (shim doesn't support compound unique keys so use findFirst + create)
    await Promise.all(
      slots.map(async (s) => {
        const existing = await prisma.timeSlot.findFirst({
          where: { doctorId, clinicId, date: targetDate, startTime: s.start },
        });
        if (!existing) {
          await prisma.timeSlot.create({
            data: { doctorId, clinicId, date: targetDate, startTime: s.start, endTime: s.end, status: SlotStatus.AVAILABLE },
          });
        }
      }),
    );

    // Release expired locks
    await this.releaseExpiredLocks();

    // Fetch current status
    const dbSlots = await prisma.timeSlot.findMany({
      where: { doctorId, clinicId, date: targetDate },
      orderBy: { startTime: 'asc' },
    });

    return dbSlots.map((slot) => ({
      id: slot.id,
      startTime: slot.startTime,
      endTime: slot.endTime,
      isAvailable: slot.status === SlotStatus.AVAILABLE,
      status: slot.status,
    }));
  }

  async lockSlot(slotId: string, userId: string): Promise<void> {
    const lockExpiresAt = new Date(Date.now() + env.SLOT_LOCK_TTL * 1000);
    const result = await prisma.timeSlot.updateMany({
      where: { id: slotId, status: SlotStatus.AVAILABLE },
      data: { status: SlotStatus.LOCKED, lockedAt: new Date(), lockedBy: userId, lockExpiresAt },
    });
    if (result.count === 0) throw AppError.conflict('Slot is no longer available');
  }

  async releaseSlotLock(slotId: string, userId: string): Promise<void> {
    await prisma.timeSlot.updateMany({
      where: { id: slotId, lockedBy: userId, status: SlotStatus.LOCKED },
      data: { status: SlotStatus.AVAILABLE, lockedAt: null, lockedBy: null, lockExpiresAt: null },
    });
  }

  async releaseExpiredLocks(): Promise<void> {
    await prisma.timeSlot.updateMany({
      where: { status: SlotStatus.LOCKED, lockExpiresAt: { lt: new Date() } },
      data: { status: SlotStatus.AVAILABLE, lockedAt: null, lockedBy: null, lockExpiresAt: null },
    });
  }

  // ─── Booking ────────────────────────────────────────────────────────────

  async bookAppointment(
    patientId: string,
    doctorId: string,
    clinicId: string,
    slotId: string,
    notes?: string,
  ) {
    return prisma.$transaction(async (tx) => {
      // Lock the slot row for update
      const slot = await tx.timeSlot.findUnique({ where: { id: slotId } });
      if (!slot) throw AppError.notFound('Slot');

      const isOwnLock = slot.lockedBy === patientId && slot.status === SlotStatus.LOCKED;
      const isAvailable = slot.status === SlotStatus.AVAILABLE;

      if (!isOwnLock && !isAvailable) {
        throw AppError.conflict('Slot is no longer available');
      }

      // Update slot to BOOKED — include status guard to prevent double-booking under concurrent requests
      const booked = await tx.timeSlot.updateMany({
        where: {
          id: slotId,
          status: { in: [SlotStatus.AVAILABLE, SlotStatus.LOCKED] },
        },
        data: { status: SlotStatus.BOOKED, bookedAt: new Date(), lockedBy: null, lockExpiresAt: null },
      });
      if (booked.count === 0) throw AppError.conflict('Slot was just taken. Please choose another.');

      // Create appointment (shim ignores include, so fetch doctor/clinic separately)
      const appointment = await tx.appointment.create({
        data: {
          patientId,
          doctorId,
          clinicId,
          slotId,
          date: slot.date,
          startTime: slot.startTime,
          endTime: slot.endTime,
          status: AppointmentStatus.CONFIRMED,
          notes,
        },
      });

      // Record status history
      await tx.appointmentStatusHistory.create({
        data: {
          appointmentId: appointment.id,
          toStatus: AppointmentStatus.CONFIRMED,
          changedBy: patientId,
        },
      });

      // Fetch doctor and clinic names for the confirmation response
      const [doctorData, clinicData] = await Promise.all([
        tx.doctor.findFirst({ where: { id: doctorId } }),
        tx.clinic.findFirst({ where: { id: clinicId } }),
      ]);

      return {
        ...appointment,
        doctor: doctorData ? { name: (doctorData as any).name, avatarUrl: (doctorData as any).avatarUrl } : null,
        clinic: clinicData ? { name: (clinicData as any).name, addressLine1: (clinicData as any).addressLine1 } : null,
      };
    });
  }

  async cancelAppointment(
    appointmentId: string,
    cancelledBy: string,
    reason?: string,
    role: string = 'PATIENT',
  ) {
    const appointment = await prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: { slot: true },
    });

    if (!appointment) throw AppError.notFound('Appointment');

    const allowedStatuses: AppointmentStatus[] = [
      AppointmentStatus.PENDING,
      AppointmentStatus.CONFIRMED,
    ];
    if (!allowedStatuses.includes(appointment.status)) {
      throw AppError.badRequest('Appointment cannot be cancelled in its current state');
    }

    if (role === 'PATIENT' && appointment.patientId !== cancelledBy) {
      throw AppError.forbidden();
    }
    if (role === 'DOCTOR' && appointment.doctorId !== cancelledBy) {
      throw AppError.forbidden();
    }

    return prisma.$transaction(async (tx) => {
      const updated = await tx.appointment.update({
        where: { id: appointmentId },
        data: {
          status: AppointmentStatus.CANCELLED,
          cancellationReason: reason,
          cancelledBy,
        },
      });

      await tx.appointmentStatusHistory.create({
        data: {
          appointmentId,
          fromStatus: appointment.status,
          toStatus: AppointmentStatus.CANCELLED,
          changedBy: cancelledBy,
          reason,
        },
      });

      // Free the slot
      await tx.timeSlot.update({
        where: { id: appointment.slotId },
        data: { status: SlotStatus.AVAILABLE, bookedAt: null },
      });

      return updated;
    });
  }

  async rescheduleAppointment(
    appointmentId: string,
    patientId: string,
    newSlotId: string,
    notes?: string,
  ) {
    const existing = await prisma.appointment.findFirst({
      where: { id: appointmentId, patientId },
    });
    if (!existing) throw AppError.notFound('Appointment');

    await this.cancelAppointment(appointmentId, patientId, 'Rescheduled', 'PATIENT');
    return this.bookAppointment(patientId, existing.doctorId, existing.clinicId!, newSlotId, notes);
  }

  // ─── Queries ────────────────────────────────────────────────────────────

  async getPatientAppointments(
    patientId: string,
    status?: AppointmentStatus[],
    page = 1,
    limit = 20,
  ) {
    const { skip, take } = buildPagination({ page, limit });
    const where: Prisma.AppointmentWhereInput = { patientId };
    if (status?.length) where.status = { in: status };

    const [data, total] = await Promise.all([
      prisma.appointment.findMany({
        where,
        skip,
        take,
        orderBy: [{ date: 'desc' }, { startTime: 'desc' }],
        include: {
          doctor: { select: { id: true, name: true, avatarUrl: true } },
          clinic: { select: { id: true, name: true, addressLine1: true, city: true } },
        },
      }),
      prisma.appointment.count({ where }),
    ]);

    return buildPaginatedResult(data, total, page, limit);
  }

  async getDoctorAppointments(
    doctorId: string,
    date?: string,
    status?: AppointmentStatus[],
    page = 1,
    limit = 50,
  ) {
    const { skip, take } = buildPagination({ page, limit });
    const where: Prisma.AppointmentWhereInput = { doctorId };
    if (date) where.date = new Date(date);
    if (status?.length) where.status = { in: status };

    const [data, total] = await Promise.all([
      prisma.appointment.findMany({
        where,
        skip,
        take,
        orderBy: [{ date: 'asc' }, { startTime: 'asc' }],
        include: {
          patient: { select: { id: true, name: true, phone: true, avatarUrl: true, gender: true, age: true } },
          clinic: { select: { id: true, name: true } },
        },
      }),
      prisma.appointment.count({ where }),
    ]);

    return buildPaginatedResult(data, total, page, limit);
  }

  async updateAppointmentStatus(
    appointmentId: string,
    doctorId: string,
    newStatus: AppointmentStatus,
  ) {
    const allowed: AppointmentStatus[] = [
      AppointmentStatus.CHECKED_IN,
      AppointmentStatus.IN_CONSULTATION,
      AppointmentStatus.COMPLETED,
      AppointmentStatus.NO_SHOW,
    ];
    if (!allowed.includes(newStatus)) {
      throw AppError.badRequest(`Doctors can only set status to: ${allowed.join(', ')}`);
    }

    const appointment = await prisma.appointment.findFirst({
      where: { id: appointmentId, doctorId },
    });
    if (!appointment) throw AppError.notFound('Appointment');

    return prisma.$transaction(async (tx) => {
      const updated = await tx.appointment.update({
        where: { id: appointmentId },
        data: { status: newStatus },
      });

      await tx.appointmentStatusHistory.create({
        data: {
          appointmentId,
          fromStatus: appointment.status,
          toStatus: newStatus,
          changedBy: doctorId,
        },
      });

      return updated;
    });
  }

  async getAppointmentById(appointmentId: string, requesterId: string, role: string) {
    const appointment = await prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: {
        doctor: { select: { id: true, name: true, avatarUrl: true, phone: true } },
        clinic: { select: { id: true, name: true, addressLine1: true, city: true } },
        patient: { select: { id: true, name: true, phone: true } },
      },
    });
    if (!appointment) throw AppError.notFound('Appointment');

    if (role === 'PATIENT' && appointment.patientId !== requesterId) throw AppError.forbidden();
    if (role === 'DOCTOR' && appointment.doctorId !== requesterId) throw AppError.forbidden();

    return appointment;
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  private generateSlots(
    startTime: string,
    endTime: string,
    durationMinutes: number,
    breakStart?: string,
    breakEnd?: string,
  ): { start: string; end: string }[] {
    const slots: { start: string; end: string }[] = [];
    let current = this.timeToMinutes(startTime);
    const end = this.timeToMinutes(endTime);
    const breakS = breakStart ? this.timeToMinutes(breakStart) : null;
    const breakE = breakEnd ? this.timeToMinutes(breakEnd) : null;

    while (current + durationMinutes <= end) {
      const slotEnd = current + durationMinutes;
      const inBreak = breakS !== null && breakE !== null && current < breakE && slotEnd > breakS;

      if (!inBreak) {
        slots.push({
          start: this.minutesToTime(current),
          end: this.minutesToTime(slotEnd),
        });
      }
      current += durationMinutes;
    }

    return slots;
  }

  private timeToMinutes(time: string): number {
    const [h, m] = time.split(':').map(Number);
    return h * 60 + m;
  }

  private minutesToTime(minutes: number): string {
    const h = Math.floor(minutes / 60).toString().padStart(2, '0');
    const m = (minutes % 60).toString().padStart(2, '0');
    return `${h}:${m}`;
  }

  private getDayName(day: number): string {
    const days = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
    return days[day];
  }
}
