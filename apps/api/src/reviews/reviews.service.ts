import { prisma } from '../config/database';
import { AppError } from '../common/errors/AppError';
import { AppointmentStatus } from '@prisma/client';

export class ReviewsService {
  async createReview(
    patientId: string,
    appointmentId: string,
    rating: number,
    comment?: string,
  ) {
    const appointment = await prisma.appointment.findFirst({
      where: { id: appointmentId, patientId, status: AppointmentStatus.COMPLETED },
    });

    if (!appointment) {
      throw AppError.badRequest('You can only review completed appointments', 'REVIEW_NOT_ELIGIBLE');
    }

    const existing = await prisma.review.findUnique({ where: { appointmentId } });
    if (existing) throw AppError.conflict('You have already reviewed this appointment');

    const review = await prisma.review.create({
      data: {
        appointmentId,
        patientId,
        doctorId: appointment.doctorId,
        rating,
        comment,
      },
    });

    // Update doctor's average rating
    await this.recalculateDoctorRating(appointment.doctorId);

    return review;
  }

  async getDoctorReviews(doctorId: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      prisma.review.findMany({
        where: { doctorId, isVisible: true, deletedAt: null },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          rating: true,
          comment: true,
          createdAt: true,
          patient: { select: { name: true, avatarUrl: true } },
        },
      }),
      prisma.review.count({ where: { doctorId, isVisible: true, deletedAt: null } }),
    ]);

    const ratingDistribution = await prisma.review.groupBy({
      by: ['rating'],
      where: { doctorId, isVisible: true },
      _count: true,
    });

    return { data, total, page, limit, ratingDistribution };
  }

  private async recalculateDoctorRating(doctorId: string) {
    const result = await prisma.review.aggregate({
      where: { doctorId, isVisible: true, deletedAt: null },
      _avg: { rating: true },
      _count: true,
    });

    await prisma.doctor.update({
      where: { id: doctorId },
      data: {
        averageRating: result._avg.rating ?? 0,
        totalReviews: result._count,
      },
    });
  }
}
