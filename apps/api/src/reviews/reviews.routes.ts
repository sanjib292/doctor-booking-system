import { Router } from 'express';
import { asyncHandler } from '../common/middleware/asyncHandler';
import { authenticate, authorize } from '../common/middleware/auth.middleware';
import { ReviewsService } from './reviews.service';
import { sendSuccess, sendCreated } from '../common/utils/response';
import { Request, Response } from 'express';
import { z } from 'zod';
import { validate } from '../common/middleware/validate';

const router = Router();
const service = new ReviewsService();

const createReviewSchema = z.object({
  appointmentId: z.string().uuid(),
  rating: z.number().int().min(1).max(5),
  comment: z.string().max(1000).optional(),
});

router.post(
  '/',
  authenticate,
  authorize('PATIENT'),
  validate(createReviewSchema),
  asyncHandler(async (req: Request, res: Response) => {
    const review = await service.createReview(req.user!.id, req.body.appointmentId, req.body.rating, req.body.comment);
    sendCreated(res, review, 'Review submitted');
  }),
);

router.get(
  '/doctor/:doctorId',
  asyncHandler(async (req: Request, res: Response) => {
    const result = await service.getDoctorReviews(
      req.params.doctorId,
      Number(req.query.page ?? 1),
      Number(req.query.limit ?? 20),
    );
    sendSuccess(res, result.data, undefined, 200, { total: result.total, ratingDistribution: result.ratingDistribution });
  }),
);

export default router;
