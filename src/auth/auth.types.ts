export interface RegisterInput {
  username: string;
  email: string;
  password: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface TokenPayload {
  userId: string;
  username: string;
  role: UserRole;
  iat?: number;
  exp?: number;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface RefreshTokenInput {
  refreshToken: string;
}

export enum UserRole {
  PLAYER = 'PLAYER',
  ADMIN = 'ADMIN',
  MODERATOR = 'MODERATOR',
  SYSTEM = 'SYSTEM',
}