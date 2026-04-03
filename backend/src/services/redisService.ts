import Redis from 'ioredis';

const redisUri = process.env.REDIS_URI || '';
export const redisClient = redisUri ? new Redis(redisUri, {
  enableReadyCheck: false,
  maxRetriesPerRequest: 1,
  connectTimeout: 3000,
  lazyConnect: true,
}) : null;

if (!redisClient) {
  console.warn('⚠️ REDIS_URI not set. Caching is disabled.');
} else {
  redisClient.on('error', (err) => console.error('Redis Error:', err.message));
  redisClient.on('connect', () => console.log('✅ Redis connected.'));
  redisClient.connect().catch(() => {});
}

// ─── Core Primitives ────────────────────────────────────────────────────────

export const getCache = async (key: string): Promise<any | null> => {
  if (!redisClient) return null;
  try {
    const data = await redisClient.get(key);
    return data ? JSON.parse(data) : null;
  } catch {
    return null;
  }
};

export const setCache = async (key: string, data: any, ttlSeconds: number = 3600): Promise<void> => {
  if (!redisClient) return;
  try {
    await redisClient.set(key, JSON.stringify(data), 'EX', ttlSeconds);
  } catch {
    // non-fatal
  }
};

export const deleteCacheKeys = async (keys: string[]): Promise<void> => {
  if (!redisClient || keys.length === 0) return;
  try {
    await redisClient.del(...keys);
  } catch {
    // non-fatal
  }
};

// ─── Surgical Invalidation ──────────────────────────────────────────────────

/**
 * Invalidate ONLY analytics and weekly-trend cache for a user on a specific date.
 * Does NOT nuke slot cache (slots are write-through: updated immediately on mutation).
 */
export const invalidateAnalyticsForDate = async (userId: string, dateKey: string): Promise<void> => {
  const keys = [
    `user:${userId}:analytics:day:${dateKey}`,
    `user:${userId}:analytics:week:${dateKey}`,
    `user:${userId}:weekly-trend:${dateKey}`,
    `user:${userId}:ai-insights`,
    // Invalidate the weekly trend key for the 7 days around this date too
    ...Array.from({ length: 7 }, (_, i) => {
      const d = new Date(dateKey);
      d.setDate(d.getDate() + i);
      return `user:${userId}:weekly-trend:${d.toISOString().split('T')[0]}`;
    }),
  ];
  // Deduplicate
  await deleteCacheKeys([...new Set(keys)]);
};

/**
 * Write-through: update the slot cache for a date immediately after a mutation.
 * This means the next GET /slots request gets the fresh value from Redis, not MongoDB.
 */
export const writeThroughSlotsCache = async (userId: string, dateKey: string, slots: any[]): Promise<void> => {
  const cacheKey = `user:${userId}:slots:${dateKey}`;
  // Use a short TTL for hot data (5 minutes)
  await setCache(cacheKey, slots, 300);
};

/**
 * Get cached slots (for write-through reads).
 */
export const getCachedSlots = async (userId: string, dateKey: string): Promise<any[] | null> => {
  const cacheKey = `user:${userId}:slots:${dateKey}`;
  return getCache(cacheKey);
};

// ─── Legacy full-scan invalidation (kept for compatibility) ─────────────────
export const invalidateUserAnalytics = invalidateAnalyticsForDate.bind(null);
