import { Request, Response, NextFunction } from 'express';
import { sendError } from '../utils/response';
import { HTTP_STATUS } from '../utils/constants';
import logger from '../utils/logger';

export const errorMiddleware = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  logger.error('Unhandled error', {
    message: err.message,
    stack: err.stack,
    code: err.code,
    status: err.status,
  });

  if (err.code && err.status) {
    sendError(res, err.code, err.message, err.status);
    return;
  }

  sendError(
    res,
    'SERVER_ERROR',
    'An internal server error occurred.',
    HTTP_STATUS.INTERNAL_ERROR
  );
};