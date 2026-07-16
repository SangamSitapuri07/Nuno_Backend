import redisClient from '../config/redis';
import logger from '../utils/logger';
import { SocketSession } from './socket.types';

export const updateSession = async (
  socketId: string,
  updates: Partial<SocketSession>
): Promise<void> => {
  const existing = await redisClient.get(`session:${socketId}`);
  if (!existing) return;

  const session = JSON.parse(existing);
  const updated = { ...session, ...updates };

  await redisClient.set(
    `session:${socketId}`,
    JSON.stringify(updated),
    { EX: 3600 }
  );
};

export const getOnlinePlayers = async (): Promise<string[]> => {
  return await redisClient.sMembers('online_players');
};

export const isPlayerOnline = async (userId: string): Promise<boolean> => {
  return await redisClient.sIsMember('online_players', userId);
};

export const getPlayerSocketId = async (
  userId: string
): Promise<string | null> => {
  return await redisClient.get(`socket:${userId}`);
};