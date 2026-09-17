import { Request, Response } from 'express';
import { DoctorsService } from './doctors.service';
import { sendSuccess } from '../common/utils/response';
import { asyncHandler } from '../common/middleware/asyncHandler';

const service = new DoctorsService();

export const searchDoctors = asyncHandler(async (req: Request, res: Response) => {
  const filters = {
    lat: req.query.lat ? Number(req.query.lat) : undefined,
    lng: req.query.lng ? Number(req.query.lng) : undefined,
    radiusKm: req.query.radiusKm ? Number(req.query.radiusKm) : 10,
    categoryId: req.query.categoryId as string | undefined,
    minRating: req.query.minRating ? Number(req.query.minRating) : undefined,
    maxFee: req.query.maxFee ? Number(req.query.maxFee) : undefined,
    minFee: req.query.minFee ? Number(req.query.minFee) : undefined,
    gender: req.query.gender as string | undefined,
    minExperience: req.query.minExperience ? Number(req.query.minExperience) : undefined,
    search: req.query.search as string | undefined,
    city: req.query.city as string | undefined,
    sortBy: req.query.sortBy as any,
    sortOrder: (req.query.sortOrder as 'asc' | 'desc') ?? 'desc',
    page: req.query.page ? Number(req.query.page) : 1,
    limit: req.query.limit ? Number(req.query.limit) : 20,
  };

  const result = await service.searchDoctors(filters);
  sendSuccess(res, result.data, undefined, 200, result.meta);
});

export const getDoctorById = asyncHandler(async (req: Request, res: Response) => {
  const doctor = await service.getDoctorById(req.params.id, req.user?.id);
  sendSuccess(res, doctor);
});

export const getDoctorProfile = asyncHandler(async (req: Request, res: Response) => {
  const profile = await service.getDoctorProfile(req.user!.id);
  sendSuccess(res, profile);
});

export const updateDoctorProfile = asyncHandler(async (req: Request, res: Response) => {
  const { about, languages, avatarUrl, fcmToken, phone } = req.body;
  const updated = await service.updateDoctorProfile(req.user!.id, { about, languages, avatarUrl, fcmToken, phone });
  sendSuccess(res, updated, 'Profile updated');
});

export const getCategories = asyncHandler(async (req: Request, res: Response) => {
  const categories = await service.getCategories();
  sendSuccess(res, categories);
});

// Phase 2: Availability days
export const getDoctorAvailability = asyncHandler(async (req: Request, res: Response) => {
  const availability = await service.getDoctorAvailability(req.params.id);
  sendSuccess(res, availability);
});
