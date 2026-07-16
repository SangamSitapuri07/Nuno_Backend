import { Socket } from 'socket.io';

export interface AuthenticatedSocket extends Socket {
  userId: string;
  username: string;
  role: string;
  roomId?: string;
  matchId?: string;
}

export interface SocketSession {
  userId: string;
  username: string;
  socketId: string;
  roomId?: string;
  matchId?: string;
  connectedAt: number;
  lastSequence: number;
}

export interface GameMessage {
  event: string;
  sequence: number;
  timestamp: number;
  payload: any;
}

export enum SocketState {
  DISCONNECTED = 'DISCONNECTED',
  CONNECTING = 'CONNECTING',
  CONNECTED = 'CONNECTED',
  AUTHENTICATING = 'AUTHENTICATING',
  AUTHENTICATED = 'AUTHENTICATED',
  JOINING_ROOM = 'JOINING_ROOM',
  IN_MATCH = 'IN_MATCH',
  RECONNECTING = 'RECONNECTING',
  CLOSED = 'CLOSED',
}