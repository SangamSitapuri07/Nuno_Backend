import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth.middleware';
import roomService from './room.service';
import { sendSuccess, sendError } from '../utils/response';
import { HTTP_STATUS, ERROR_CODES } from '../utils/constants';
import asyncHandler from '../utils/asyncHandler';

const router = Router();

// Get current room
router.get(
  '/room',
  authMiddleware,
  asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const room = await roomService.getPlayerRoom(userId);

    if (!room) {
      sendError(
        res,
        ERROR_CODES.INVALID_ROOM,
        'Not in a room.',
        HTTP_STATUS.NOT_FOUND
      );
      return;
    }

    sendSuccess(res, room);
  })
);

export default router;