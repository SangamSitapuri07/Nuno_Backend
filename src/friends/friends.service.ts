import prisma from '../config/database';
import { isValidUid, UID_LENGTH } from '../auth/uid';
import redisClient from '../config/redis';
import logger from '../utils/logger';
import { PlayerOnlineStatus } from './friends.types';

export class FriendsService {

  // ─────────────────────────────────────────
  // GET FRIENDS LIST
  // ─────────────────────────────────────────

  async getFriends(userId: string) {
    const friends = await prisma.friend.findMany({
      where: {
        OR: [
          { userOne: userId },
          { userTwo: userId },
        ],
      },
      include: {
        userOneRef: {
          select: {
            id: true,
            uid: true,
            username: true,
            avatarUrl: true,
            lastLogin: true,
          },
        },
        userTwoRef: {
          select: {
            id: true,
            uid: true,
            username: true,
            avatarUrl: true,
            lastLogin: true,
          },
        },
      },
    });

    const friendList = await Promise.all(
      friends.map(async (f) => {
        const friend = f.userOne === userId ? f.userTwoRef : f.userOneRef;
        const status = await this.getPlayerStatus(friend.id);

        let roomCode: string | null = null;
        if (status === PlayerOnlineStatus.IN_LOBBY) {
          const inRoomId = await redisClient.get(`player:room:${friend.id}`);
          if (inRoomId) {
            const roomData = await redisClient.get(`room:${inRoomId}`);
            if (roomData) {
              try {
                const parsed = JSON.parse(roomData);
                roomCode = parsed.roomCode || null;
              } catch (e) {}
            }
          }
        }

        return {
          friendshipId: f.id,
          userId: friend.id,
          uid: friend.uid,
          username: friend.username,
          avatarUrl: friend.avatarUrl,
          status,
          roomCode,
          lastOnline: friend.lastLogin,
        };
      })
    );

    return friendList;
  }

  // ─────────────────────────────────────────
  // SEND FRIEND REQUEST
  // ─────────────────────────────────────────

  async sendFriendRequest(
    senderId: string,
    receiverId: string
  ): Promise<void> {
    if (senderId === receiverId) {
      throw { code: 'INVALID_REQUEST', message: 'Cannot add yourself.', status: 400 };
    }

    // Check receiver exists
    const receiver = await prisma.user.findUnique({
      where: { id: receiverId },
    });

    if (!receiver) {
      throw { code: 'USER_NOT_FOUND', message: 'Player not found.', status: 404 };
    }

    // Check already friends
    const existingFriendship = await prisma.friend.findFirst({
      where: {
        OR: [
          { userOne: senderId, userTwo: receiverId },
          { userOne: receiverId, userTwo: senderId },
        ],
      },
    });

    if (existingFriendship) {
      throw { code: 'ALREADY_FRIENDS', message: 'Already friends.', status: 409 };
    }

    // Check existing request
    const existingRequest = await prisma.friendRequest.findFirst({
      where: {
        OR: [
          { senderId, receiverId, status: 'PENDING' },
          { senderId: receiverId, receiverId: senderId, status: 'PENDING' },
        ],
      },
    });

    if (existingRequest) {
      throw { code: 'REQUEST_EXISTS', message: 'Request already exists.', status: 409 };
    }

    await prisma.friendRequest.create({
      data: {
        senderId,
        receiverId,
        status: 'PENDING',
      },
    });

    logger.info('Friend request sent', { senderId, receiverId });
  }

  // ─────────────────────────────────────────
  // ACCEPT FRIEND REQUEST
  // ─────────────────────────────────────────

  async acceptFriendRequest(
    userId: string,
    requestId: string
  ) {
    const request = await prisma.friendRequest.findUnique({
      where: { id: requestId },
    });

    if (!request || request.receiverId !== userId) {
      throw { code: 'REQUEST_NOT_FOUND', message: 'Request not found.', status: 404 };
    }

    if (request.status !== 'PENDING') {
      throw { code: 'INVALID_REQUEST', message: 'Request is no longer pending.', status: 400 };
    }

    // Update request status
    await prisma.friendRequest.update({
      where: { id: requestId },
      data: { status: 'ACCEPTED' },
    });

    // Create friendship
    await prisma.friend.create({
      data: {
        userOne: request.senderId,
        userTwo: request.receiverId,
      },
    });

    logger.info('Friend request accepted', { requestId, userId });
    return request;
  }

  // ─────────────────────────────────────────
  // REJECT FRIEND REQUEST
  // ─────────────────────────────────────────

  async rejectFriendRequest(
    userId: string,
    requestId: string
  ): Promise<void> {
    const request = await prisma.friendRequest.findUnique({
      where: { id: requestId },
    });

    if (!request || request.receiverId !== userId) {
      throw { code: 'REQUEST_NOT_FOUND', message: 'Request not found.', status: 404 };
    }

    await prisma.friendRequest.update({
      where: { id: requestId },
      data: { status: 'DECLINED' },
    });

    logger.info('Friend request rejected', { requestId, userId });
  }

  // ─────────────────────────────────────────
  // REMOVE FRIEND
  // ─────────────────────────────────────────

  async removeFriend(
    userId: string,
    friendId: string
  ): Promise<void> {
    const friendship = await prisma.friend.findFirst({
      where: {
        OR: [
          { userOne: userId, userTwo: friendId },
          { userOne: friendId, userTwo: userId },
        ],
      },
    });

    if (!friendship) {
      throw { code: 'NOT_FRIENDS', message: 'Not friends.', status: 404 };
    }

    await prisma.friend.delete({
      where: { id: friendship.id },
    });

    logger.info('Friend removed', { userId, friendId });
  }

  // ─────────────────────────────────────────
  // GET FRIEND REQUESTS
  // ─────────────────────────────────────────

  async getFriendRequests(userId: string) {
    const requests = await prisma.friendRequest.findMany({
      where: {
        receiverId: userId,
        status: 'PENDING',
      },
      include: {
        sender: {
          select: {
            id: true,
            uid: true,
            username: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return requests;
  }

  // ─────────────────────────────────────────
  // SEARCH PLAYERS
  // ─────────────────────────────────────────

  async searchPlayers(query: string, userId: string) {
    const trimmed = (query ?? '').trim();

    // A run of digits is a uid, not a name.
    //
    // This is the flow players actually use to add each other - read the
    // number off a friend's profile and type it in - so it is matched
    // exactly and returns at most the one account it identifies. Punctuation
    // is stripped first because the app displays the uid with a leading '#'
    // and people paste it back in that way.
    const asUid = trimmed.replace(/[^0-9]/g, '');
    if (asUid.length === UID_LENGTH && isValidUid(asUid)) {
      const exact = await prisma.user.findFirst({
        where: {
          uid: asUid,
          id: { not: userId },
          accountStatus: 'ACTIVE',
        },
        select: {
          id: true,
          uid: true,
          username: true,
          avatarUrl: true,
          rankPoints: true,
        },
      });

      return exact ? [exact] : [];
    }

    const players = await prisma.user.findMany({
      where: {
        username: {
          contains: trimmed,
          mode: 'insensitive',
        },
        id: { not: userId },
        accountStatus: 'ACTIVE',
      },
      select: {
        id: true,
        uid: true,
        username: true,
        avatarUrl: true,
        rankPoints: true,
      },
      take: 10,
    });

    return players;
  }

  // ─────────────────────────────────────────
  // SEND FRIEND REQUEST BY UID
  // ─────────────────────────────────────────

  /**
   * Adds a player by the number printed on their profile.
   *
   * Resolving the uid here rather than in the app means the client never has
   * to know a player's internal id to send a request, which is the whole
   * point of having a public number.
   */
  async sendRequestByUid(senderId: string, rawUid: string): Promise<void> {
    const uid = (rawUid ?? '').replace(/[^0-9]/g, '');

    if (!isValidUid(uid)) {
      throw {
        code: 'INVALID_UID',
        message: `A player ID is ${UID_LENGTH} digits.`,
        status: 400,
      };
    }

    const target = await prisma.user.findUnique({
      where: { uid },
      select: { id: true, accountStatus: true },
    });

    if (!target || target.accountStatus !== 'ACTIVE') {
      throw {
        code: 'USER_NOT_FOUND',
        message: 'No player has that ID.',
        status: 404,
      };
    }

    // Reuses the normal path, so the self-add, already-friends and
    // duplicate-request rules apply exactly as they do everywhere else.
    await this.sendFriendRequest(senderId, target.id);
  }

  // ─────────────────────────────────────────
  // GET PLAYER STATUS
  // ─────────────────────────────────────────

  async getPlayerStatus(userId: string): Promise<PlayerOnlineStatus> {
    const isOnline = await redisClient.sIsMember('online_players', userId);
    if (!isOnline) return PlayerOnlineStatus.OFFLINE;

    const inMatch = await redisClient.get(`match:player:${userId}`);
    if (inMatch) return PlayerOnlineStatus.IN_MATCH;

    const inRoom = await redisClient.get(`player:room:${userId}`);
    if (inRoom) return PlayerOnlineStatus.IN_LOBBY;

    return PlayerOnlineStatus.ONLINE;
  }

  // ─────────────────────────────────────────
  // BROADCAST USER STATUS TO FRIENDS
  // ─────────────────────────────────────────

  async broadcastUserStatus(io: any, userId: string, customStatus?: string): Promise<void> {
    try {
      if (!userId || !io) return;
      const status = customStatus || (await this.getPlayerStatus(userId));

      let roomCode: string | null = null;
      if (status === PlayerOnlineStatus.IN_LOBBY) {
        const inRoomId = await redisClient.get(`player:room:${userId}`);
        if (inRoomId) {
          const roomData = await redisClient.get(`room:${inRoomId}`);
          if (roomData) {
            try {
              const parsed = JSON.parse(roomData);
              roomCode = parsed.roomCode || null;
            } catch (e) {}
          }
        }
      }

      const friends = await prisma.friend.findMany({
        where: {
          OR: [
            { userOne: userId },
            { userTwo: userId },
          ],
        },
      });

      if (!friends.length) return;

      const friendIds = new Set(
        friends.map((f) => (f.userOne === userId ? f.userTwo : f.userOne))
      );

      // Emit to each friend's personal room. Scanning io.sockets.sockets
      // only reaches this instance, which is why presence looked stuck at
      // OFFLINE for players connected elsewhere.
      for (const friendId of friendIds) {
        io.to(`user:${friendId}`).emit('friend.statusUpdated', {
          userId,
          status,
          roomCode,
        });
      }

      logger.info('Broadcasted user status to friends', { userId, status, roomCode });
    } catch (error) {
      logger.error('Error broadcasting user status', { error, userId });
    }
  }

  // ─────────────────────────────────────────
  // GET NOTIFICATIONS
  // ─────────────────────────────────────────

  async getNotifications(userId: string) {
    return await prisma.notification.findMany({
      where: { playerId: userId },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
  }

  // ─────────────────────────────────────────
  // MARK NOTIFICATIONS READ
  // ─────────────────────────────────────────

  async markNotificationsRead(userId: string): Promise<void> {
    await prisma.notification.updateMany({
      where: { playerId: userId, read: false },
      data: { read: true },
    });
  }

  // ─────────────────────────────────────────
  // CREATE NOTIFICATION
  // ─────────────────────────────────────────

  async createNotification(
    playerId: string,
    title: string,
    message: string
  ): Promise<void> {
    await prisma.notification.create({
      data: {
        playerId,
        title,
        message,
      },
    });
  }
}

export default new FriendsService();