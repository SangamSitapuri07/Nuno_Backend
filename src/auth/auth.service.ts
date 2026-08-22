import argon2 from 'argon2';
import jwt from 'jsonwebtoken';
import prisma from '../config/database';
import redisClient from '../config/redis';
import config from '../config/config';
import logger from '../utils/logger';
import { TokenPayload, AuthTokens, UserRole } from './auth.types';
import { RegisterInput, LoginInput } from './auth.validation';
import { verifyGoogleIdToken } from './google';
import { allocateUid } from './uid';

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
        uid: await allocateUid(),
        username,
        email,
        passwordHash,
        // This account picked its own name, so it skips the setup screen.
        usernameSet: true,
        statistics: { create: {} },
        settings: { create: {} },
        leaderboard: { create: {} },
      },
    });

    logger.info('User registered successfully', {
      userId: user.id,
      uid: user.uid,
      username,
    });
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

    // A Google account has no password of its own. Saying so beats a generic
    // "invalid credentials" the player cannot possibly act on.
    if (!user.passwordHash) {
      throw {
        code: 'USE_GOOGLE_SIGN_IN',
        message: 'This account uses Google sign-in. Tap "Continue with Google".',
        status: 409,
      };
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
  // GOOGLE SIGN-IN
  // ─────────────────────────────────────────

  /**
   * Signs a player in with a Google ID token, creating the account on first
   * use.
   *
   * One call covers both sign-up and sign-in, because from the player's side
   * there is no difference - they tap "Continue with Google" and end up in
   * the game. `isNewAccount` and `needsUsername` tell the app whether to send
   * them to the pick-a-username screen first.
   */
  async googleSignIn(idToken: string): Promise<
    AuthTokens & { isNewAccount: boolean; needsUsername: boolean }
  > {
    const profile = await verifyGoogleIdToken(idToken);

    // Match on googleId first. Email is deliberately the fallback and not the
    // primary key: people change the email on a Google account, and matching
    // only on email would also let someone who registered that address with a
    // password be taken over by a Google account that merely claims it.
    let user = await prisma.user.findUnique({
      where: { googleId: profile.googleId },
    });

    if (!user) {
      const byEmail = await prisma.user.findUnique({
        where: { email: profile.email },
      });

      if (byEmail) {
        // An existing account with the same address. Only link it when Google
        // has actually verified that address, otherwise this is an account
        // takeover primitive.
        if (!profile.emailVerified) {
          throw {
            code: 'EMAIL_NOT_VERIFIED',
            message:
              'Your Google account has not verified this email address.',
            status: 403,
          };
        }

        user = await prisma.user.update({
          where: { id: byEmail.id },
          data: {
            googleId: profile.googleId,
            avatarUrl: byEmail.avatarUrl ?? profile.picture,
          },
        });

        logger.info('Linked Google identity to an existing account', {
          userId: user.id,
        });
      }
    }

    let isNewAccount = false;

    if (!user) {
      user = await this.createGoogleUser(profile);
      isNewAccount = true;
    }

    if (user.accountStatus !== 'ACTIVE') {
      throw {
        code: 'ACCOUNT_INACTIVE',
        message: 'Your account is not active.',
        status: 403,
      };
    }

    await this.clearStaleSession(user.id);

    const tokens = this.generateTokens({
      userId: user.id,
      username: user.username,
      role: UserRole.PLAYER,
    });

    try {
      await redisClient.set(
        `refresh_token:${user.id}`,
        tokens.refreshToken,
        { EX: 30 * 24 * 60 * 60 }
      );
    } catch (e) {
      // Redis is optional here.
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLogin: new Date() },
    });

    logger.info('Google sign-in succeeded', {
      userId: user.id,
      uid: user.uid,
      isNewAccount,
    });

    return {
      ...tokens,
      isNewAccount,
      needsUsername: !user.usernameSet,
    };
  }

  /**
   * Creates the account behind a first-time Google sign-in.
   *
   * Both `uid` and `username` are unique, and two people can sign up at the
   * same instant, so a unique-violation is retried with fresh values rather
   * than surfaced as a failed sign-in.
   */
  private async createGoogleUser(profile: {
    googleId: string;
    email: string;
    name: string | null;
    picture: string | null;
  }) {
    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        return await prisma.user.create({
          data: {
            uid: await allocateUid(),
            // A placeholder the player replaces on the next screen. It is
            // still unique and still valid, so the account works even if they
            // background the app before choosing one.
            username: await this.provisionalUsername(profile.name),
            email: profile.email,
            googleId: profile.googleId,
            passwordHash: null,
            usernameSet: false,
            avatarUrl: profile.picture,
            emailVerified: true,
            statistics: { create: {} },
            settings: { create: {} },
            leaderboard: { create: {} },
          },
        });
      } catch (error: any) {
        // P2002 is Prisma's unique constraint violation.
        if (error?.code === 'P2002' && attempt < 4) continue;
        throw error;
      }
    }

    throw {
      code: 'ACCOUNT_CREATE_FAILED',
      message: 'Could not create your account. Please try again.',
      status: 500,
    };
  }

  /** A unique, valid, throwaway username for a brand-new Google account. */
  private async provisionalUsername(name: string | null): Promise<string> {
    // Seed from the Google display name so the suggestion feels personal,
    // falling back to a generic stem when it has nothing usable in it.
    const stem =
      (name ?? '')
        .replace(/[^a-zA-Z0-9_]/g, '')
        .slice(0, 12) || 'Player';

    for (let i = 0; i < 10; i++) {
      const candidate = `${stem}${Math.floor(1000 + Math.random() * 9000)}`;
      const taken = await prisma.user.findUnique({
        where: { username: candidate },
        select: { id: true },
      });
      if (!taken) return candidate;
    }

    // Vanishingly unlikely; keep it unique rather than give up.
    return `Player${Date.now().toString().slice(-9)}`;
  }

  // ─────────────────────────────────────────
  // SET USERNAME
  // ─────────────────────────────────────────

  /**
   * Sets the player's chosen username after a Google sign-in.
   *
   * Deliberately one-shot: it only applies while `usernameSet` is false, so
   * this cannot be used as a free rename endpoint. Renaming is a separate
   * concern with its own rules.
   */
  async setUsername(userId: string, username: string): Promise<{
    username: string;
    uid: string;
  }> {
    const user = await prisma.user.findUnique({ where: { id: userId } });

    if (!user) {
      throw { code: 'USER_NOT_FOUND', message: 'User not found.', status: 404 };
    }

    if (user.usernameSet) {
      throw {
        code: 'USERNAME_ALREADY_SET',
        message: 'Your username has already been chosen.',
        status: 409,
      };
    }

    // Case-insensitive: 'Rahul' and 'rahul' must not be different players.
    const taken = await prisma.user.findFirst({
      where: {
        username: { equals: username, mode: 'insensitive' },
        id: { not: userId },
      },
      select: { id: true },
    });

    if (taken) {
      throw {
        code: 'USERNAME_TAKEN',
        message: 'That username is already taken.',
        status: 409,
      };
    }

    try {
      const updated = await prisma.user.update({
        where: { id: userId },
        data: { username, usernameSet: true },
      });

      // The match-state layer caches names for five minutes; drop this one so
      // the new name shows up at the table immediately rather than after the
      // TTL expires.
      const { invalidateNameCache } = await import('../gameplay/game.state');
      invalidateNameCache(userId);

      logger.info('Username chosen', { userId, username });
      return { username: updated.username, uid: updated.uid };
    } catch (error: any) {
      // Somebody took it between the check and the write.
      if (error?.code === 'P2002') {
        throw {
          code: 'USERNAME_TAKEN',
          message: 'That username is already taken.',
          status: 409,
        };
      }
      throw error;
    }
  }

  /** True when [username] is free. Powers the live tick on the setup screen. */
  async isUsernameAvailable(username: string): Promise<boolean> {
    const taken = await prisma.user.findFirst({
      where: { username: { equals: username, mode: 'insensitive' } },
      select: { id: true },
    });
    return !taken;
  }

  /** Drops room/match/queue keys left over from a previous session. */
  private async clearStaleSession(userId: string): Promise<void> {
    try {
      await redisClient.del(`player:room:${userId}`);
      await redisClient.del(`match:player:${userId}`);
      await redisClient.del(`queue:player:${userId}`);
    } catch (e) {
      // Best effort.
    }
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