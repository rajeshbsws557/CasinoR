// ============================================
// Wallet Routes
// ============================================

import { Router } from 'express';
import {
  getBalance,
  getTransactions,
  getDepositInfo,
  submitDeposit,
  getDeposits,
  submitWithdrawal,
  getWithdrawals,
} from '../controllers/wallet.controller';
import { authMiddleware } from '../middleware/auth';
import { depositLimiter, withdrawalLimiter, balanceLimiter } from '../middleware/rateLimiter';

const router = Router();

router.use(authMiddleware); // All wallet routes require authentication

// Balance
router.get('/balance', balanceLimiter, getBalance);

// Transactions
router.get('/transactions', getTransactions);

// Deposits (bKash/Nagad)
router.get('/deposit-info', getDepositInfo);
router.post('/deposit', depositLimiter, submitDeposit);
router.get('/deposits', getDeposits);

// Withdrawals
router.post('/withdraw', withdrawalLimiter, submitWithdrawal);
router.get('/withdrawals', getWithdrawals);

export default router;
