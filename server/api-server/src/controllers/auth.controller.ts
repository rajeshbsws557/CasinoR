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
      required_wager: config.wallet.initialBalance * 2,
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
        paymentMethods: user.payment_methods || [],
      },
    });
  } catch (error) {
    console.error('[AuthController] getProfile error:', error);
    res.status(500).json({ success: false, error: 'Failed to get profile' });
  }
}

/**
 * PUT /api/auth/profile
 * Updates the authenticated user's profile (username).
 */
export async function updateProfile(req: Request, res: Response): Promise<void> {
  try {
    const { username } = req.body;

    if (!username || typeof username !== 'string') {
      res.status(400).json({ success: false, error: 'Username is required' });
      return;
    }

    if (username.length < 3 || username.length > 20) {
      res.status(400).json({ success: false, error: 'Username must be 3-20 characters' });
      return;
    }

    const db = getDb();
    const { ObjectId } = await import('mongodb');
    const userOid = new ObjectId(req.user!.userId);

    // Check if username is taken by another user
    const existing = await db.collection('users').findOne({
      username: username.toLowerCase(),
      _id: { $ne: userOid },
    });

    if (existing) {
      res.status(409).json({ success: false, error: 'Username is already taken' });
      return;
    }

    const result = await db.collection('users').findOneAndUpdate(
      { _id: userOid },
      {
        $set: {
          username: username.toLowerCase(),
          updated_at: new Date(),
        },
      },
      { returnDocument: 'after', projection: { password_hash: 0 } },
    );

    if (!result) {
      res.status(404).json({ success: false, error: 'User not found' });
      return;
    }

    res.json({
      success: true,
      data: {
        id: result._id.toString(),
        username: result.username,
        email: result.email,
        balance: result.balance,
        totalWagered: result.total_wagered,
        totalProfit: result.total_profit,
        createdAt: result.created_at,
        paymentMethods: result.payment_methods || [],
      },
    });
  } catch (error) {
    console.error('[AuthController] updateProfile error:', error);
    res.status(500).json({ success: false, error: 'Failed to update profile' });
  }
}

/**
 * PUT /api/auth/payment-methods
 * Updates the authenticated user's payment methods (bKash/Nagad).
 */
export async function updatePaymentMethods(req: Request, res: Response): Promise<void> {
  try {
    const { payment_methods } = req.body;

    if (!Array.isArray(payment_methods)) {
      res.status(400).json({ success: false, error: 'payment_methods must be an array' });
      return;
    }

    // Validate each payment method
    const validTypes = ['bkash', 'nagad'];
    const validated: Array<{ type: string; phone_number: string }> = [];

    for (const method of payment_methods) {
      if (!method.type || !validTypes.includes(method.type)) {
        res.status(400).json({ success: false, error: `Invalid payment type: ${method.type}. Must be bkash or nagad` });
        return;
      }
      if (!method.phone_number || typeof method.phone_number !== 'string') {
        res.status(400).json({ success: false, error: 'Phone number is required for each payment method' });
        return;
      }
      // Strip non-digits and validate length
      const digits = method.phone_number.replace(/\D/g, '');
      if (digits.length < 11 || digits.length > 14) {
        res.status(400).json({ success: false, error: 'Phone number must be 11-14 digits' });
        return;
      }
      validated.push({ type: method.type, phone_number: digits });
    }

    const db = getDb();
    const { ObjectId } = await import('mongodb');
    const userOid = new ObjectId(req.user!.userId);

    const result = await db.collection('users').findOneAndUpdate(
      { _id: userOid },
      {
        $set: {
          payment_methods: validated,
          updated_at: new Date(),
        },
      },
      { returnDocument: 'after', projection: { password_hash: 0 } },
    );

    if (!result) {
      res.status(404).json({ success: false, error: 'User not found' });
      return;
    }

    res.json({
      success: true,
      data: {
        paymentMethods: result.payment_methods || [],
      },
    });
  } catch (error) {
    console.error('[AuthController] updatePaymentMethods error:', error);
    res.status(500).json({ success: false, error: 'Failed to update payment methods' });
  }
}
