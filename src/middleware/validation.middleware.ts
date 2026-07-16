import { Request, Response, NextFunction } from 'express';
import { sendError } from '../utils/response';
import { HTTP_STATUS, ERROR_CODES } from '../utils/constants';

// ─────────────────────────────────────────
// VALIDATE UUID
// ─────────────────────────────────────────

export const validateUUID = (paramName: string) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const value = req.params[paramName];
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

    if (!value || !uuidRegex.test(value)) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        `Invalid ${paramName} format.`,
        HTTP_STATUS.BAD_REQUEST
      );
      return;
    }

    next();
  };
};

// ─────────────────────────────────────────
// VALIDATE REQUIRED FIELDS
// ─────────────────────────────────────────

export const validateRequiredFields = (fields: string[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const missing = fields.filter((field) => {
      return (
        req.body[field] === undefined ||
        req.body[field] === null ||
        req.body[field] === ''
      );
    });

    if (missing.length > 0) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        `Missing required fields: ${missing.join(', ')}`,
        HTTP_STATUS.BAD_REQUEST
      );
      return;
    }

    next();
  };
};