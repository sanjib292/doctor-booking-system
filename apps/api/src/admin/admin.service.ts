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
      prisma.doctor.count({ where: { verificationStatus: VerificationStatus.PENDING } }),
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

    return updated;
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

  // ─── Category Management ─────────────────────────────────────────────

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
      where: { doctorId: review.doctorId, isVisible: true },
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
