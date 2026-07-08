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

    const where: Prisma.DoctorWhereInput = {
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

    if (filters.gender) {
      where.gender = filters.gender as any;
    }

    if (filters.minRating) {
      where.averageRating = { gte: filters.minRating };
    }

    if (filters.minExperience) {
      where.experienceYears = { gte: filters.minExperience };
    }

    if (filters.categoryId) {
      where.categories = { some: { categoryId: filters.categoryId } };
    }

    if (filters.city) {
      where.clinics = {
        some: { clinic: { city: { contains: filters.city, mode: 'insensitive' }, isActive: true } },
      };
    }

    if (filters.maxFee || filters.minFee) {
      where.clinics = {
        ...((where.clinics as any) ?? {}),
        some: {
          ...(((where.clinics as any)?.some) ?? {}),
          consultationFee: {
            ...(filters.minFee ? { gte: filters.minFee } : {}),
            ...(filters.maxFee ? { lte: filters.maxFee } : {}),
          },
        },
      };
    }

    const [doctors, total] = await Promise.all([
      prisma.doctor.findMany({
        where,
        skip,
        take,
        select: {
          id: true,
          name: true,
          avatarUrl: true,
          qualifications: true,
          experienceYears: true,
          averageRating: true,
          totalReviews: true,
          languages: true,
          verificationStatus: true,
          categories: {
            select: { category: { select: { id: true, name: true, iconUrl: true } }, isPrimary: true },
          },
          clinics: {
            where: { isActive: true },
            select: {
              id: true,
              consultationFee: true,
              isPrimary: true,
              clinic: {
                select: { id: true, name: true, city: true, lat: true, lng: true, addressLine1: true },
              },
            },
            take: 1,
          },
        },
        orderBy: this.buildOrderBy(filters.sortBy, filters.sortOrder),
      }),
      prisma.doctor.count({ where }),
    ]);

    const enriched = doctors.map((doc) => {
      let distance: number | null = null;
      if (filters.lat && filters.lng && doc.clinics[0]?.clinic) {
        distance = this.haversineKm(
          filters.lat,
          filters.lng,
          doc.clinics[0].clinic.lat,
          doc.clinics[0].clinic.lng,
        );
      }
      return { ...doc, distance };
    });

    if (filters.sortBy === 'distance' && filters.lat && filters.lng) {
      enriched.sort((a, b) => (a.distance ?? Infinity) - (b.distance ?? Infinity));
    }

    return buildPaginatedResult(enriched, total, page, limit);
  }

  async getDoctorById(doctorId: string, userId?: string) {
    const doctor = await prisma.doctor.findFirst({
      where: { id: doctorId, isActive: true, deletedAt: null },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        gender: true,
        avatarUrl: true,
        about: true,
        qualifications: true,
        experienceYears: true,
        languages: true,
        verificationStatus: true,
        averageRating: true,
        totalReviews: true,
        createdAt: true,
        categories: {
          select: { category: true, isPrimary: true },
        },
        clinics: {
          where: { isActive: true },
          include: {
            clinic: true,
          },
        },
        availabilities: {
          where: { isActive: true },
        },
        reviews: {
          where: { isVisible: true, deletedAt: null },
          take: 5,
          orderBy: { createdAt: 'desc' },
          select: {
            id: true,
            rating: true,
            comment: true,
            createdAt: true,
            patient: { select: { name: true, avatarUrl: true } },
          },
        },
      },
    });

    if (!doctor) throw AppError.notFound('Doctor');

    let isFavorite = false;
    if (userId) {
      const fav = await prisma.favorite.findUnique({
        where: { userId_doctorId: { userId, doctorId } },
      });
      isFavorite = !!fav;
    }

    return { ...doctor, isFavorite };
  }

  async getDoctorProfile(doctorId: string) {
    const doctor = await prisma.doctor.findUnique({
      where: { id: doctorId },
      include: {
        categories: { include: { category: true } },
        clinics: { include: { clinic: true } },
        availabilities: true,
        vacations: { where: { endDate: { gte: new Date() } } },
        blockedDates: { where: { date: { gte: new Date() } } },
      },
    });

    if (!doctor) throw AppError.notFound('Doctor');
    const { passwordHash, ...safe } = doctor;
    return safe;
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
