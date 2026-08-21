import redisClient from '../config/redis';
import logger from '../utils/logger';

/**
 * Rematch voting.
 *
 * Keyed on the ROOM, not the match.
 *
 * The vote happens after the match has ended, and ending a match deletes
 * everything about it - the state, and the `match:player:` mapping each
 * socket rebuilds its `matchId` from. Keying the tally on the match id meant
 * the key was named after something that no longer existed by the time
 * anybody could vote, and any player whose socket had reconnected in the
 * meantime had no id to send at all. The room outlives the match, which is
 * exactly the lifetime a "shall we play again?" question needs.
 */

/** A vote is only good for so long; nobody waits five minutes at a results screen. */
const VOTE_TTL_SECONDS = 120;

export class RematchService {
  private acceptedKey = (roomId: string) => `rematch:${roomId}:accepted`;
  private declinedKey = (roomId: string) => `rematch:${roomId}:declined`;

  /** Records a vote to play again. */
  async accept(roomId: string, userId: string): Promise<void> {
    await redisClient.sAdd(this.acceptedKey(roomId), userId);
    await redisClient.expire(this.acceptedKey(roomId), VOTE_TTL_SECONDS);
    logger.info('Rematch accepted', { roomId, userId });
  }

  /** Records a refusal, which is what stops everyone else waiting. */
  async decline(roomId: string, userId: string): Promise<void> {
    await redisClient.sAdd(this.declinedKey(roomId), userId);
    await redisClient.expire(this.declinedKey(roomId), VOTE_TTL_SECONDS);
    logger.info('Rematch declined', { roomId, userId });
  }

  /** Everyone who has voted yes. */
  async accepted(roomId: string): Promise<string[]> {
    return redisClient.sMembers(this.acceptedKey(roomId));
  }

  /** Everyone who has voted no. */
  async declined(roomId: string): Promise<string[]> {
    return redisClient.sMembers(this.declinedKey(roomId));
  }

  /**
   * True when every player still in the room has agreed.
   *
   * A declining player is not simply absent from the accepted set - they may
   * still be sitting in the room - so a single refusal has to block the
   * rematch outright rather than leaving the others waiting for a vote that
   * will never come.
   */
  async allAccepted(roomId: string, playerIds: string[]): Promise<boolean> {
    if (playerIds.length < 2) return false;

    const [accepted, declined] = await Promise.all([
      this.accepted(roomId),
      this.declined(roomId),
    ]);

    if (playerIds.some((id) => declined.includes(id))) return false;
    return playerIds.every((id) => accepted.includes(id));
  }

  /** Clears the tally, so the next match starts from nobody having voted. */
  async clear(roomId: string): Promise<void> {
    await redisClient.del(this.acceptedKey(roomId));
    await redisClient.del(this.declinedKey(roomId));
  }
}

export default new RematchService();
