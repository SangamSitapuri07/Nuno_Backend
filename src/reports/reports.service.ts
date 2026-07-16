import prisma from '../config/database';
import logger from '../utils/logger';

export class ReportsService {

  async reportPlayer(
    reporterId: string,
    reportedPlayerId: string,
    reason: string,
    matchId?: string
  ): Promise<void> {
    if (reporterId === reportedPlayerId) {
      throw { code: 'INVALID_REPORT', message: 'Cannot report yourself.', status: 400 };
    }

    const player = await prisma.user.findUnique({
      where: { id: reportedPlayerId },
    });

    if (!player) {
      throw { code: 'PLAYER_NOT_FOUND', message: 'Player not found.', status: 404 };
    }

    await prisma.report.create({
      data: {
        reporterId,
        reportedPlayer: reportedPlayerId,
        reason,
        matchId: matchId || null,
        status: 'PENDING',
      },
    });

    logger.info('Player reported', { reporterId, reportedPlayerId, reason });
  }

  async blockPlayer(
    userId: string,
    blockedPlayerId: string
  ): Promise<void> {
    if (userId === blockedPlayerId) {
      throw { code: 'INVALID_BLOCK', message: 'Cannot block yourself.', status: 400 };
    }

    // Store in Redis for fast lookup
    const redis = (await import('../config/redis')).default;
    await redis.sAdd(`blocked:${userId}`, blockedPlayerId);

    logger.info('Player blocked', { userId, blockedPlayerId });
  }

  async unblockPlayer(
    userId: string,
    blockedPlayerId: string
  ): Promise<void> {
    const redis = (await import('../config/redis')).default;
    await redis.sRem(`blocked:${userId}`, blockedPlayerId);

    logger.info('Player unblocked', { userId, blockedPlayerId });
  }

  async getBlockedPlayers(userId: string): Promise<string[]> {
    const redis = (await import('../config/redis')).default;
    return await redis.sMembers(`blocked:${userId}`);
  }

  async isBlocked(userId: string, otherUserId: string): Promise<boolean> {
    const redis = (await import('../config/redis')).default;
    return await redis.sIsMember(`blocked:${userId}`, otherUserId);
  }
}

export default new ReportsService();