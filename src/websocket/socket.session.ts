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
/**
 * This instance's live socket for a user, or null.
 *
 * Socket.IO already indexes the personal room every socket joins on
 * authentication, so this is a map lookup. The alternative used in several
 * handlers was a linear walk of `io.sockets.sockets` per player, which is
 * O(all connected players) for each member of a table.
 *
 * Only sees sockets served by THIS instance, which is what callers that need
 * to mutate socket state (matchId, roomId) want. Anything that merely needs
 * to deliver a message should emit to `user:<id>` so the Redis adapter can
 * route it wherever the player actually is.
 */
export const getLocalSocket = (io: any, userId: string): any => {
  const room = io.sockets.adapter.rooms.get(`user:${userId}`);
  if (!room) return null;
  for (const socketId of room) {
    const socket = io.sockets.sockets.get(socketId);
    if (socket) return socket;
  }
  return null;
};
