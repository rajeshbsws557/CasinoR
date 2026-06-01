// ============================================
// Crypto Service — Environment Configuration
// ============================================

import * as dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3002', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379',
  },

  mongo: {
    url: process.env.MONGO_URL || 'mongodb://localhost:27017/crashgame',
    dbName: 'crashgame',
  },

  game: {
    houseEdgeDivisor: parseInt(process.env.HOUSE_EDGE_DIVISOR || '33', 10),
    serverSeedLength: 16,  // 16 hex characters = 8 bytes
  },
} as const;
