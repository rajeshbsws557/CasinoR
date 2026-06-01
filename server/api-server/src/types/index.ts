// ============================================
// API Server — TypeScript Types
// ============================================

import { ObjectId } from 'mongodb';

// ─── Database Documents ───

export interface UserDocument {
  _id?: ObjectId;
  username: string;
  email: string;
  password_hash: string;
  balance: number;        // In paisa (1 BDT = 100 paisa)
  client_seed: string;
  total_wagered: number;
  total_profit: number;
  token_version: number;  // Increment to invalidate all existing JWTs
  created_at: Date;
  updated_at: Date;
}

export interface BetDocument {
  _id?: ObjectId;
  round_id: string;
  user_id: ObjectId;
  amount: number;
  auto_cashout: number | null;
  cashout_multiplier: number | null;
  profit: number | null;
  status: 'pending' | 'won' | 'lost';
  placed_at: Date;
  cashed_out_at: Date | null;
}

export interface GameRoundDocument {
  _id?: ObjectId;
  round_id: string;
  nonce: number;
  server_seed: string;
  server_seed_hash: string;
  client_seeds: string[];
  crash_point: number;
  status: 'active' | 'completed';
  started_at: Date;
  crashed_at: Date | null;
  total_bets: number;
  total_wagered: number;
  total_paid_out: number;
}

export interface TransactionDocument {
  _id?: ObjectId;
  user_id: ObjectId;
  type: 'deposit' | 'withdrawal' | 'bet_place' | 'bet_win';
  amount: number;
  balance_after: number;
  reference_id: string;
  created_at: Date;
}

// ─── Deposit & Withdrawal Documents ───

export type PaymentMethod = 'bkash' | 'nagad';
export type DepositStatus = 'pending' | 'approved' | 'rejected';
export type WithdrawalStatus = 'pending' | 'completed' | 'rejected';

export interface DepositDocument {
  _id?: ObjectId;
  user_id: ObjectId;
  method: PaymentMethod;
  transaction_id: string;      // bKash/Nagad cash-out transaction ID
  amount: number;              // In paisa
  status: DepositStatus;
  reject_reason?: string;
  submitted_at: Date;
  reviewed_at?: Date;
  reviewed_by?: string;        // Admin identifier
}

export interface WithdrawalDocument {
  _id?: ObjectId;
  user_id: ObjectId;
  method: PaymentMethod;
  phone_number: string;        // BD phone number (e.g., 01XXXXXXXXX)
  amount: number;              // In paisa
  status: WithdrawalStatus;
  reject_reason?: string;
  requested_at: Date;
  processed_at?: Date;
  processed_by?: string;       // Admin identifier
}

// ─── API Types ───

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
}

export interface AuthTokenPayload {
  userId: string;
  username: string;
  email: string;
  tokenVersion?: number;
}

export interface RegisterRequest {
  username: string;
  email: string;
  password: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface DepositRequest {
  method: PaymentMethod;
  transaction_id: string;
  amount: number;              // In paisa
}

export interface WithdrawalRequest {
  method: PaymentMethod;
  phone_number: string;
  amount: number;              // In paisa
}

export interface PaginationQuery {
  page?: number;
  limit?: number;
}

// Express Request augmentation
declare global {
  namespace Express {
    interface Request {
      user?: AuthTokenPayload;
    }
  }
}
