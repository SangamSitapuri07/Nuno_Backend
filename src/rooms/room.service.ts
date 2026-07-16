import redisClient from '../config/redis';
import logger from '../utils/logger';
import { generateId, generateRoomCode } from '../utils/generateId';
import {
  Room,
  RoomPlayer,
  RoomStatus,
  CreateRoomInput,
  JoinRoomInput,
} from './room.types';

const ROOM_EXPIRY = 3600;

export class RoomService {

  // ─────────────────────────────────────────
  // CREATE ROOM
  // ─────────────────────────────────────────

  async createRoom(
    userId: string,
    username: string,
    socketId: string,
    input: CreateRoomInput
  ): Promise<Room> {
    // Check if player already in room
    const existingRoom = await redisClient.get(`player:room:${userId}`);
    if (existingRoom) {
      throw { code: 'ALREADY_IN_ROOM', message: 'Already in a room.', status: 400 };
    }

    const roomId = generateId();
    const roomCode = generateRoomCode();

    const host: RoomPlayer = {
      userId,
      username,
      avatarUrl: null,
      isReady: false,
      isHost: true,
      isVoiceConnected: false,
      ping: 0,
      socketId,
      joinedAt: Date.now(),
    };

    const room: Room = {
    roomId,
    roomCode,
    hostId: userId,
    players: [host],
    maxPlayers: Math.min(Math.max(input.maxPlayers || 4, 2), 10),
      currentPlayers: 1,
      voiceEnabled: input.voiceEnabled ?? true,
      chatEnabled: true,
      gameMode: input.gameMode || 'CASUAL',
      status: RoomStatus.WAITING,
      createdAt: Date.now(),
    };

    await this.saveRoom(room);
    await redisClient.set(`room:code:${roomCode}`, roomId, { EX: ROOM_EXPIRY });
    await redisClient.set(`player:room:${userId}`, roomId, { EX: ROOM_EXPIRY });

    logger.info('Room created', { roomId, roomCode, hostId: userId });

    return room;
  }

  // ─────────────────────────────────────────
  // JOIN ROOM
  // ─────────────────────────────────────────

  async joinRoom(
    userId: string,
    username: string,
    socketId: string,
    input: JoinRoomInput
  ): Promise<Room> {
    // Check if player already in room
    const existingRoom = await redisClient.get(`player:room:${userId}`);
    if (existingRoom) {
      throw { code: 'PLAYER_ALREADY_IN_ROOM', message: 'Already in a room.', status: 400 };
    }

    // Get room by code
    const roomId = await redisClient.get(`room:code:${input.roomCode}`);
    if (!roomId) {
      throw { code: 'ROOM_NOT_FOUND', message: 'Room not found.', status: 404 };
    }

    const room = await this.getRoom(roomId);
    if (!room) {
      throw { code: 'ROOM_NOT_FOUND', message: 'Room not found.', status: 404 };
    }

    if (room.status === RoomStatus.IN_GAME) {
      throw { code: 'ROOM_LOCKED', message: 'Match already started.', status: 400 };
    }

    if (room.currentPlayers >= room.maxPlayers) {
      throw { code: 'ROOM_FULL', message: 'Room is full.', status: 400 };
    }

    const player: RoomPlayer = {
      userId,
      username,
      avatarUrl: null,
      isReady: false,
      isHost: false,
      isVoiceConnected: false,
      ping: 0,
      socketId,
      joinedAt: Date.now(),
    };

    room.players.push(player);
    room.currentPlayers++;

    await this.saveRoom(room);
    await redisClient.set(`player:room:${userId}`, roomId, { EX: ROOM_EXPIRY });

    logger.info('Player joined room', { roomId, userId });

    return room;
  }

  // ─────────────────────────────────────────
  // LEAVE ROOM
  // ─────────────────────────────────────────

  async leaveRoom(userId: string): Promise<Room | null> {
    const roomId = await redisClient.get(`player:room:${userId}`);
    if (!roomId) return null;

    const room = await this.getRoom(roomId);
    if (!room) return null;

    room.players = room.players.filter((p) => p.userId !== userId);
    room.currentPlayers--;

    await redisClient.del(`player:room:${userId}`);

    if (room.players.length === 0) {
      await this.destroyRoom(room);
      return null;
    }

    // Transfer host if needed
    if (room.hostId === userId) {
      const oldestPlayer = room.players.reduce((prev, curr) =>
        prev.joinedAt < curr.joinedAt ? prev : curr
      );
      room.hostId = oldestPlayer.userId;
      oldestPlayer.isHost = true;
    }

    await this.saveRoom(room);

    logger.info('Player left room', { roomId, userId });

    return room;
  }

  // ─────────────────────────────────────────
  // SET READY STATUS
  // ─────────────────────────────────────────

  async setReadyStatus(
    userId: string,
    isReady: boolean
  ): Promise<Room | null> {
    const roomId = await redisClient.get(`player:room:${userId}`);
    if (!roomId) return null;

    const room = await this.getRoom(roomId);
    if (!room) return null;

    const player = room.players.find((p) => p.userId === userId);
    if (player) {
      player.isReady = isReady;
    }

    await this.saveRoom(room);

    return room;
  }

  // ─────────────────────────────────────────
  // KICK PLAYER
  // ─────────────────────────────────────────

  async kickPlayer(
    hostId: string,
    targetUserId: string
  ): Promise<Room | null> {
    const roomId = await redisClient.get(`player:room:${hostId}`);
    if (!roomId) return null;

    const room = await this.getRoom(roomId);
    if (!room) return null;

    if (room.hostId !== hostId) {
      throw { code: 'HOST_ONLY_ACTION', message: 'Only the host can kick players.', status: 403 };
    }

    room.players = room.players.filter((p) => p.userId !== targetUserId);
    room.currentPlayers--;

    await redisClient.del(`player:room:${targetUserId}`);
    await this.saveRoom(room);

    logger.info('Player kicked from room', { roomId, targetUserId, hostId });

    return room;
  }

  // ─────────────────────────────────────────
  // CHECK ALL READY
  // ─────────────────────────────────────────

  isAllReady(room: Room): boolean {
    if (room.players.length < 2) return false;
    return room.players.every((p) => p.isReady);
  }

  // ─────────────────────────────────────────
  // GET ROOM
  // ─────────────────────────────────────────

  async getRoom(roomId: string): Promise<Room | null> {
    const data = await redisClient.get(`room:${roomId}`);
    if (!data) return null;
    return JSON.parse(data);
  }

  // ─────────────────────────────────────────
  // GET PLAYER ROOM
  // ─────────────────────────────────────────

  async getPlayerRoom(userId: string): Promise<Room | null> {
    const roomId = await redisClient.get(`player:room:${userId}`);
    if (!roomId) return null;
    return await this.getRoom(roomId);
  }

  // ─────────────────────────────────────────
  // SAVE ROOM
  // ─────────────────────────────────────────

  async saveRoom(room: Room): Promise<void> {
    await redisClient.set(
      `room:${room.roomId}`,
      JSON.stringify(room),
      { EX: ROOM_EXPIRY }
    );
  }

  // ─────────────────────────────────────────
  // DESTROY ROOM
  // ─────────────────────────────────────────

  async destroyRoom(room: Room): Promise<void> {
    await redisClient.del(`room:${room.roomId}`);
    await redisClient.del(`room:code:${room.roomCode}`);

    for (const player of room.players) {
      await redisClient.del(`player:room:${player.userId}`);
    }

    logger.info('Room destroyed', { roomId: room.roomId });
  }
}

export default new RoomService();