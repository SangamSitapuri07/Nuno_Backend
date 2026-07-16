import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth.middleware';
import reportsService from './reports.service';
import { sendSuccess, sendError } from '../utils/response';
import { HTTP_STATUS, ERROR_CODES } from '../utils/constants';
import asyncHandler from '../utils/asyncHandler';

const router = Router();

router.post(
  '/reports',
  authMiddleware,
  asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const { playerId, reason, matchId } = req.body;

    if (!playerId || !reason) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        'Player ID and reason are required.',
        HTTP_STATUS.BAD_REQUEST
      );
      return;
    }

    await reportsService.reportPlayer(userId, playerId, reason, matchId);
    sendSuccess(res, { message: 'Report submitted.' }, HTTP_STATUS.CREATED);
  })
);

router.post(
  '/block',
  authMiddleware,
  asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const { playerId } = req.body;

    if (!playerId) {
      sendError(res, ERROR_CODES.VALIDATION_ERROR, 'Player ID required.', HTTP_STATUS.BAD_REQUEST);
      return;
    }

    await reportsService.blockPlayer(userId, playerId);
    sendSuccess(res, { message: 'Player blocked.' });
  })
);

router.delete(
  '/block/:playerId',
  authMiddleware,
  asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const playerId = req.params.playerId as string;

    await reportsService.unblockPlayer(userId, playerId);
    sendSuccess(res, { message: 'Player unblocked.' });
  })
);

router.get(
  '/block',
  authMiddleware,
  asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const blocked = await reportsService.getBlockedPlayers(userId);
    sendSuccess(res, blocked);
  })
);

export default router;