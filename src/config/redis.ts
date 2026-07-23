import logger from '../utils/logger';

class InMemoryStore {
  private store: Map<string, { value: string; expiry: number | null }> = new Map();
  private sets: Map<string, Set<string>> = new Map();
  private lists: Map<string, string[]> = new Map();

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
    const expiry = options?.EX ? Date.now() + (options.EX * 1000) : null;
    this.store.set(key, { value, expiry });
  }

  async del(key: string): Promise<void> {
    this.store.delete(key);
    this.sets.delete(key);
    this.lists.delete(key);
  }

  async exists(key: string): Promise<number> {
    const item = this.store.get(key);
    if (!item) return 0;
    if (item.expiry && Date.now() > item.expiry) {
      this.store.delete(key);
      return 0;
    }
    return 1;
  }

  async expire(key: string, seconds: number): Promise<void> {
    const item = this.store.get(key);
    if (item) {
      item.expiry = Date.now() + (seconds * 1000);
    }
  }

  async incr(key: string): Promise<number> {
    const current = await this.get(key);
    const newVal = (parseInt(current || '0') + 1).toString();
    await this.set(key, newVal);
    return parseInt(newVal);
  }

  // Set operations
  async sAdd(key: string, member: string): Promise<void> {
    if (!this.sets.has(key)) this.sets.set(key, new Set());
    this.sets.get(key)!.add(member);
  }

  async sRem(key: string, member: string): Promise<void> {
    this.sets.get(key)?.delete(member);
  }

  async sMembers(key: string): Promise<string[]> {
    return Array.from(this.sets.get(key) || []);
  }

  async sIsMember(key: string, member: string): Promise<boolean> {
    return this.sets.get(key)?.has(member) || false;
  }

  // List operations
  async lPush(key: string, value: string): Promise<void> {
    if (!this.lists.has(key)) this.lists.set(key, []);
    this.lists.get(key)!.unshift(value);
  }

  async lRange(key: string, start: number, stop: number): Promise<string[]> {
    const list = this.lists.get(key) || [];
    if (stop === -1) return list.slice(start);
    return list.slice(start, stop + 1);
  }

  async lRem(key: string, count: number, value: string): Promise<void> {
    const list = this.lists.get(key);
    if (!list) return;
    const index = list.indexOf(value);
    if (index !== -1) list.splice(index, 1);
  }

  async lLen(key: string): Promise<number> {
    return (this.lists.get(key) || []).length;
  }
}

const redisClient = new InMemoryStore();

export const connectRedis = async (): Promise<void> => {
  logger.info('In-memory store initialized (no Redis needed)');
};

export const disconnectRedis = async (): Promise<void> => {
  logger.info('In-memory store closed');
};

export default redisClient;