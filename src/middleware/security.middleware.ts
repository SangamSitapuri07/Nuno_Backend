import { Request, Response, NextFunction } from 'express';
import { sendError } from '../utils/response';
import { HTTP_STATUS } from '../utils/constants';
import logger from '../utils/logger';

// ─────────────────────────────────────────
// SANITIZE INPUT
// ─────────────────────────────────────────

export const sanitizeInput = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  if (req.body) {
    req.body = sanitizeObject(req.body);
  }
  // req.query is read-only in Express 5
  // Sanitize individual query values instead
  if (req.query) {
    for (const key of Object.keys(req.query)) {
      const value = req.query[key];
      if (typeof value === 'string') {
        (req.query as any)[key] = sanitizeObject(value);
      }
    }
  }
  next();
};

const sanitizeObject = (obj: any): any => {
  if (typeof obj === 'string') {
    return obj
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/javascript:/gi, '')
      .replace(/on\w+\s*=/gi, '')
      .trim();
  }

  // Arrays must stay arrays.
  //
  // The object branch below rebuilds its input as a plain {} literal, so an
  // array arrived at the route as {"0": ..., "1": ...} and every
  // Array.isArray check downstream failed. That silently turned a valid
  // request body into a 400.
  if (Array.isArray(obj)) {
    return obj.map(sanitizeObject);
  }

  // Only plain objects are rebuilt. Dates, Buffers and anything else with a
  // prototype would otherwise be flattened into a bare object and lose both
  // their type and their methods.
  if (typeof obj === 'object' && obj !== null) {
    const proto = Object.getPrototypeOf(obj);
    if (proto !== Object.prototype && proto !== null) return obj;

    const sanitized: any = {};
    for (const key of Object.keys(obj)) {
      // Skip prototype-polluting keys rather than copying them across.
      if (key === '__proto__' || key === 'constructor' || key === 'prototype') {
        continue;
      }
      sanitized[key] = sanitizeObject(obj[key]);
    }
    return sanitized;
  }

  return obj;
};

// ─────────────────────────────────────────
// VALIDATE CONTENT TYPE
// ─────────────────────────────────────────

export const validateContentType = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  if (
    req.method !== 'GET' &&
    req.method !== 'DELETE' &&
    req.headers['content-type'] &&
    !req.headers['content-type'].includes('application/json')
  ) {
    sendError(
      res,
      'INVALID_CONTENT_TYPE',
      'Content-Type must be application/json.',
      HTTP_STATUS.BAD_REQUEST
    );
    return;
  }
  next();
};

// ─────────────────────────────────────────
// SECURITY LOGGER
// ─────────────────────────────────────────

export const securityLogger = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const sensitiveRoutes = [
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
  ];

  const isSensitive = sensitiveRoutes.some((route) =>
    req.path.includes(route)
  );

  if (isSensitive) {
    logger.info('Sensitive route accessed', {
      method: req.method,
      path: req.path,
      ip: req.ip,
      userAgent: req.headers['user-agent'],
    });
  }

  next();
};

// ─────────────────────────────────────────
// PREVENT PARAMETER POLLUTION
// ─────────────────────────────────────────

export const preventParamPollution = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  try {
    for (const key of Object.keys(req.query)) {
      if (Array.isArray(req.query[key])) {
        (req.query as any)[key] = (req.query[key] as string[])[0];
      }
    }
  } catch (error) {
    // Ignore errors, req.query might be read-only in some Express versions
  }
  next();
};