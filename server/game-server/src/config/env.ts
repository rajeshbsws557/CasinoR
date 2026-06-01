// ============================================
// Game Server — Environment Configuration
// ============================================

import * as dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
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
  },

  cryptoService: {
    url: process.env.CRYPTO_SERVICE_URL || 'http://localhost:3002',
  },

  game: {
    bettingPhaseMs: parseInt(process.env.BETTING_PHASE_MS || '7000', 10),
    cooldownPhaseMs: parseInt(process.env.COOLDOWN_PHASE_MS || '3000', 10),
    tickIntervalMs: parseInt(process.env.TICK_INTERVAL_MS || '50', 10),
    growthRate: parseFloat(process.env.GROWTH_RATE || '0.00006'),
    minBet: parseInt(process.env.MIN_BET || '100', 10),
    maxBet: parseInt(process.env.MAX_BET || '1000000', 10),
  },

  ws: {
    heartbeatIntervalMs: 30000,
    heartbeatTimeoutMs: 60000,
  },
} as const;
