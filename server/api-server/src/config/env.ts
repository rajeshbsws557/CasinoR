// ============================================
// API Server — Environment Configuration
// ============================================

import * as dotenv from 'dotenv';
dotenv.config();

// Reject weak JWT secret in production
if (
  process.env.NODE_ENV === 'production' &&
  (!process.env.JWT_SECRET || process.env.JWT_SECRET === 'dev-secret-change-me')
) {
  console.error('FATAL: JWT_SECRET must be set to a strong value in production');
  process.exit(1);
}

export const config = {
  port: parseInt(process.env.PORT || '3001', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379',
  },

  mongo: {
    url: process.env.MONGO_URL || 'mongodb://localhost:27017/crashgame',
    dbName: 'crashgame',
  },

  jwt: {
    secret: process.env.JWT_SECRET || 'dev-secret-change-me',
    expiresIn: '24h',
  },

  cryptoService: {
    url: process.env.CRYPTO_SERVICE_URL || 'http://localhost:3002',
  },

  bcrypt: {
    saltRounds: 12,
  },

  admin: {
    apiKey: process.env.ADMIN_API_KEY || '',
  },

  wallet: {
    initialBalance: 0, // 0 for production — real money, no free credits
    // Payment gateway number for bKash/Nagad deposits
    paymentNumber: process.env.PAYMENT_NUMBER || '01637858197',
    // Deposit limits (in paisa: 100 paisa = 1 BDT)
    minDeposit: parseInt(process.env.MIN_DEPOSIT || '10000', 10),     // ৳100
    maxDeposit: parseInt(process.env.MAX_DEPOSIT || '5000000', 10),   // ৳50,000
    // Withdrawal limits (in paisa)
    minWithdrawal: parseInt(process.env.MIN_WITHDRAWAL || '50000', 10),  // ৳500
    maxWithdrawal: parseInt(process.env.MAX_WITHDRAWAL || '2500000', 10), // ৳25,000
    // Withdrawal cooldown in milliseconds (24 hours)
    withdrawalCooldownMs: parseInt(process.env.WITHDRAWAL_COOLDOWN_MS || '86400000', 10),
  },

  cors: {
    // Comma-separated origins, or '*' for dev
    allowedOrigins: process.env.CORS_ORIGINS || '*',
  },
} as const;
