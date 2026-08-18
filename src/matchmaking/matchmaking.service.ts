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

/// After this long, pair whoever is waiting regardless of rating.
const RATING_IGNORED_AFTER = 45000;
const MIN_PLAYERS = 2;
const MAX_PLAYERS = 8;

/// Table sizes a player may queue for. Anything outside this is clamped.
const VALID_TABLE_SIZES = [2, 3, 4, 6, 8];

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

    // Clamp to a size we actually offer, so a malformed client cannot park
    // itself in a bucket nobody else can ever join.
    const requested = input.requiredPlayers ?? 2;
    const requiredPlayers = VALID_TABLE_SIZES.includes(requested)
      ? requested
      : Math.min(Math.max(requested, MIN_PLAYERS), MAX_PLAYERS);

    const entry: QueueEntry = {
      userId,
      username,
      rating,
      mode: input.mode,
      region,
      joinedAt: Date.now(),
      socketId,
      requiredPlayers,
    };

    // The size is part of the key. With a single list per mode, a 2-player
    // and an 8-player request sat in the same queue and the fallback below
    // would eventually pair them regardless of what either asked for.
    const queueKey = `queue:${input.mode}:${requiredPlayers}`;
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
      requiredPlayers,
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

  async findMatch(
    mode: GameMode,
    tableSize: number
  ): Promise<MatchFound | null> {
    const queueKey = `queue:${mode}:${tableSize}`;
    const entries = await redisClient.lRange(queueKey, 0, -1);

    logger.info('FindMatch', { mode, tableSize, entriesCount: entries.length });

    // A table only starts when the size the players asked for is met.
    if (entries.length < tableSize) return null;

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
    const matched = this.matchPlayers(players, tableSize);
    if (!matched || matched.length < tableSize) {
      logger.info('No compatible match found', {
        mode,
        tableSize,
        playerCount: players.length,
      });
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
      tableSize,
      mode,
      players: matched.map(p => p.username),
    });

    return match;
  }

  // ─────────────────────────────────────────
  // MATCH PLAYERS
  // ─────────────────────────────────────────

  /// Picks [tableSize] compatible players from a single-size queue.
  ///
  /// Everyone in this queue asked for the same table size, so the only
  /// question left is rating. The permitted rating gap widens the longer the
  /// oldest player has waited, and after a grace period it is ignored
  /// entirely - a long wait is worse than an uneven table.
  private matchPlayers(
    players: QueueEntry[],
    tableSize: number
  ): QueueEntry[] | null {
    const unique = players.filter(
      (p, i, self) => i === self.findIndex((o) => o.userId === p.userId)
    );

    if (unique.length < tableSize) return null;

    const first = unique[0];
    const waitedMs = Date.now() - first.joinedAt;
    const expansions = Math.floor(waitedMs / EXPANSION_INTERVAL);
    const ratingRange =
      RATING_RANGE_INITIAL + expansions * RATING_RANGE_EXPANSION;

    const compatible = unique.filter(
      (p) =>
        p.userId === first.userId ||
        Math.abs(p.rating - first.rating) <= ratingRange
    );

    if (compatible.length >= tableSize) {
      return compatible.slice(0, tableSize);
    }

    // Ignore rating once someone has waited this long.
    if (waitedMs > RATING_IGNORED_AFTER && unique.length >= tableSize) {
      return unique.slice(0, tableSize);
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

      // Each table size is its own queue, so they are checked separately.
      for (const tableSize of VALID_TABLE_SIZES) {
        const queueKey = `queue:${mode}:${tableSize}`;
        const queueSize = await redisClient.lLen(queueKey);
        if (queueSize < tableSize) continue;

        logger.info('Queue check', { mode, tableSize, queueSize });

        const match = await this.findMatch(mode, tableSize);
        if (match) {
          matches.push(match);
          logger.info('Match found!', {
            mode,
            tableSize,
            playerCount: match.players.length,
          });
        }
      }
    }

    return matches;
  }

  /// How many players are waiting for a given size, for the searching screen.
  async getQueueDepth(mode: GameMode, tableSize: number): Promise<number> {
    return await redisClient.lLen(`queue:${mode}:${tableSize}`);
  }
}

export default new MatchmakingService();