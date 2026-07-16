import redisClient from '../config/redis';
import logger from '../utils/logger';

export class RematchService {

  async requestRematch(matchId: string, userId: string): Promise<void> {
    await redisClient.sAdd(`rematch:${matchId}:accepted`, userId);
    await redisClient.expire(`rematch:${matchId}:accepted`, 60);

    logger.info('Rematch requested', { matchId, userId });
  }

  async acceptRematch(matchId: string, userId: string): Promise<void> {
    await redisClient.sAdd(`rematch:${matchId}:accepted`, userId);

    logger.info('Rematch accepted', { matchId, userId });
  }

  async declineRematch(matchId: string, userId: string): Promise<void> {
    await redisClient.sAdd(`rematch:${matchId}:declined`, userId);

    logger.info('Rematch declined', { matchId, userId });
  }

  async allPlayersAccepted(matchId: string, playerIds: string[]): Promise<boolean> {
    const accepted = await redisClient.sMembers(`rematch:${matchId}:accepted`);
    return playerIds.every(id => accepted.includes(id));
  }

  async clearRematch(matchId: string): Promise<void> {
    await redisClient.del(`rematch:${matchId}:accepted`);
    await redisClient.del(`rematch:${matchId}:declined`);
  }
}

export default new RematchService();