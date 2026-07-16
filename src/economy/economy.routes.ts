import { Router } from 'express';
import economyController from './economy.controller';
import { authMiddleware } from '../middleware/auth.middleware';

const router = Router();

router.get(
  '/inventory',
  authMiddleware,
  economyController.getInventory
);

router.get(
  '/store',
  authMiddleware,
  economyController.getStore
);

router.post(
  '/store/purchase',
  authMiddleware,
  economyController.purchaseItem
);

router.post(
  '/rewards/daily',
  authMiddleware,
  economyController.claimDailyReward
);

router.get(
  '/balance',
  authMiddleware,
  economyController.getBalance
);

export default router;