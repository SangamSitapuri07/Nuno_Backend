import { createClient } from 'redis';
import logger from '../utils/logger';
import config from './config';

const redisClient = createClient({
  url: config.redis.url,
});

redisClient.on('connect', () => {
  logger.info('Redis connected successfully');
});

redisClient.on('error', (error) => {
  logger.error('Redis connection error', { error });
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