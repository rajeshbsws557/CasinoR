// ============================================
// Fairness Controller — Seed Management & Verification Proxy
// ============================================

import { Request, Response } from 'express';
import { ObjectId } from 'mongodb';
import crypto from 'crypto';
import { getDb } from '../services/MongoService';
import { config } from '../config/env';

/**
 * GET /api/fairness/current-seeds
 * Returns the user's active client seed.
 */
export async function getCurrentSeeds(req: Request, res: Response): Promise<void> {
  try {
    const db = getDb();
    const user = await db.collection('users').findOne(
      { _id: new ObjectId(req.user!.userId) },
      { projection: { client_seed: 1 } }
    );

    if (!user) {
      res.status(404).json({ success: false, error: 'User not found' });
      return;
    }

    res.json({
      success: true,
      data: {
        clientSeed: user.client_seed,
      },
    });
  } catch (error) {
    console.error('[FairnessController] getCurrentSeeds error:', error);
    res.status(500).json({ success: false, error: 'Failed to get seeds' });
  }
}

/**
 * POST /api/fairness/rotate-seed
 * Sets a new client seed for the user. Optionally accepts a custom seed.
 */
export async function rotateSeed(req: Request, res: Response): Promise<void> {
  try {
    const { clientSeed } = req.body;

    // Use provided seed or generate a random one
    const newSeed = clientSeed && typeof clientSeed === 'string' && clientSeed.length >= 4
      ? clientSeed.substring(0, 32) // Cap at 32 chars
      : crypto.randomBytes(8).toString('hex');

    const db = getDb();
    await db.collection('users').updateOne(
      { _id: new ObjectId(req.user!.userId) },
      {
        $set: {
          client_seed: newSeed,
          updated_at: new Date(),
        },
      }
    );

    res.json({
      success: true,
      data: {
        clientSeed: newSeed,
        message: 'Client seed updated. New seed will be used for future rounds.',
      },
    });
  } catch (error) {
    console.error('[FairnessController] rotateSeed error:', error);
    res.status(500).json({ success: false, error: 'Failed to rotate seed' });
  }
}

/**
 * GET /api/fairness/verify/:roundId
 * Proxies to the crypto service for round verification.
 */
export async function verifyRound(req: Request, res: Response): Promise<void> {
  try {
    const { roundId } = req.params;
    const cryptoUrl = `${config.cryptoService.url}/api/crypto/verify/${roundId}`;

    const response = await fetch(cryptoUrl);
    const data = await response.json();

    res.status(response.status).json(data);
  } catch (error) {
    console.error('[FairnessController] verifyRound error:', error);
    res.status(500).json({ success: false, error: 'Verification service unavailable' });
  }
}
