import { Server } from 'socket.io';
import { AuthenticatedSocket } from '../websocket/socket.types';
import voiceService from './voice.service';
import { SOCKET_EVENTS } from '../utils/constants';
import logger from '../utils/logger';

/**
 * True when both players are in the same voice channel.
 *
 * Signalling is addressed by user id, and until this check existed nothing
 * verified the two were at the same table. A modified client could offer to
 * any user id on the server and open a peer connection to a stranger in
 * another match - an audio connection the target never agreed to. The relay
 * is cheap; the check has to happen here because the server is the only
 * party that knows the whole picture.
 */
const sameChannel = async (
  socket: AuthenticatedSocket,
  targetUserId: string
): Promise<boolean> => {
  const roomId = (socket as any).voiceRoomId;
  if (!roomId) return false;

  const voiceRoom = await voiceService.getVoiceRoom(roomId);
  if (!voiceRoom) return false;

  return voiceRoom.participants.some((p) => p.userId === targetUserId);
};

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

      // Drop any channel this socket is still in. Without this, joining a
      // second table left the socket subscribed to both.
      const previous = (socket as any).voiceRoomId;
      if (previous && previous !== roomId) {
        await voiceService.leaveVoiceRoom(previous, socket.userId);
        socket.to(`voice:${previous}`).emit(SOCKET_EVENTS.VOICE_LEFT, {
          userId: socket.userId,
        });
        socket.leave(`voice:${previous}`);
      }

      socket.join(roomId);
      socket.join(`voice:${roomId}`);
      (socket as any).roomId = roomId;
      (socket as any).voiceRoomId = roomId;

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
      io.to(`voice:${roomId}`).emit('voice.userJoined', {
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
      if (!socket.userId) return;

      const roomId = (socket as any).voiceRoomId ?? socket.roomId;
      if (!roomId) return;

      await voiceService.leaveVoiceRoom(roomId, socket.userId);

      socket.to(`voice:${roomId}`).emit(SOCKET_EVENTS.VOICE_LEFT, {
        userId: socket.userId,
      });

      // Actually leave the channel.
      //
      // The socket used to stay subscribed to `voice:<roomId>` for the life
      // of the connection, because nothing ever called socket.leave for it.
      // A player who finished a match and sat down at a different table kept
      // receiving the old table's join announcements, and two channels'
      // signalling arrived on one client.
      socket.leave(`voice:${roomId}`);
      (socket as any).voiceRoomId = undefined;

    } catch (error) {
      logger.error('Voice leave error', { error });
    }
  });

  // ─────────────────────────────────────────
  // SDP OFFER (from initiator to target)
  // ─────────────────────────────────────────

  socket.on(SOCKET_EVENTS.VOICE_OFFER, async (data: {
    targetUserId: string;
    offer: { sdp: string; type: string };
  }) => {
    try {
      if (!socket.userId || !data?.targetUserId || !data?.offer) return;

      if (!(await sameChannel(socket, data.targetUserId))) {
        logger.warn('Rejected cross-channel voice signalling', {
          from: socket.userId,
          to: data.targetUserId,
        });
        return;
      }

      // The personal room already reaches the target on any instance. The
      // extra local scan that used to follow delivered a second copy, and a
      // duplicated offer restarts negotiation on the receiving peer.
      io.to(`user:${data.targetUserId}`).emit(SOCKET_EVENTS.VOICE_OFFER, {
        fromUserId: socket.userId,
        fromUsername: socket.username,
        offer: data.offer,
      });

      logger.info('Voice offer relayed', {
        from: socket.userId,
        to: data.targetUserId
      });

    } catch (error) {
      logger.error('Voice offer error', { error });
    }
  });

  // ─────────────────────────────────────────
  // SDP ANSWER (response to offer)
  // ─────────────────────────────────────────

  socket.on(SOCKET_EVENTS.VOICE_ANSWER, async (data: {
    targetUserId: string;
    answer: { sdp: string; type: string };
  }) => {
    try {
      if (!socket.userId || !data?.targetUserId || !data?.answer) return;

      if (!(await sameChannel(socket, data.targetUserId))) {
        logger.warn('Rejected cross-channel voice signalling', {
          from: socket.userId,
          to: data.targetUserId,
        });
        return;
      }

      io.to(`user:${data.targetUserId}`).emit(SOCKET_EVENTS.VOICE_ANSWER, {
        fromUserId: socket.userId,
        answer: data.answer,
      });

      logger.info('Voice answer relayed', {
        from: socket.userId,
        to: data.targetUserId
      });

    } catch (error) {
      logger.error('Voice answer error', { error });
    }
  });

  // ─────────────────────────────────────────
  // ICE CANDIDATE (network info for connection)
  // ─────────────────────────────────────────

  socket.on(SOCKET_EVENTS.VOICE_ICE_CANDIDATE, async (data: {
    targetUserId: string;
    candidate: { candidate: string; sdpMid: string; sdpMLineIndex: number };
  }) => {
    try {
      if (!socket.userId || !data?.targetUserId || !data?.candidate) return;

      if (!(await sameChannel(socket, data.targetUserId))) {
        logger.warn('Rejected cross-channel voice signalling', {
          from: socket.userId,
          to: data.targetUserId,
        });
        return;
      }

      io.to(`user:${data.targetUserId}`).emit(SOCKET_EVENTS.VOICE_ICE_CANDIDATE, {
        fromUserId: socket.userId,
        candidate: data.candidate,
      });

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