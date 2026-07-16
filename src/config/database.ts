import { PrismaClient } from '@prisma/client';
import logger from '../utils/logger';

const prismaClient = new PrismaClient();

export const connectDatabase = async (): Promise<void> => {
  try {
    await prismaClient.$connect();
    logger.info('Database connected successfully');
  } catch (error) {
    logger.error('Database connection failed', { error });
    process.exit(1);
  }
};

export const disconnectDatabase = async (): Promise<void> => {
  await prismaClient.$disconnect();
  logger.info('Database disconnected');
};

export default prismaClient;