import redisClient from '../config/redis';
import logger from '../utils/logger';
import { MatchState } from './game.types';

const MATCH_EXPIRY = 7200;

/**
 * Usernames and levels, cached in process.
 *
 * getPlayerStateWithNames ran a findMany on every call, and it is called once
 * per player every time a table is synced - so a four-player broadcast was
 * four identical queries for names that do not change during a match. The
 * cache is keyed by user id with a short TTL, which is long enough to cover a
 * whole match and short enough that a rename shows up quickly.
 */
const NAME_TTL_MS = 5 * 60 * 1000;

interface CachedName {
  username: string;
  level: number;
  fetchedAt: number;
}

const nameCache = new Map<string, CachedName>();

/** Dropped when a profile changes, so a rename is not held for the full TTL. */
export const invalidateNameCache = (userId: string): void => {
  nameCache.delete(userId);
};

export class GameStateManager {

  // ─────────────────────────────────────────
  // SAVE STATE
  // ─────────────────────────────────────────

  async saveState(state: MatchState): Promise<void> {
    await redisClient.set(
      `game:${state.matchId}`,
      JSON.stringify(state),
      { EX: MATCH_EXPIRY }
    );
  }

  // ─────────────────────────────────────────
  // GET STATE
  // ─────────────────────────────────────────

  async getState(matchId: string): Promise<MatchState | null> {
    const data = await redisClient.get(`game:${matchId}`);
    if (!data) return null;
    return JSON.parse(data);
  }

  // ─────────────────────────────────────────
  // DELETE STATE
  // ─────────────────────────────────────────

  async deleteState(matchId: string): Promise<void> {
    await redisClient.del(`game:${matchId}`);
    logger.info('Game state deleted', { matchId });
  }

  // ─────────────────────────────────────────
  // GET PLAYER STATE
  // ─────────────────────────────────────────

  /**
   * Names for a match's players, hitting the database only for the ones that
   * are not already cached.
   */
  private async resolveNames(
    playerIds: string[]
  ): Promise<Record<string, { username: string; level: number }>> {
    const now = Date.now();
    const result: Record<string, { username: string; level: number }> = {};
    const missing: string[] = [];

    for (const id of playerIds) {
      const hit = nameCache.get(id);
      if (hit && now - hit.fetchedAt < NAME_TTL_MS) {
        result[id] = { username: hit.username, level: hit.level };
      } else {
        missing.push(id);
      }
    }

    if (missing.length > 0) {
      const prisma = (await import('../config/database')).default;
      const users = await prisma.user.findMany({
        where: { id: { in: missing } },
        select: { id: true, username: true, level: true },
      });

      for (const u of users) {
        nameCache.set(u.id, {
          username: u.username,
          level: u.level,
          fetchedAt: now,
        });
        result[u.id] = { username: u.username, level: u.level };
      }
    }

    return result;
  }

  async getPlayerStateWithNames(userId: string, state: MatchState): Promise<any> {
    const usernameMap = await this.resolveNames(state.players);

    return {
      matchId: state.matchId,
      roomId: state.roomId,
      currentTurn: state.currentTurn,
      direction: state.direction,
      currentColor: state.currentColor,
      currentValue: state.currentValue,
      status: state.status,
      topCard: state.discardPile[state.discardPile.length - 1],
      drawPileCount: state.drawPile.length,
      myHand: state.hands[userId] || [],
      playerCardCounts: Object.fromEntries(
        Object.entries(state.hands).map(([id, cards]) => [id, cards.length])
      ),
      players: state.players,
      playerNames: usernameMap,
      winner: state.winner,
      totalTurns: state.totalTurns,
    };
  }

  // Keep old method as fallback
  getPlayerState(userId: string, state: MatchState) {
    return {
      matchId: state.matchId,
      roomId: state.roomId,
      currentTurn: state.currentTurn,
      direction: state.direction,
      currentColor: state.currentColor,
      currentValue: state.currentValue,
      status: state.status,
      topCard: state.discardPile[state.discardPile.length - 1],
      drawPileCount: state.drawPile.length,
      myHand: state.hands[userId] || [],
      playerCardCounts: Object.fromEntries(
        Object.entries(state.hands).map(([id, cards]) => [id, cards.length])
      ),
      players: state.players,
      winner: state.winner,
      totalTurns: state.totalTurns,
    };
  }
}

export default new GameStateManager();