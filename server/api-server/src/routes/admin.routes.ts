// ============================================
// Admin Routes — Protected by HttpOnly Cookie Session
// ============================================

import { Router } from 'express';
import {
  adminSessionMiddleware,
  adminLoginHandler,
  adminLogoutHandler,
} from '../middleware/admin-session';
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

// ── Public endpoints (before auth middleware) ──
router.post('/login', adminLoginHandler);
router.post('/logout', adminLogoutHandler);

// ── Protected endpoints (require valid session cookie or X-Admin-Key) ──
router.use(adminSessionMiddleware);

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
