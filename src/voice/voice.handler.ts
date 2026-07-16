import { Server } from 'socket.io';
import { AuthenticatedSocket } from '../websocket/socket.types';
import voiceService from './voice.service';
import { SOCKET_EVENTS } from '../utils/constants';
import logger from '../utils/logger';

export const initializeVoiceHandlers = (
  io: Server,
  socket: AuthenticatedSocket
): void => {

  // ─────────────────────────────────────────
  // JOIN VOICE ROOM
  // ─────────────────────────────────────────

  socket.on(SOCKET_EVENTS.VOICE_JOIN, async (data: { roomId: string }) => {
    try {
      if (!socket.userId) return;

      const roomId = data?.roomId || socket.roomId;
      if (!roomId) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'INVALID_ROOM',
          message: 'Room ID is required.',
        });
        return;
      }

      const voiceRoom = await voiceService.joinVoiceRoom(
        roomId,
        socket.userId,
        socket.username,
        socket.id
      );

      // Send list of existing participants to the joining player
      const otherParticipants = voiceRoom.participants
        .filter(p => p.userId !== socket.userId)
        .map(p => ({
          userId: p.userId,
          username: p.username,
          socketId: p.socketId
        }));

      socket.emit(SOCKET_EVENTS.VOICE_JOINED, {
        roomId,
        yourId: socket.userId,
        existingParticipants: otherParticipants
      });

      // Notify existing participants that a new user joined
      socket.to(roomId).emit('voice.userJoined', {
        userId: socket.userId,
        username: socket.username,
        socketId: socket.id
      });

      logger.info('Voice room joined', {
        userId: socket.userId,
        roomId,
        totalParticipants: voiceRoom.participants.length
      });

    } catch (error: any) {
      logger.error('Voice join error', { error });
    }
  });

  // ─────────────────────────────────────────
  // LEAVE VOICE ROOM
  // ─────────────────────────────────────────

  socket.on(SOCKET_EVENTS.VOICE_LEAVE, async () => {
    try {
      if (!socket.userId || !socket.roomId) return;

      await voiceService.leaveVoiceRoom(socket.roomId, socket.userId);

      socket.to(socket.roomId).emit(SOCKET_EVENTS.VOICE_LEFT, {
        userId: socket.userId,
      });

    } catch (error) {
      logger.error('Voice leave error', { error });
    }
  });

  // ─────────────────────────────────────────
  // SDP OFFER (from initiator to target)
  // ─────────────────────────────────────────

  socket.on(SOCKET_EVENTS.VOICE_OFFER, async (data: {
    targetUserId: string;
    sdp: string;
  }) => {
    try {
      if (!socket.userId || !data?.targetUserId || !data?.sdp) return;

      // Find target socket
      let targetSocketId: string | null = null;
      for (const [id, s] of io.sockets.sockets) {
        if ((s as any).userId === data.targetUserId) {
          targetSocketId = id;
          break;
        }
      }

      if (targetSocketId) {
        io.to(targetSocketId).emit(SOCKET_EVENTS.VOICE_OFFER, {
          fromUserId: socket.userId,
          fromUsername: socket.username,
          sdp: data.sdp,
        });
        logger.info('Voice offer relayed', {
          from: socket.userId,
          to: data.targetUserId
        });
      }

    } catch (error) {
      logger.error('Voice offer error', { error });
    }
  });

  // ─────────────────────────────────────────
  // SDP ANSWER (response to offer)
  // ─────────────────────────────────────────

  socket.on(SOCKET_EVENTS.VOICE_ANSWER, async (data: {
    targetUserId: string;
    sdp: string;
  }) => {
    try {
      if (!socket.userId || !data?.targetUserId || !data?.sdp) return;

      let targetSocketId: string | null = null;
      for (const [id, s] of io.sockets.sockets) {
        if ((s as any).userId === data.targetUserId) {
          targetSocketId = id;
          break;
        }
      }

      if (targetSocketId) {
        io.to(targetSocketId).emit(SOCKET_EVENTS.VOICE_ANSWER, {
          fromUserId: socket.userId,
          sdp: data.sdp,
        });
        logger.info('Voice answer relayed', {
          from: socket.userId,
          to: data.targetUserId
        });
      }

    } catch (error) {
      logger.error('Voice answer error', { error });
    }
  });

  // ─────────────────────────────────────────
  // ICE CANDIDATE (network info for connection)
  // ─────────────────────────────────────────

  socket.on(SOCKET_EVENTS.VOICE_ICE_CANDIDATE, async (data: {
    targetUserId: string;
    candidate: string;
    sdpMid: string;
    sdpMLineIndex: number;
  }) => {
    try {
      if (!socket.userId || !data?.targetUserId) return;

      let targetSocketId: string | null = null;
      for (const [id, s] of io.sockets.sockets) {
        if ((s as any).userId === data.targetUserId) {
          targetSocketId = id;
          break;
        }
      }

      if (targetSocketId) {
        io.to(targetSocketId).emit(SOCKET_EVENTS.VOICE_ICE_CANDIDATE, {
          fromUserId: socket.userId,
          candidate: data.candidate,
          sdpMid: data.sdpMid,
          sdpMLineIndex: data.sdpMLineIndex,
        });
      }

    } catch (error) {
      logger.error('ICE candidate error', { error });
    }
  });

  // ─────────────────────────────────────────
  // MUTE / UNMUTE
  // ─────────────────────────────────────────

  socket.on('voice.mute', async (data: { isMuted: boolean }) => {
    try {
      if (!socket.userId || !socket.roomId) return;

      await voiceService.setMuteStatus(
        socket.roomId,
        socket.userId,
        data?.isMuted ?? true
      );

      socket.to(socket.roomId).emit('voice.muteChanged', {
        userId: socket.userId,
        isMuted: data?.isMuted ?? true,
      });

    } catch (error) {
      logger.error('Mute error', { error });
    }
  });
};