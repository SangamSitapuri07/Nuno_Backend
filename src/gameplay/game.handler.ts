import { Server } from 'socket.io';
import { AuthenticatedSocket } from '../websocket/socket.types';
import gameEngine from './game.engine';
import gameStateManager from './game.state';
import rematchService from './rematch.service';
import roomService from '../rooms/room.service';
import friendsService from '../friends/friends.service';
import redisClient from '../config/redis';
import { getLocalSocket } from '../websocket/socket.session';
import { SOCKET_EVENTS } from '../utils/constants';
import { PlayCardInput, MatchStatus } from './game.types';
import { generateId } from '../utils/generateId';
import logger from '../utils/logger';

// ─────────────────────────────────────────
// AUTO TIMER TRACKING
// ─────────────────────────────────────────

const activeMatchTimers = new Set<string>();

/**
 * Puts a room back into a playable state once its match has ended.
 *
 * Without this the room stays IN_GAME and every player keeps a
 * `match:player:` key, so joinRoom refuses new arrivals and a rematch can
 * never be started in the same room.
 */
const releaseRoomAfterMatch = async (
  io: Server,
  roomId: string,
  playerIds: string[]
): Promise<void> => {
  try {
    const redis = (await import('../config/redis')).default;
    const roomService = (await import('../rooms/room.service')).default;

    // Everyone leaves the room when the match ends.
    //
    // Only `match:player:` used to be cleared, so `player:room:` outlived the
    // game and friends saw "In Lobby" for someone sitting idle on the results
    // screen. Worse, the stale key made the next Create Room or Join Room
    // fail with ALREADY_IN_ROOM until its hour-long TTL expired.
    //
    // Emptying the room destroys it, which is correct: the table is finished
    // and a rematch now re-forms one rather than reusing this.
    for (const playerId of playerIds) {
      await redis.del(`match:player:${playerId}`);
    }

    const room = await roomService.getRoom(roomId);

    for (const playerId of playerIds) {
      try {
        await roomService.leaveRoom(playerId);
      } catch (error) {
        logger.error('Failed to remove a player from the finished room', {
          userId: playerId,
          roomId,
          error,
        });
      }
    }

    // Tell anyone still listening that the table has broken up, using the
    // pre-departure snapshot so the payload is not empty.
    if (room) {
      room.status = 'WAITING' as any;
      for (const player of room.players) player.isReady = false;
      io.to(roomId).emit(SOCKET_EVENTS.ROOM_UPDATED, { room });
    }

    // Friends should see them as available again, not stuck in a lobby.
    for (const playerId of playerIds) {
      await friendsService.broadcastUserStatus(io, playerId);
    }
  } catch (error) {
    logger.error('Failed to release the room after a match', { error, roomId });
  }
};

export const startMatchTimer = (io: Server, matchId: string): void => {
  if (activeMatchTimers.has(matchId)) return;
  activeMatchTimers.add(matchId);

  logger.info('Started match timer', { matchId });

  // When this match may next need attention, as a millisecond timestamp.
  //
  // The tick used to read the whole match state from the store every second
  // purely to look at a clock, which is one network round trip per match per
  // second - the single largest source of load in the server, and it scales
  // with the number of tables rather than with anything players are doing.
  //
  // A turn is only actionable at two moments: 3s in (auto-draw when the hand
  // has nothing playable) and 20s in (the turn expires). Between those there
  // is nothing to decide, so the state is not fetched at all. Skipped ticks
  // cost a comparison against a number held in this process.
  let nextCheckAt = 0;

  const interval = setInterval(async () => {
    try {
      if (Date.now() < nextCheckAt) return;

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

      if (!shouldAutoDraw) {
        // Nothing to do until the next threshold this turn can cross.
        // Re-read a little early so a turn that started mid-tick is not
        // acted on late.
        const nextThreshold = elapsed < 3 ? 3 : 20;
        const waitMs = Math.max(250, (nextThreshold - elapsed) * 1000 - 250);
        nextCheckAt = Date.now() + waitMs;
        return;
      }

      // Acting now, so the next turn is examined from scratch.
      nextCheckAt = 0;

      {
        const newState = await gameEngine.handleTimeout(matchId);

        if (newState) {
          io.to(state.roomId).emit(SOCKET_EVENTS.TURN_CHANGED, {
            currentPlayer: newState.currentTurn,
            remainingTime: 20,
          });

          // Addressed by the player's own room rather than by scanning every
          // socket on the server. The scan was O(all connected players) for
          // each player at the table - quadratic in the worst case, and it
          // only ever found sockets belonging to this instance.
          for (const playerId of newState.players) {
            const playerState = await gameStateManager.getPlayerStateWithNames(playerId, newState);
            io.to(`user:${playerId}`).emit(SOCKET_EVENTS.GAME_SYNC_STATE, playerState);
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

        // Hand the room back so it can be played in again.
        //
        // It was left IN_GAME forever, which made a rematch impossible: the
        // room stayed locked and nobody could rejoin it either.
        await releaseRoomAfterMatch(io, roomId, state.players);

        for (const playerId of state.players) {
          await friendsService.broadcastUserStatus(io, playerId);
        }
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

  // ─────────────────────────────────────────
  // JUMP IN  (house rule)
  // ─────────────────────────────────────────

  socket.on(SOCKET_EVENTS.CARD_JUMP_IN, async (data: PlayCardInput) => {
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

      const { state, events } = await gameEngine.jumpIn(
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
        jumpedIn: true,
      });

      for (const playerId of state.players) {
        const playerSocketId = await getPlayerSocketId(io, playerId);
        if (playerSocketId) {
          const playerState =
            await gameStateManager.getPlayerStateWithNames(playerId, state);
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

        await releaseRoomAfterMatch(io, roomId, state.players);

        for (const playerId of state.players) {
          await friendsService.broadcastUserStatus(io, playerId);
        }
      }

      socket.emit(SOCKET_EVENTS.CARD_ACCEPTED, {
        cardId: data.cardId,
        success: true,
      });
    } catch (error: any) {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: error.code || 'SERVER_ERROR',
        message: error.message || 'Failed to jump in.',
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
          await friendsService.broadcastUserStatus(io, playerId);
        }
      }

    } catch (error) {
      logger.error('Surrender error', { error });
    }
  });

  /**
   * Resolves the room a rematch vote belongs to.
   *
   * `socket.roomId` is set when the match starts and survives on a live
   * socket, but a client that reconnected between the results screen and the
   * button press has none - and it cannot be rebuilt from `player:room:`
   * either, because finalizeMatch deletes that too. The room record itself
   * outlives the match, so it is found by scanning for the one this player is
   * still listed in, and the socket is repaired on the way through.
   */
  const resolveRematchRoom = async (): Promise<string | null> => {
    if (socket.roomId) return socket.roomId;

    const roomId = await roomService.findRoomContaining(socket.userId!);
    if (!roomId) return null;

    socket.roomId = roomId;
    if (!socket.rooms.has(roomId)) socket.join(roomId);
    return roomId;
  };

  socket.on(SOCKET_EVENTS.REMATCH_REQUEST, async () => {
    try {
      // Deliberately NOT gated on socket.matchId: the match is over by the
      // time anyone votes, so requiring its id is requiring something that
      // has already been deleted.
      if (!socket.userId) return;

      const roomId = await resolveRematchRoom();
      if (!roomId) return;

      await rematchService.accept(roomId, socket.userId);
      io.to(roomId).emit(SOCKET_EVENTS.REMATCH_REQUEST, {
        userId: socket.userId,
      });
    } catch (error) {
      logger.error('Rematch request error', { error });
    }
  });

  socket.on(SOCKET_EVENTS.REMATCH_ACCEPT, async () => {
    try {
      if (!socket.userId) return;

      const roomId = await resolveRematchRoom();
      if (!roomId) return;

      const room = await roomService.getRoom(roomId);
      if (!room) return;

      // A rematch is only for the players still sitting here. Anyone who
      // went back to the menu has left the room, so they are not counted and
      // cannot hold the vote open.
      const playerIds = room.players.map(p => p.userId);

      // The voter must actually be in the room - a stale socket could
      // otherwise vote its way into a game it is no longer part of.
      if (!playerIds.includes(socket.userId)) return;

      await rematchService.accept(roomId, socket.userId);

      // Always broadcast the vote, including the one that completes the set.
      // Previously the deciding vote was swallowed by the else-branch, so the
      // tally on everyone's results screen stopped one short of the total.
      io.to(roomId).emit(SOCKET_EVENTS.REMATCH_ACCEPT, {
        userId: socket.userId,
      });

      // Two players minimum, enforced inside allAccepted: "everyone agreed"
      // is trivially true of a party of one, which would deal a game against
      // nobody.
      if (!(await rematchService.allAccepted(roomId, playerIds))) return;

      const newMatchId = generateId();
      await rematchService.clear(roomId);

      const gameState = await gameEngine.initializeMatch(
        newMatchId,
        roomId,
        playerIds,
        room.gameMode
      );

      // The room is playing again, so it must not accept newcomers midway.
      room.status = 'IN_GAME' as any;
      room.matchId = newMatchId;
      for (const player of room.players) player.isReady = false;
      await (roomService as any).saveRoom(room);

      startMatchTimer(io, newMatchId);

      // Re-point every socket at the new match BEFORE telling anyone it
      // started.
      //
      // The client reacts to rematch.started by clearing its state and
      // asking for a sync. That request used to arrive while this loop was
      // still awaiting getPlayerSocketId, so socket.matchId was unset and
      // match:player had been deleted when the previous match ended - the
      // sync handler found nothing, returned silently, and the player sat on
      // a syncing screen that never resolved. Doing the bookkeeping first
      // means a sync arriving at any point after the announcement is
      // answerable.
      const sockets = new Map<string, string>();
      for (const playerId of playerIds) {
        const playerSocketId = await getPlayerSocketId(io, playerId);
        if (!playerSocketId) continue;

        sockets.set(playerId, playerSocketId);

        const playerSocket = io.sockets.sockets.get(playerSocketId);
        if (playerSocket) {
          (playerSocket as any).matchId = newMatchId;
          (playerSocket as any).roomId = roomId;
        }

        // Also the shared key, so a sync from a socket this instance does
        // not own can still resolve the match.
        //
        // The TTL matters: this is the only match:player write that lacked
        // one, so a rematch left a key with no expiry behind. Every other
        // writer uses an hour, which is longer than any match runs.
        await redisClient.set(`match:player:${playerId}`, newMatchId, {
          EX: 3600,
        });
      }

      io.to(roomId).emit(SOCKET_EVENTS.REMATCH_STARTED, {
        matchId: newMatchId,
      });

      for (const [playerId, playerSocketId] of sockets) {
        const playerState = await gameStateManager.getPlayerStateWithNames(playerId, gameState);
        io.to(playerSocketId).emit(SOCKET_EVENTS.GAME_INITIAL_STATE, playerState);
      }
    } catch (error) {
      logger.error('Rematch accept error', { error });
    }
  });

  socket.on(SOCKET_EVENTS.REMATCH_DECLINE, async () => {
    try {
      if (!socket.userId) return;

      const roomId = await resolveRematchRoom();
      if (!roomId) return;

      await rematchService.decline(roomId, socket.userId);
      io.to(roomId).emit(SOCKET_EVENTS.REMATCH_DECLINE, {
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
  const socket = getLocalSocket(io, userId);
  return socket ? socket.id : null;
};