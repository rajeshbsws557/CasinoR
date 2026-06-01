// ============================================
// Wallet Controller — Deposits, Withdrawals, Balance
// ============================================

import { Request, Response } from 'express';
import { ObjectId } from 'mongodb';
import { getDb, getClient } from '../services/MongoService';
import { getRedisClient } from '../services/RedisService';
import { config } from '../config/env';
import { DepositRequest, WithdrawalRequest } from '../types';

// ─── Validation Helpers ───

const BD_PHONE_REGEX = /^01[3-9]\d{8}$/; // Bangladesh 11-digit mobile format
const TRANSACTION_ID_REGEX = /^[A-Za-z0-9]{4,30}$/; // Alphanumeric, 4-30 chars

function isValidPaymentMethod(method: string): method is 'bkash' | 'nagad' {
  return method === 'bkash' || method === 'nagad';
}

// ─── Balance ───

/**
 * GET /api/wallet/balance
 * Returns the user's current balance in BDT.
 */
export async function getBalance(req: Request, res: Response): Promise<void> {
  try {
    const db = getDb();
    const user = await db.collection('users').findOne(
      { _id: new ObjectId(req.user!.userId) },
      { projection: { balance: 1 } }
    );

    if (!user) {
      res.status(404).json({ success: false, error: 'User not found' });
      return;
    }

    res.json({
      success: true,
      data: {
        balance: user.balance,
        formatted: `৳${(user.balance / 100).toFixed(2)}`,
        currency: 'BDT',
      },
    });
  } catch (error) {
    console.error('[WalletController] getBalance error:', error);
    res.status(500).json({ success: false, error: 'Failed to get balance' });
  }
}

// ─── Transactions ───

/**
 * GET /api/wallet/transactions
 * Returns paginated transaction history.
 */
export async function getTransactions(req: Request, res: Response): Promise<void> {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 20));
    const skip = (page - 1) * limit;

    const db = getDb();
    const userId = new ObjectId(req.user!.userId);

    const [transactions, total] = await Promise.all([
      db.collection('transactions')
        .find({ user_id: userId })
        .sort({ created_at: -1 })
        .skip(skip)
        .limit(limit)
        .toArray(),
      db.collection('transactions').countDocuments({ user_id: userId }),
    ]);

    res.json({
      success: true,
      data: {
        transactions: transactions.map((tx) => ({
          id: tx._id.toString(),
          type: tx.type,
          amount: tx.amount,
          formattedAmount: `৳${(Math.abs(tx.amount) / 100).toFixed(2)}`,
          balanceAfter: tx.balance_after,
          referenceId: tx.reference_id,
          createdAt: tx.created_at,
        })),
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
        },
      },
    });
  } catch (error) {
    console.error('[WalletController] getTransactions error:', error);
    res.status(500).json({ success: false, error: 'Failed to get transactions' });
  }
}

// ─── Deposit Info ───

/**
 * GET /api/wallet/deposit-info
 * Returns the bKash/Nagad number and deposit instructions.
 */
export async function getDepositInfo(_req: Request, res: Response): Promise<void> {
  res.json({
    success: true,
    data: {
      payment_number: config.wallet.paymentNumber,
      methods: ['bkash', 'nagad'],
      currency: 'BDT',
      min_amount: config.wallet.minDeposit,
      max_amount: config.wallet.maxDeposit,
      min_formatted: `৳${(config.wallet.minDeposit / 100).toFixed(0)}`,
      max_formatted: `৳${(config.wallet.maxDeposit / 100).toFixed(0)}`,
      instructions: [
        'Open your bKash or Nagad app',
        `Cash Out to: ${config.wallet.paymentNumber}`,
        'Complete the transaction',
        'Enter the Transaction ID below and submit',
        'Your balance will be credited after admin verification',
      ],
    },
  });
}

// ─── Submit Deposit ───

/**
 * POST /api/wallet/deposit
 * Submits a deposit request with bKash/Nagad transaction ID.
 * Deposit is PENDING until admin approves.
 */
export async function submitDeposit(req: Request, res: Response): Promise<void> {
  try {
    const { method, transaction_id, amount } = req.body as DepositRequest;

    // ── Validate method ──
    if (!method || !isValidPaymentMethod(method)) {
      res.status(400).json({
        success: false,
        error: 'Payment method must be "bkash" or "nagad"',
      });
      return;
    }

    // ── Validate transaction ID ──
    if (!transaction_id || typeof transaction_id !== 'string') {
      res.status(400).json({
        success: false,
        error: 'Transaction ID is required',
      });
      return;
    }

    const trimmedTxId = transaction_id.trim();
    if (!TRANSACTION_ID_REGEX.test(trimmedTxId)) {
      res.status(400).json({
        success: false,
        error: 'Transaction ID must be 4-30 alphanumeric characters',
      });
      return;
    }

    // ── Validate amount ──
    if (!amount || typeof amount !== 'number' || !Number.isInteger(amount) || amount <= 0) {
      res.status(400).json({
        success: false,
        error: 'Amount must be a positive integer (in paisa)',
      });
      return;
    }

    if (amount < config.wallet.minDeposit) {
      res.status(400).json({
        success: false,
        error: `Minimum deposit is ৳${(config.wallet.minDeposit / 100).toFixed(0)}`,
      });
      return;
    }

    if (amount > config.wallet.maxDeposit) {
      res.status(400).json({
        success: false,
        error: `Maximum deposit is ৳${(config.wallet.maxDeposit / 100).toFixed(0)}`,
      });
      return;
    }

    const db = getDb();
    const userId = new ObjectId(req.user!.userId);

    // ── Check for duplicate transaction ID (prevent replay) ──
    const existingDeposit = await db.collection('deposits').findOne({
      transaction_id: trimmedTxId,
    });

    if (existingDeposit) {
      res.status(409).json({
        success: false,
        error: 'This transaction ID has already been submitted',
      });
      return;
    }

    // ── Check for too many pending deposits ──
    const pendingCount = await db.collection('deposits').countDocuments({
      user_id: userId,
      status: 'pending',
    });

    if (pendingCount >= 5) {
      res.status(429).json({
        success: false,
        error: 'You already have 5 pending deposits. Please wait for them to be reviewed.',
      });
      return;
    }

    // ── Create deposit record ──
    const depositDoc = {
      user_id: userId,
      method,
      transaction_id: trimmedTxId,
      amount,
      status: 'pending' as const,
      submitted_at: new Date(),
    };

    const result = await db.collection('deposits').insertOne(depositDoc);

    console.log(`[Wallet] Deposit submitted: user=${req.user!.username} method=${method} txId=${trimmedTxId} amount=৳${(amount / 100).toFixed(2)}`);

    res.status(201).json({
      success: true,
      data: {
        deposit_id: result.insertedId.toString(),
        status: 'pending',
        message: 'Deposit submitted successfully. Your balance will be credited after verification.',
      },
    });
  } catch (error) {
    console.error('[WalletController] submitDeposit error:', error);
    res.status(500).json({ success: false, error: 'Failed to submit deposit' });
  }
}

// ─── Deposit History ───

/**
 * GET /api/wallet/deposits
 * Returns the user's deposit history with statuses.
 */
export async function getDeposits(req: Request, res: Response): Promise<void> {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 20));
    const skip = (page - 1) * limit;

    const db = getDb();
    const userId = new ObjectId(req.user!.userId);

    const [deposits, total] = await Promise.all([
      db.collection('deposits')
        .find({ user_id: userId })
        .sort({ submitted_at: -1 })
        .skip(skip)
        .limit(limit)
        .toArray(),
      db.collection('deposits').countDocuments({ user_id: userId }),
    ]);

    res.json({
      success: true,
      data: {
        deposits: deposits.map((d) => ({
          id: d._id.toString(),
          method: d.method,
          transactionId: d.transaction_id,
          amount: d.amount,
          formattedAmount: `৳${(d.amount / 100).toFixed(2)}`,
          status: d.status,
          rejectReason: d.reject_reason,
          submittedAt: d.submitted_at,
          reviewedAt: d.reviewed_at,
        })),
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
      },
    });
  } catch (error) {
    console.error('[WalletController] getDeposits error:', error);
    res.status(500).json({ success: false, error: 'Failed to get deposits' });
  }
}

// ─── Submit Withdrawal ───

/**
 * POST /api/wallet/withdraw
 * Submits a withdrawal request. Balance is debited immediately.
 * Admin processes the actual bKash/Nagad transfer manually.
 */
export async function submitWithdrawal(req: Request, res: Response): Promise<void> {
  try {
    const { method, phone_number, amount } = req.body as WithdrawalRequest;

    // ── Validate method ──
    if (!method || !isValidPaymentMethod(method)) {
      res.status(400).json({
        success: false,
        error: 'Payment method must be "bkash" or "nagad"',
      });
      return;
    }

    // ── Validate phone number ──
    if (!phone_number || typeof phone_number !== 'string') {
      res.status(400).json({
        success: false,
        error: 'Phone number is required',
      });
      return;
    }

    const trimmedPhone = phone_number.trim();
    if (!BD_PHONE_REGEX.test(trimmedPhone)) {
      res.status(400).json({
        success: false,
        error: 'Invalid Bangladesh phone number. Must be 11 digits starting with 01.',
      });
      return;
    }

    // ── Validate amount ──
    if (!amount || typeof amount !== 'number' || !Number.isInteger(amount) || amount <= 0) {
      res.status(400).json({
        success: false,
        error: 'Amount must be a positive integer (in paisa)',
      });
      return;
    }

    if (amount < config.wallet.minWithdrawal) {
      res.status(400).json({
        success: false,
        error: `Minimum withdrawal is ৳${(config.wallet.minWithdrawal / 100).toFixed(0)}`,
      });
      return;
    }

    if (amount > config.wallet.maxWithdrawal) {
      res.status(400).json({
        success: false,
        error: `Maximum withdrawal is ৳${(config.wallet.maxWithdrawal / 100).toFixed(0)}`,
      });
      return;
    }

    const db = getDb();
    const userId = new ObjectId(req.user!.userId);

    // ── Cooldown check: max 1 withdrawal per 24 hours ──
    const lastWithdrawal = await db.collection('withdrawals').findOne(
      { user_id: userId, status: { $in: ['pending', 'completed'] } },
      { sort: { requested_at: -1 } }
    );

    if (lastWithdrawal) {
      const timeSinceLastMs = Date.now() - new Date(lastWithdrawal.requested_at).getTime();
      if (timeSinceLastMs < config.wallet.withdrawalCooldownMs) {
        const remainingHours = Math.ceil((config.wallet.withdrawalCooldownMs - timeSinceLastMs) / 3600000);
        res.status(429).json({
          success: false,
          error: `You can only withdraw once every 24 hours. Try again in ~${remainingHours} hour(s).`,
        });
        return;
      }
    }

    // ── Check pending withdrawals ──
    const pendingCount = await db.collection('withdrawals').countDocuments({
      user_id: userId,
      status: 'pending',
    });

    if (pendingCount >= 3) {
      res.status(429).json({
        success: false,
        error: 'You already have 3 pending withdrawals. Please wait for them to be processed.',
      });
      return;
    }

    // ── Atomic balance debit via MongoDB transaction ──
    const mongoClient = getClient();
    const session = mongoClient.startSession();

    try {
      let withdrawalId: string = '';
      let newBalance = 0;

      await session.withTransaction(async () => {
        // Debit balance (fails if insufficient)
        const userResult = await db.collection('users').findOneAndUpdate(
          { _id: userId, balance: { $gte: amount } },
          {
            $inc: { balance: -amount },
            $set: { updated_at: new Date() },
          },
          { returnDocument: 'after', session }
        );

        if (!userResult) {
          throw new Error('Insufficient balance');
        }

        newBalance = userResult.balance;

        const now = new Date();

        // Create withdrawal record
        const withdrawalResult = await db.collection('withdrawals').insertOne({
          user_id: userId,
          method,
          phone_number: trimmedPhone,
          amount,
          status: 'pending',
          requested_at: now,
        }, { session });

        withdrawalId = withdrawalResult.insertedId.toString();

        // Record transaction in ledger
        await db.collection('transactions').insertOne({
          user_id: userId,
          type: 'withdrawal',
          amount: -amount,
          balance_after: newBalance,
          reference_id: `withdrawal_${withdrawalId}`,
          created_at: now,
        }, { session });
      });

      console.log(`[Wallet] Withdrawal submitted: user=${req.user!.username} method=${method} phone=${trimmedPhone} amount=৳${(amount / 100).toFixed(2)}`);

      res.status(201).json({
        success: true,
        data: {
          withdrawal_id: withdrawalId,
          balance: newBalance,
          formatted_balance: `৳${(newBalance / 100).toFixed(2)}`,
          status: 'pending',
          message: 'Withdrawal request submitted. You will receive the funds in your account shortly.',
        },
      });
    } catch (error) {
      if ((error as Error).message === 'Insufficient balance') {
        res.status(400).json({ success: false, error: 'Insufficient balance for this withdrawal' });
      } else {
        throw error;
      }
    } finally {
      await session.endSession();
    }
  } catch (error) {
    console.error('[WalletController] submitWithdrawal error:', error);
    res.status(500).json({ success: false, error: 'Failed to submit withdrawal' });
  }
}

// ─── Withdrawal History ───

/**
 * GET /api/wallet/withdrawals
 * Returns the user's withdrawal history with statuses.
 */
export async function getWithdrawals(req: Request, res: Response): Promise<void> {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 20));
    const skip = (page - 1) * limit;

    const db = getDb();
    const userId = new ObjectId(req.user!.userId);

    const [withdrawals, total] = await Promise.all([
      db.collection('withdrawals')
        .find({ user_id: userId })
        .sort({ requested_at: -1 })
        .skip(skip)
        .limit(limit)
        .toArray(),
      db.collection('withdrawals').countDocuments({ user_id: userId }),
    ]);

    res.json({
      success: true,
      data: {
        withdrawals: withdrawals.map((w) => ({
          id: w._id.toString(),
          method: w.method,
          phoneNumber: w.phone_number,
          amount: w.amount,
          formattedAmount: `৳${(w.amount / 100).toFixed(2)}`,
          status: w.status,
          rejectReason: w.reject_reason,
          requestedAt: w.requested_at,
          processedAt: w.processed_at,
        })),
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
      },
    });
  } catch (error) {
    console.error('[WalletController] getWithdrawals error:', error);
    res.status(500).json({ success: false, error: 'Failed to get withdrawals' });
  }
}
