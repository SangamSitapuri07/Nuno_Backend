import prisma from '../config/database';

/**
 * Public player numbers.
 *
 * The primary key is a uuid, which is fine for the database and useless to a
 * player: adding a friend means reading a number off a screen and typing it
 * in, and nobody is going to do that with 36 hex characters. This is the
 * Free Fire / BGMI style id - ten digits, no leading zero, so it always
 * displays at a constant width.
 */

/** Lowest and highest possible uid. Ten digits, never starting with 0. */
export const UID_MIN = 1_000_000_000;
export const UID_MAX = 9_999_999_999;

export const UID_LENGTH = 10;

/** True when [value] is a syntactically valid uid. */
export const isValidUid = (value: string): boolean =>
  /^[1-9][0-9]{9}$/.test(value);

/**
 * Normalises whatever the player typed into a bare uid.
 *
 * People paste these with spaces, dashes or a leading '#', because that is
 * how the app displays them. Rejecting that would just look broken.
 */
export const normaliseUid = (input: string): string =>
  (input ?? '').replace(/[^0-9]/g, '');

const randomUid = (): string => {
  const span = UID_MAX - UID_MIN + 1;
  return String(UID_MIN + Math.floor(Math.random() * span));
};

/**
 * Allocates a uid that is not yet taken.
 *
 * Retried rather than assumed unique: the space is large, but "large" is not
 * "guaranteed", and the column has a unique index that would otherwise turn a
 * collision into a failed registration. The caller still has to be prepared
 * for a unique-violation, because another request can take the same number
 * between this check and the insert - that is what the retry in the service
 * is for.
 */
export const allocateUid = async (attempts = 10): Promise<string> => {
  for (let i = 0; i < attempts; i++) {
    const candidate = randomUid();
    const clash = await prisma.user.findUnique({
      where: { uid: candidate },
      select: { id: true },
    });
    if (!clash) return candidate;
  }

  throw {
    code: 'UID_ALLOCATION_FAILED',
    message: 'Could not allocate a player id. Please try again.',
    status: 500,
  };
};
