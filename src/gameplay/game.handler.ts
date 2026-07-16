import { Server } from 'socket.io';
import { AuthenticatedSocket } from '../websocket/socket.types';
import gameEngine from './game.engine';
import gameStateManager from './game.state';
import rematchService from './rematch.service';
import roomService from '../rooms/room.service';
import { SOCKET_EVENTS } from '../utils/constants';
import { PlayCardInput, MatchStatus } from './game.types';
import { generateId } from '../utils/generateId';
import logger from '../utils/logger';

// ─────────────────────────────────────────
// AUTO TIMER TRACKING
// ─────────────────────────────────────────

const activeMatchTimers = new Set<string>();

export const startMatchTimer = (io: Server, matchId: string): void => {
  if (activeMatchTimers.has(matchId)) return;
  activeMatchTimers.add(matchId);

  logger.info('Started match timer', { matchId });

  const interval = setInterval(async () => {
    try {
      const state = await gameEngine.getMatchState(matchId);

      if (!state || state.status !== MatchStatus.RUNNING) {
        clearInterval(interval);
        activeMatchTimers.delete(matchId);
        logger.info('Stopped match timer', { matchId });
        return;
      }

      const elapsed = (Date.now() - state.timerStarted) / 1000;
      const currentPlayer = state.currentTurn;

      // Check if player has no playable card - auto-draw after 3 seconds
      const hasPlayable = gameEngine.hasPlayableCard(currentPlayer, state);

      // Auto-draw if timer expired OR if player has no playable cards (after brief pause)
      const shouldAutoDraw = elapsed >= 20 || (!hasPlayable && elapsed >= 3);

      if (shouldAutoDraw) {
        const newState = await gameEngine.handleTimeout(matchId);

        if (newState) {
          io.to(state.roomId).emit(SOCKET_EVENTS.TURN_CHANGED, {
            currentPlayer: newState.currentTurn,
            remainingTime: 20,
          });

          for (const playerId of newState.players) {
            for (const [socketId, sock] of io.sockets.sockets) {
              const s = sock as any;
              if (s.userId === playerId) {
                const playerState = await gameStateManager.getPlayerStateWithNames(playerId, newState);
                io.to(socketId).emit(SOCKET_EVENTS.GAME_SYNC_STATE, playerState);
                break;
              }
            }
          }

          logger.info('Auto-draw triggered', {
            matchId,
            playerId: currentPlayer,
            reason: hasPlayable ? 'timeout' : 'no_playable_card'
          });
        }
      }
    } catch (error) {
      logger.error('Timer check error', { error });
    }
  }, 1000);  // Check every 1 second instead of 3
};

export const stopMatchTimer = (matchId: string): void => {
  activeMatchTimers.delete(matchId);
};

// ─────────────────────────────────────────
// INITIALIZE GAME HANDLERS
// ─────────────────────────────────────────

export const initializeGameHandlers = (
  io: Server,
  socket: AuthenticatedSocket
): void => {

  socket.on(SOCKET_EVENTS.CARD_PLAY, async (data: PlayCardInput) => {
    try {
      if (!socket.userId || !socket.matchId) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'INVALID_MATCH',
          message: 'Not in a match.',
        });
        return;
      }

      if (!data?.cardId) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'INVALID_PAYLOAD',
          message: 'Card ID is required.',
        });
        return;
      }

      const { state, events } = await gameEngine.playCard(
        socket.matchId,
        socket.userId,
        data
      );

      const roomId = socket.roomId;
      if (!roomId) return;

      io.to(roomId).emit(SOCKET_EVENTS.PLAYER_PLAYED_CARD, {
        userId: socket.userId,
        cardId: data.cardId,
        currentColor: state.currentColor,
        currentValue: state.currentValue,
        direction: state.direction,
      });

      for (const playerId of state.players) {
        const playerSocketId = await getPlayerSocketId(io, playerId);
        if (playerSocketId) {
          const playerState = await gameStateManager.getPlayerStateWithNames(playerId, state);
          io.to(playerSocketId).emit(SOCKET_EVENTS.GAME_SYNC_STATE, playerState);
        }
      }

      if (state.status === MatchStatus.RUNNING) {
        io.to(roomId).emit(SOCKET_EVENTS.TURN_CHANGED, {
          currentPlayer: state.currentTurn,
          remainingTime: 20,
        });
      }

      if (events.includes('direction.changed')) {
        io.to(roomId).emit(SOCKET_EVENTS.DIRECTION_CHANGED, {
          direction: state.direction,
        });
      }

      if (events.includes('game.finished')) {
        stopMatchTimer(state.matchId);
        io.to(roomId).emit(SOCKET_EVENTS.GAME_FINISHED, {
          winner: state.winner,
          duration: Math.floor((Date.now() - state.startedAt) / 1000),
          totalTurns: state.totalTurns,
          matchId: state.matchId,
        });
      }

      socket.emit(SOCKET_EVENTS.CARD_ACCEPTED, {
        cardId: data.cardId,
        success: true,
      });

    } catch (error: any) {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: error.code || 'SERVER_ERROR',
        message: error.message || 'Failed to play card.',
      });
    }
  });

  socket.on(SOCKET_EVENTS.CARD_DRAW, async () => {
    try {
      if (!socket.userId || !socket.matchId) return;

      const { state, drawnCards } = await gameEngine.drawCard(
        socket.matchId,
        socket.userId
      );

      const roomId = socket.roomId;
      if (!roomId) return;

      socket.emit(SOCKET_EVENTS.PLAYER_DREW_CARD, {
        cards: drawnCards,
        count: drawnCards.length,
      });

      socket.to(roomId).emit(SOCKET_EVENTS.PLAYER_DREW_CARD, {
        userId: socket.userId,
        count: drawnCards.length,
      });

      for (const playerId of state.players) {
        const playerSocketId = await getPlayerSocketId(io, playerId);
        if (playerSocketId) {
          const playerState = await gameStateManager.getPlayerStateWithNames(playerId, state);
          io.to(playerSocketId).emit(SOCKET_EVENTS.GAME_SYNC_STATE, playerState);
        }
      }

      io.to(roomId).emit(SOCKET_EVENTS.TURN_CHANGED, {
        currentPlayer: state.currentTurn,
        remainingTime: 20,
      });

    } catch (error: any) {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: error.code || 'SERVER_ERROR',
        message: error.message || 'Failed to draw card.',
      });
    }
  });

  socket.on(SOCKET_EVENTS.GAME_SYNC_REQUEST, async () => {
    try {
      if (!socket.userId) return;

      if (!socket.matchId) {
        const redis = (await import('../config/redis')).default;
        const matchId = await redis.get(`match:player:${socket.userId}`);
        if (matchId) {
          socket.matchId = matchId;
        } else {
          return;
        }
      }

      const state = await gameEngine.getMatchState(socket.matchId);
      if (!state) return;

      if (state.roomId && !socket.rooms.has(state.roomId)) {
        socket.join(state.roomId);
        (socket as any).roomId = state.roomId;
      }

      const playerState = await gameStateManager.getPlayerStateWithNames(
        socket.userId,
        state
      );

      socket.emit(SOCKET_EVENTS.GAME_SYNC_STATE, playerState);

    } catch (error) {
      logger.error('Sync request error', { error });
    }
  });

  socket.on(SOCKET_EVENTS.SURRENDER, async () => {
    try {
      if (!socket.userId || !socket.matchId || !socket.roomId) return;

      const state = await gameEngine.getMatchState(socket.matchId);
      if (!state) return;

      const remainingPlayers = state.players.filter(p => p !== socket.userId);

      if (remainingPlayers.length >= 1) {
        state.winner = remainingPlayers[0];
        state.status = MatchStatus.FINISHED;
        state.hands[socket.userId] = [];
        await gameStateManager.saveState(state);

        await (gameEngine as any).finalizeMatch(state);
        stopMatchTimer(state.matchId);

        io.to(socket.roomId).emit(SOCKET_EVENTS.GAME_FINISHED, {
          winner: state.winner,
          duration: Math.floor((Date.now() - state.startedAt) / 1000),
          totalTurns: state.totalTurns,
          matchId: state.matchId,
          surrenderedBy: socket.userId,
        });

        const redis = (await import('../config/redis')).default;
        for (const playerId of state.players) {
          await redis.del(`match:player:${playerId}`);
          await redis.del(`player:room:${playerId}`);
        }
      }

    } catch (error) {
      logger.error('Surrender error', { error });
    }
  });

  socket.on(SOCKET_EVENTS.REMATCH_REQUEST, async () => {
    try {
      if (!socket.userId || !socket.matchId || !socket.roomId) return;
      await rematchService.requestRematch(socket.matchId, socket.userId);
      io.to(socket.roomId).emit(SOCKET_EVENTS.REMATCH_REQUEST, {
        userId: socket.userId,
      });
    } catch (error) {
      logger.error('Rematch request error', { error });
    }
  });

  socket.on(SOCKET_EVENTS.REMATCH_ACCEPT, async () => {
    try {
      if (!socket.userId || !socket.matchId || !socket.roomId) return;

      await rematchService.acceptRematch(socket.matchId, socket.userId);

      const room = await roomService.getRoom(socket.roomId);
      if (!room) return;

      const playerIds = room.players.map(p => p.userId);
      const allAccepted = await rematchService.allPlayersAccepted(socket.matchId, playerIds);

      if (allAccepted) {
        const newMatchId = generateId();
        await rematchService.clearRematch(socket.matchId);

        const gameState = await gameEngine.initializeMatch(
          newMatchId,
          socket.roomId,
          playerIds,
          room.gameMode
        );

        startMatchTimer(io, newMatchId);

        io.to(socket.roomId).emit(SOCKET_EVENTS.REMATCH_STARTED, {
          matchId: newMatchId,
        });

        for (const playerId of playerIds) {
          const playerSocketId = await getPlayerSocketId(io, playerId);
          if (playerSocketId) {
            const playerSocket = io.sockets.sockets.get(playerSocketId);
            if (playerSocket) (playerSocket as any).matchId = newMatchId;
            const playerState = await gameStateManager.getPlayerStateWithNames(playerId, gameState);
            io.to(playerSocketId).emit(SOCKET_EVENTS.GAME_INITIAL_STATE, playerState);
          }
        }
      } else {
        io.to(socket.roomId).emit(SOCKET_EVENTS.REMATCH_ACCEPT, {
          userId: socket.userId,
        });
      }
    } catch (error) {
      logger.error('Rematch accept error', { error });
    }
  });

  socket.on(SOCKET_EVENTS.REMATCH_DECLINE, async () => {
    try {
      if (!socket.userId || !socket.matchId || !socket.roomId) return;
      await rematchService.declineRematch(socket.matchId, socket.userId);
      io.to(socket.roomId).emit(SOCKET_EVENTS.REMATCH_DECLINE, {
        userId: socket.userId,
      });
    } catch (error) {
      logger.error('Rematch decline error', { error });
    }
  });

  socket.on(SOCKET_EVENTS.QUICK_CHAT, async (data: { messageType: string }) => {
    try {
      if (!socket.userId || !socket.roomId || !data?.messageType) return;
      io.to(socket.roomId).emit(SOCKET_EVENTS.QUICK_CHAT, {
        userId: socket.userId,
        username: socket.username,
        messageType: data.messageType,
        timestamp: Date.now(),
      });
    } catch (error) {
      logger.error('Quick chat error', { error });
    }
  });

  socket.on(SOCKET_EVENTS.EMOTE_SEND, async (data: { emote: string }) => {
    try {
      if (!socket.userId || !socket.roomId || !data?.emote) return;
      io.to(socket.roomId).emit(SOCKET_EVENTS.EMOTE_RECEIVED, {
        userId: socket.userId,
        username: socket.username,
        emote: data.emote,
        timestamp: Date.now(),
      });
    } catch (error) {
      logger.error('Emote error', { error });
    }
  });

  socket.on('uno.call', async () => {
    try {
      if (!socket.userId || !socket.matchId) return;

      const state = await gameEngine.getMatchState(socket.matchId);
      if (!state) return;

      const myHand = state.hands[socket.userId];
      if (!myHand || myHand.length !== 1) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'INVALID_UNO',
          message: 'You can only call UNO with 1 card left!',
        });
        return;
      }

      if (!state.unoCalledBy) state.unoCalledBy = [];
      if (!state.unoCalledBy.includes(socket.userId)) {
        state.unoCalledBy.push(socket.userId);
      }

      await gameStateManager.saveState(state);

      io.to(socket.roomId!).emit('uno.called', {
        userId: socket.userId,
        username: socket.username,
      });
    } catch (error) {
      logger.error('UNO call error', { error });
    }
  });
};

const getPlayerSocketId = async (
  io: Server,
  userId: string
): Promise<string | null> => {
  for (const [socketId, socket] of io.sockets.sockets) {
    const s = socket as AuthenticatedSocket;
    if (s.userId === userId) return socketId;
  }
  return null;
};