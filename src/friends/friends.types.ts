export enum FriendRequestStatus {
  PENDING = 'PENDING',
  ACCEPTED = 'ACCEPTED',
  DECLINED = 'DECLINED',
  CANCELLED = 'CANCELLED',
}

export enum PlayerOnlineStatus {
  ONLINE = 'ONLINE',
  IN_MATCH = 'IN_MATCH',
  IN_LOBBY = 'IN_LOBBY',
  AWAY = 'AWAY',
  OFFLINE = 'OFFLINE',
  DO_NOT_DISTURB = 'DO_NOT_DISTURB',
}

export interface FriendEntry {
  userId: string;
  username: string;
  avatarUrl: string | null;
  status: PlayerOnlineStatus;
  lastOnline: Date | null;
}

export interface SendFriendRequestInput {
  playerId: string;
}

export interface RespondFriendRequestInput {
  requestId: string;
}