import { Router } from 'express';
import leaderboardController from './leaderboard.controller';
import { authMiddleware } from '../middleware/auth.middleware';

const router = Router();

router.get(
  '/leaderboard/global',
  authMiddleware,
  leaderboardController.getGlobal
);

router.get(
  '/leaderboard/friends',
  authMiddleware,
  leaderboardController.getFriends
);

router.get(
  '/leaderboard/rank',
  authMiddleware,
  leaderboardController.getPlayerRank
);

router.get(
  '/leaderboard/history',
  authMiddleware,
  leaderboardController.getMatchHistory
);

export default router;