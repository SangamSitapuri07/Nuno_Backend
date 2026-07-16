export enum GameMode {
  CASUAL = 'CASUAL',
  RANKED = 'RANKED',
  PRIVATE = 'PRIVATE',
  CUSTOM = 'CUSTOM',
}

export enum QueueStatus {
  IDLE = 'IDLE',
  SEARCHING = 'SEARCHING',
  MATCH_FOUND = 'MATCH_FOUND',
  CONFIRMING = 'CONFIRMING',
  LOBBY = 'LOBBY',
  IN_GAME = 'IN_GAME',
}

export interface QueueEntry {
  userId: string;
  username: string;
  rating: number;
  mode: GameMode;
  region: string;
  joinedAt: number;
  socketId: string;
}

export interface MatchFound {
  matchId: string;
  roomId: string;
  players: QueueEntry[];
  mode: GameMode;
  region: string;
  createdAt: number;
}

export interface QueueJoinInput {
  mode: GameMode;
  region?: string;
}