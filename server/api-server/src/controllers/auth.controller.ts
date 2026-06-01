// ============================================
// Auth Controller — Register, Login, Profile
// ============================================

import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { getDb } from '../services/MongoService';
import { generateToken } from '../middleware/auth';
import { config } from '../config/env';
import { RegisterRequest, LoginRequest, ApiResponse } from '../types';

/**
 * POST /api/auth/register
 * Creates a new user account with demo credits.
 */
export async function register(req: Request, res: Response): Promise<void> {
  try {
    const { username, email, password } = req.body as RegisterRequest;

    // Validation
    if (!username || !email || !password) {
      res.status(400).json({ success: false, error: 'Username, email, and password are required' });
      return;
    }

    if (username.length < 3 || username.length > 20) {
      res.status(400).json({ success: false, error: 'Username must be 3-20 characters' });
      return;
    }

    if (password.length < 6) {
      res.status(400).json({ success: false, error: 'Password must be at least 6 characters' });
      return;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      res.status(400).json({ success: false, error: 'Invalid email format' });
      return;
    }

    const db = getDb();

    // Check for existing user
    const existing = await db.collection('users').findOne({
      $or: [
        { email: email.toLowerCase() },
        { username: username.toLowerCase() },
      ],
    });

    if (existing) {
      const field = existing.email === email.toLowerCase() ? 'email' : 'username';
      res.status(409).json({ success: false, error: `A user with this ${field} already exists` });
      return;
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, config.bcrypt.saltRounds);

    // Generate initial client seed
    const clientSeed = crypto.randomBytes(8).toString('hex');

    // Create user
    const now = new Date();
    const result = await db.collection('users').insertOne({
      username: username.toLowerCase(),
      email: email.toLowerCase(),
      password_hash: passwordHash,
      balance: config.wallet.initialBalance,
      client_seed: clientSeed,
      total_wagered: 0,
      total_profit: 0,
      created_at: now,
      updated_at: now,
    });

    // Record initial deposit transaction
    await db.collection('transactions').insertOne({
      user_id: result.insertedId,
      type: 'deposit',
      amount: config.wallet.initialBalance,
      balance_after: config.wallet.initialBalance,
      reference_id: 'initial_deposit',
      created_at: now,
    });

    // Generate JWT
    const token = generateToken({
      userId: result.insertedId.toString(),
      username: username.toLowerCase(),
      email: email.toLowerCase(),
    });

    res.status(201).json({
      success: true,
      data: {
        token,
        user: {
          id: result.insertedId.toString(),
          username: username.toLowerCase(),
          email: email.toLowerCase(),
          balance: config.wallet.initialBalance,
        },
      },
    } satisfies ApiResponse);
  } catch (error) {
    console.error('[AuthController] register error:', error);
    res.status(500).json({ success: false, error: 'Registration failed' });
  }
}

/**
 * POST /api/auth/login
 * Authenticates a user and returns a JWT.
 */
export async function login(req: Request, res: Response): Promise<void> {
  try {
    const { email, password } = req.body as LoginRequest;

    if (!email || !password) {
      res.status(400).json({ success: false, error: 'Email and password are required' });
      return;
    }

    const db = getDb();
    const user = await db.collection('users').findOne({ email: email.toLowerCase() });

    if (!user) {
      res.status(401).json({ success: false, error: 'Invalid email or password' });
      return;
    }

    // Verify password
    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      res.status(401).json({ success: false, error: 'Invalid email or password' });
      return;
    }

    // Generate JWT
    const token = generateToken({
      userId: user._id.toString(),
      username: user.username,
      email: user.email,
    });

    // Update last login
    await db.collection('users').updateOne(
      { _id: user._id },
      { $set: { updated_at: new Date() } }
    );

    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user._id.toString(),
          username: user.username,
          email: user.email,
          balance: user.balance,
        },
      },
    } satisfies ApiResponse);
  } catch (error) {
    console.error('[AuthController] login error:', error);
    res.status(500).json({ success: false, error: 'Login failed' });
  }
}

/**
 * GET /api/auth/me
 * Returns the authenticated user's profile.
 */
export async function getProfile(req: Request, res: Response): Promise<void> {
  try {
    const db = getDb();
    const { ObjectId } = await import('mongodb');
    const user = await db.collection('users').findOne(
      { _id: new ObjectId(req.user!.userId) },
      { projection: { password_hash: 0 } }
    );

    if (!user) {
      res.status(404).json({ success: false, error: 'User not found' });
      return;
    }

    res.json({
      success: true,
      data: {
        id: user._id.toString(),
        username: user.username,
        email: user.email,
        balance: user.balance,
        clientSeed: user.client_seed,
        totalWagered: user.total_wagered,
        totalProfit: user.total_profit,
        createdAt: user.created_at,
      },
    });
  } catch (error) {
    console.error('[AuthController] getProfile error:', error);
    res.status(500).json({ success: false, error: 'Failed to get profile' });
  }
}
