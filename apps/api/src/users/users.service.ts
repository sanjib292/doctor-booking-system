import { prisma } from '../config/database';
import { AppError } from '../common/errors/AppError';

export class UsersService {
  async getProfile(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId, deletedAt: null },
      select: {
        id: true,
        name: true,
        phone: true,
        email: true,
        gender: true,
        age: true,
        avatarUrl: true,
        role: true,
        createdAt: true,
      },
    });
    if (!user) throw AppError.notFound('User');
    return user;
  }

  async updateProfile(
    userId: string,
    data: Partial<{ name: string; email: string; gender: string; age: number; avatarUrl: string; fcmToken: string }>,
  ) {
    return prisma.user.update({
      where: { id: userId },
      data,
      select: {
        id: true, name: true, phone: true, email: true, gender: true, age: true, avatarUrl: true, role: true,
      },
    });
  }

  async updateLocation(userId: string, lat: number, lng: number) {
    await prisma.user.update({
      where: { id: userId },
      data: { lastKnownLat: lat, lastKnownLng: lng, lastLocationAt: new Date() },
    });
  }

  async getFavorites(userId: string) {
    const favorites = await prisma.favorite.findMany({
      where: { userId },
      include: {
        user: false,
      },
    });

    const doctorIds = favorites.map((f) => f.doctorId);
    const doctors = await prisma.doctor.findMany({
      where: { id: { in: doctorIds }, isActive: true, deletedAt: null },
      select: {
        id: true,
        name: true,
        avatarUrl: true,
        averageRating: true,
        totalReviews: true,
        experienceYears: true,
        categories: { select: { category: { select: { name: true } }, isPrimary: true }, take: 1 },
        clinics: {
          where: { isActive: true },
          select: { consultationFee: true, clinic: { select: { city: true } } },
          take: 1,
        },
      },
    });

    return doctors;
  }

  async toggleFavorite(userId: string, doctorId: string): Promise<{ isFavorite: boolean }> {
    const existing = await prisma.favorite.findUnique({
      where: { userId_doctorId: { userId, doctorId } },
    });

    if (existing) {
      await prisma.favorite.delete({ where: { userId_doctorId: { userId, doctorId } } });
      return { isFavorite: false };
    }

    await prisma.favorite.create({ data: { userId, doctorId } });
    return { isFavorite: true };
  }

  async getNotifications(userId: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const [data, total, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where: { userId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.notification.count({ where: { userId } }),
      prisma.notification.count({ where: { userId, isRead: false } }),
    ]);

    return { data, total, page, limit, unreadCount };
  }

  async markNotificationsRead(userId: string, notificationIds?: string[]) {
    const where = notificationIds?.length
      ? { userId, id: { in: notificationIds } }
      : { userId, isRead: false };

    await prisma.notification.updateMany({
      where,
      data: { isRead: true, readAt: new Date() },
    });
  }

  async deleteAccount(userId: string) {
    await prisma.user.update({
      where: { id: userId },
      data: { deletedAt: new Date(), isActive: false, fcmToken: null },
    });

    // Revoke all refresh tokens
    await prisma.refreshToken.updateMany({
      where: { userId },
      data: { isRevoked: true },
    });
  }
}
