import { Prisma } from '@prisma/client';
import { prisma } from '../config/database';
import { AppError } from '../common/errors/AppError';
import { buildPagination, buildPaginatedResult, PaginationQuery } from '../common/types/pagination';

export interface DoctorSearchFilters extends PaginationQuery {
  lat?: number;
  lng?: number;
  radiusKm?: number;
  categoryId?: string;
  speciality?: string;
  minRating?: number;
  maxFee?: number;
  minFee?: number;
  gender?: string;
  minExperience?: number;
  search?: string;
  city?: string;
  sortBy?: 'distance' | 'rating' | 'fee' | 'experience';
  sortOrder?: 'asc' | 'desc';
}

export class DoctorsService {
  async searchDoctors(filters: DoctorSearchFilters) {
    const { skip, take, page, limit } = buildPagination(filters);

    // Build raw WHERE clause parts that the shim can handle (flat fields only)
    const where: any = {
      isActive: true,
      deletedAt: null,
      verificationStatus: 'VERIFIED',
    };

    if (filters.search) {
      where.OR = [
        { name: { contains: filters.search, mode: 'insensitive' } },
        { about: { contains: filters.search, mode: 'insensitive' } },
      ];
    }
    if (filters.gender) where.gender = filters.gender;
    if (filters.minRating) where.averageRating = { gte: filters.minRating };
    if (filters.minExperience) where.experienceYears = { gte: filters.minExperience };

    // Fetch flat doctor rows (shim ignores select/include)
    const [flatDoctors, total] = await Promise.all([
      prisma.doctor.findMany({ where, skip, take, orderBy: this.buildOrderBy(filters.sortBy, filters.sortOrder) }),
      prisma.doctor.count({ where }),
    ]);

    if (flatDoctors.length === 0) return buildPaginatedResult([], 0, page, limit);

    const doctorIds = flatDoctors.map((d: any) => d.id);

    // Fetch clinic associations and category associations in parallel
    const [clinicRows, categoryRows] = await Promise.all([
      prisma.$queryRaw(
        `SELECT dc.id, dc."doctorId", dc."consultationFee", dc."isPrimary",
                c.id as "clinicId", c.name as "clinicName", c.city, c.lat, c.lng, c."addressLine1"
         FROM doctor_clinics dc
         JOIN clinics c ON c.id = dc."clinicId"
         WHERE dc."doctorId" = ANY($1) AND dc."isActive" = true`,
        doctorIds,
      ),
      prisma.$queryRaw(
        `SELECT dcat."doctorId", dcat."isPrimary",
                cat.id as "categoryId", cat.name as "categoryName", cat."iconUrl"
         FROM doctor_categories dcat
         JOIN categories cat ON cat.id = dcat."categoryId"
         WHERE dcat."doctorId" = ANY($1)`,
        doctorIds,
      ),
    ]);

    // Group by doctorId
    const clinicsByDoctor = new Map<string, any[]>();
    for (const row of clinicRows as any[]) {
      if (!clinicsByDoctor.has(row.doctorId)) clinicsByDoctor.set(row.doctorId, []);
      clinicsByDoctor.get(row.doctorId)!.push({
        id: row.id,
        consultationFee: row.consultationFee,
        isPrimary: row.isPrimary,
        clinic: { id: row.clinicId, name: row.clinicName, city: row.city, lat: row.lat, lng: row.lng, addressLine1: row.addressLine1 },
      });
    }
    const categoriesByDoctor = new Map<string, any[]>();
    for (const row of categoryRows as any[]) {
      if (!categoriesByDoctor.has(row.doctorId)) categoriesByDoctor.set(row.doctorId, []);
      categoriesByDoctor.get(row.doctorId)!.push({
        isPrimary: row.isPrimary,
        category: { id: row.categoryId, name: row.categoryName, iconUrl: row.iconUrl },
      });
    }

    // Filter by categoryId / city / fee if supplied (post-join)
    let doctors = flatDoctors.map((doc: any) => {
      const { passwordHash, ...safe } = doc;
      return {
        ...safe,
        clinics: clinicsByDoctor.get(doc.id) ?? [],
        categories: categoriesByDoctor.get(doc.id) ?? [],
      };
    });

    if (filters.categoryId) {
      doctors = doctors.filter((d: any) =>
        d.categories.some((c: any) => c.category.id === filters.categoryId),
      );
    }
    if (filters.city) {
      const cityLower = filters.city.toLowerCase();
      doctors = doctors.filter((d: any) =>
        d.clinics.some((c: any) => c.clinic.city?.toLowerCase().includes(cityLower)),
      );
    }
    if (filters.minFee || filters.maxFee) {
      doctors = doctors.filter((d: any) =>
        d.clinics.some((c: any) => {
          const fee = c.consultationFee ?? 0;
          return (!filters.minFee || fee >= filters.minFee) && (!filters.maxFee || fee <= filters.maxFee);
        }),
      );
    }

    // Distance enrichment + sort
    const enriched = doctors.map((doc: any) => {
      let distance: number | null = null;
      const primaryClinic = doc.clinics.find((c: any) => c.isPrimary) ?? doc.clinics[0];
      if (filters.lat && filters.lng && primaryClinic?.clinic?.lat != null && primaryClinic?.clinic?.lng != null) {
        distance = this.haversineKm(filters.lat, filters.lng, primaryClinic.clinic.lat, primaryClinic.clinic.lng);
      }
      return { ...doc, distance };
    });

    if (filters.sortBy === 'distance' && filters.lat && filters.lng) {
      enriched.sort((a: any, b: any) => (a.distance ?? Infinity) - (b.distance ?? Infinity));
    }

    return buildPaginatedResult(enriched, total, page, limit);
  }

  async getDoctorById(doctorId: string, userId?: string) {
    const doctor = await prisma.doctor.findFirst({
      where: { id: doctorId, isActive: true, deletedAt: null },
    });
    if (!doctor) throw AppError.notFound('Doctor');

    const [clinicRows, categoryRows, availabilities, reviews] = await Promise.all([
      prisma.$queryRaw(
        `SELECT dc.*, c.id as "clinicId", c.name as "clinicName", c.city, c.lat, c.lng,
                c."addressLine1", c."addressLine2", c.pincode, c.phone as "clinicPhone", c."isActive" as "clinicActive"
         FROM doctor_clinics dc
         JOIN clinics c ON c.id = dc."clinicId"
         WHERE dc."doctorId" = $1 AND dc."isActive" = true`,
        doctorId,
      ),
      prisma.$queryRaw(
        `SELECT dcat."isPrimary", cat.*
         FROM doctor_categories dcat
         JOIN categories cat ON cat.id = dcat."categoryId"
         WHERE dcat."doctorId" = $1`,
        doctorId,
      ),
      prisma.doctorAvailability.findMany({ where: { doctorId, isActive: true } }),
      prisma.$queryRaw(
        `SELECT r.id, r.rating, r.comment, r."createdAt",
                u.name as "patientName", u."avatarUrl" as "patientAvatar"
         FROM reviews r
         JOIN users u ON u.id = r."patientId"
         WHERE r."doctorId" = $1 AND r."isVisible" = true AND r."deletedAt" IS NULL
         ORDER BY r."createdAt" DESC LIMIT 5`,
        doctorId,
      ),
    ]);

    const clinics = (clinicRows as any[]).map((row) => ({
      id: row.id,
      consultationFee: row.consultationFee,
      isPrimary: row.isPrimary,
      isActive: row.isActive,
      clinic: {
        id: row.clinicId, name: row.clinicName, city: row.city, lat: row.lat, lng: row.lng,
        addressLine1: row.addressLine1, addressLine2: row.addressLine2, pincode: row.pincode,
        phone: row.clinicPhone, isActive: row.clinicActive,
      },
    }));

    const categories = (categoryRows as any[]).map((row) => ({
      isPrimary: row.isPrimary,
      category: { id: row.id, name: row.name, iconUrl: row.iconUrl },
    }));

    const formattedReviews = (reviews as any[]).map((r) => ({
      id: r.id, rating: r.rating, comment: r.comment, createdAt: r.createdAt,
      patient: { name: r.patientName, avatarUrl: r.patientAvatar },
    }));

    let isFavorite = false;
    if (userId) {
      const fav = await prisma.favorite.findFirst({ where: { userId, doctorId } });
      isFavorite = !!fav;
    }

    const { passwordHash, ...safe } = doctor as any;
    return { ...safe, clinics, categories, availabilities, reviews: formattedReviews, isFavorite };
  }

  async getDoctorProfile(doctorId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { id: doctorId } });
    if (!doctor) throw AppError.notFound('Doctor');

    const today = new Date().toISOString().split('T')[0];

    const [clinicRows, categoryRows, availabilities, vacations, blockedDates] = await Promise.all([
      prisma.$queryRaw(
        `SELECT dc.*, c.id as "clinicId", c.name as "clinicName", c.city, c.lat, c.lng,
                c."addressLine1", c."addressLine2", c.pincode, c.phone as "clinicPhone"
         FROM doctor_clinics dc
         JOIN clinics c ON c.id = dc."clinicId"
         WHERE dc."doctorId" = $1`,
        doctorId,
      ),
      prisma.$queryRaw(
        `SELECT dcat."isPrimary", cat.*
         FROM doctor_categories dcat
         JOIN categories cat ON cat.id = dcat."categoryId"
         WHERE dcat."doctorId" = $1`,
        doctorId,
      ),
      prisma.doctorAvailability.findMany({ where: { doctorId } }),
      prisma.$queryRaw(
        `SELECT * FROM doctor_vacations WHERE "doctorId" = $1 AND "endDate" >= $2`,
        doctorId, today,
      ),
      prisma.$queryRaw(
        `SELECT * FROM blocked_dates WHERE "doctorId" = $1 AND date >= $2`,
        doctorId, today,
      ),
    ]);

    const clinics = (clinicRows as any[]).map((row) => ({
      id: row.id, consultationFee: row.consultationFee, isPrimary: row.isPrimary, isActive: row.isActive,
      clinic: { id: row.clinicId, name: row.clinicName, city: row.city, lat: row.lat, lng: row.lng,
        addressLine1: row.addressLine1, addressLine2: row.addressLine2, pincode: row.pincode, phone: row.clinicPhone },
    }));

    const categories = (categoryRows as any[]).map((row) => ({
      isPrimary: row.isPrimary,
      category: { id: row.id, name: row.name, iconUrl: row.iconUrl },
    }));

    const { passwordHash, ...safe } = doctor as any;
    return { ...safe, clinics, categories, availabilities, vacations, blockedDates };
  }

  async updateDoctorProfile(
    doctorId: string,
    data: Partial<{ about: string; languages: string[]; avatarUrl: string; fcmToken: string }>,
  ) {
    const doctor = await prisma.doctor.update({
      where: { id: doctorId },
      data,
    });
    const { passwordHash, ...safe } = doctor;
    return safe;
  }

  async getCategories() {
    return prisma.category.findMany({
      where: { isActive: true, deletedAt: null },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  // Phase 2: Get working days for a doctor (for patient-facing calendar)
  async getDoctorAvailability(doctorId: string) {
    const availabilities = await prisma.doctorAvailability.findMany({
      where: { doctorId, isActive: true },
      select: { dayOfWeek: true, startTime: true, endTime: true, slotDurationMinutes: true },
      orderBy: { dayOfWeek: 'asc' },
    });
    return availabilities;
  }

  private buildOrderBy(
    sortBy?: string,
    order: 'asc' | 'desc' = 'desc',
  ): Prisma.DoctorOrderByWithRelationInput {
    switch (sortBy) {
      case 'rating':
        return { averageRating: order };
      case 'experience':
        return { experienceYears: order };
      default:
        return { averageRating: 'desc' };
    }
  }

  private haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 6371;
    const dLat = this.toRad(lat2 - lat1);
    const dLon = this.toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(this.toRad(lat1)) * Math.cos(this.toRad(lat2)) * Math.sin(dLon / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  private toRad(deg: number): number {
    return (deg * Math.PI) / 180;
  }
}
