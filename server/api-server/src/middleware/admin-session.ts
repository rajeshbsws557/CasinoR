// ============================================
// Admin Session Middleware (HttpOnly Cookie JWT)
// ============================================
//
// Replaces the X-Admin-Key header approach with
// HttpOnly cookie-based sessions to prevent XSS
// credential theft on the admin panel.

import { Request, Response, NextFunction } from 'express';
import * as crypto from 'crypto';
import * as jwt from 'jsonwebtoken';
import { config } from '../config/env';

const COOKIE_NAME = 'admin_session';

interface AdminTokenPayload {
  role: 'admin';
  iat: number;
  exp: number;
}

/**
 * Issues a signed JWT inside an HttpOnly cookie.
 * Called from POST /api/admin/login after key validation.
 */
export function issueAdminSession(res: Response): void {
  const maxAgeMs = config.admin.sessionMaxAgeMs;

  const token = jwt.sign(
    { role: 'admin' } as Omit<AdminTokenPayload, 'iat' | 'exp'>,
    config.admin.sessionSecret,
    { expiresIn: Math.floor(maxAgeMs / 1000) },
  );

  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,
    secure: config.nodeEnv === 'production',
    sameSite: 'strict',
    maxAge: maxAgeMs,
    path: '/api/admin',
  });
}

/**
 * Clears the admin session cookie.
 */
export function clearAdminSession(res: Response): void {
  res.clearCookie(COOKIE_NAME, {
    httpOnly: true,
    secure: config.nodeEnv === 'production',
    sameSite: 'strict',
    path: '/api/admin',
  });
}

/**
 * Validates the X-Admin-Key against the server's ADMIN_API_KEY.
 * Uses constant-time comparison to prevent timing attacks.
 */
function validateApiKey(key: string): boolean {
  if (!config.admin.apiKey || !key) return false;
  if (key.length !== config.admin.apiKey.length) return false;

  const a = Buffer.from(key);
  const b = Buffer.from(config.admin.apiKey);

  try {
    return crypto.timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

/**
 * Middleware that authenticates admin requests.
 *
 * Priority order:
 * 1. HttpOnly cookie `admin_session` (preferred — XSS-proof)
 * 2. X-Admin-Key header (backward compat / programmatic access)
 *
 * If neither is valid, returns 401/403.
 */
export function adminSessionMiddleware(req: Request, res: Response, next: NextFunction): void {
  if (!config.admin.apiKey) {
    res.status(503).json({
      success: false,
      error: 'Admin API is not configured. Set ADMIN_API_KEY environment variable.',
    });
    return;
  }

  // ── Strategy 1: HttpOnly cookie JWT ──
  const cookieToken = req.cookies?.[COOKIE_NAME];
  if (cookieToken) {
    try {
      const payload = jwt.verify(cookieToken, config.admin.sessionSecret) as AdminTokenPayload;
      if (payload.role === 'admin') {
        return next();
      }
    } catch {
      // Cookie is invalid/expired — fall through to header check
      clearAdminSession(res);
    }
  }

  // ── Strategy 2: X-Admin-Key header (backward compat) ──
  const headerKey = req.headers['x-admin-key'] as string | undefined;
  if (headerKey && validateApiKey(headerKey)) {
    return next();
  }

  // ── Neither worked ──
  if (headerKey) {
    console.warn(`[Admin] Invalid API key attempt from IP: ${req.ip}`);
    res.status(403).json({ success: false, error: 'Invalid admin credentials' });
  } else {
    res.status(401).json({ success: false, error: 'Admin authentication required' });
  }
}

/**
 * Handler for POST /api/admin/login
 * Validates the API key and issues an HttpOnly session cookie.
 */
export function adminLoginHandler(req: Request, res: Response): void {
  const { key } = req.body || {};

  if (!key || typeof key !== 'string') {
    res.status(400).json({ success: false, error: 'API key is required' });
    return;
  }

  if (!validateApiKey(key)) {
    console.warn(`[Admin] Failed login attempt from IP: ${req.ip}`);
    res.status(403).json({ success: false, error: 'Invalid admin API key' });
    return;
  }

  issueAdminSession(res);
  console.log(`[Admin] Successful login from IP: ${req.ip}`);
  res.json({ success: true, data: { message: 'Authenticated' } });
}

/**
 * Handler for POST /api/admin/logout
 * Clears the admin session cookie.
 */
export function adminLogoutHandler(_req: Request, res: Response): void {
  clearAdminSession(res);
  res.json({ success: true, data: { message: 'Logged out' } });
}
