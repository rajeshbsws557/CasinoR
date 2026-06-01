// ============================================
// Admin Controller — Deposit Approval & Withdrawal Processing
// ============================================

import { Request, Response } from 'express';
import { ObjectId } from 'mongodb';
import { getDb, getClient } from '../services/MongoService';

// ─── Deposit Management ───

/**
 * GET /api/admin/deposits/pending
 * Lists all pending deposits for admin review.
 */
export async function getPendingDeposits(req: Request, res: Response): Promise<void> {
  try {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string) || 50));
    const skip = (page - 1) * limit;

    const [deposits, total] = await Promise.all([
      db.collection('deposits')
        .aggregate([
          { $match: { status: 'pending' } },
          { $sort: { submitted_at: 1 } }, // Oldest first
          { $skip: skip },
          { $limit: limit },
          {
            $lookup: {
              from: 'users',
              localField: 'user_id',
              foreignField: '_id',
              as: 'user',
              pipeline: [{ $project: { username: 1, email: 1 } }],
            },
          },
          { $unwind: { path: '$user', preserveNullAndEmptyArrays: true } },
        ])
        .toArray(),
      db.collection('deposits').countDocuments({ status: 'pending' }),
    ]);

    res.json({
      success: true,
      data: {
        deposits: deposits.map((d) => ({
          id: d._id.toString(),
          userId: d.user_id.toString(),
          username: d.user?.username || 'unknown',
          email: d.user?.email || 'unknown',
          method: d.method,
          transactionId: d.transaction_id,
          amount: d.amount,
          formattedAmount: `৳${(d.amount / 100).toFixed(2)}`,
          submittedAt: d.submitted_at,
        })),
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
      },
    });
  } catch (error) {
    console.error('[AdminController] getPendingDeposits error:', error);
    res.status(500).json({ success: false, error: 'Failed to get pending deposits' });
  }
}

/**
 * POST /api/admin/deposits/:id/approve
 * Approves a deposit and credits the user's balance atomically.
 */
export async function approveDeposit(req: Request, res: Response): Promise<void> {
  try {
    const depositId = req.params.id;

    if (!ObjectId.isValid(depositId)) {
      res.status(400).json({ success: false, error: 'Invalid deposit ID' });
      return;
    }

    const db = getDb();
    const mongoClient = getClient();
    const session = mongoClient.startSession();

    try {
      let result: any = null;

      await session.withTransaction(async () => {
        // Find and lock the deposit
        const deposit = await db.collection('deposits').findOneAndUpdate(
          { _id: new ObjectId(depositId), status: 'pending' },
          {
            $set: {
              status: 'approved',
              reviewed_at: new Date(),
              reviewed_by: 'admin',
            },
          },
          { returnDocument: 'after', session }
        );

        if (!deposit) {
          throw new Error('Deposit not found or already processed');
        }

        // Credit user balance
        const userResult = await db.collection('users').findOneAndUpdate(
          { _id: deposit.user_id },
          {
            $inc: { balance: deposit.amount },
            $set: { updated_at: new Date() },
          },
          { returnDocument: 'after', session }
        );

        if (!userResult) {
          throw new Error('User not found');
        }

        // Record transaction in ledger
        await db.collection('transactions').insertOne({
          user_id: deposit.user_id,
          type: 'deposit',
          amount: deposit.amount,
          balance_after: userResult.balance,
          reference_id: `deposit_${depositId}`,
          created_at: new Date(),
        }, { session });

        result = {
          depositId,
          userId: deposit.user_id.toString(),
          amount: deposit.amount,
          newBalance: userResult.balance,
        };
      });

      console.log(`[Admin] Deposit approved: deposit=${depositId} user=${result.userId} amount=৳${(result.amount / 100).toFixed(2)} newBalance=৳${(result.newBalance / 100).toFixed(2)}`);

      res.json({
        success: true,
        data: {
          ...result,
          formattedAmount: `৳${(result.amount / 100).toFixed(2)}`,
          formattedBalance: `৳${(result.newBalance / 100).toFixed(2)}`,
          message: 'Deposit approved and balance credited',
        },
      });
    } catch (error) {
      if ((error as Error).message === 'Deposit not found or already processed') {
        res.status(404).json({ success: false, error: (error as Error).message });
      } else {
        throw error;
      }
    } finally {
      await session.endSession();
    }
  } catch (error) {
    console.error('[AdminController] approveDeposit error:', error);
    res.status(500).json({ success: false, error: 'Failed to approve deposit' });
  }
}

/**
 * POST /api/admin/deposits/:id/reject
 * Rejects a deposit with a reason.
 */
export async function rejectDeposit(req: Request, res: Response): Promise<void> {
  try {
    const depositId = req.params.id;
    const { reason } = req.body;

    if (!ObjectId.isValid(depositId)) {
      res.status(400).json({ success: false, error: 'Invalid deposit ID' });
      return;
    }

    const db = getDb();
    const result = await db.collection('deposits').findOneAndUpdate(
      { _id: new ObjectId(depositId), status: 'pending' },
      {
        $set: {
          status: 'rejected',
          reject_reason: reason || 'No reason provided',
          reviewed_at: new Date(),
          reviewed_by: 'admin',
        },
      },
      { returnDocument: 'after' }
    );

    if (!result) {
      res.status(404).json({ success: false, error: 'Deposit not found or already processed' });
      return;
    }

    console.log(`[Admin] Deposit rejected: deposit=${depositId} reason=${reason || 'none'}`);

    res.json({
      success: true,
      data: { depositId, status: 'rejected', message: 'Deposit rejected' },
    });
  } catch (error) {
    console.error('[AdminController] rejectDeposit error:', error);
    res.status(500).json({ success: false, error: 'Failed to reject deposit' });
  }
}

// ─── Withdrawal Management ───

/**
 * GET /api/admin/withdrawals/pending
 * Lists all pending withdrawals for admin processing.
 */
export async function getPendingWithdrawals(req: Request, res: Response): Promise<void> {
  try {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string) || 50));
    const skip = (page - 1) * limit;

    const [withdrawals, total] = await Promise.all([
      db.collection('withdrawals')
        .aggregate([
          { $match: { status: 'pending' } },
          { $sort: { requested_at: 1 } },
          { $skip: skip },
          { $limit: limit },
          {
            $lookup: {
              from: 'users',
              localField: 'user_id',
              foreignField: '_id',
              as: 'user',
              pipeline: [{ $project: { username: 1, email: 1 } }],
            },
          },
          { $unwind: { path: '$user', preserveNullAndEmptyArrays: true } },
        ])
        .toArray(),
      db.collection('withdrawals').countDocuments({ status: 'pending' }),
    ]);

    res.json({
      success: true,
      data: {
        withdrawals: withdrawals.map((w) => ({
          id: w._id.toString(),
          userId: w.user_id.toString(),
          username: w.user?.username || 'unknown',
          email: w.user?.email || 'unknown',
          method: w.method,
          phoneNumber: w.phone_number,
          amount: w.amount,
          formattedAmount: `৳${(w.amount / 100).toFixed(2)}`,
          requestedAt: w.requested_at,
        })),
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
      },
    });
  } catch (error) {
    console.error('[AdminController] getPendingWithdrawals error:', error);
    res.status(500).json({ success: false, error: 'Failed to get pending withdrawals' });
  }
}

/**
 * POST /api/admin/withdrawals/:id/complete
 * Marks a withdrawal as completed (admin has sent the money).
 */
export async function completeWithdrawal(req: Request, res: Response): Promise<void> {
  try {
    const withdrawalId = req.params.id;

    if (!ObjectId.isValid(withdrawalId)) {
      res.status(400).json({ success: false, error: 'Invalid withdrawal ID' });
      return;
    }

    const db = getDb();
    const result = await db.collection('withdrawals').findOneAndUpdate(
      { _id: new ObjectId(withdrawalId), status: 'pending' },
      {
        $set: {
          status: 'completed',
          processed_at: new Date(),
          processed_by: 'admin',
        },
      },
      { returnDocument: 'after' }
    );

    if (!result) {
      res.status(404).json({ success: false, error: 'Withdrawal not found or already processed' });
      return;
    }

    console.log(`[Admin] Withdrawal completed: withdrawal=${withdrawalId} method=${result.method} phone=${result.phone_number} amount=৳${(result.amount / 100).toFixed(2)}`);

    res.json({
      success: true,
      data: { withdrawalId, status: 'completed', message: 'Withdrawal marked as completed' },
    });
  } catch (error) {
    console.error('[AdminController] completeWithdrawal error:', error);
    res.status(500).json({ success: false, error: 'Failed to complete withdrawal' });
  }
}

/**
 * POST /api/admin/withdrawals/:id/reject
 * Rejects a withdrawal and refunds the balance atomically.
 */
export async function rejectWithdrawal(req: Request, res: Response): Promise<void> {
  try {
    const withdrawalId = req.params.id;
    const { reason } = req.body;

    if (!ObjectId.isValid(withdrawalId)) {
      res.status(400).json({ success: false, error: 'Invalid withdrawal ID' });
      return;
    }

    const db = getDb();
    const mongoClient = getClient();
    const session = mongoClient.startSession();

    try {
      let result: any = null;

      await session.withTransaction(async () => {
        // Find and update withdrawal
        const withdrawal = await db.collection('withdrawals').findOneAndUpdate(
          { _id: new ObjectId(withdrawalId), status: 'pending' },
          {
            $set: {
              status: 'rejected',
              reject_reason: reason || 'No reason provided',
              processed_at: new Date(),
              processed_by: 'admin',
            },
          },
          { returnDocument: 'after', session }
        );

        if (!withdrawal) {
          throw new Error('Withdrawal not found or already processed');
        }

        // Refund balance
        const userResult = await db.collection('users').findOneAndUpdate(
          { _id: withdrawal.user_id },
          {
            $inc: { balance: withdrawal.amount },
            $set: { updated_at: new Date() },
          },
          { returnDocument: 'after', session }
        );

        if (!userResult) {
          throw new Error('User not found');
        }

        // Record refund in ledger
        await db.collection('transactions').insertOne({
          user_id: withdrawal.user_id,
          type: 'deposit', // Refund is effectively a deposit
          amount: withdrawal.amount,
          balance_after: userResult.balance,
          reference_id: `withdrawal_refund_${withdrawalId}`,
          created_at: new Date(),
        }, { session });

        result = {
          withdrawalId,
          userId: withdrawal.user_id.toString(),
          refundedAmount: withdrawal.amount,
          newBalance: userResult.balance,
        };
      });

      console.log(`[Admin] Withdrawal rejected & refunded: withdrawal=${withdrawalId} refund=৳${(result.refundedAmount / 100).toFixed(2)}`);

      res.json({
        success: true,
        data: {
          ...result,
          formattedRefund: `৳${(result.refundedAmount / 100).toFixed(2)}`,
          formattedBalance: `৳${(result.newBalance / 100).toFixed(2)}`,
          message: 'Withdrawal rejected and balance refunded',
        },
      });
    } catch (error) {
      if ((error as Error).message === 'Withdrawal not found or already processed') {
        res.status(404).json({ success: false, error: (error as Error).message });
      } else {
        throw error;
      }
    } finally {
      await session.endSession();
    }
  } catch (error) {
    console.error('[AdminController] rejectWithdrawal error:', error);
    res.status(500).json({ success: false, error: 'Failed to reject withdrawal' });
  }
}

// ─── Dashboard & User Management ───

/**
 * GET /api/admin/stats
 * Retrieves dashboard overview statistics
 */
export async function getDashboardStats(req: Request, res: Response): Promise<void> {
  try {
    const db = getDb();
    const [
      totalUsers,
      totalDepositsAgg,
      totalWithdrawalsAgg,
      pendingDeposits,
      pendingWithdrawals
    ] = await Promise.all([
      db.collection('users').countDocuments(),
      db.collection('deposits').aggregate([
        { $match: { status: 'approved' } },
        { $group: { _id: null, total: { $sum: '$amount' } } }
      ]).toArray(),
      db.collection('withdrawals').aggregate([
        { $match: { status: 'completed' } },
        { $group: { _id: null, total: { $sum: '$amount' } } }
      ]).toArray(),
      db.collection('deposits').countDocuments({ status: 'pending' }),
      db.collection('withdrawals').countDocuments({ status: 'pending' })
    ]);

    const totalDeposits = totalDepositsAgg[0]?.total || 0;
    const totalWithdrawals = totalWithdrawalsAgg[0]?.total || 0;

    res.json({
      success: true,
      data: {
        totalUsers,
        totalDeposits,
        totalWithdrawals,
        pendingDeposits,
        pendingWithdrawals,
        formattedTotalDeposits: `৳${(totalDeposits / 100).toFixed(2)}`,
        formattedTotalWithdrawals: `৳${(totalWithdrawals / 100).toFixed(2)}`,
      }
    });
  } catch (error) {
    console.error('[AdminController] getDashboardStats error:', error);
    res.status(500).json({ success: false, error: 'Failed to get dashboard stats' });
  }
}

/**
 * GET /api/admin/users
 * Retrieves a list of all users
 */
export async function getUsers(req: Request, res: Response): Promise<void> {
  try {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string) || 50));
    const skip = (page - 1) * limit;
    
    // Optional search by username or email
    const search = req.query.search as string;
    const query: any = {};
    if (search) {
      query.$or = [
        { username: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } },
      ];
    }

    const [users, total] = await Promise.all([
      db.collection('users')
        .find(query)
        .project({ password: 0 }) // Exclude password hashes
        .sort({ created_at: -1 })
        .skip(skip)
        .limit(limit)
        .toArray(),
      db.collection('users').countDocuments(query),
    ]);

    res.json({
      success: true,
      data: {
        users: users.map(u => ({
          id: u._id.toString(),
          username: u.username,
          email: u.email,
          balance: u.balance,
          formattedBalance: `৳${(u.balance / 100).toFixed(2)}`,
          createdAt: u.created_at,
          updatedAt: u.updated_at,
        })),
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
      }
    });
  } catch (error) {
    console.error('[AdminController] getUsers error:', error);
    res.status(500).json({ success: false, error: 'Failed to get users' });
  }
}

/**
 * POST /api/admin/users/:id/balance
 * Manually updates a user's balance
 */
export async function updateUserBalance(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.params.id;
    const { amount, reason } = req.body;

    if (!ObjectId.isValid(userId)) {
      res.status(400).json({ success: false, error: 'Invalid user ID' });
      return;
    }
    
    if (typeof amount !== 'number') {
      res.status(400).json({ success: false, error: 'Amount must be a number (paisa)' });
      return;
    }

    const db = getDb();
    const mongoClient = getClient();
    const session = mongoClient.startSession();

    try {
      let result: any = null;

      await session.withTransaction(async () => {
        // Find and update user
        const userResult = await db.collection('users').findOneAndUpdate(
          { _id: new ObjectId(userId) },
          {
            $inc: { balance: amount },
            $set: { updated_at: new Date() },
          },
          { returnDocument: 'after', session }
        );

        if (!userResult) {
          throw new Error('User not found');
        }

        if (userResult.balance < 0) {
           throw new Error('Balance cannot be negative');
        }

        // Record transaction
        await db.collection('transactions').insertOne({
          user_id: userResult._id,
          type: amount >= 0 ? 'admin_credit' : 'admin_debit',
          amount: Math.abs(amount),
          balance_after: userResult.balance,
          reference_id: `admin_adj_${new ObjectId().toString()}`,
          metadata: { reason: reason || 'Manual admin adjustment' },
          created_at: new Date(),
        }, { session });

        result = {
          userId: userResult._id.toString(),
          adjustment: amount,
          newBalance: userResult.balance,
        };
      });

      console.log(`[Admin] Balance adjusted: user=${userId} change=৳${(result.adjustment / 100).toFixed(2)} reason="${reason}"`);

      res.json({
        success: true,
        data: {
          ...result,
          formattedAdjustment: `${result.adjustment >= 0 ? '+' : '-'}৳${(Math.abs(result.adjustment) / 100).toFixed(2)}`,
          formattedBalance: `৳${(result.newBalance / 100).toFixed(2)}`,
          message: 'User balance updated successfully',
        },
      });
    } catch (error) {
      if ((error as Error).message === 'User not found' || (error as Error).message === 'Balance cannot be negative') {
        res.status(400).json({ success: false, error: (error as Error).message });
      } else {
        throw error;
      }
    } finally {
      await session.endSession();
    }
  } catch (error) {
    console.error('[AdminController] updateUserBalance error:', error);
    res.status(500).json({ success: false, error: 'Failed to update user balance' });
  }
}
