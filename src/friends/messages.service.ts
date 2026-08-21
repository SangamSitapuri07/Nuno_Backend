import prisma from '../config/database';
import logger from '../utils/logger';

/**
 * One-to-one messages between friends.
 *
 * DMs used to be a pure socket relay: the message was forwarded to whoever
 * happened to be connected and then forgotten. That meant the conversation
 * only existed in the two apps' memory, so it disappeared on restart, and
 * anything sent while the other player was offline was never delivered at
 * all. Every message is now a row, and the socket is only the live-delivery
 * path on top of it.
 */

export const MAX_MESSAGE_LENGTH = 500;

/** How many messages a conversation returns by default. */
const PAGE_SIZE = 50;

/**
 * How long a message is kept.
 *
 * DMs here are chatter between matches, not a mailbox, so they are dropped
 * after a day rather than accumulating forever in a database that is only
 * meant to hold game state.
 */
export const MESSAGE_TTL_HOURS = 24;

const ttlCutoff = (): Date =>
  new Date(Date.now() - MESSAGE_TTL_HOURS * 60 * 60 * 1000);

export class MessagesService {
  /**
   * True when the two users are friends.
   *
   * DMs are friends-only. Without this check any account could message any
   * other by user id, which is a harassment vector and the reason the block
   * list exists elsewhere in the app.
   */
  async areFriends(a: string, b: string): Promise<boolean> {
    const link = await prisma.friend.findFirst({
      where: {
        OR: [
          { userOne: a, userTwo: b },
          { userOne: b, userTwo: a },
        ],
      },
      select: { id: true },
    });
    return link !== null;
  }

  /**
   * Stores a message and returns the saved row.
   *
   * Validation lives here rather than in the socket handler so the rules
   * cannot drift between transports.
   */
  async send(senderId: string, receiverId: string, body: string) {
    const text = (body ?? '').trim();

    if (senderId === receiverId) {
      throw {
        code: 'INVALID_TARGET',
        message: 'You cannot message yourself.',
        status: 400,
      };
    }

    if (text.length === 0) {
      throw {
        code: 'EMPTY_MESSAGE',
        message: 'Type something first.',
        status: 400,
      };
    }

    if (text.length > MAX_MESSAGE_LENGTH) {
      throw {
        code: 'MESSAGE_TOO_LONG',
        message: `Messages are limited to ${MAX_MESSAGE_LENGTH} characters.`,
        status: 400,
      };
    }

    if (!(await this.areFriends(senderId, receiverId))) {
      throw {
        code: 'NOT_FRIENDS',
        message: 'You can only message friends.',
        status: 403,
      };
    }

    const message = await prisma.directMessage.create({
      data: { senderId, receiverId, body: text },
    });

    logger.info('DM stored', { from: senderId, to: receiverId });

    return message;
  }

  /**
   * The conversation between two users, oldest last.
   *
   * Queried newest-first so the limit takes the most recent page, then
   * reversed for display - a chat reads top to bottom.
   */
  async conversation(
    userId: string,
    friendId: string,
    limit = PAGE_SIZE
  ) {
    const rows = await prisma.directMessage.findMany({
      where: {
        // Filtered on read as well as swept in the background: the sweep runs
        // hourly, and without this a message could still be shown for up to
        // an hour after it was supposed to disappear.
        createdAt: { gte: ttlCutoff() },
        OR: [
          { senderId: userId, receiverId: friendId },
          { senderId: friendId, receiverId: userId },
        ],
      },
      orderBy: { createdAt: 'desc' },
      take: Math.min(Math.max(limit, 1), 200),
    });

    return rows.reverse();
  }

  /** Marks everything [friendId] sent to [userId] as read. */
  async markRead(userId: string, friendId: string): Promise<number> {
    const result = await prisma.directMessage.updateMany({
      where: { receiverId: userId, senderId: friendId, readAt: null },
      data: { readAt: new Date() },
    });
    return result.count;
  }

  /**
   * Unread totals per friend, for the badge on the friends list.
   *
   * Grouped in the database rather than counted per friend in a loop, which
   * would be one query per row of the list.
   */
  async unreadCounts(userId: string): Promise<Record<string, number>> {
    const rows = await prisma.directMessage.groupBy({
      by: ['senderId'],
      where: {
        receiverId: userId,
        readAt: null,
        // An expired message must not keep a badge alive for a conversation
        // whose contents have already gone.
        createdAt: { gte: ttlCutoff() },
      },
      _count: { _all: true },
    });

    const counts: Record<string, number> = {};
    for (const row of rows as Array<{ senderId: string; _count: { _all: number } }>) {
      counts[row.senderId] = row._count._all;
    }
    return counts;
  }
  /**
   * Deletes messages older than the TTL.
   *
   * Returns the number removed so the caller can log it. Safe to call
   * concurrently - it is a plain bounded delete, not a read-then-write.
   */
  async purgeExpired(): Promise<number> {
    const result = await prisma.directMessage.deleteMany({
      where: { createdAt: { lt: ttlCutoff() } },
    });

    if (result.count > 0) {
      logger.info('Expired DMs purged', { count: result.count });
    }

    return result.count;
  }

  /**
   * Starts the hourly purge.
   *
   * Hourly rather than at midnight: the cutoff is a rolling 24 hours from
   * each message, so there is no single moment when everything expires, and
   * an hourly pass keeps each sweep small.
   */
  startExpiryTimer(): NodeJS.Timeout {
    // One pass at boot clears anything that expired while the process was
    // down - on a free tier that is most of the time.
    this.purgeExpired().catch((error) =>
      logger.error('Initial DM purge failed', { error })
    );

    const timer = setInterval(
      () => {
        this.purgeExpired().catch((error) =>
          logger.error('Scheduled DM purge failed', { error })
        );
      },
      60 * 60 * 1000
    );

    // Do not hold the process open just for this.
    timer.unref?.();
    return timer;
  }
}

export default new MessagesService();
