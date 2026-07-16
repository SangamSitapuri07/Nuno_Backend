import { Router } from 'express';
import friendsController from './friends.controller';
import { authMiddleware } from '../middleware/auth.middleware';

const router = Router();

router.get('/friends', authMiddleware, friendsController.getFriends);
router.post('/friends/request', authMiddleware, friendsController.sendRequest);
router.post('/friends/accept', authMiddleware, friendsController.acceptRequest);
router.post('/friends/reject', authMiddleware, friendsController.rejectRequest);
router.delete('/friends/:friendId', authMiddleware, friendsController.removeFriend);
router.get('/friends/requests', authMiddleware, friendsController.getRequests);
router.get('/players/search', authMiddleware, friendsController.searchPlayers);
router.get('/notifications', authMiddleware, friendsController.getNotifications);
router.patch('/notifications/read', authMiddleware, friendsController.markNotificationsRead);

export default router;