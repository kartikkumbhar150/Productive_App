import Redis from 'ioredis';

// Ensure the application doesn't crash if REDIS_URI is missing (use local mock or just log)
const redisUri = process.env.REDIS_URI || '';
export const redisClient = redisUri ? new Redis(redisUri) : null;

if (!redisClient) {
  console.warn('⚠️ REDIS_URI not set. Caching is disabled. Provide a Redis URL for production performance.');
} else {
  redisClient.on('error', (err) => console.error('Redis Error:', err));
  redisClient.on('connect', () => console.log('✅ Redis connected successfully.'));
}

/**
 * Get cache by exact key
 */
export const getCache = async (key: string): Promise<any | null> => {
  if (!redisClient) return null;
  try {
    const data = await redisClient.get(key);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error('Redis Get Error:', error);
    return null;
  }
};

/**
 * Set cache with TTL (Default 1 hour)
 */
export const setCache = async (key: string, data: any, ttlSeconds: number = 3600): Promise<void> => {
  if (!redisClient) return;
  try {
    await redisClient.set(key, JSON.stringify(data), 'EX', ttlSeconds);
  } catch (error) {
    console.error('Redis Set Error:', error);
  }
};

/**
 * Delete specific keys directly
 */
export const deleteCacheKeys = async (keys: string[]): Promise<void> => {
  if (!redisClient || keys.length === 0) return;
  try {
    await redisClient.del(...keys);
  } catch (error) {
    console.error('Redis Delete Error:', error);
  }
};

/**
 * Clear ALL specific user analytics/reports/heatmaps based on pattern matching.
 * ioredis requires using SCAN to find patterned keys and then DEL
 */
export const invalidateUserAnalytics = async (userId: string): Promise<void> => {
  if (!redisClient) return;
  try {
    // We want to delete: user:{userId}:analytics:*, user:{userId}:weekly-trend:*, 
    // user:{userId}:heatmap:*, user:{userId}:reports:*, user:{userId}:ai-insights
    
    // Pattern to match all analytics/report driven keys for this user
    const pattern = `user:${userId}:*`;
    
    let cursor = '0';
    let keysToDelete: string[] = [];

    do {
      const [newCursor, keys] = await redisClient.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
      cursor = newCursor;
      
      // Filter keys to only delete computed/analytics data, but keep base things intact if needed
      // Actually, invalidating everything (tasks, slots, analytics) ensures strict consistency.
      keysToDelete.push(...keys);
    } while (cursor !== '0');

    if (keysToDelete.length > 0) {
      await redisClient.del(...keysToDelete);
      console.log(`🧹 Cleared ${keysToDelete.length} cache keys for user ${userId}`);
    }
  } catch (error) {
    console.error('Redis Invalidation Error:', error);
  }
};
