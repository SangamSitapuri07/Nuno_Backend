import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';

import config from './config/config';
import logger from './utils/logger';
import { connectDatabase } from './config/database';
import { connectRedis } from './config/redis';
import { errorMiddleware } from './middleware/error.middleware';
import { apiRateLimit, authRateLimit } from './middleware/rateLimit.middleware';
import { initializeSocketHandlers } from './websocket/socket.handler';

import authRoutes from './auth/auth.routes';
import userRoutes from './users/user.routes';
import matchmakingRoutes from './matchmaking/matchmaking.routes';
import roomRoutes from './rooms/room.routes';
import friendsRoutes from './friends/friends.routes';
import leaderboardRoutes from './leaderboard/leaderboard.routes';
import economyRoutes from './economy/economy.routes';
import reportsRoutes from './reports/reports.routes';
import {
  sanitizeInput,
  validateContentType,
  securityLogger,
  preventParamPollution,
} from './middleware/security.middleware';

dotenv.config();

// Fix BigInt serialization
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};

const app = express();
const httpServer = createServer(app);

const io = new Server(httpServer, {
  cors: {
    origin: config.cors.allowedOrigins,
    methods: ['GET', 'POST'],
  },
  pingInterval: 15000,
  pingTimeout: 30000,
  connectTimeout: 45000,
});

// ─────────────────────────────────────────
// MIDDLEWARE
// ─────────────────────────────────────────

app.use(helmet());
app.use(cors({
  origin: config.cors.allowedOrigins,
  credentials: true,
}));
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true }));
app.use(apiRateLimit);
app.use(sanitizeInput);
app.use(validateContentType);
app.use(securityLogger);
app.use(preventParamPollution);
// ─────────────────────────────────────────
// ROUTES
// ─────────────────────────────────────────

app.get('/api/v1/health', (req, res) => {
  res.status(200).json({
    success: true,
    data: {
      status: 'healthy',
      version: config.server.appVersion,
      environment: config.server.nodeEnv,
      timestamp: new Date().toISOString(),
    },
  });
});

app.use('/api/v1/auth', authRateLimit, authRoutes);
app.use('/api/v1', userRoutes);
app.use('/api/v1', matchmakingRoutes);
app.use('/api/v1', roomRoutes);
app.use('/api/v1', friendsRoutes);
app.use('/api/v1', leaderboardRoutes);
app.use('/api/v1', economyRoutes);
app.use('/api/v1', reportsRoutes);

// ─────────────────────────────────────────
// 404 HANDLER
// ─────────────────────────────────────────

app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: {
      code: 'NOT_FOUND',
      message: 'The requested resource was not found.',
    },
  });
});

// ─────────────────────────────────────────
// ERROR HANDLER
// ─────────────────────────────────────────

app.use(errorMiddleware);

// ─────────────────────────────────────────
// WEBSOCKET
// ─────────────────────────────────────────

initializeSocketHandlers(io);

// ─────────────────────────────────────────
// START SERVER
// ─────────────────────────────────────────

const startServer = async () => {
  try {
    await connectDatabase();
    await connectRedis();

    httpServer.listen(config.server.port, () => {
      logger.info(`${config.server.appName} server started`, {
        port: config.server.port,
        environment: config.server.nodeEnv,
        version: config.server.appVersion,
      });
    });
  } catch (error) {
    logger.error('Failed to start server', { error });
    process.exit(1);
  }
};

// ─────────────────────────────────────────
// GRACEFUL SHUTDOWN
// ─────────────────────────────────────────

process.on('SIGTERM', async () => {
  logger.info('SIGTERM received. Shutting down gracefully...');
  httpServer.close(() => {
    logger.info('HTTP server closed.');
    process.exit(0);
  });
});

process.on('SIGINT', async () => {
  logger.info('SIGINT received. Shutting down gracefully...');
  httpServer.close(() => {
    logger.info('HTTP server closed.');
    process.exit(0);
  });
});

export { io };

startServer();