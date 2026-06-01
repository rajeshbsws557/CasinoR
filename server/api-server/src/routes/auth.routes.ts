// ============================================
// Auth Routes
// ============================================

import { Router } from 'express';
import { register, login, getProfile, updateProfile, updatePaymentMethods } from '../controllers/auth.controller';
import { authMiddleware } from '../middleware/auth';
import { authLimiter } from '../middleware/rateLimiter';

const router = Router();

router.post('/register', authLimiter, register);
router.post('/login', authLimiter, login);
router.get('/me', authMiddleware, getProfile);
router.put('/profile', authMiddleware, updateProfile);
router.put('/payment-methods', authMiddleware, updatePaymentMethods);

export default router;

