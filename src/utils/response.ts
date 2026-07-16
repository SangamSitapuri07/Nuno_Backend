import { Response } from 'express';
import { HTTP_STATUS } from './constants';

export const sendSuccess = (
  res: Response,
  data: object | null = null,
  statusCode: number = HTTP_STATUS.OK
) => {
  return res.status(statusCode).json({
    success: true,
    data,
  });
};

export const sendError = (
  res: Response,
  code: string,
  message: string,
  statusCode: number = HTTP_STATUS.INTERNAL_ERROR
) => {
  return res.status(statusCode).json({
    success: false,
    error: {
      code,
      message,
    },
  });
};