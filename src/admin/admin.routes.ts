import { Router, Request, Response } from 'express';
import prisma from '../config/database';
import logger from '../utils/logger';
import { sendSuccess, sendError } from '../utils/response';
import asyncHandler from '../utils/asyncHandler';
import { isValidUid, normaliseUid } from '../auth/uid';
import { HTTP_STATUS } from '../utils/constants';

/**
 * Operator-only endpoints.
 *
 * These exist because the alternative - a shell on the running instance - is
 * not available on every Render plan, and because granting test coins should
 * not require handing the database password around.
 *
 * The whole router is disabled unless ADMIN_TOKEN is set, so a deployment
 * that never configures one has no admin surface at all. That is deliberate:
 * a route that grants unlimited currency is exactly the sort of thing that
 * must fail closed.
 */

const router = Router();

/** Minimum length for ADMIN_TOKEN. Short tokens are guessable. */
const MIN_TOKEN_LENGTH = 24;

/** Coins granted when the caller does not say. Whole catalogue is 72,600. */
const DEFAULT_AMOUNT = 100_000;

/** Upper bound on a single grant, so a typo cannot mint a billion coins. */
const MAX_AMOUNT = 10_000_000;

/**
 * Constant-time string comparison.
 *
 * `a === b` on a secret returns as soon as it finds a differing byte, which
 * leaks the length of the matching prefix to anyone who can measure the
 * response time. Comparing every byte regardless removes that signal.
 */
const safeEqual = (a: string, b: string): boolean => {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
};

/**
 * Coerces whatever arrived into a flat list of candidate uids.
 *
 * Handles a real array, an array-like object ({"0": x, "1": y}) produced by
 * middleware that rebuilds objects, a single string, and a comma or space
 * separated string - because a human typing this into a shell will try all
 * four.
 */
const collectUids = (input: unknown): unknown[] => {
  if (input === undefined || input === null) return [];

  if (Array.isArray(input)) return input.flatMap((v) => collectUids(v));

  if (typeof input === 'string') {
    const parts = input.split(/[,\s]+/).filter((part) => part.length > 0);

    // Split only when every piece is a uid in its own right.
    //
    // "7664285497 5262524395" is two accounts, but "# 7664 285497" is one
    // account written the way the app displays it. Splitting blindly would
    // turn the second into three malformed ids, so fall back to treating the
    // whole string as a single value whenever the split does not produce
    // clean uids.
    if (parts.length > 1 && parts.every((p) => isValidUid(normaliseUid(p)))) {
      return parts;
    }

    return [input];
  }

  if (typeof input === 'number') return [String(input)];

  if (typeof input === 'object') {
    // Array-like: numeric keys, in order.
    const keys = Object.keys(input as object);
    if (keys.length > 0 && keys.every((k) => /^\d+$/.test(k))) {
      return keys
        .sort((a, b) => Number(a) - Number(b))
        .flatMap((k) => collectUids((input as any)[k]));
    }
  }

  return [];
};

const requireAdmin = (req: Request, res: Response): boolean => {
  const expected = process.env.ADMIN_TOKEN ?? '';

  // Fail closed. No token configured means no admin API.
  if (!expected) {
    sendError(
      res,
      'NOT_FOUND',
      'The requested resource was not found.',
      HTTP_STATUS.NOT_FOUND
    );
    return false;
  }

  if (expected.length < MIN_TOKEN_LENGTH) {
    logger.error('ADMIN_TOKEN is too short; admin routes refused', {
      length: expected.length,
      required: MIN_TOKEN_LENGTH,
    });
    sendError(
      res,
      'NOT_FOUND',
      'The requested resource was not found.',
      HTTP_STATUS.NOT_FOUND
    );
    return false;
  }

  const header = req.header('x-admin-token') ?? '';

  if (!safeEqual(header, expected)) {
    logger.warn('Rejected admin request', { path: req.path, ip: req.ip });
    sendError(res, 'UNAUTHORIZED', 'Not authorised.', HTTP_STATUS.UNAUTHORIZED);
    return false;
  }

  return true;
};

/**
 * Validates the uids and writes the balances. Shared by both routes so they
 * cannot drift apart.
 */
const applyCoins = async (
  res: Response,
  rawUids: unknown[],
  amount: number,
  replace: boolean
) => {
  const uids: string[] = [];
  for (const raw of rawUids) {
    const uid = normaliseUid(String(raw));
    if (!isValidUid(uid)) {
      return sendError(
        res,
        'INVALID_PAYLOAD',
        `"${raw}" is not a 10-digit player id.`,
        HTTP_STATUS.BAD_REQUEST
      );
    }
    uids.push(uid);
  }

  const results: Array<{
    uid: string;
    found: boolean;
    username?: string;
    before?: number;
    after?: number;
  }> = [];

  for (const uid of uids) {
    const user = await prisma.user.findUnique({
      where: { uid },
      select: { id: true, username: true, coins: true },
    });

    if (!user) {
      results.push({ uid, found: false });
      continue;
    }

    const updated = await prisma.user.update({
      where: { id: user.id },
      data: replace ? { coins: amount } : { coins: { increment: amount } },
      select: { coins: true },
    });

    logger.info('Admin adjusted coins', {
      uid,
      before: user.coins,
      after: updated.coins,
      replace,
    });

    results.push({
      uid,
      found: true,
      username: user.username,
      before: user.coins,
      after: updated.coins,
    });
  }

  return sendSuccess(res, {
    granted: replace ? undefined : amount,
    set: replace ? amount : undefined,
    results,
    notFound: results.filter((r) => !r.found).map((r) => r.uid),
  });
};

/**
 * POST /api/v1/admin/coins
 *
 * Body: { "uids": ["7664285497"], "amount": 100000, "set": false }
 *
 * `amount` is added to the current balance. Pass `"set": true` to replace it
 * instead, which is what to use when re-testing the shop from zero.
 */
router.post(
  '/admin/coins',
  asyncHandler(async (req: Request, res: Response) => {
    if (!requireAdmin(req, res)) return;

    const body = req.body ?? {};

    // Accept every shape a client might reasonably send.
    //
    // Insisting on a real JS array was too strict: middleware in this app
    // rebuilt arrays as {"0": ...}, PowerShell users reach for a bare
    // string, and a query parameter is never an array. None of those are
    // mistakes worth a 400 when the intent is unambiguous.
    const rawUids: unknown[] = collectUids(body.uids ?? req.query.uids);

    if (rawUids.length === 0) {
      return sendError(
        res,
        'INVALID_PAYLOAD',
        'Send { "uids": ["1234567890"] } - the 10-digit id from the profile ' +
          'screen. A bare string or a comma-separated list is fine too.',
        HTTP_STATUS.BAD_REQUEST
      );
    }

    if (rawUids.length > 50) {
      return sendError(
        res,
        'INVALID_PAYLOAD',
        'At most 50 accounts per request.',
        HTTP_STATUS.BAD_REQUEST
      );
    }

    const amount = body.amount === undefined ? DEFAULT_AMOUNT : Number(body.amount);

    if (!Number.isFinite(amount) || !Number.isInteger(amount) || amount < 0) {
      return sendError(
        res,
        'INVALID_PAYLOAD',
        'amount must be a whole number, zero or more.',
        HTTP_STATUS.BAD_REQUEST
      );
    }

    if (amount > MAX_AMOUNT) {
      return sendError(
        res,
        'INVALID_PAYLOAD',
        `amount may not exceed ${MAX_AMOUNT.toLocaleString()}.`,
        HTTP_STATUS.BAD_REQUEST
      );
    }

    const replace = body.set === true;

    return applyCoins(res, rawUids, amount, replace);
  })
);

/**
 * GET /api/v1/admin/grant?uids=...&amount=...&token=...
 *
 * The same operation as POST /admin/coins, reachable from a browser address
 * bar. A GET that changes data is not something to be proud of, but the
 * alternative - talking somebody through JSON quoting in PowerShell over
 * chat - has already cost more than it saved. It is behind the same token,
 * it is not linked from anywhere, and it disappears with ADMIN_TOKEN.
 *
 * The token may travel as ?token= here, since a browser cannot set headers.
 * That does put it in the server log, so rotate it when finished.
 */
router.get(
  '/admin/grant',
  asyncHandler(async (req: Request, res: Response) => {
    // Allow the token as a query parameter for this route only.
    if (!req.header('x-admin-token') && typeof req.query.token === 'string') {
      req.headers['x-admin-token'] = req.query.token;
    }
    if (!requireAdmin(req, res)) return;

    const uids = collectUids(req.query.uids);
    if (uids.length === 0 || uids.length > 50) {
      return sendError(
        res,
        'INVALID_PAYLOAD',
        'Pass ?uids=1234567890,9876543210 (up to 50).',
        HTTP_STATUS.BAD_REQUEST
      );
    }

    const amount =
      req.query.amount === undefined ? DEFAULT_AMOUNT : Number(req.query.amount);
    if (
      !Number.isFinite(amount) ||
      !Number.isInteger(amount) ||
      amount < 0 ||
      amount > MAX_AMOUNT
    ) {
      return sendError(
        res,
        'INVALID_PAYLOAD',
        `amount must be a whole number between 0 and ${MAX_AMOUNT}.`,
        HTTP_STATUS.BAD_REQUEST
      );
    }

    const replace = req.query.set === 'true';

    return applyCoins(res, uids, amount, replace);
  })
);

/**
 * GET /api/v1/admin/player/:uid
 *
 * Read-only. Useful for checking a balance without granting anything.
 */
router.get(
  '/admin/player/:uid',
  asyncHandler(async (req: Request, res: Response) => {
    if (!requireAdmin(req, res)) return;

    const uid = normaliseUid(String(req.params.uid));
    if (!isValidUid(uid)) {
      return sendError(
        res,
        'INVALID_PAYLOAD',
        'Not a 10-digit player id.',
        HTTP_STATUS.BAD_REQUEST
      );
    }

    const user = await prisma.user.findUnique({
      where: { uid },
      select: {
        uid: true,
        username: true,
        coins: true,
        level: true,
        xp: true,
        leaderboard: { select: { rating: true, tier: true, division: true } },
      },
    });

    if (!user) {
      return sendError(
        res,
        'USER_NOT_FOUND',
        'No account with that player id.',
        HTTP_STATUS.NOT_FOUND
      );
    }

    return sendSuccess(res, user);
  })
);

export default router;
