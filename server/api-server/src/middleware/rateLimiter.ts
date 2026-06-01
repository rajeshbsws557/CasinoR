// ============================================
// Rate Limiter Middleware (Redis-backed)
// ============================================

import { Request, Response, NextFunction } from 'express';
import { getRedisClient } from '../services/RedisService';

interface RateLimitOptions {
  windowMs: number;    // Time window in milliseconds
  maxRequests: number; // Max requests per window
  keyPrefix: string;   // Redis key prefix
}

/**
 * Creates a Redis-backed rate limiter middleware.
 * Uses sliding window counter pattern.
 */
export function rateLimiter(options: RateLimitOptions) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const redis = getRedisClient();
      const identifier = req.user?.userId || req.ip || 'anonymous';
      const key = `${options.keyPrefix}:${identifier}`;
      const windowSeconds = Math.ceil(options.windowMs / 1000);

      const current = await redis.incr(key);

      if (current === 1) {
        await redis.expire(key, windowSeconds);
      }

      if (current > options.maxRequests) {
        const ttl = await redis.ttl(key);
        res.status(429).json({
          success: false,
          error: 'Too many requests. Please try again later.',
          retryAfter: ttl,
        });
        return;
      }

      // Add rate limit headers
      res.setHeader('X-RateLimit-Limit', options.maxRequests);
      res.setHeader('X-RateLimit-Remaining', Math.max(0, options.maxRequests - current));

      next();
    } catch (error) {
      // If Redis is down, allow the request through
      console.error('[RateLimiter] Error:', error);
      next();
    }
  };
}

// Pre-configured limiters
export const authLimiter = rateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  maxRequests: 20,
  keyPrefix: 'ratelimit:auth',
});

export const apiLimiter = rateLimiter({
  windowMs: 60 * 1000, // 1 minute
  maxRequests: 100,
  keyPrefix: 'ratelimit:api',
});

// ─── Payment-specific rate limiters ───

export const depositLimiter = rateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  maxRequests: 5,            // Max 5 deposit submissions per 15 min
  keyPrefix: 'ratelimit:deposit',
});

export const withdrawalLimiter = rateLimiter({
  windowMs: 60 * 60 * 1000, // 1 hour
  maxRequests: 3,            // Max 3 withdrawal requests per hour
  keyPrefix: 'ratelimit:withdrawal',
});

export const balanceLimiter = rateLimiter({
  windowMs: 10 * 1000, // 10 seconds
  maxRequests: 10,      // Max 10 balance checks per 10 seconds
  keyPrefix: 'ratelimit:balance',
});
