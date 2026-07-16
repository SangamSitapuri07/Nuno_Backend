import jwt from 'jsonwebtoken';
import config from '../config/config';
import prisma from '../config/database';
import redisClient from '../config/redis';
import logger from '../utils/logger';
import { AuthenticatedSocket, SocketSession } from './socket.types';
import { SOCKET_EVENTS } from '../utils/constants';

export const authenticateSocket = async (
  socket: AuthenticatedSocket,
  token: string
): Promise<boolean> => {
  try {
    const payload = jwt.verify(token, config.jwt.accessSecret) as any;

    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: {
        id: true,
        username: true,
        accountStatus: true,
      },
    });

    if (!user || user.accountStatus !== 'ACTIVE') {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: 'AUTH_FAILED',
        message: 'Authentication failed.',
      });
      socket.disconnect();
      return false;
    }

    // Check if already connected with another socket
    const existingSocketId = await redisClient.get(`socket:${user.id}`);
    if (existingSocketId && existingSocketId !== socket.id) {
      logger.info('Duplicate login detected', { userId: user.id });
    }

    // Set socket properties
    socket.userId = user.id;
    socket.username = user.username;
    socket.role = payload.role;

    // Store session in Redis
    const session: SocketSession = {
      userId: user.id,
      username: user.username,
      socketId: socket.id,
      connectedAt: Date.now(),
      lastSequence: 0,
    };

    await redisClient.set(
      `socket:${user.id}`,
      socket.id,
      { EX: 3600 }
    );

    await redisClient.set(
      `session:${socket.id}`,
      JSON.stringify(session),
      { EX: 3600 }
    );

    // Add to online players
    await redisClient.sAdd('online_players', user.id);

    logger.info('Socket authenticated', {
      userId: user.id,
      socketId: socket.id,
    });

    return true;

  } catch (error) {
    logger.error('Socket authentication error', { error });
    socket.emit(SOCKET_EVENTS.ERROR, {
      code: 'AUTH_FAILED',
      message: 'Invalid or expired token.',
    });
    socket.disconnect();
    return false;
  }
};

export const getSocketSession = async (
  socketId: string
): Promise<SocketSession | null> => {
  const session = await redisClient.get(`session:${socketId}`);
  if (!session) return null;
  return JSON.parse(session);
};

export const removeSocketSession = async (
  socket: AuthenticatedSocket
): Promise<void> => {
  if (!socket.userId) return;

  await redisClient.del(`socket:${socket.userId}`);
  await redisClient.del(`session:${socket.id}`);
  await redisClient.sRem('online_players', socket.userId);

  logger.info('Socket session removed', {
    userId: socket.userId,
    socketId: socket.id,
  });
};