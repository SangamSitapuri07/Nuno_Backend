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
  requiredPlayers: number;
}

export interface QueueJoinInput {
  mode: GameMode;
  region?: string;

  /// Table size the player is queuing for. Only players who asked for the
  /// same size are matched together, so a 2-player and a 6-player request
  /// never end up in the same game.
  requiredPlayers?: number;
}

export interface MatchFound {
  matchId: string;
  roomId: string;
  players: QueueEntry[];
  mode: GameMode;
  region: string;
  createdAt: number;
}
