import { AuthenticatedSocket } from '../websocket/socket.types';
import { socketRateLimiter, logSecurityEvent } from '../utils/security';
import { SOCKET_EVENTS } from '../utils/constants';
import logger from '../utils/logger';

// ─────────────────────────────────────────
// SOCKET RATE LIMIT CONFIGS
// ─────────────────────────────────────────

const RATE_LIMITS: { [event: string]: { max: number; window: number } } = {
  'chat.send': { max: 5, window: 10 },
  'player.emote': { max: 10, window: 10 },
  'room.ready': { max: 5, window: 10 },
  'queue.join': { max: 5, window: 60 },
  'queue.leave': { max: 5, window: 60 },
  'card.play': { max: 30, window: 60 },
  'card.draw': { max: 30, window: 60 },
};

// ─────────────────────────────────────────
// APPLY SOCKET SECURITY
// ─────────────────────────────────────────

export const applySocketSecurity = (
  socket: AuthenticatedSocket
): void => {

  // Wrap original emit to add rate limiting
  const originalOn = socket.on.bind(socket);

  socket.on = function (event: string, listener: any) {
    const wrappedListener = async (...args: any[]) => {
      // Skip security for auth events
      if (event === SOCKET_EVENTS.AUTHENTICATE) {
        return listener(...args);
      }

      // Check if socket is authenticated
      if (!socket.userId) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'AUTH_FAILED',
          message: 'Not authenticated.',
        });
        return;
      }

      // Apply rate limiting if configured
      const rateConfig = RATE_LIMITS[event];
      if (rateConfig) {
        const allowed = await socketRateLimiter(
          socket.userId,
          event,
          rateConfig.max,
          rateConfig.window
        );

        if (!allowed) {
          socket.emit(SOCKET_EVENTS.ERROR, {
            code: 'RATE_LIMIT',
            message: 'Too many requests.',
          });
          return;
        }
      }

      return listener(...args);
    };

    return originalOn(event, wrappedListener);
  } as any;
};

// ─────────────────────────────────────────
// VALIDATE SOCKET PAYLOAD
// ─────────────────────────────────────────

export const validateSocketPayload = (
  data: any,
  requiredFields: string[]
): boolean => {
  if (!data || typeof data !== 'object') return false;

  for (const field of requiredFields) {
    if (data[field] === undefined || data[field] === null) {
      return false;
    }
  }

  return true;
};