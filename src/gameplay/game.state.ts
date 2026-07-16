import redisClient from '../config/redis';
import logger from '../utils/logger';
import { MatchState } from './game.types';

const MATCH_EXPIRY = 7200;

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

  async getPlayerStateWithNames(userId: string, state: MatchState): Promise<any> {
    const prisma = (await import('../config/database')).default;

    // Fetch usernames for all players
    const users = await prisma.user.findMany({
      where: { id: { in: state.players } },
      select: { id: true, username: true, level: true }
    });

    const usernameMap: Record<string, { username: string, level: number }> = {};
    users.forEach(u => {
      usernameMap[u.id] = { username: u.username, level: u.level };
    });

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