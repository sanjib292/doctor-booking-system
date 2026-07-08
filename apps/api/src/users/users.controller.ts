import { Request, Response } from 'express';
import { UsersService } from './users.service';
import { sendSuccess } from '../common/utils/response';
import { asyncHandler } from '../common/middleware/asyncHandler';

const service = new UsersService();

export const getProfile = asyncHandler(async (req: Request, res: Response) => {
  const user = await service.getProfile(req.user!.id);
  sendSuccess(res, user);
});

export const updateProfile = asyncHandler(async (req: Request, res: Response) => {
  const user = await service.updateProfile(req.user!.id, req.body);
  sendSuccess(res, user, 'Profile updated');
});

export const updateLocation = asyncHandler(async (req: Request, res: Response) => {
  const { lat, lng } = req.body;
  await service.updateLocation(req.user!.id, lat, lng);
  sendSuccess(res, null, 'Location updated');
});

export const getFavorites = asyncHandler(async (req: Request, res: Response) => {
  const favorites = await service.getFavorites(req.user!.id);
  sendSuccess(res, favorites);
});

export const toggleFavorite = asyncHandler(async (req: Request, res: Response) => {
  const result = await service.toggleFavorite(req.user!.id, req.params.doctorId);
  sendSuccess(res, result);
});

export const getNotifications = asyncHandler(async (req: Request, res: Response) => {
  const result = await service.getNotifications(
    req.user!.id,
    Number(req.query.page ?? 1),
    Number(req.query.limit ?? 20),
  );
  sendSuccess(res, result.data, undefined, 200, {
    total: result.total,
    page: result.page,
    limit: result.limit,
    unreadCount: result.unreadCount,
  });
});

export const markNotificationsRead = asyncHandler(async (req: Request, res: Response) => {
  await service.markNotificationsRead(req.user!.id, req.body.ids);
  sendSuccess(res, null, 'Notifications marked as read');
});

export const deleteAccount = asyncHandler(async (req: Request, res: Response) => {
  await service.deleteAccount(req.user!.id);
  sendSuccess(res, null, 'Account deleted');
});
