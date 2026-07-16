import { Request, Response } from 'express';
import userService from './user.service';
import { updateProfileSchema, updateSettingsSchema } from './user.validation';
import { sendSuccess, sendError } from '../utils/response';
import { HTTP_STATUS, ERROR_CODES } from '../utils/constants';
import asyncHandler from '../utils/asyncHandler';

export class UserController {

  // ─────────────────────────────────────────
  // GET PROFILE
  // ─────────────────────────────────────────

  getProfile = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const profile = await userService.getProfile(userId);
    sendSuccess(res, profile);
  });

  // ─────────────────────────────────────────
  // UPDATE PROFILE
  // ─────────────────────────────────────────

  updateProfile = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;

    const validation = updateProfileSchema.safeParse(req.body);

    if (!validation.success) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        validation.error.issues[0].message,
        HTTP_STATUS.UNPROCESSABLE
      );
      return;
    }

    const profile = await userService.updateProfile(userId, validation.data);
    sendSuccess(res, profile);
  });

  // ─────────────────────────────────────────
  // GET SETTINGS
  // ─────────────────────────────────────────

  getSettings = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const settings = await userService.getSettings(userId);
    sendSuccess(res, settings);
  });

  // ─────────────────────────────────────────
  // UPDATE SETTINGS
  // ─────────────────────────────────────────

  updateSettings = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;

    const validation = updateSettingsSchema.safeParse(req.body);

    if (!validation.success) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        validation.error.issues[0].message,
        HTTP_STATUS.UNPROCESSABLE
      );
      return;
    }

    const settings = await userService.updateSettings(userId, validation.data);
    sendSuccess(res, settings);
  });

  // ─────────────────────────────────────────
  // GET STATISTICS
  // ─────────────────────────────────────────

  getStatistics = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const statistics = await userService.getStatistics(userId);
    sendSuccess(res, statistics);
  });

  // ─────────────────────────────────────────
  // GET MATCH HISTORY
  // ─────────────────────────────────────────

  getMatchHistory = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const history = await userService.getMatchHistory(userId);
    sendSuccess(res, history);
  });
}

export default new UserController();