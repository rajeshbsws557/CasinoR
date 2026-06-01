// ============================================
// JWT Authentication Middleware
// ============================================

import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config/env';
import { AuthTokenPayload } from '../types';

/**
 * Middleware that verifies JWT tokens from the Authorization header.
 * Sets req.user with the decoded token payload on success.
 * Logs IP + user-agent for audit trail.
 */
export function authMiddleware(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({
      success: false,
      error: 'No authentication token provided',
    });
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, config.jwt.secret) as AuthTokenPayload;
    req.user = decoded;

    // Audit log for authenticated requests (non-verbose in production)
    if (config.nodeEnv !== 'production') {
      console.log(`[Auth] ${decoded.username} | ${req.method} ${req.path} | IP: ${req.ip}`);
    }

    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      res.status(401).json({
        success: false,
        error: 'Token expired. Please login again.',
      });
    } else {
      res.status(401).json({
        success: false,
        error: 'Invalid authentication token',
      });
    }
  }
}

/**
 * Generates a JWT token for a user.
 */
export function generateToken(payload: AuthTokenPayload): string {
  return jwt.sign(payload, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn,
  });
}
