import { Server } from 'socket.io';
import { AuthenticatedSocket } from '../websocket/socket.types';
import roomService from './room.service';
import friendsService from '../friends/friends.service';
import { getLocalSocket } from '../websocket/socket.session';
import { SOCKET_EVENTS } from '../utils/constants';
import { CreateRoomInput, JoinRoomInput, RoomStatus } from './room.types';
import logger from '../utils/logger';

export const initializeRoomHandlers = (
  io: Server,
  socket: AuthenticatedSocket
): void => {

  socket.on(SOCKET_EVENTS.ROOM_CREATE, async (data: CreateRoomInput) => {
    try {
      const room = await roomService.createRoom(
    socket.userId,
    socket.username,
    socket.id,
    data || { gameMode: 'PRIVATE', maxPlayers: 4, voiceEnabled: true }
);

      socket.join(room.roomId);
      socket.roomId = room.roomId;

      socket.emit(SOCKET_EVENTS.ROOM_CREATED, {
        roomId: room.roomId,
        roomCode: room.roomCode,
        room,
      });

      socket.emit(SOCKET_EVENTS.ROOM_UPDATED, { room });

      await friendsService.broadcastUserStatus(io, socket.userId);

    } catch (error: any) {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: error.code || 'SERVER_ERROR',
        message: error.message || 'Failed to create room.',
      });
    }
  });

  socket.on(SOCKET_EVENTS.ROOM_JOIN, async (data: JoinRoomInput) => {
    try {
      if (!data?.roomCode) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'INVALID_PAYLOAD',
          message: 'Room code is required.',
        });
        return;
      }

      const room = await roomService.joinRoom(
        socket.userId,
        socket.username,
        socket.id,
        data
      );

      socket.join(room.roomId);
      socket.roomId = room.roomId;

      socket.emit(SOCKET_EVENTS.ROOM_JOINED, { room });
      io.to(room.roomId).emit(SOCKET_EVENTS.ROOM_UPDATED, { room });

      await friendsService.broadcastUserStatus(io, socket.userId);

    } catch (error: any) {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: error.code || 'SERVER_ERROR',
        message: error.message || 'Failed to join room.',
      });
    }
  });

  socket.on(SOCKET_EVENTS.ROOM_LEAVE, async () => {
    try {
      const roomId = socket.roomId;
      const room = await roomService.leaveRoom(socket.userId);

      if (roomId) {
        socket.leave(roomId);
        socket.roomId = undefined;

        if (room) {
          io.to(roomId).emit(SOCKET_EVENTS.ROOM_UPDATED, { room });
          if (room.hostId !== socket.userId) {
            io.to(roomId).emit(SOCKET_EVENTS.ROOM_HOST_CHANGED, {
              newHost: room.hostId,
            });
          }
        }
      }

      socket.emit('room.left', { success: true });
      await friendsService.broadcastUserStatus(io, socket.userId);

    } catch (error: any) {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: error.code || 'SERVER_ERROR',
        message: error.message || 'Failed to leave room.',
      });
    }
  });

  socket.on('room.ready', async (data: { isReady: boolean }) => {
    try {
      const room = await roomService.setReadyStatus(
        socket.userId,
        data?.isReady ?? true
      );

      if (!room) return;

      // Readiness no longer starts the match on its own. The host presses
      // START, which is the convention players expect and which stops a
      // match beginning the instant the last person happens to tap ready.
      io.to(room.roomId).emit(SOCKET_EVENTS.ROOM_UPDATED, { room });

    } catch (error: any) {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: error.code || 'SERVER_ERROR',
        message: error.message || 'Failed to update ready status.',
      });
    }
  });

  // ═══ START MATCH (host only) ═══
  socket.on(SOCKET_EVENTS.ROOM_START, async () => {
    try {
      const room = await roomService.getPlayerRoom(socket.userId);
      if (!room) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'ROOM_NOT_FOUND',
          message: 'You are not in a room.',
        });
        return;
      }

      if (room.hostId !== socket.userId) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'HOST_ONLY_ACTION',
          message: 'Only the host can start the match.',
        });
        return;
      }

      if (room.players.length < 2) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'NOT_ENOUGH_PLAYERS',
          message: 'At least 2 players are needed to start.',
        });
        return;
      }

      // The host is counted as ready implicitly - they are the one starting -
      // so only the guests must have confirmed.
      const guestsReady = room.players
        .filter((p) => p.userId !== room.hostId)
        .every((p) => p.isReady);

      if (!guestsReady) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'PLAYERS_NOT_READY',
          message: 'Every player must be ready first.',
        });
        return;
      }

      if (room.status === RoomStatus.COUNTDOWN ||
          room.status === RoomStatus.IN_GAME) {
        return;
      }

      room.status = RoomStatus.COUNTDOWN;
      await roomService.saveRoom(room);
      io.to(room.roomId).emit(SOCKET_EVENTS.ROOM_UPDATED, { room });
      startCountdown(io, room.roomId);

    } catch (error: any) {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: error.code || 'SERVER_ERROR',
        message: error.message || 'Failed to start the match.',
      });
    }
  });

  socket.on('room.kick', async (data: { targetUserId: string }) => {
    try {
      if (!data?.targetUserId) return;

      const room = await roomService.kickPlayer(
        socket.userId,
        data.targetUserId
      );

      if (!room) return;

      io.to(room.roomId).emit(SOCKET_EVENTS.ROOM_UPDATED, { room });

      io.to(`user:${data.targetUserId}`).emit('room.kicked', {
        reason: 'Kicked by host.',
      });
      const targetSocket = findSocketByUserId(io, data.targetUserId);
      targetSocket?.leave(room.roomId);

      await friendsService.broadcastUserStatus(io, data.targetUserId);

    } catch (error: any) {
      socket.emit(SOCKET_EVENTS.ERROR, {
        code: error.code || 'SERVER_ERROR',
        message: error.message || 'Failed to kick player.',
      });
    }
  });
};

const startCountdown = (io: Server, roomId: string): void => {
  let count = 10;

  const interval = setInterval(async () => {
    const roomService = (await import('./room.service')).default;
    const room = await roomService.getRoom(roomId);
    if (!room) {
      clearInterval(interval);
      return;
    }

    if (room.players.length < 2) {
      clearInterval(interval);
      io.to(roomId).emit(SOCKET_EVENTS.ROOM_COUNTDOWN_CANCELLED, {
        reason: 'Need at least 2 players.',
      });
      return;
    }

    // Mirrors the START check: the host is implicitly ready, so only the
    // guests are required to still be confirmed. Using isAllReady() here
    // would cancel instantly, because the host never marks themselves ready.
    const guestsReady = room.players
      .filter((p) => p.userId !== room.hostId)
      .every((p) => p.isReady);

    if (!guestsReady) {
      clearInterval(interval);
      io.to(roomId).emit(SOCKET_EVENTS.ROOM_COUNTDOWN_CANCELLED, {
        reason: 'Player unreadied.',
      });
      return;
    }

    if (count <= 0) {
      clearInterval(interval);

      const gameEngine = (await import('../gameplay/game.engine')).default;
      const gameStateManager = (await import('../gameplay/game.state')).default;
      const { generateId } = await import('../utils/generateId');
      const { startMatchTimer } = await import('../gameplay/game.handler');

      const matchId = generateId();
      const playerIds = room.players.map(p => p.userId);

      room.status = 'IN_GAME' as any;
      room.matchId = matchId;
      await roomService.saveRoom(room);

      const gameState = await gameEngine.initializeMatch(
        matchId,
        room.roomId,
        playerIds,
        room.gameMode
      );

      // Start auto-draw timer for this match
      startMatchTimer(io, matchId);

      io.to(roomId).emit(SOCKET_EVENTS.GAME_STARTED, {
        matchId,
        roomId: room.roomId,
      });

      const redis = (await import('../config/redis')).default;
      for (const playerId of playerIds) {
        await redis.set(`match:player:${playerId}`, matchId, { EX: 3600 });
      }

      for (const playerId of playerIds) {
        // O(1) via the personal room rather than walking every socket on the
        // server once per player.
        const sock = getLocalSocket(io, playerId);
        if (sock) sock.matchId = matchId;

        const playerState = await gameStateManager.getPlayerStateWithNames(playerId, gameState);
        io.to(`user:${playerId}`).emit(SOCKET_EVENTS.GAME_INITIAL_STATE, playerState);

        await friendsService.broadcastUserStatus(io, playerId);
      }
      return;
    }

    io.to(roomId).emit(SOCKET_EVENTS.ROOM_COUNTDOWN, { count });
    count--;

  }, 1000);
};

/// Local lookup only. Prefer `io.to(`user:${id}`).emit(...)` for anything
/// that must reach a player regardless of which instance serves them.
const findSocketByUserId = (io: Server, userId: string): any =>
  getLocalSocket(io, userId);