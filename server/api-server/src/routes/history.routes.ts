// ============================================
// History Routes
// ============================================

import { Router } from 'express';
import { getRounds, getRoundById, getUserBets } from '../controllers/history.controller';
import { authMiddleware } from '../middleware/auth';

const router = Router();

// Public: anyone can view round history
router.get('/rounds', getRounds);
router.get('/rounds/:roundId', getRoundById);

// Protected: user's own bet history
router.get('/bets', authMiddleware, getUserBets);

export default router;
