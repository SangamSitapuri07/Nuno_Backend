import { Router } from 'express';
import userController from './user.controller';
import { authMiddleware } from '../middleware/auth.middleware';

const router = Router();

router.get('/profile', authMiddleware, userController.getProfile);
router.put('/profile', authMiddleware, userController.updateProfile);
router.get('/settings', authMiddleware, userController.getSettings);
router.put('/settings', authMiddleware, userController.updateSettings);
router.get('/statistics', authMiddleware, userController.getStatistics);
router.get('/history', authMiddleware, userController.getMatchHistory);

export default router;