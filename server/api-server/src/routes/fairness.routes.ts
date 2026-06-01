// ============================================
// Fairness Routes
// ============================================

import { Router } from 'express';
import { getCurrentSeeds, rotateSeed, verifyRound } from '../controllers/fairness.controller';
import { authMiddleware } from '../middleware/auth';

const router = Router();

// Public: round verification
router.get('/verify/:roundId', verifyRound);

// Protected: seed management
router.get('/current-seeds', authMiddleware, getCurrentSeeds);
router.post('/rotate-seed', authMiddleware, rotateSeed);

export default router;
