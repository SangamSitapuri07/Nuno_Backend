import { createClient } from 'redis';
import logger from '../utils/logger';
import config from './config';

const redisUrl = config.redis.url;

const redisClient = createClient({
  url: redisUrl,
  socket: {
    tls: redisUrl.startsWith('rediss://'),
    rejectUnauthorized: false,
    reconnectStrategy: (retries) => {
      if (retries > 10) {
        logger.error('Redis max retries reached');
        return new Error('Max retries reached');
      }
      return Math.min(retries * 200, 3000);
    }
  }
});

redisClient.on('connect', () => {
  logger.info('Redis connected successfully');
});

redisClient.on('error', (error) => {
  if (error.message && !error.message.includes('ECONNRESET')) {
    logger.error('Redis connection error', { message: error.message });
  }
});

redisClient.on('end', () => {
  logger.warn('Redis disconnected');
});

redisClient.on('reconnecting', () => {
  logger.info('Redis reconnecting');
});

export const connectRedis = async (): Promise<void> => {
  try {
    await redisClient.connect();
    logger.info('Redis client ready');
  } catch (error) {
    logger.error('Redis connection failed', { error });
    process.exit(1);
  }
};

export const disconnectRedis = async (): Promise<void> => {
  await redisClient.disconnect();
  logger.info('Redis disconnected');
};

export default redisClient;