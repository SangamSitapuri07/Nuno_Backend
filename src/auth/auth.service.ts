import argon2 from 'argon2';
import jwt from 'jsonwebtoken';
import prisma from '../config/database';
import redisClient from '../config/redis';
import config from '../config/config';
import logger from '../utils/logger';
import { TokenPayload, AuthTokens, UserRole } from './auth.types';
import { RegisterInput, LoginInput } from './auth.validation';

export class AuthService {

  // ─────────────────────────────────────────
  // REGISTER
  // ─────────────────────────────────────────

  async register(input: RegisterInput): Promise<void> {
    const { username, email, password } = input;

    const existingUsername = await prisma.user.findUnique({
      where: { username },
    });

    if (existingUsername) {
      throw { code: 'USERNAME_TAKEN', message: 'Username is already taken.', status: 409 };
    }

    const existingEmail = await prisma.user.findUnique({
      where: { email },
    });

    if (existingEmail) {
      throw { code: 'EMAIL_TAKEN', message: 'Email is already registered.', status: 409 };
    }

    const passwordHash = await argon2.hash(password, {
      type: argon2.argon2id,
    });

    const user = await prisma.user.create({
      data: {
        username,
        email,
        passwordHash,
        statistics: { create: {} },
        settings: { create: {} },
        leaderboard: { create: {} },
      },
    });

    logger.info('User registered successfully', { userId: user.id, username });
  }

  // ─────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────

  async login(input: LoginInput): Promise<AuthTokens> {
    const { email, password } = input;

    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      throw { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password.', status: 401 };
    }

    const passwordValid = await argon2.verify(user.passwordHash, password);

    if (!passwordValid) {
      throw { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password.', status: 401 };
    }

    if (user.accountStatus !== 'ACTIVE') {
      throw { code: 'ACCOUNT_INACTIVE', message: 'Your account is not active.', status: 403 };
    }

    // Clean up stale session data
    try {
      await redisClient.del(`player:room:${user.id}`);
      await redisClient.del(`match:player:${user.id}`);
      await redisClient.del(`queue:player:${user.id}`);
    } catch (e) {
      // Ignore Redis errors during cleanup
    }

    const tokens = this.generateTokens({
      userId: user.id,
      username: user.username,
      role: UserRole.PLAYER,
    });

    // Store refresh token in Redis for fast access (optional cache)
    try {
      await redisClient.set(
        `refresh_token:${user.id}`,
        tokens.refreshToken,
        { EX: 30 * 24 * 60 * 60 }
      );
    } catch (e) {
      // Redis might be unavailable, that's ok
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLogin: new Date() },
    });

    logger.info('User logged in successfully', { userId: user.id });

    return tokens;
  }

  // ─────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────

  async logout(userId: string): Promise<void> {
    try {
      await redisClient.del(`refresh_token:${userId}`);
    } catch (e) {}
    logger.info('User logged out', { userId });
  }

  // ─────────────────────────────────────────
  // REFRESH TOKEN - Now works without Redis
  // ─────────────────────────────────────────

  async refreshToken(token: string): Promise<AuthTokens> {
    try {
      // Verify the token cryptographically (this works without Redis)
      const payload = jwt.verify(
        token,
        config.jwt.refreshSecret
      ) as TokenPayload;

      // Verify user still exists and is active
      const user = await prisma.user.findUnique({
        where: { id: payload.userId },
      });

      if (!user) {
        throw { code: 'INVALID_TOKEN', message: 'User not found.', status: 401 };
      }

      if (user.accountStatus !== 'ACTIVE') {
        throw { code: 'INVALID_TOKEN', message: 'Account is not active.', status: 401 };
      }

      // Generate new tokens
      const tokens = this.generateTokens({
        userId: user.id,
        username: user.username,
        role: UserRole.PLAYER,
      });

      // Try to update Redis cache but don't fail if unavailable
      try {
        await redisClient.set(
          `refresh_token:${user.id}`,
          tokens.refreshToken,
          { EX: 30 * 24 * 60 * 60 }
        );
      } catch (e) {
        // Redis might be down, that's ok
      }

      logger.info('Token refreshed successfully', { userId: user.id });

      return tokens;

    } catch (error: any) {
      if (error.code) throw error;

      if (error.name === 'TokenExpiredError') {
        throw { code: 'INVALID_TOKEN', message: 'Refresh token expired. Please login again.', status: 401 };
      }

      throw { code: 'INVALID_TOKEN', message: 'Invalid refresh token.', status: 401 };
    }
  }

  // ─────────────────────────────────────────
  // GENERATE TOKENS
  // ─────────────────────────────────────────

  private generateTokens(payload: TokenPayload): AuthTokens {
    const accessToken = jwt.sign(
      payload,
      config.jwt.accessSecret,
      { expiresIn: config.jwt.accessExpiresIn } as jwt.SignOptions
    );

    const refreshToken = jwt.sign(
      payload,
      config.jwt.refreshSecret,
      { expiresIn: config.jwt.refreshExpiresIn } as jwt.SignOptions
    );

    return {
      accessToken,
      refreshToken,
      expiresIn: 900,
    };
  }
}

export default new AuthService();