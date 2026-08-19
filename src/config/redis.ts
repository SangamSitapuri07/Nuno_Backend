import { createClient, RedisClientType } from 'redis';
import logger from '../utils/logger';
import prisma from './database';
import { PgStore } from './pgstore';

/**
 * Shared state store.
 *
 * Rooms, matchmaking queues, live match state and socket sessions all live
 * here. On a hosted platform the process can be restarted or scaled to more
 * than one instance at any time, so this MUST be a real Redis when a
 * REDIS_URL is configured — an in-process map would silently give each
 * instance its own private view, and two players would never see each other.
 *
 * The in-memory implementation is retained only as a local-development
 * convenience, and the server logs loudly when it is in use.
 */

interface Store {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, options?: { EX?: number }): Promise<void>;
  del(key: string): Promise<void>;
  exists(key: string): Promise<number>;
  incr(key: string): Promise<number>;
  expire(key: string, seconds: number): Promise<void>;
  keys(pattern: string): Promise<string[]>;
  sAdd(key: string, member: string): Promise<void>;
  sRem(key: string, member: string): Promise<void>;
  sIsMember(key: string, member: string): Promise<boolean>;
  sMembers(key: string): Promise<string[]>;
  lPush(key: string, value: string): Promise<void>;
  lRange(key: string, start: number, stop: number): Promise<string[]>;
  lRem(key: string, count: number, value: string): Promise<void>;
  lLen(key: string): Promise<number>;
}

// ─────────────────────────────────────────
// IN-MEMORY FALLBACK (local development only)
// ─────────────────────────────────────────

class InMemoryStore implements Store {
  private store = new Map<string, { value: string; expiry: number | null }>();
  private sets = new Map<string, Set<string>>();
  private lists = new Map<string, string[]>();

  async get(key: string): Promise<string | null> {
    const item = this.store.get(key);
    if (!item) return null;
    if (item.expiry && Date.now() > item.expiry) {
      this.store.delete(key);
      return null;
    }
    return item.value;
  }

  async set(key: string, value: string, options?: { EX?: number }): Promise<void> {
    this.store.set(key, {
      value,
      expiry: options?.EX ? Date.now() + options.EX * 1000 : null,
    });
  }

  async del(key: string): Promise<void> {
    this.store.delete(key);
    this.sets.delete(key);
    this.lists.delete(key);
  }

  async exists(key: string): Promise<number> {
    return (await this.get(key)) === null ? 0 : 1;
  }

  async incr(key: string): Promise<number> {
    // Read and write with NO await in between.
    //
    // `await this.get(key)` looks harmless but it is a suspension point:
    // concurrent callers all resumed having read the same value and all wrote
    // back the same number, so incr handed out duplicates. That silently
    // broke every caller relying on it as a lock - the daily reward guard
    // among them, where four simultaneous taps each saw "1" and were each
    // paid. Everything below is synchronous, so it runs to completion before
    // any other caller can observe the map.
    const item = this.store.get(key);
    const expired = item?.expiry != null && Date.now() > item.expiry;
    const current = !item || expired ? 0 : parseInt(item.value, 10) || 0;
    const next = current + 1;
    // A value that had expired starts a fresh entry with no TTL, matching
    // Redis; otherwise the existing TTL is preserved and only the value moves.
    this.store.set(key, {
      value: String(next),
      expiry: expired ? null : (item?.expiry ?? null),
    });
    return next;
  }

  async expire(key: string, seconds: number): Promise<void> {
    const item = this.store.get(key);
    if (item) item.expiry = Date.now() + seconds * 1000;
  }

  async keys(pattern: string): Promise<string[]> {
    const re = new RegExp('^' + pattern.replace(/\*/g, '.*') + '$');
    return [...this.store.keys(), ...this.sets.keys(), ...this.lists.keys()]
      .filter((k) => re.test(k));
  }

  async sAdd(key: string, member: string): Promise<void> {
    if (!this.sets.has(key)) this.sets.set(key, new Set());
    this.sets.get(key)!.add(member);
  }

  async sRem(key: string, member: string): Promise<void> {
    this.sets.get(key)?.delete(member);
  }

  async sIsMember(key: string, member: string): Promise<boolean> {
    return this.sets.get(key)?.has(member) ?? false;
  }

  async sMembers(key: string): Promise<string[]> {
    return [...(this.sets.get(key) ?? [])];
  }

  async lPush(key: string, value: string): Promise<void> {
    if (!this.lists.has(key)) this.lists.set(key, []);
    this.lists.get(key)!.unshift(value);
  }

  async lRange(key: string, start: number, stop: number): Promise<string[]> {
    const list = this.lists.get(key) ?? [];
    return stop === -1 ? list.slice(start) : list.slice(start, stop + 1);
  }

  async lRem(key: string, _count: number, value: string): Promise<void> {
    const list = this.lists.get(key);
    if (!list) return;
    const i = list.indexOf(value);
    if (i !== -1) list.splice(i, 1);
  }

  async lLen(key: string): Promise<number> {
    return (this.lists.get(key) ?? []).length;
  }
}

// ─────────────────────────────────────────
// REDIS-BACKED STORE
// ─────────────────────────────────────────

class RedisStore implements Store {
  constructor(private client: RedisClientType) {}

  async get(key: string) {
    return this.client.get(key);
  }

  async set(key: string, value: string, options?: { EX?: number }) {
    if (options?.EX) await this.client.set(key, value, { EX: options.EX });
    else await this.client.set(key, value);
  }

  async del(key: string) {
    await this.client.del(key);
  }

  async exists(key: string) {
    return this.client.exists(key);
  }

  async incr(key: string) {
    return this.client.incr(key);
  }

  async expire(key: string, seconds: number) {
    await this.client.expire(key, seconds);
  }

  async keys(pattern: string) {
    return this.client.keys(pattern);
  }

  async sAdd(key: string, member: string) {
    await this.client.sAdd(key, member);
  }

  async sRem(key: string, member: string) {
    await this.client.sRem(key, member);
  }

  async sIsMember(key: string, member: string) {
    return this.client.sIsMember(key, member);
  }

  async sMembers(key: string) {
    return this.client.sMembers(key);
  }

  async lPush(key: string, value: string) {
    await this.client.lPush(key, value);
  }

  async lRange(key: string, start: number, stop: number) {
    return this.client.lRange(key, start, stop);
  }

  async lRem(key: string, count: number, value: string) {
    await this.client.lRem(key, count, value);
  }

  async lLen(key: string) {
    return this.client.lLen(key);
  }
}

// ─────────────────────────────────────────
// SELECTION
// ─────────────────────────────────────────

const memoryStore = new InMemoryStore();

/** Swapped for a RedisStore by connectRedis() when a REDIS_URL is present. */
let activeStore: Store = memoryStore;

/** Proxy so modules can import this once at load time. */
const redisClient: Store = {
  get: (k) => activeStore.get(k),
  set: (k, v, o) => activeStore.set(k, v, o),
  del: (k) => activeStore.del(k),
  exists: (k) => activeStore.exists(k),
  incr: (k) => activeStore.incr(k),
  expire: (k, s) => activeStore.expire(k, s),
  keys: (p) => activeStore.keys(p),
  sAdd: (k, m) => activeStore.sAdd(k, m),
  sRem: (k, m) => activeStore.sRem(k, m),
  sIsMember: (k, m) => activeStore.sIsMember(k, m),
  sMembers: (k) => activeStore.sMembers(k),
  lPush: (k, v) => activeStore.lPush(k, v),
  lRange: (k, a, b) => activeStore.lRange(k, a, b),
  lRem: (k, c, v) => activeStore.lRem(k, c, v),
  lLen: (k) => activeStore.lLen(k),
};

/** Raw client, used by the Socket.IO Redis adapter. */
export let rawRedisClient: RedisClientType | null = null;

export const connectRedis = async (): Promise<void> => {
  const url = process.env.REDIS_URL;

  // Prefer Redis when one is configured.
  if (url) {
    try {
      const client: RedisClientType = createClient({ url });
      client.on('error', (err) => logger.error('Redis error', { err }));
      await client.connect();

      rawRedisClient = client;
      activeStore = new RedisStore(client);
      logger.info('Redis connected', { url: url.replace(/:[^:@]*@/, ':***@') });
      return;
    } catch (error) {
      logger.error('Redis connection failed; trying Postgres instead', {
        error,
      });
    }
  }

  // Otherwise fall back to Postgres, which is already provisioned. Shared
  // state is what multiplayer actually needs, and a managed Redis is not
  // required to get it.
  try {
    const pg = new PgStore(prisma);
    await pg.init();
    activeStore = pg;
    logger.info('Shared state store: Postgres (no Redis configured)');
    return;
  } catch (error) {
    logger.error(
      'Postgres KV store failed to initialise — falling back to an ' +
        'in-process store. Multiplayer will NOT work across instances or ' +
        'survive a restart.',
      { error }
    );
  }
};

export const disconnectRedis = async (): Promise<void> => {
  if (rawRedisClient) {
    await rawRedisClient.quit();
    rawRedisClient = null;
  }
};

/** True when a real Redis is backing the store. */
export const isRedisActive = (): boolean => rawRedisClient !== null;

/** True when state is shared across instances (Redis or Postgres). */
export const isSharedStore = (): boolean => !(activeStore instanceof InMemoryStore);

export default redisClient;
