import prisma from '../config/database';
import logger from '../utils/logger';
import {
  TIER_THRESHOLDS,
  XP_REWARDS,
  LEVEL_THRESHOLDS,
  RankTier,
} from './leaderboard.types';

export class LeaderboardService {

  // ─────────────────────────────────────────
  // GET GLOBAL LEADERBOARD
  // ─────────────────────────────────────────

  async getGlobalLeaderboard(limit: number = 100) {
    const entries = await prisma.leaderboard.findMany({
      orderBy: { rating: 'desc' },
      take: limit,
      include: {
        user: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            statistics: {
              select: {
                gamesWon: true,
              },
            },
          },
        },
      },
    });

    return entries.map((entry, index) => ({
      rank: index + 1,
      userId: entry.user.id,
      username: entry.user.username,
      avatarUrl: entry.user.avatarUrl,
      rating: entry.rating,
      tier: entry.tier,
      division: entry.division,
      wins: entry.user.statistics?.gamesWon || 0,
    }));
  }

  // ─────────────────────────────────────────
  // GET FRIENDS LEADERBOARD
  // ─────────────────────────────────────────

  async getFriendsLeaderboard(userId: string) {
    const friends = await prisma.friend.findMany({
      where: {
        OR: [
          { userOne: userId },
          { userTwo: userId },
        ],
      },
    });

    const friendIds = friends.map((f) =>
      f.userOne === userId ? f.userTwo : f.userOne
    );

    friendIds.push(userId);

    const entries = await prisma.leaderboard.findMany({
      where: { playerId: { in: friendIds } },
      orderBy: { rating: 'desc' },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            statistics: {
              select: {
                gamesWon: true,
              },
            },
          },
        },
      },
    });

    return entries.map((entry, index) => ({
      rank: index + 1,
      userId: entry.user.id,
      username: entry.user.username,
      avatarUrl: entry.user.avatarUrl,
      rating: entry.rating,
      tier: entry.tier,
      division: entry.division,
      wins: entry.user.statistics?.gamesWon || 0,
    }));
  }

  // ─────────────────────────────────────────
  // UPDATE RATING
  // ─────────────────────────────────────────

  async updateRating(
    userId: string,
    ratingChange: number
  ): Promise<void> {
    const leaderboard = await prisma.leaderboard.findUnique({
      where: { playerId: userId },
    });

    if (!leaderboard) return;

    const newRating = Math.max(0, leaderboard.rating + ratingChange);
    const { tier, division } = this.getTierFromRating(newRating);

    await prisma.leaderboard.update({
      where: { playerId: userId },
      data: {
        rating: newRating,
        tier,
        division,
      },
    });

    logger.info('Rating updated', { userId, ratingChange, newRating, tier });
  }

  // ─────────────────────────────────────────
  // CALCULATE XP
  // ─────────────────────────────────────────

  calculateXP(isWinner: boolean, isMVP: boolean = false): number {
    let xp = XP_REWARDS.MATCH_COMPLETED;
    if (isWinner) xp += XP_REWARDS.VICTORY_BONUS;
    if (isMVP) xp += XP_REWARDS.MVP_BONUS;
    return xp;
  }

  // ─────────────────────────────────────────
  // UPDATE XP AND LEVEL
  // ─────────────────────────────────────────

  async updateXPAndLevel(
    userId: string,
    xpToAdd: number
  ): Promise<{ leveledUp: boolean; newLevel: number }> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { xp: true, level: true },
    });

    if (!user) return { leveledUp: false, newLevel: 1 };

    const newXP = user.xp + xpToAdd;
    const newLevel = this.getLevelFromXP(newXP);
    const leveledUp = newLevel > user.level;

    await prisma.user.update({
      where: { id: userId },
      data: {
        xp: newXP,
        level: newLevel,
      },
    });

    if (leveledUp) {
      logger.info('Player leveled up', { userId, newLevel });
    }

    return { leveledUp, newLevel };
  }

  // ─────────────────────────────────────────
  // GET LEVEL FROM XP
  // ─────────────────────────────────────────

  getLevelFromXP(xp: number): number {
    let level = 1;
    for (let i = 0; i < LEVEL_THRESHOLDS.length; i++) {
      if (xp >= LEVEL_THRESHOLDS[i]) {
        level = i + 1;
      } else {
        break;
      }
    }
    return level;
  }

  // ─────────────────────────────────────────
  // GET TIER FROM RATING
  // ─────────────────────────────────────────

  getTierFromRating(rating: number): { tier: string; division: string } {
    let tier = RankTier.BRONZE;
    let division = 'III';

    for (const [tierName, threshold] of Object.entries(TIER_THRESHOLDS)) {
      if (rating >= threshold) {
        tier = tierName as RankTier;
      }
    }

    const tierThreshold = TIER_THRESHOLDS[tier];
    const nextTierThreshold =
      TIER_THRESHOLDS[this.getNextTier(tier)] || tierThreshold + 500;
    const rangePerDivision = (nextTierThreshold - tierThreshold) / 3;

    const positionInTier = rating - tierThreshold;

    if (positionInTier >= rangePerDivision * 2) {
      division = 'I';
    } else if (positionInTier >= rangePerDivision) {
      division = 'II';
    } else {
      division = 'III';
    }

    return { tier, division };
  }

  // ─────────────────────────────────────────
  // GET NEXT TIER
  // ─────────────────────────────────────────

  private getNextTier(tier: string): string {
    const tiers = Object.keys(TIER_THRESHOLDS);
    const index = tiers.indexOf(tier);
    return tiers[index + 1] || tier;
  }

  // ─────────────────────────────────────────
  // GET PLAYER RANK
  // ─────────────────────────────────────────

  async getPlayerRank(userId: string) {
    const leaderboard = await prisma.leaderboard.findUnique({
      where: { playerId: userId },
    });

    if (!leaderboard) return null;

    const rank = await prisma.leaderboard.count({
      where: { rating: { gt: leaderboard.rating } },
    });

    return {
      globalRank: rank + 1,
      rating: leaderboard.rating,
      tier: leaderboard.tier,
      division: leaderboard.division,
      season: leaderboard.season,
    };
  }

  // ─────────────────────────────────────────
  // GET MATCH HISTORY
  // ─────────────────────────────────────────

  async getMatchHistory(userId: string) {
    const history = await prisma.matchPlayer.findMany({
      where: { playerId: userId },
      include: {
        match: {
          select: {
            id: true,
            gameMode: true,
            duration: true,
            startedAt: true,
            endedAt: true,
            winnerId: true,
          },
        },
      },
      orderBy: {
        match: {
          startedAt: 'desc',
        },
      },
      take: 20,
    });

    return history.map((h) => ({
      matchId: h.match.id,
      gameMode: h.match.gameMode,
      duration: h.match.duration,
      startedAt: h.match.startedAt,
      endedAt: h.match.endedAt,
      isWinner: h.match.winnerId === userId,
      finalPosition: h.finalPosition,
      ratingChange: h.ratingChange,
      xpEarned: h.xpEarned,
    }));
  }
}

export default new LeaderboardService();