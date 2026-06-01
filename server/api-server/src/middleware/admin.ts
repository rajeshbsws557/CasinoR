// ============================================
// Admin API Key Middleware
// ============================================

import { Request, Response, NextFunction } from 'express';
import { config } from '../config/env';

/**
 * Middleware that verifies the X-Admin-Key header against the
 * ADMIN_API_KEY environment variable. Used for deposit approval
 * and withdrawal processing endpoints.
 */
export function adminMiddleware(req: Request, res: Response, next: NextFunction): void {
  const adminKey = req.headers['x-admin-key'] as string | undefined;

  if (!config.admin.apiKey) {
    res.status(503).json({
      success: false,
      error: 'Admin API is not configured. Set ADMIN_API_KEY environment variable.',
    });
    return;
  }

  if (!adminKey) {
    res.status(401).json({
      success: false,
      error: 'Admin API key required. Provide X-Admin-Key header.',
    });
    return;
  }

  // Constant-time comparison to prevent timing attacks
  if (adminKey.length !== config.admin.apiKey.length) {
    res.status(403).json({ success: false, error: 'Invalid admin API key' });
    return;
  }

  const a = Buffer.from(adminKey);
  const b = Buffer.from(config.admin.apiKey);

  // Use timingSafeEqual for constant-time comparison
  let isValid = true;
  try {
    const crypto = require('crypto');
    isValid = crypto.timingSafeEqual(a, b);
  } catch {
    // Buffers must be same length for timingSafeEqual
    isValid = adminKey === config.admin.apiKey;
  }

  if (!isValid) {
    console.warn(`[Admin] Invalid API key attempt from IP: ${req.ip}`);
    res.status(403).json({ success: false, error: 'Invalid admin API key' });
    return;
  }

  next();
}
