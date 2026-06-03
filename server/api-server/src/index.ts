// ============================================
// API Server — Entry Point
// ============================================

import express from 'express';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import { config } from './config/env';
import { getRedisClient, closeRedis } from './services/RedisService';
import { connectMongo, closeMongo } from './services/MongoService';
import { errorHandler } from './middleware/errorHandler';
import authRoutes from './routes/auth.routes';
import walletRoutes from './routes/wallet.routes';
import historyRoutes from './routes/history.routes';
import fairnessRoutes from './routes/fairness.routes';
import adminRoutes from './routes/admin.routes';

const app = express();

// ─── Security Middleware ───

// CORS configuration
const corsOptions: cors.CorsOptions = {
  origin: config.cors.allowedOrigins === '*'
    ? true
    : config.cors.allowedOrigins.split(',').map(o => o.trim()),
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Admin-Key'],
  credentials: true,
  maxAge: 86400, // 24 hours preflight cache
};
app.use(cors(corsOptions));

// Body parsing with size limits
app.use(express.json({ limit: '10kb' })); // Stricter limit for wallet/auth requests

// Cookie parser for admin session cookies
app.use(cookieParser());

// Security headers
app.use((_req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
  res.setHeader('Pragma', 'no-cache');
  next();
});

// Trust proxy (for rate limiting behind nginx)
app.set('trust proxy', 1);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'api-server' });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/history', historyRoutes);
app.use('/api/fairness', fairnessRoutes);
app.use('/api/admin', adminRoutes);

// Error handler (must be last)
app.use(errorHandler);

// Startup
async function start(): Promise<void> {
  try {
    await connectMongo();
    getRedisClient();

    app.listen(config.port, () => {
      console.log(`🌐 API Server running on port ${config.port}`);
      console.log(`   Environment: ${config.nodeEnv}`);
      console.log(`   Currency: BDT (৳)`);
      console.log(`   Deposit range: ৳${(config.wallet.minDeposit / 100).toFixed(0)} - ৳${(config.wallet.maxDeposit / 100).toFixed(0)}`);
      console.log(`   Withdrawal range: ৳${(config.wallet.minWithdrawal / 100).toFixed(0)} - ৳${(config.wallet.maxWithdrawal / 100).toFixed(0)}`);
    });
  } catch (error) {
    console.error('Failed to start API Server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
async function shutdown(): Promise<void> {
  console.log('\n🌐 Shutting down API Server...');
  await closeRedis();
  await closeMongo();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

start();
