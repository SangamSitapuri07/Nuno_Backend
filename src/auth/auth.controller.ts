import { Request, Response } from 'express';
import authService from './auth.service';
import { registerSchema, loginSchema, refreshTokenSchema } from './auth.validation';
import { sendSuccess, sendError } from '../utils/response';
import { HTTP_STATUS, ERROR_CODES } from '../utils/constants';
import asyncHandler from '../utils/asyncHandler';

export class AuthController {

  // ─────────────────────────────────────────
  // REGISTER
  // ─────────────────────────────────────────

  register = asyncHandler(async (req: Request, res: Response) => {
    const validation = registerSchema.safeParse(req.body);

    if (!validation.success) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        validation.error.issues[0].message,
        HTTP_STATUS.UNPROCESSABLE
      );
      return;
    }

    await authService.register(validation.data);

    sendSuccess(
      res,
      { message: 'Account created successfully.' },
      HTTP_STATUS.CREATED
    );
  });

  // ─────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────

  login = asyncHandler(async (req: Request, res: Response) => {
    const validation = loginSchema.safeParse(req.body);

    if (!validation.success) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        validation.error.issues[0].message,
        HTTP_STATUS.UNPROCESSABLE
      );
      return;
    }

    const tokens = await authService.login(validation.data);

    sendSuccess(res, tokens, HTTP_STATUS.OK);
  });

  // ─────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────

  logout = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;

    if (!userId) {
      sendError(
        res,
        ERROR_CODES.AUTH_FAILED,
        'Unauthorized.',
        HTTP_STATUS.UNAUTHORIZED
      );
      return;
    }

    await authService.logout(userId);

    sendSuccess(res, { message: 'Logged out successfully.' });
  });

  // ─────────────────────────────────────────
  // REFRESH TOKEN
  // ─────────────────────────────────────────

  refresh = asyncHandler(async (req: Request, res: Response) => {
    const validation = refreshTokenSchema.safeParse(req.body);

    if (!validation.success) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        validation.error.issues[0].message,
        HTTP_STATUS.UNPROCESSABLE
      );
      return;
    }

    const tokens = await authService.refreshToken(validation.data.refreshToken);

    sendSuccess(res, tokens, HTTP_STATUS.OK);
  });
}

export default new AuthController();