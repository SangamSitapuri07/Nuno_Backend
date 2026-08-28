import { HouseRules } from '../gameplay/house.rules';

export enum RoomStatus {
  CREATED = 'CREATED',
  WAITING = 'WAITING',
  READY = 'READY',
  COUNTDOWN = 'COUNTDOWN',
  IN_GAME = 'IN_GAME',
  FINISHED = 'FINISHED',
  DESTROYED = 'DESTROYED',
}

export enum PlayerReadyStatus {
  READY = 'READY',
  NOT_READY = 'NOT_READY',
}

export interface RoomPlayer {
  userId: string;
  username: string;
  avatarUrl: string | null;
  isReady: boolean;
  isHost: boolean;
  isVoiceConnected: boolean;
  ping: number;
  socketId: string;
  joinedAt: number;
}

export interface Room {
  roomId: string;
  roomCode: string;
  hostId: string;
  players: RoomPlayer[];
  maxPlayers: number;
  currentPlayers: number;
  voiceEnabled: boolean;
  chatEnabled: boolean;
  gameMode: string;
  status: RoomStatus;
  createdAt: number;
  matchId?: string;

  /// Variants the host has enabled. Absent means the official Mattel game,
  /// which is what every room created before this existed used.
  houseRules?: HouseRules;
}

export interface CreateRoomInput {
  gameMode: string;
  maxPlayers?: number;
  voiceEnabled?: boolean;
}

export interface JoinRoomInput {
  roomCode: string;
}