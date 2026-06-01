// ============================================
// Seed Generator — Cryptographically Secure
// ============================================

import crypto from 'crypto';
import { config } from '../config/env';

/**
 * Generates a cryptographically secure server seed.
 * Returns a 16-character hexadecimal string (8 random bytes).
 */
export function generateServerSeed(): string {
  const bytes = config.game.serverSeedLength / 2; // 16 hex chars = 8 bytes
  return crypto.randomBytes(bytes).toString('hex');
}

/**
 * Computes the SHA-256 hash of a server seed.
 * This hash is published to clients BEFORE the round begins,
 * committing the server to that specific seed without revealing it.
 */
export function hashServerSeed(serverSeed: string): string {
  return crypto
    .createHash('sha256')
    .update(serverSeed)
    .digest('hex');
}

/**
 * Verifies that a given server seed matches its hash.
 * Used post-round to prove the seed was not changed.
 */
export function verifyServerSeedHash(
  serverSeed: string,
  expectedHash: string
): boolean {
  const computedHash = hashServerSeed(serverSeed);
  // Use timing-safe comparison to prevent timing attacks
  try {
    return crypto.timingSafeEqual(
      Buffer.from(computedHash, 'hex'),
      Buffer.from(expectedHash, 'hex')
    );
  } catch {
    return false;
  }
}
