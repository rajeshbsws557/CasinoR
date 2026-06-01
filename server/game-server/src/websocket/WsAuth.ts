// ============================================
// WebSocket Authentication — JWT on Upgrade
// ============================================

import { IncomingMessage } from 'http';
import jwt from 'jsonwebtoken';
import { config } from '../config/env';

export interface AuthPayload {
  userId: string;
  username: string;
  email: string;
}

/**
 * Extracts and verifies JWT token from WebSocket upgrade request.
 * Token can be in:
 *   1. Query parameter: ws://host/ws?token=xxx
 *   2. Authorization header: Bearer xxx
 */
export function authenticateWsConnection(req: IncomingMessage): AuthPayload | null {
  try {
    let token: string | null = null;

    // Try query parameter first
    const url = new URL(req.url || '', `http://${req.headers.host}`);
    token = url.searchParams.get('token');

    // Fall back to Authorization header
    if (!token) {
      const authHeader = req.headers.authorization;
      if (authHeader && authHeader.startsWith('Bearer ')) {
        token = authHeader.split(' ')[1];
      }
    }

    if (!token) {
      return null;
    }

    const decoded = jwt.verify(token, config.jwt.secret) as AuthPayload;
    return decoded;
  } catch (error) {
    console.error('[WsAuth] Authentication failed:', (error as Error).message);
    return null;
  }
}
