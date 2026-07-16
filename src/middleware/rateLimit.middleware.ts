import rateLimit from 'express-rate-limit';
import { sendError } from '../utils/response';
import { HTTP_STATUS, ERROR_CODES } from '../utils/constants';

export const authRateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    sendError(
      res,
      ERROR_CODES.RATE_LIMIT,
      'Too many requests. Please try again later.',
      HTTP_STATUS.TOO_MANY_REQUESTS
    );
  },
});

export const apiRateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    sendError(
      res,
      ERROR_CODES.RATE_LIMIT,
      'Too many requests. Please try again later.',
      HTTP_STATUS.TOO_MANY_REQUESTS
    );
  },
});