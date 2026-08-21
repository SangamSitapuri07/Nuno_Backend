import { Router } from 'express';
import authController from './auth.controller';
import { authMiddleware } from '../middleware/auth.middleware';

const router = Router();

router.post('/register', authController.register);
router.post('/login', authController.login);

// Google sign-in. One route covers both sign-up and sign-in.
router.post('/google', authController.googleSignIn);

// Chosen once, straight after a first Google sign-in.
router.post('/username', authMiddleware, authController.setUsername);
router.get('/username/available', authMiddleware, authController.checkUsername);
router.post('/logout', authMiddleware, authController.logout);
router.post('/refresh', authController.refresh);

export default router;