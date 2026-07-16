import redisClient from '../config/redis';
import logger from '../utils/logger';
import { VoiceRoom, VoiceParticipant } from './voice.types';

const VOICE_ROOM_EXPIRY = 7200;

export class VoiceService {

  // ─────────────────────────────────────────
  // CREATE VOICE ROOM
  // ─────────────────────────────────────────

  async createVoiceRoom(roomId: string): Promise<VoiceRoom> {
    const voiceRoom: VoiceRoom = {
      roomId,
      participants: [],
      createdAt: Date.now(),
    };

    await this.saveVoiceRoom(voiceRoom);

    logger.info('Voice room created', { roomId });

    return voiceRoom;
  }

  // ─────────────────────────────────────────
  // JOIN VOICE ROOM
  // ─────────────────────────────────────────

  async joinVoiceRoom(
    roomId: string,
    userId: string,
    username: string,
    socketId: string
  ): Promise<VoiceRoom> {
    let voiceRoom = await this.getVoiceRoom(roomId);

    if (!voiceRoom) {
      voiceRoom = await this.createVoiceRoom(roomId);
    }

    // Check if already in room
    const existing = voiceRoom.participants.find((p) => p.userId === userId);
    if (existing) {
      existing.socketId = socketId;
      await this.saveVoiceRoom(voiceRoom);
      return voiceRoom;
    }

    const participant: VoiceParticipant = {
      userId,
      username,
      socketId,
      isMuted: false,
      isSpeaking: false,
      joinedAt: Date.now(),
    };

    voiceRoom.participants.push(participant);
    await this.saveVoiceRoom(voiceRoom);

    logger.info('Player joined voice room', { roomId, userId });

    return voiceRoom;
  }

  // ─────────────────────────────────────────
  // LEAVE VOICE ROOM
  // ─────────────────────────────────────────

  async leaveVoiceRoom(
    roomId: string,
    userId: string
  ): Promise<VoiceRoom | null> {
    const voiceRoom = await this.getVoiceRoom(roomId);
    if (!voiceRoom) return null;

    voiceRoom.participants = voiceRoom.participants.filter(
      (p) => p.userId !== userId
    );

    if (voiceRoom.participants.length === 0) {
      await this.deleteVoiceRoom(roomId);
      return null;
    }

    await this.saveVoiceRoom(voiceRoom);

    logger.info('Player left voice room', { roomId, userId });

    return voiceRoom;
  }

  // ─────────────────────────────────────────
  // SET MUTE STATUS
  // ─────────────────────────────────────────

  async setMuteStatus(
    roomId: string,
    userId: string,
    isMuted: boolean
  ): Promise<void> {
    const voiceRoom = await this.getVoiceRoom(roomId);
    if (!voiceRoom) return;

    const participant = voiceRoom.participants.find(
      (p) => p.userId === userId
    );

    if (participant) {
      participant.isMuted = isMuted;
      await this.saveVoiceRoom(voiceRoom);
    }
  }

  // ─────────────────────────────────────────
  // GET VOICE ROOM
  // ─────────────────────────────────────────

  async getVoiceRoom(roomId: string): Promise<VoiceRoom | null> {
    const data = await redisClient.get(`voice:${roomId}`);
    if (!data) return null;
    return JSON.parse(data);
  }

  // ─────────────────────────────────────────
  // GET PARTICIPANT SOCKET ID
  // ─────────────────────────────────────────

  async getParticipantSocketId(
    roomId: string,
    userId: string
  ): Promise<string | null> {
    const voiceRoom = await this.getVoiceRoom(roomId);
    if (!voiceRoom) return null;

    const participant = voiceRoom.participants.find(
      (p) => p.userId === userId
    );

    return participant?.socketId || null;
  }

  // ─────────────────────────────────────────
  // SAVE VOICE ROOM
  // ─────────────────────────────────────────

  private async saveVoiceRoom(voiceRoom: VoiceRoom): Promise<void> {
    await redisClient.set(
      `voice:${voiceRoom.roomId}`,
      JSON.stringify(voiceRoom),
      { EX: VOICE_ROOM_EXPIRY }
    );
  }

  // ─────────────────────────────────────────
  // DELETE VOICE ROOM
  // ─────────────────────────────────────────

  private async deleteVoiceRoom(roomId: string): Promise<void> {
    await redisClient.del(`voice:${roomId}`);
    logger.info('Voice room deleted', { roomId });
  }
}

export default new VoiceService();