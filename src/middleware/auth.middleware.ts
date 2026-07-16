import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import config from '../config/config';
import prisma from '../config/database';
import { sendError } from '../utils/response';
import { HTTP_STATUS, ERROR_CODES } from '../utils/constants';
import { TokenPayload } from '../auth/auth.types';
import logger from '../utils/logger';

export const authMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      sendError(
        res,
        ERROR_CODES.AUTH_FAILED,
        'Authorization token is required.',
        HTTP_STATUS.UNAUTHORIZED
      );
      return;
    }

    const token = authHeader.split(' ')[1];

    const payload = jwt.verify(token, config.jwt.accessSecret) as TokenPayload;

    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: {
        id: true,
        username: true,
        accountStatus: true,
      },
    });

    if (!user) {
      sendError(
        res,
        ERROR_CODES.AUTH_FAILED,
        'User not found.',
        HTTP_STATUS.UNAUTHORIZED
      );
      return;
    }

    if (user.accountStatus !== 'ACTIVE') {
      sendError(
        res,
        ERROR_CODES.AUTH_FAILED,
        'Account is not active.',
        HTTP_STATUS.FORBIDDEN
      );
      return;
    }

    (req as any).user = payload;

    next();

  } catch (error: any) {
    if (error.name === 'TokenExpiredError') {
      sendError(
        res,
        ERROR_CODES.AUTH_FAILED,
        'Token has expired.',
        HTTP_STATUS.UNAUTHORIZED
      );
      return;
    }

    sendError(
      res,
      ERROR_CODES.AUTH_FAILED,
      'Invalid token.',
      HTTP_STATUS.UNAUTHORIZED
    );
  }
};