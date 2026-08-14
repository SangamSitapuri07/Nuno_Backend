import { PrismaClient } from '@prisma/client';
import logger from '../utils/logger';

/**
 * A Redis-shaped key/value store backed by the Postgres database you already
 * have.
 *
 * Render's free Redis expires, and the app only needs a small, shared,
 * restart-surviving store — not Redis' throughput. Postgres gives us exactly
 * that at no extra cost, and every instance sees the same rows, which is the
 * property that was actually missing.
 *
 * Keys carry an optional expiry and are cleaned up lazily on read plus by a
 * periodic sweep, mirroring Redis' TTL semantics closely enough for rooms,
 * queues, sessions and match state.
 */
export class PgStore {
  private sweepTimer: NodeJS.Timeout | null = null;

  constructor(private prisma: PrismaClient) {}

  /// Prisma's generated client types the raw helpers loosely, so results are
  /// cast at the call site rather than via type arguments.
  private async query<T>(sql: string, ...params: unknown[]): Promise<T[]> {
    return (await (this.prisma as any).$queryRawUnsafe(
      sql,
      ...params
    )) as T[];
  }

  /** Creates the table and indexes if they do not exist yet. */
  async init(): Promise<void> {
    await this.prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS kv_store (
        key         TEXT PRIMARY KEY,
        value       TEXT,
        members     TEXT[] DEFAULT '{}',
        list_items  TEXT[] DEFAULT '{}',
        expires_at  TIMESTAMPTZ
      )
    `);
    await this.prisma.$executeRawUnsafe(
      `CREATE INDEX IF NOT EXISTS kv_store_expires_idx ON kv_store (expires_at)`
    );

    // Drop anything that expired while the process was down.
    await this.sweep();
    this.sweepTimer = setInterval(() => {
      this.sweep().catch(() => {});
    }, 60_000);

    logger.info('Postgres KV store ready');
  }

  async close(): Promise<void> {
    if (this.sweepTimer) clearInterval(this.sweepTimer);
    this.sweepTimer = null;
  }

  private async sweep(): Promise<void> {
    await this.prisma.$executeRawUnsafe(
      `DELETE FROM kv_store WHERE expires_at IS NOT NULL AND expires_at < NOW()`
    );
  }

  // ── strings ─────────────────────────────────────────────────

  async get(key: string): Promise<string | null> {
    const rows: any[] = await this.query<{ value: string | null }>(
      `SELECT value FROM kv_store
        WHERE key = $1 AND (expires_at IS NULL OR expires_at > NOW())`,
      key
    );
    return rows[0]?.value ?? null;
  }

  async set(
    key: string,
    value: string,
    options?: { EX?: number }
  ): Promise<void> {
    const expires = options?.EX
      ? new Date(Date.now() + options.EX * 1000)
      : null;

    await this.prisma.$executeRawUnsafe(
      `INSERT INTO kv_store (key, value, expires_at) VALUES ($1, $2, $3)
       ON CONFLICT (key) DO UPDATE SET value = $2, expires_at = $3`,
      key,
      value,
      expires
    );
  }

  async del(key: string): Promise<void> {
    await this.prisma.$executeRawUnsafe(
      `DELETE FROM kv_store WHERE key = $1`,
      key
    );
  }

  async exists(key: string): Promise<number> {
    return (await this.get(key)) === null ? 0 : 1;
  }

  async incr(key: string): Promise<number> {
    const rows: any[] = await this.query<{ value: string }>(
      `INSERT INTO kv_store (key, value) VALUES ($1, '1')
       ON CONFLICT (key) DO UPDATE
         SET value = (COALESCE(kv_store.value, '0')::bigint + 1)::text
       RETURNING value`,
      key
    );
    return parseInt(rows[0]?.value ?? '1', 10);
  }

  async expire(key: string, seconds: number): Promise<void> {
    await this.prisma.$executeRawUnsafe(
      `UPDATE kv_store SET expires_at = $2 WHERE key = $1`,
      key,
      new Date(Date.now() + seconds * 1000)
    );
  }

  async keys(pattern: string): Promise<string[]> {
    const like = pattern.replace(/\*/g, '%');
    const rows: any[] = await this.query<{ key: string }>(
      `SELECT key FROM kv_store
        WHERE key LIKE $1 AND (expires_at IS NULL OR expires_at > NOW())`,
      like
    );
    return rows.map((r) => r.key);
  }

  // ── sets (online_players, etc.) ─────────────────────────────

  async sAdd(key: string, member: string): Promise<void> {
    await this.prisma.$executeRawUnsafe(
      `INSERT INTO kv_store (key, members) VALUES ($1, ARRAY[$2])
       ON CONFLICT (key) DO UPDATE
         SET members = (
           SELECT ARRAY(SELECT DISTINCT unnest(kv_store.members || ARRAY[$2]))
         )`,
      key,
      member
    );
  }

  async sRem(key: string, member: string): Promise<void> {
    await this.prisma.$executeRawUnsafe(
      `UPDATE kv_store SET members = array_remove(members, $2) WHERE key = $1`,
      key,
      member
    );
  }

  async sIsMember(key: string, member: string): Promise<boolean> {
    const rows: any[] = await this.query<{ found: boolean }>(
      `SELECT $2 = ANY(members) AS found FROM kv_store WHERE key = $1`,
      key,
      member
    );
    return rows[0]?.found ?? false;
  }

  async sMembers(key: string): Promise<string[]> {
    const rows: any[] = await this.query<{ members: string[] }>(
      `SELECT members FROM kv_store WHERE key = $1`,
      key
    );
    return rows[0]?.members ?? [];
  }

  // ── lists (matchmaking queues) ──────────────────────────────

  async lPush(key: string, value: string): Promise<void> {
    await this.prisma.$executeRawUnsafe(
      `INSERT INTO kv_store (key, list_items) VALUES ($1, ARRAY[$2])
       ON CONFLICT (key) DO UPDATE
         SET list_items = ARRAY[$2] || kv_store.list_items`,
      key,
      value
    );
  }

  async lRange(key: string, start: number, stop: number): Promise<string[]> {
    const rows: any[] = await this.query<{ list_items: string[] }>(
      `SELECT list_items FROM kv_store WHERE key = $1`,
      key
    );
    const list = rows[0]?.list_items ?? [];
    return stop === -1 ? list.slice(start) : list.slice(start, stop + 1);
  }

  async lRem(key: string, _count: number, value: string): Promise<void> {
    await this.prisma.$executeRawUnsafe(
      `UPDATE kv_store SET list_items = array_remove(list_items, $2)
        WHERE key = $1`,
      key,
      value
    );
  }

  async lLen(key: string): Promise<number> {
    const rows: any[] = await this.query<{ n: bigint }>(
      `SELECT COALESCE(array_length(list_items, 1), 0) AS n
         FROM kv_store WHERE key = $1`,
      key
    );
    return Number(rows[0]?.n ?? 0);
  }
}
