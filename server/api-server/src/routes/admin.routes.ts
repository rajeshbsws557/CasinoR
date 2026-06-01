// ============================================
// Admin Routes — Protected by API Key
// ============================================

import { Router } from 'express';
import { adminMiddleware } from '../middleware/admin';
import {
  getPendingDeposits,
  approveDeposit,
  rejectDeposit,
  getPendingWithdrawals,
  completeWithdrawal,
  rejectWithdrawal,
  getDashboardStats,
  getUsers,
  updateUserBalance,
} from '../controllers/admin.controller';

const router = Router();

router.use(adminMiddleware); // All admin routes require API key

// Deposit management
router.get('/deposits/pending', getPendingDeposits);
router.post('/deposits/:id/approve', approveDeposit);
router.post('/deposits/:id/reject', rejectDeposit);

// Withdrawal management
router.get('/withdrawals/pending', getPendingWithdrawals);
router.post('/withdrawals/:id/complete', completeWithdrawal);
router.post('/withdrawals/:id/reject', rejectWithdrawal);

// Dashboard stats
router.get('/stats', getDashboardStats);

// User management
router.get('/users', getUsers);
router.post('/users/:id/balance', updateUserBalance);

export default router;
