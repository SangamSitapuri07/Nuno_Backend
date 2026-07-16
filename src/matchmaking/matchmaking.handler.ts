import { Server } from 'socket.io';
import { AuthenticatedSocket } from '../websocket/socket.types';
import matchmakingService from './matchmaking.service';
import { SOCKET_EVENTS } from '../utils/constants';
import { GameMode, QueueJoinInput } from './matchmaking.types';
import logger from '../utils/logger';

export const initializeMatchmakingHandlers = (
  io: Server,
  socket: AuthenticatedSocket
): void => {

  // ─────────────────────────────────────────
  // JOIN QUEUE
  // ─────────────────────────────────────────

  socket.on(SOCKET_EVENTS.QUEUE_JOIN, async (data: QueueJoinInput) => {
    try {
      if (!socket.userId) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'AUTH_FAILED',
          message: 'Not authenticated.',
        });
        return;
      }

      if (!data?.mode || !Object.values(GameMode).includes(data.mode)) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'INVALID_MODE',
          message: 'Invalid game mode.',
        });
        return;
      }

      // Prevent duplicate join
      const alreadyInQueue = await matchmakingService.getQueueStatus(socket.userId);
      if (alreadyInQueue) {
        logger.info('Player already in queue, skipping', { userId: socket.userId });
        socket.emit('queue.joined', {
          mode: data.mode,
          region: data.region || 'AUTO',
          timestamp: Date.now(),
        });
        return;
      }

      await matchmakingService.joinQueue(
        socket.userId,
        socket.username,
        socket.id,
        data
      );

      socket.emit('queue.joined', {
        mode: data.mode,
        region: data.region || 'AUTO',
        timestamp: Date.now(),
      });

      logger.info('Player joined queue', {
        userId: socket.userId,
        mode: data.mode,
      });

      // Try to find match
      await processAndNotify(io, data.mode);

    } catch (error: any) {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: error.code || 'SERVER_ERROR',
        message: error.message || 'Failed to join queue.',
      });
    }
  });

  // ─────────────────────────────────────────
  // LEAVE QUEUE
  // ─────────────────────────────────────────

  socket.on(SOCKET_EVENTS.QUEUE_LEAVE, async () => {
    try {
      if (!socket.userId) return;

      await matchmakingService.leaveQueue(socket.userId);

      socket.emit('queue.left', {
        timestamp: Date.now(),
      });

      logger.info('Player left queue', { userId: socket.userId });

    } catch (error: any) {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: error.code || 'SERVER_ERROR',
        message: error.message || 'Failed to leave queue.',
      });
    }
  });
};

// ─────────────────────────────────────────
// PROCESS AND NOTIFY
// ─────────────────────────────────────────

const processAndNotify = async (
  io: Server,
  mode: GameMode
): Promise<void> => {
  try {
    const matches = await matchmakingService.processQueues();

    for (const match of matches) {
      const roomService = (await import('../rooms/room.service')).default;
      const gameEngine = (await import('../gameplay/game.engine')).default;
      const gameStateManager = (await import('../gameplay/game.state')).default;
      const { generateId } = await import('../utils/generateId');

      // Create the room
      const firstPlayer = match.players[0];
      const room = await roomService.createRoom(
        firstPlayer.userId,
        firstPlayer.username,
        firstPlayer.socketId,
        {
          gameMode: match.mode,
          maxPlayers: 4,
          voiceEnabled: true,
        }
      );

      // Join all other players
      for (let i = 1; i < match.players.length; i++) {
        const player = match.players[i];
        await roomService.joinRoom(
          player.userId,
          player.username,
          player.socketId,
          { roomCode: room.roomCode }
        );
      }

      // Set room and match state for each player socket
      for (const player of match.players) {
        const playerSocket = io.sockets.sockets.get(player.socketId);
        if (playerSocket) {
          (playerSocket as any).roomId = room.roomId;
          playerSocket.join(room.roomId);

          playerSocket.emit(SOCKET_EVENTS.MATCH_FOUND, {
            matchId: match.matchId,
            roomId: room.roomId,
            roomCode: room.roomCode,
            mode: match.mode,
            players: match.players.map((p) => ({
              userId: p.userId,
              username: p.username,
              rating: p.rating,
            })),
          });
        }
      }

      // Auto-start after 3 seconds for casual/ranked
      setTimeout(async () => {
        try {
          const currentRoom = await roomService.getRoom(room.roomId);
          if (!currentRoom) return;

          const matchId = generateId();
          const playerIds = match.players.map(p => p.userId);

          currentRoom.status = 'IN_GAME' as any;
          currentRoom.matchId = matchId;
          await roomService.saveRoom(currentRoom);

          // Initialize game
          const gameState = await gameEngine.initializeMatch(
            matchId,
            room.roomId,
            playerIds,
            match.mode
          );

          // Track player match
          const redis = (await import('../config/redis')).default;
          for (const playerId of playerIds) {
            await redis.set(`match:player:${playerId}`, matchId, { EX: 3600 });
          }
          const { startMatchTimer } = await import('../gameplay/game.handler');
            startMatchTimer(io, matchId);

          // Notify all players game started
          io.to(room.roomId).emit(SOCKET_EVENTS.GAME_STARTED, {
            matchId: matchId,
            roomId: room.roomId,
          });

          // Send initial state to each player with matchId set
          for (const playerId of playerIds) {
            for (const [socketId, sock] of io.sockets.sockets) {
              const s = sock as any;
              if (s.userId === playerId) {
                s.matchId = matchId;
                const playerState = await gameStateManager.getPlayerStateWithNames(playerId, gameState);
                io.to(socketId).emit(SOCKET_EVENTS.GAME_INITIAL_STATE, playerState);
                logger.info('Sent initial state', { userId: playerId, matchId });
                break;
              }
            }
          }
        } catch (err) {
          logger.error('Error starting matched game', { error: err });
        }
      }, 3000);
    }
  } catch (error) {
    logger.error('Error processing queues', { error });
  }
};