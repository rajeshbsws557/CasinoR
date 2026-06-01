// ==============================================
// CasinoR — MongoDB Initialization Script
// Runs once on first container boot
// ==============================================

db = db.getSiblingDB('crashgame');

print('🎰 Initializing CrashGame database...');

// ─────────────────────────────────────────────
// Users Collection
// ─────────────────────────────────────────────
db.createCollection('users', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['username', 'email', 'password_hash', 'balance'],
      properties: {
        username: { bsonType: 'string', minLength: 3, maxLength: 20 },
        email: { bsonType: 'string' },
        password_hash: { bsonType: 'string' },
        balance: { bsonType: 'long', minimum: 0 },
        client_seed: { bsonType: 'string' },
        total_wagered: { bsonType: 'long', minimum: 0 },
        total_profit: { bsonType: 'long' },
        created_at: { bsonType: 'date' },
        updated_at: { bsonType: 'date' }
      }
    }
  }
});

db.users.createIndex({ email: 1 }, { unique: true });
db.users.createIndex({ username: 1 }, { unique: true });

print('  ✓ users collection created');

// ─────────────────────────────────────────────
// Game Rounds Collection
// ─────────────────────────────────────────────
db.createCollection('game_rounds', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['round_id', 'nonce', 'server_seed_hash', 'status'],
      properties: {
        round_id: { bsonType: 'string' },
        nonce: { bsonType: 'int' },
        server_seed: { bsonType: 'string' },
        server_seed_hash: { bsonType: 'string' },
        client_seeds: { bsonType: 'array' },
        crash_point: { bsonType: 'double' },
        status: { enum: ['active', 'completed'] },
        started_at: { bsonType: 'date' },
        crashed_at: { bsonType: 'date' },
        total_bets: { bsonType: 'int' },
        total_wagered: { bsonType: 'long' },
        total_paid_out: { bsonType: 'long' }
      }
    }
  }
});

db.game_rounds.createIndex({ round_id: 1 }, { unique: true });
db.game_rounds.createIndex({ nonce: 1 }, { unique: true });
db.game_rounds.createIndex({ crashed_at: -1 });
db.game_rounds.createIndex({ status: 1 });

print('  ✓ game_rounds collection created');

// ─────────────────────────────────────────────
// Bets Collection
// ─────────────────────────────────────────────
db.createCollection('bets', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['round_id', 'user_id', 'amount', 'status'],
      properties: {
        round_id: { bsonType: 'string' },
        user_id: { bsonType: 'objectId' },
        amount: { bsonType: 'long', minimum: 1 },
        auto_cashout: { bsonType: ['double', 'null'] },
        cashout_multiplier: { bsonType: ['double', 'null'] },
        profit: { bsonType: ['long', 'null'] },
        status: { enum: ['pending', 'won', 'lost'] },
        placed_at: { bsonType: 'date' },
        cashed_out_at: { bsonType: ['date', 'null'] }
      }
    }
  }
});

db.bets.createIndex({ user_id: 1, placed_at: -1 });
db.bets.createIndex({ round_id: 1 });
db.bets.createIndex({ status: 1 });

print('  ✓ bets collection created');

// ─────────────────────────────────────────────
// Transactions Collection (Ledger)
// ─────────────────────────────────────────────
db.createCollection('transactions', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['user_id', 'type', 'amount', 'balance_after'],
      properties: {
        user_id: { bsonType: 'objectId' },
        type: { enum: ['deposit', 'withdrawal', 'bet_place', 'bet_win'] },
        amount: { bsonType: 'long' },
        balance_after: { bsonType: 'long' },
        reference_id: { bsonType: 'string' },
        created_at: { bsonType: 'date' }
      }
    }
  }
});

db.transactions.createIndex({ user_id: 1, created_at: -1 });
db.transactions.createIndex({ reference_id: 1 });

print('  ✓ transactions collection created');

print('🎰 CrashGame database initialization complete!');
