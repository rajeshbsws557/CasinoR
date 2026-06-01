// ============================================
// Database Index Setup Script
// Run: npx ts-node src/scripts/setupIndexes.ts
// ============================================

import * as dotenv from 'dotenv';
dotenv.config();

import { MongoClient } from 'mongodb';

const MONGO_URL = process.env.MONGO_URL || 'mongodb://localhost:27017/crashgame';
const DB_NAME = 'crashgame';

async function setupIndexes(): Promise<void> {
  const client = new MongoClient(MONGO_URL);

  try {
    await client.connect();
    const db = client.db(DB_NAME);
    console.log('[Setup] Connected to MongoDB');

    // ─── Users Collection ───
    console.log('[Setup] Creating indexes for: users');
    await db.collection('users').createIndex(
      { email: 1 },
      { unique: true, name: 'idx_users_email_unique' }
    );
    await db.collection('users').createIndex(
      { username: 1 },
      { unique: true, name: 'idx_users_username_unique' }
    );

    // ─── Deposits Collection ───
    console.log('[Setup] Creating indexes for: deposits');
    await db.collection('deposits').createIndex(
      { transaction_id: 1 },
      { unique: true, name: 'idx_deposits_txid_unique' }
    );
    await db.collection('deposits').createIndex(
      { user_id: 1, status: 1 },
      { name: 'idx_deposits_user_status' }
    );
    await db.collection('deposits').createIndex(
      { status: 1, submitted_at: 1 },
      { name: 'idx_deposits_status_submitted' }
    );

    // ─── Withdrawals Collection ───
    console.log('[Setup] Creating indexes for: withdrawals');
    await db.collection('withdrawals').createIndex(
      { user_id: 1, status: 1 },
      { name: 'idx_withdrawals_user_status' }
    );
    await db.collection('withdrawals').createIndex(
      { user_id: 1, requested_at: -1 },
      { name: 'idx_withdrawals_user_requested' }
    );
    await db.collection('withdrawals').createIndex(
      { status: 1, requested_at: 1 },
      { name: 'idx_withdrawals_status_requested' }
    );

    // ─── Transactions Collection ───
    console.log('[Setup] Creating indexes for: transactions');
    await db.collection('transactions').createIndex(
      { user_id: 1, created_at: -1 },
      { name: 'idx_transactions_user_created' }
    );
    await db.collection('transactions').createIndex(
      { reference_id: 1 },
      { name: 'idx_transactions_reference' }
    );

    // ─── Bets Collection ───
    console.log('[Setup] Creating indexes for: bets');
    await db.collection('bets').createIndex(
      { round_id: 1, user_id: 1 },
      { name: 'idx_bets_round_user' }
    );
    await db.collection('bets').createIndex(
      { user_id: 1, placed_at: -1 },
      { name: 'idx_bets_user_placed' }
    );

    // ─── Game Rounds Collection ───
    console.log('[Setup] Creating indexes for: game_rounds');
    await db.collection('game_rounds').createIndex(
      { round_id: 1 },
      { unique: true, name: 'idx_rounds_roundid_unique' }
    );
    await db.collection('game_rounds').createIndex(
      { nonce: -1 },
      { name: 'idx_rounds_nonce_desc' }
    );

    console.log('\n✅ All indexes created successfully');
  } catch (error) {
    console.error('❌ Failed to create indexes:', error);
    process.exit(1);
  } finally {
    await client.close();
  }
}

setupIndexes();
