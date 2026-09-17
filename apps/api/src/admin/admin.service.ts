import { Prisma, VerificationStatus } from '@prisma/client';
import { prisma } from '../config/database';
import { AppError } from '../common/errors/AppError';
import { hashPassword } from '../common/utils/hash';
import { buildPagination, buildPaginatedResult } from '../common/types/pagination';

export class AdminService {
  // ─── Dashboard ──────────────────────────────────────────────────────────

  async getDashboardStats() {
    const [
      totalUsers,
      totalDoctors,
      totalAppointments,
      totalClinics,
      todayAppointments,
      pendingVerifications,
      appointmentsByStatus,
      recentAppointments,
    ] = await Promise.all([
      prisma.user.count({ where: { deletedAt: null } }),
      prisma.doctor.count({ where: { deletedAt: null, isActive: true } }),
      prisma.appointment.count(),
      prisma.clinic.count({ where: { isActive: true } }),
      prisma.appointment.count({ where: { date: { gte: this.startOfDay(), lte: this.endOfDay() } } }),
      prisma.doctor.count({ where: { verificationStatus: VerificationStatus.PENDING, deletedAt: null } }),
      prisma.appointment.groupBy({ by: ['status'], _count: true }),
      prisma.appointment.findMany({
        take: 5,
        orderBy: { createdAt: 'desc' },
        include: {
          patient: { select: { name: true } },
          doctor: { select: { name: true } },
        },
      }),
    ]);

    return {
      totalUsers,
      totalDoctors,
      totalAppointments,
      totalClinics,
      todayAppointments,
      pendingVerifications,
      appointmentsByStatus,
      recentAppointments,
    };
  }

  // ─── Doctor Management ──────────────────────────────────────────────────

  async getDoctors(page = 1, limit = 20, search?: string, status?: VerificationStatus) {
    const { skip, take } = buildPagination({ page, limit });
    const where: Prisma.DoctorWhereInput = { deletedAt: null };
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
      ];
    }
    if (status) where.verificationStatus = status;

    const [data, total] = await Promise.all([
      prisma.doctor.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true, name: true, email: true, phone: true, avatarUrl: true,
          verificationStatus: true, isActive: true, averageRating: true, createdAt: true,
          categories: { select: { category: { select: { name: true } } }, take: 1 },
        },
      }),
      prisma.doctor.count({ where }),
    ]);

    return buildPaginatedResult(data, total, page, limit);
  }

  async createDoctor(data: {
    name: string; email: string; phone: string; password: string;
    qualifications?: string[]; experienceYears?: number; gender?: string;
  }) {
    const passwordHash = await hashPassword(data.password);
    const doctor = await prisma.doctor.create({
      data: {
        name: data.name,
        email: data.email,
        phone: data.phone,
        passwordHash,
        qualifications: data.qualifications ?? [],
        experienceYears: data.experienceYears ?? 0,
        gender: (data.gender as any) ?? undefined,
        verificationStatus: VerificationStatus.VERIFIED,
      },
    });
    const { passwordHash: _, ...safe } = doctor;
    return safe;
  }

  async verifyDoctor(doctorId: string, status: VerificationStatus, adminId: string) {
    const doctor = await prisma.doctor.update({
      where: { id: doctorId },
      data: { verificationStatus: status, verifiedAt: status === VerificationStatus.VERIFIED ? new Date() : null },
    });

    await prisma.auditLog.create({
      data: {
        adminId,
        action: `doctor.${status.toLowerCase()}`,
        entity: 'doctor',
        entityId: doctorId,
      },
    });

    const { passwordHash, ...safe } = doctor;
    return safe;
  }

  async toggleDoctorActive(doctorId: string, adminId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { id: doctorId } });
    if (!doctor) throw AppError.notFound('Doctor');

    const updated = await prisma.doctor.update({
      where: { id: doctorId },
      data: { isActive: !doctor.isActive },
    });

    await prisma.auditLog.create({
      data: {
        adminId,
        action: updated.isActive ? 'doctor.activated' : 'doctor.deactivated',
        entity: 'doctor',
        entityId: doctorId,
      },
    });

    const { passwordHash, ...safe } = updated;
    return safe;
  }

  // ─── User Management ────────────────────────────────────────────────────

  async getUsers(page = 1, limit = 20, search?: string) {
    const { skip, take } = buildPagination({ page, limit });
    const where: Prisma.UserWhereInput = { deletedAt: null };
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { phone: { contains: search } },
        { email: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [data, total] = await Promise.all([
      prisma.user.findMany({
        where, skip, take, orderBy: { createdAt: 'desc' },
        select: { id: true, name: true, phone: true, email: true, gender: true, age: true, avatarUrl: true, isActive: true, isBlocked: true, createdAt: true },
      }),
      prisma.user.count({ where }),
    ]);

    return buildPaginatedResult(data, total, page, limit);
  }

  async toggleUserBlock(userId: string, adminId: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw AppError.notFound('User');

    const updated = await prisma.user.update({
      where: { id: userId },
      data: { isBlocked: !user.isBlocked },
    });

    await prisma.auditLog.create({
      data: {
        adminId,
        action: updated.isBlocked ? 'user.blocked' : 'user.unblocked',
        entity: 'user',
        entityId: userId,
      },
    });

    const { passwordHash: _ph, ...safe } = updated as any;
    return safe;
  }

  // ─── Clinic Management ──────────────────────────────────────────────────

  async createClinic(data: Prisma.ClinicCreateInput) {
    return prisma.clinic.create({ data });
  }

  async updateClinic(clinicId: string, data: Prisma.ClinicUpdateInput) {
    return prisma.clinic.update({ where: { id: clinicId }, data });
  }

  async getClinics(page = 1, limit = 20, city?: string) {
    const { skip, take } = buildPagination({ page, limit });
    const where: Prisma.ClinicWhereInput = { deletedAt: null };
    if (city) where.city = { contains: city, mode: 'insensitive' };

    const [data, total] = await Promise.all([
      prisma.clinic.findMany({ where, skip, take, orderBy: { createdAt: 'desc' } }),
      prisma.clinic.count({ where }),
    ]);

    return buildPaginatedResult(data, total, page, limit);
  }

  // ─── Appointments ────────────────────────────────────────────────────

  async getAppointments(page = 1, limit = 20, status?: string, doctorId?: string, patientId?: string) {
    const { skip, take } = buildPagination({ page, limit });
    const where: any = {};
    if (status) where.status = status;
    if (doctorId) where.doctorId = doctorId;
    if (patientId) where.patientId = patientId;

    const [flatAppts, total] = await Promise.all([
      prisma.appointment.findMany({ where, skip, take, orderBy: { createdAt: 'desc' } }),
      prisma.appointment.count({ where }),
    ]);

    if (flatAppts.length === 0) return buildPaginatedResult([], 0, page, limit);

    const apptIds = (flatAppts as any[]).map((a: any) => a.id);
    const apptRows = await prisma.$queryRaw(
      `SELECT a.id,
              u.id as "patientId", u.name as "patientName", u."avatarUrl" as "patientAvatar",
              d.id as "doctorId", d.name as "doctorName", d."avatarUrl" as "doctorAvatar",
              c.id as "clinicId", c.name as "clinicName"
       FROM appointments a
       JOIN users u ON u.id = a."patientId"
       JOIN doctors d ON d.id = a."doctorId"
       LEFT JOIN clinics c ON c.id = a."clinicId"
       WHERE a.id = ANY($1)`,
      apptIds,
    );

    const lookup = new Map<string, any>();
    for (const row of apptRows as any[]) lookup.set(row.id, row);

    const data = (flatAppts as any[]).map((a: any) => {
      const rel = lookup.get(a.id) ?? {};
      return {
        ...a,
        patient: { id: rel.patientId, name: rel.patientName, avatarUrl: rel.patientAvatar },
        doctor: { id: rel.doctorId, name: rel.doctorName, avatarUrl: rel.doctorAvatar },
        clinic: rel.clinicId ? { id: rel.clinicId, name: rel.clinicName } : null,
      };
    });

    return buildPaginatedResult(data, total, page, limit);
  }

  // ─── Category Management ─────────────────────────────────────────────

  async getAllCategories() {
    return prisma.category.findMany({ where: { deletedAt: null }, orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }] });
  }

  async createCategory(name: string, iconUrl?: string, color?: string) {
    const slug = name.toLowerCase().replace(/\s+/g, '-');
    return prisma.category.create({ data: { name, slug, iconUrl, color } });
  }

  async updateCategory(id: string, data: Partial<{ name: string; iconUrl: string; color: string; isActive: boolean; sortOrder: number }>) {
    return prisma.category.update({ where: { id }, data });
  }

  async deleteCategory(id: string) {
    return prisma.category.update({ where: { id }, data: { deletedAt: new Date(), isActive: false } });
  }

  // ─── Doctor Availability ─────────────────────────────────────────────

  async getDoctorAvailability(doctorId: string) {
    return prisma.doctorAvailability.findMany({
      where: { doctorId },
      orderBy: { dayOfWeek: 'asc' },
    });
  }

  async setDoctorAvailability(doctorId: string, data: {
    dayOfWeek: string; startTime: string; endTime: string;
    slotDurationMinutes: number; breakStart?: string; breakEnd?: string; isActive?: boolean;
  }) {
    const existing = await prisma.doctorAvailability.findFirst({
      where: { doctorId, dayOfWeek: data.dayOfWeek as any },
    });
    if (existing) {
      return prisma.doctorAvailability.update({
        where: { id: (existing as any).id },
        data: {
          startTime: data.startTime,
          endTime: data.endTime,
          slotDurationMinutes: data.slotDurationMinutes,
          breakStart: data.breakStart ?? null,
          breakEnd: data.breakEnd ?? null,
          isActive: data.isActive ?? true,
        },
      });
    }
    return prisma.doctorAvailability.create({
      data: { doctorId, dayOfWeek: data.dayOfWeek as any, startTime: data.startTime, endTime: data.endTime, slotDurationMinutes: data.slotDurationMinutes, breakStart: data.breakStart, breakEnd: data.breakEnd, isActive: data.isActive ?? true },
    });
  }

  async deleteDoctorAvailabilityDay(doctorId: string, dayOfWeek: string) {
    const existing = await prisma.doctorAvailability.findFirst({ where: { doctorId, dayOfWeek: dayOfWeek as any } });
    if (!existing) throw AppError.notFound('Availability');
    return prisma.doctorAvailability.delete({ where: { id: (existing as any).id } });
  }

  // ─── Doctor Clinic Assignment ────────────────────────────────────────

  async getDoctorClinics(doctorId: string) {
    const rows = await prisma.$queryRaw(
      `SELECT dc.*, c.name as "clinicName", c.city, c."addressLine1"
       FROM doctor_clinics dc
       JOIN clinics c ON c.id = dc."clinicId"
       WHERE dc."doctorId" = $1`,
      doctorId,
    );
    return rows;
  }

  async assignClinicToDoctor(doctorId: string, clinicId: string, consultationFee: number, isPrimary = false) {
    const clinic = await prisma.clinic.findFirst({ where: { id: clinicId } });
    if (!clinic) throw AppError.notFound('Clinic');
    const existing = await prisma.doctorClinic.findFirst({ where: { doctorId, clinicId } });
    if (existing) {
      return prisma.doctorClinic.update({ where: { id: (existing as any).id }, data: { consultationFee, isPrimary, isActive: true } });
    }
    if (isPrimary) {
      // Clear existing primary
      const primaryRows = await prisma.doctorClinic.findMany({ where: { doctorId, isPrimary: true } });
      for (const r of primaryRows as any[]) {
        await prisma.doctorClinic.update({ where: { id: r.id }, data: { isPrimary: false } });
      }
    }
    return prisma.doctorClinic.create({ data: { doctorId, clinicId, consultationFee, isPrimary, isActive: true } });
  }

  async removeClinicFromDoctor(doctorId: string, clinicId: string) {
    const existing = await prisma.doctorClinic.findFirst({ where: { doctorId, clinicId } });
    if (!existing) throw AppError.notFound('DoctorClinic');
    return prisma.doctorClinic.delete({ where: { id: (existing as any).id } });
  }

  // ─── Doctor Category Assignment ──────────────────────────────────────

  async getDoctorCategories(doctorId: string) {
    const rows = await prisma.$queryRaw(
      `SELECT dc.*, c.name as "categoryName", c.color
       FROM doctor_categories dc
       JOIN categories c ON c.id = dc."categoryId"
       WHERE dc."doctorId" = $1`,
      doctorId,
    );
    return rows;
  }

  async assignCategoryToDoctor(doctorId: string, categoryId: string, isPrimary = false) {
    const cat = await prisma.category.findFirst({ where: { id: categoryId } });
    if (!cat) throw AppError.notFound('Category');
    const existing = await prisma.doctorCategory.findFirst({ where: { doctorId, categoryId } });
    if (existing) return existing;
    return prisma.doctorCategory.create({ data: { doctorId, categoryId, isPrimary } });
  }

  async removeCategoryFromDoctor(doctorId: string, categoryId: string) {
    const existing = await prisma.doctorCategory.findFirst({ where: { doctorId, categoryId } });
    if (!existing) throw AppError.notFound('DoctorCategory');
    return prisma.doctorCategory.delete({ where: { id: (existing as any).id } });
  }

  // ─── Audit Logs ──────────────────────────────────────────────────────

  async getAuditLogs(page = 1, limit = 50) {
    const { skip, take } = buildPagination({ page, limit });
    const [data, total] = await Promise.all([
      prisma.auditLog.findMany({
        skip, take, orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { name: true, phone: true } },
          admin: { select: { name: true, email: true } },
        },
      }),
      prisma.auditLog.count(),
    ]);
    return buildPaginatedResult(data, total, page, limit);
  }

  // ─── Review Moderation ────────────────────────────────────────────────

  async moderateReview(reviewId: string, isVisible: boolean, adminId: string) {
    const review = await prisma.review.update({
      where: { id: reviewId },
      data: { isVisible, moderatedAt: new Date(), moderatedBy: adminId },
    });

    const agg = await prisma.review.aggregate({
      where: { doctorId: review.doctorId, isVisible: true, deletedAt: null },
      _avg: { rating: true },
      _count: true,
    });

    await prisma.doctor.update({
      where: { id: review.doctorId },
      data: { averageRating: agg._avg.rating ?? 0, totalReviews: agg._count },
    });

    return review;
  }

  private startOfDay(): Date {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d;
  }

  private endOfDay(): Date {
    const d = new Date();
    d.setHours(23, 59, 59, 999);
    return d;
  }
}
