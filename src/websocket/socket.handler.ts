import { Server, Socket } from 'socket.io';
import { AuthenticatedSocket } from './socket.types';
import { authenticateSocket, removeSocketSession } from './socket.auth';
import { initializeMatchmakingHandlers } from '../matchmaking/matchmaking.handler';
import { initializeRoomHandlers } from '../rooms/room.handler';
import { initializeGameHandlers } from '../gameplay/game.handler';
import { initializeVoiceHandlers } from '../voice/voice.handler';
import { SOCKET_EVENTS } from '../utils/constants';
import logger from '../utils/logger';

export const initializeSocketHandlers = (io: Server): void => {

  io.on('connection', (rawSocket: Socket) => {
    const socket = rawSocket as AuthenticatedSocket;

    logger.info('Socket connected', { socketId: socket.id });

    socket.on(SOCKET_EVENTS.AUTHENTICATE, async (data: { token: string }) => {
      if (!data?.token) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'AUTH_FAILED',
          message: 'Token is required.',
        });
        return;
      }

      const success = await authenticateSocket(socket, data.token);

      if (success) {
        socket.emit(SOCKET_EVENTS.AUTHENTICATED, {
          success: true,
          playerId: socket.userId,
        });

        // Prevent duplicate handler registration
if (!(socket as any)._handlersRegistered) {
    initializeMatchmakingHandlers(io, socket);
    initializeRoomHandlers(io, socket);
    initializeGameHandlers(io, socket);
    initializeVoiceHandlers(io, socket);
    (socket as any)._handlersRegistered = true;
}

        // Restore user's match/room state from Redis after reconnection
        
        const restoreMatchState = async () => {
    try {
        const redis = (await import('../config/redis')).default;
        const matchId = await redis.get(`match:player:${socket.userId}`);
        const roomId = await redis.get(`player:room:${socket.userId}`);

        if (matchId) {
            // Verify match still exists
            const matchExists = await redis.get(`game:${matchId}`);
            if (matchExists) {
                (socket as any).matchId = matchId;
                logger.info('Restored matchId on auth', { userId: socket.userId, matchId });
            } else {
                // Stale match - cleanup
                await redis.del(`match:player:${socket.userId}`);
                logger.info('Cleaned stale matchId', { userId: socket.userId, matchId });
            }
        }

        if (roomId) {
            // Verify room still exists
            const roomExists = await redis.get(`room:${roomId}`);
            if (roomExists) {
                (socket as any).roomId = roomId;
                socket.join(roomId);
                logger.info('Restored roomId on auth', { userId: socket.userId, roomId });
            } else {
                // Stale room - cleanup
                await redis.del(`player:room:${socket.userId}`);
                logger.info('Cleaned stale roomId', { userId: socket.userId, roomId });
            }
        }
    } catch (err) {
        logger.error('Failed to restore match state', { error: err });
    }
};

        restoreMatchState();

        // CHAT HANDLER
        socket.on(SOCKET_EVENTS.CHAT_SEND, async (data: { message: string }) => {
          try {
            if (!socket.userId || !socket.roomId || !data?.message) return;

            const messageText = data.message.trim();
            if (messageText.length === 0 || messageText.length > 200) return;

            io.to(socket.roomId).emit(SOCKET_EVENTS.CHAT_RECEIVED, {
              userId: socket.userId,
              username: socket.username,
              message: messageText,
              timestamp: Date.now(),
            });
          } catch (error) {
            logger.error('Chat error', { error });
          }
        });

        logger.info('Socket authentication successful', {
          userId: socket.userId,
          socketId: socket.id,
        });
      }
    });

    socket.on('disconnect', async (reason) => {
      logger.info('Socket disconnected', {
        socketId: socket.id,
        userId: socket.userId,
        reason,
      });

      // Only clean up room membership, keep match/room in Redis for reconnection
      if (socket.roomId) {
        try {
          const roomService = (await import('../rooms/room.service')).default;
          // Don't remove from room on disconnect - allow reconnection
        } catch (e) {
          // Ignore
        }
      }

      await removeSocketSession(socket);
    });

    socket.on('error', (error) => {
      logger.error('Socket error', {
        socketId: socket.id,
        userId: socket.userId,
        error,
      });
    });
  });

  logger.info('Socket handlers initialized');
};