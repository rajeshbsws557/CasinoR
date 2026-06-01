// ============================================
// Crypto Service — Routes
// ============================================

import { Router } from 'express';
import {
  generateRound,
  registerClientSeed,
  verifyRoundHandler,
  getCrashPoint,
} from '../controllers/crypto.controller';

const router = Router();

// Internal endpoints (called by game-server)
router.post('/generate-round', generateRound);
router.post('/register-client-seed', registerClientSeed);
router.get('/crash-point/:roundId', getCrashPoint);

// Public endpoint (called by clients for verification)
router.get('/verify/:roundId', verifyRoundHandler);

export default router;
