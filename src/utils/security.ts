import crypto from 'crypto';
import redisClient from '../config/redis';
import logger from '../utils/logger';

// ─────────────────────────────────────────
// GENERATE SECURE TOKEN
// ─────────────────────────────────────────

export const generateSecureToken = (length: number = 32): string => {
  return crypto.randomBytes(length).toString('hex');
};

// ─────────────────────────────────────────
// HASH STRING
// ─────────────────────────────────────────

export const hashString = (value: string): string => {
  return crypto.createHash('sha256').update(value).digest('hex');
};

// ─────────────────────────────────────────
// REPLAY ATTACK PROTECTION
// ─────────────────────────────────────────

export const checkReplayAttack = async (
  requestId: string,
  expirySeconds: number = 300
): Promise<boolean> => {
  const key = `replay:${requestId}`;
  const exists = await redisClient.exists(key);

  if (exists) {
    logger.warn('Replay attack detected', { requestId });
    return true;
  }

  await redisClient.set(key, '1', { EX: expirySeconds });
  return false;
};

// ─────────────────────────────────────────
// WEBSOCKET RATE LIMITER
// ─────────────────────────────────────────

export const socketRateLimiter = async (
  userId: string,
  event: string,
  maxRequests: number,
  windowSeconds: number
): Promise<boolean> => {
  const key = `rate:${userId}:${event}`;
  const count = await redisClient.incr(key);

  if (count === 1) {
    await redisClient.expire(key, windowSeconds);
  }

  if (count > maxRequests) {
    logger.warn('Socket rate limit exceeded', { userId, event });
    return false;
  }

  return true;
};

// ─────────────────────────────────────────
// LOG SECURITY EVENT
// ─────────────────────────────────────────

export const logSecurityEvent = (
  event: string,
  userId: string | null,
  details: object = {}
): void => {
  logger.warn(`Security Event: ${event}`, {
    userId,
    ...details,
    timestamp: new Date().toISOString(),
  });
};