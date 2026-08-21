import prisma from '../config/database';
import logger from '../utils/logger';
import { UpdateProfileInput, UpdateSettingsInput } from './user.validation';

export class UserService {

  // ─────────────────────────────────────────
  // GET PROFILE
  // ─────────────────────────────────────────

  async getProfile(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        // The public player number, so the app can show it on the profile
        // and the player can read it out to a friend.
        uid: true,
        username: true,
        // False until the player has chosen their own name after a Google
        // sign-in; the app uses it to route to the setup screen.
        usernameSet: true,
        email: true,
        avatarUrl: true,
        level: true,
        xp: true,
        coins: true,
        rankPoints: true,
        accountStatus: true,
        createdAt: true,
        lastLogin: true,
        statistics: {
          select: {
            gamesPlayed: true,
            gamesWon: true,
            gamesLost: true,
            winRate: true,
            longestWinStreak: true,
            currentWinStreak: true,
            cardsPlayed: true,
            cardsDrawn: true,
          },
        },
        leaderboard: {
          select: {
            rating: true,
            tier: true,
            division: true,
            season: true,
          },
        },
      },
    });

    if (!user) {
      throw { code: 'USER_NOT_FOUND', message: 'User not found.', status: 404 };
    }

    return user;
  }

  // ─────────────────────────────────────────
  // UPDATE PROFILE
  // ─────────────────────────────────────────

  async updateProfile(userId: string, input: UpdateProfileInput) {
    if (input.username) {
      const existing = await prisma.user.findUnique({
        where: { username: input.username },
      });

      if (existing && existing.id !== userId) {
        throw { code: 'USERNAME_TAKEN', message: 'Username is already taken.', status: 409 };
      }
    }

    const user = await prisma.user.update({
      where: { id: userId },
      data: {
        ...(input.username && { username: input.username }),
        ...(input.avatarUrl && { avatarUrl: input.avatarUrl }),
        updatedAt: new Date(),
      },
      select: {
        id: true,
        username: true,
        avatarUrl: true,
        updatedAt: true,
      },
    });

    logger.info('Profile updated', { userId });

    return user;
  }

  // ─────────────────────────────────────────
  // GET SETTINGS
  // ─────────────────────────────────────────

  async getSettings(userId: string) {
    const settings = await prisma.playerSettings.findUnique({
      where: { playerId: userId },
    });

    if (!settings) {
      throw { code: 'SETTINGS_NOT_FOUND', message: 'Settings not found.', status: 404 };
    }

    return settings;
  }

  // ─────────────────────────────────────────
  // UPDATE SETTINGS
  // ─────────────────────────────────────────

  async updateSettings(userId: string, input: UpdateSettingsInput) {
    const settings = await prisma.playerSettings.update({
      where: { playerId: userId },
      data: {
        ...(input.language !== undefined && { language: input.language }),
        ...(input.musicVolume !== undefined && { musicVolume: input.musicVolume }),
        ...(input.soundVolume !== undefined && { soundVolume: input.soundVolume }),
        ...(input.voiceVolume !== undefined && { voiceVolume: input.voiceVolume }),
        ...(input.pushToTalk !== undefined && { pushToTalk: input.pushToTalk }),
        ...(input.notifications !== undefined && { notifications: input.notifications }),
        ...(input.darkMode !== undefined && { darkMode: input.darkMode }),
      },
    });

    logger.info('Settings updated', { userId });

    return settings;
  }

  // ─────────────────────────────────────────
  // GET STATISTICS
  // ─────────────────────────────────────────

  async getStatistics(userId: string) {
    const statistics = await prisma.playerStatistics.findUnique({
      where: { userId },
      select: {
        id: true,
        userId: true,
        gamesPlayed: true,
        gamesWon: true,
        gamesLost: true,
        winRate: true,
        longestWinStreak: true,
        currentWinStreak: true,
        cardsPlayed: true,
        cardsDrawn: true,
      },
    });

    // A missing row is not an error: an account created before statistics
    // were seeded - or one whose row was lost - would otherwise see the whole
    // Stats tab fail with a 404 rather than a set of zeroes.
    if (!statistics) {
      return await prisma.playerStatistics.create({
        data: { userId },
      });
    }

    return statistics;
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
      startedAt: h.match.startedAt.toISOString(),
      endedAt: h.match.endedAt.toISOString(),
      isWinner: h.match.winnerId === userId,
      finalPosition: h.finalPosition,
      ratingChange: h.ratingChange,
      xpEarned: h.xpEarned,
    }));
  }
}
export default new UserService();