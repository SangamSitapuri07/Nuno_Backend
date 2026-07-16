import redisClient from '../config/redis';
import prisma from '../config/database';
import logger from '../utils/logger';
import { generateId, generateRoomCode } from '../utils/generateId';
import {
  QueueEntry,
  GameMode,
  MatchFound,
  QueueJoinInput,
} from './matchmaking.types';

const RATING_RANGE_INITIAL = 1000;
const RATING_RANGE_EXPANSION = 50;
const EXPANSION_INTERVAL = 10000;
const MIN_PLAYERS = 2;
const MAX_PLAYERS = 10;

export class MatchmakingService {

  // ─────────────────────────────────────────
  // JOIN QUEUE
  // ─────────────────────────────────────────

  async joinQueue(
    userId: string,
    username: string,
    socketId: string,
    input: QueueJoinInput
  ): Promise<void> {
    // Remove from any existing queue first
    await this.leaveQueue(userId);

    // Check if already in match - auto cleanup stale
    const inMatch = await redisClient.get(`match:player:${userId}`);
    if (inMatch) {
      const matchExists = await redisClient.get(`game:${inMatch}`);
      if (matchExists) {
        throw { code: 'ALREADY_IN_MATCH', message: 'Already in a match.', status: 400 };
      } else {
        // Stale match data - cleanup
        await redisClient.del(`match:player:${userId}`);
        await redisClient.del(`player:room:${userId}`);
        logger.info('Cleaned stale match data', { userId });
      }
    }

    // Get player rating
    const leaderboard = await prisma.leaderboard.findUnique({
      where: { playerId: userId },
    });

    const rating = leaderboard?.rating || 1000;
    const region = input.region || 'AUTO';

    const entry: QueueEntry = {
    userId,
    username,
    rating,
    mode: input.mode,
    region,
    joinedAt: Date.now(),
    socketId,
    requiredPlayers: input.requiredPlayers || 2,
};

    // Add to queue
    const queueKey = `queue:${input.mode}`;
    await redisClient.lPush(queueKey, JSON.stringify(entry));
    await redisClient.set(
      `queue:player:${userId}`,
      queueKey,
      { EX: 300 }
    );

    logger.info('Player joined queue', {
      userId,
      username,
      mode: input.mode,
      rating,
      queueKey,
    });
  }

  // ─────────────────────────────────────────
  // LEAVE QUEUE
  // ─────────────────────────────────────────

  async leaveQueue(userId: string): Promise<void> {
    const queueKey = await redisClient.get(`queue:player:${userId}`);
    if (!queueKey) return;

    // Get all entries and remove this player
    const entries = await redisClient.lRange(queueKey, 0, -1);
    for (const entry of entries) {
      try {
        const parsed: QueueEntry = JSON.parse(entry);
        if (parsed.userId === userId) {
          await redisClient.lRem(queueKey, 0, entry);
        }
      } catch (e) {
        // Invalid entry, remove it
        await redisClient.lRem(queueKey, 0, entry);
      }
    }

    await redisClient.del(`queue:player:${userId}`);

    logger.info('Player left queue', { userId });
  }

  // ─────────────────────────────────────────
  // FIND MATCH
  // ─────────────────────────────────────────

  async findMatch(mode: GameMode): Promise<MatchFound | null> {
    const queueKey = `queue:${mode}`;
    const entries = await redisClient.lRange(queueKey, 0, -1);

    logger.info('FindMatch', { mode, entriesCount: entries.length });

    if (entries.length < MIN_PLAYERS) return null;

    const players: QueueEntry[] = [];
    for (const entry of entries) {
      try {
        players.push(JSON.parse(entry));
      } catch (e) {
        // Remove invalid entry
        await redisClient.lRem(queueKey, 0, entry);
      }
    }

    // Sort by join time
    players.sort((a, b) => a.joinedAt - b.joinedAt);

    // Try to find compatible players
    const matched = this.matchPlayers(players, mode);
    if (!matched || matched.length < MIN_PLAYERS) {
      logger.info('No compatible match found', { mode, playerCount: players.length });
      return null;
    }

    // Remove matched players from queue
    for (const player of matched) {
      // Remove all entries for this player
      const allEntries = await redisClient.lRange(queueKey, 0, -1);
      for (const entry of allEntries) {
        try {
          const parsed = JSON.parse(entry);
          if (parsed.userId === player.userId) {
            await redisClient.lRem(queueKey, 0, entry);
          }
        } catch (e) {
          await redisClient.lRem(queueKey, 0, entry);
        }
      }
      await redisClient.del(`queue:player:${player.userId}`);
    }

    // Create match
    const matchId = generateId();
    const roomId = generateId();
    const roomCode = generateRoomCode();

    const match: MatchFound = {
      matchId,
      roomId,
      players: matched,
      mode,
      region: 'AUTO',
      createdAt: Date.now(),
    };

    // Store match in Redis
    await redisClient.set(
      `match:${matchId}`,
      JSON.stringify(match),
      { EX: 3600 }
    );

    // Mark players as in match
    for (const player of matched) {
      await redisClient.set(
        `match:player:${player.userId}`,
        matchId,
        { EX: 3600 }
      );
    }

    // Store room code
    await redisClient.set(
      `room:code:${roomCode}`,
      roomId,
      { EX: 3600 }
    );

    logger.info('Match created', {
      matchId,
      roomId,
      playerCount: matched.length,
      mode,
      players: matched.map(p => p.username),
    });

    return match;
  }

  // ─────────────────────────────────────────
  // MATCH PLAYERS
  // ─────────────────────────────────────────

  private matchPlayers(
    players: QueueEntry[],
    mode: GameMode
  ): QueueEntry[] | null {
    if (players.length < 2) return null;

    // Remove duplicates by userId
    const uniquePlayers = players.filter((player, index, self) =>
      index === self.findIndex(p => p.userId === player.userId)
    );

    if (uniquePlayers.length < 2) return null;

    // Group by requiredPlayers count
    const groups: { [key: number]: QueueEntry[] } = {};
    uniquePlayers.forEach(p => {
      const required = p.requiredPlayers || 2;
      if (!groups[required]) groups[required] = [];
      groups[required].push(p);
    });

    // Try to match groups that have enough players
    for (const [requiredStr, groupPlayers] of Object.entries(groups)) {
      const required = parseInt(requiredStr);

      if (groupPlayers.length >= required) {
        const now = Date.now();
        const first = groupPlayers[0];
        const waitTime = (now - first.joinedAt) / 1000;
        const expansions = Math.floor(waitTime / (EXPANSION_INTERVAL / 1000));
        const ratingRange = RATING_RANGE_INITIAL + expansions * RATING_RANGE_EXPANSION;

        const compatible = groupPlayers.filter(p => {
          if (p.userId === first.userId) return true;
          return Math.abs(p.rating - first.rating) <= ratingRange;
        });

        if (compatible.length >= required) {
          return compatible.slice(0, required);
        }
      }
    }

    // Fallback: after 30 seconds waiting, match any 2+ players regardless of requiredPlayers
    const now = Date.now();
    const oldest = uniquePlayers[0];
    if (oldest && (now - oldest.joinedAt) > 30000) {
      if (uniquePlayers.length >= 2) {
        return uniquePlayers.slice(0, Math.min(uniquePlayers.length, 4));
      }
    }

    return null;
  }
  // ─────────────────────────────────────────
  // GET QUEUE STATUS
  // ─────────────────────────────────────────

  async getQueueStatus(userId: string): Promise<string | null> {
    return await redisClient.get(`queue:player:${userId}`);
  }

  // ─────────────────────────────────────────
  // PROCESS QUEUES
  // ─────────────────────────────────────────

  async processQueues(): Promise<MatchFound[]> {
    const matches: MatchFound[] = [];

    for (const mode of Object.values(GameMode)) {
      if (mode === GameMode.PRIVATE) continue;
      if (mode === GameMode.CUSTOM) continue;

      const queueKey = `queue:${mode}`;
      const queueSize = await redisClient.lLen(queueKey);
      logger.info('Queue check', { mode, queueSize });

      if (queueSize >= MIN_PLAYERS) {
        const match = await this.findMatch(mode);
        if (match) {
          matches.push(match);
          logger.info('Match found!', { mode, playerCount: match.players.length });
        }
      }
    }

    return matches;
  }
}

export default new MatchmakingService();