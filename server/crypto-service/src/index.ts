// ============================================
// Crypto Service — Entry Point
// ============================================

import express from 'express';
import cors from 'cors';
import { config } from './config/env';
import { getRedisClient, closeRedis } from './services/RedisService';
import { connectMongo, closeMongo } from './services/MongoService';
import cryptoRoutes from './routes/crypto.routes';

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'crypto-service' });
});

// Routes
app.use('/api/crypto', cryptoRoutes);

// Startup
async function start(): Promise<void> {
  try {
    // Connect to data stores
    await connectMongo();
    getRedisClient(); // Initialize Redis connection

    app.listen(config.port, () => {
      console.log(`🔐 Crypto Service running on port ${config.port}`);
      console.log(`   Environment: ${config.nodeEnv}`);
    });
  } catch (error) {
    console.error('Failed to start Crypto Service:', error);
    process.exit(1);
  }
}

// Graceful shutdown
async function shutdown(): Promise<void> {
  console.log('\n🔐 Shutting down Crypto Service...');
  await closeRedis();
  await closeMongo();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

start();
