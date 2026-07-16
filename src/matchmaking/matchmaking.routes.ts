import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth.middleware';
import matchmakingService from './matchmaking.service';
import { sendSuccess, sendError } from '../utils/response';
import { HTTP_STATUS } from '../utils/constants';
import asyncHandler from '../utils/asyncHandler';

const router = Router();

// Get queue status
router.get(
  '/queue/status',
  authMiddleware,
  asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const status = await matchmakingService.getQueueStatus(userId);
    sendSuccess(res, { inQueue: !!status, queueKey: status });
  })
);

export default router;