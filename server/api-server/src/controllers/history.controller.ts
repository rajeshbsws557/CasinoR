// ============================================
// History Controller — Rounds & Bets
// ============================================

import { Request, Response } from 'express';
import { ObjectId } from 'mongodb';
import { getDb } from '../services/MongoService';

/**
 * GET /api/history/rounds
 * Returns paginated game round history (completed rounds only).
 */
export async function getRounds(req: Request, res: Response): Promise<void> {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 20));
    const skip = (page - 1) * limit;

    const db = getDb();

    const [rounds, total] = await Promise.all([
      db.collection('game_rounds')
        .find({ status: 'completed' })
        .sort({ crashed_at: -1 })
        .skip(skip)
        .limit(limit)
        .project({
          round_id: 1,
          nonce: 1,
          crash_point: 1,
          server_seed_hash: 1,
          total_bets: 1,
          total_wagered: 1,
          total_paid_out: 1,
          crashed_at: 1,
          // Do NOT expose server_seed in the list view
        })
        .toArray(),
      db.collection('game_rounds').countDocuments({ status: 'completed' }),
    ]);

    res.json({
      success: true,
      data: {
        rounds: rounds.map((r) => ({
          roundId: r.round_id,
          nonce: r.nonce,
          crashPoint: r.crash_point,
          serverSeedHash: r.server_seed_hash,
          totalBets: r.total_bets,
          totalWagered: r.total_wagered,
          totalPaidOut: r.total_paid_out,
          crashedAt: r.crashed_at,
        })),
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
        },
      },
    });
  } catch (error) {
    console.error('[HistoryController] getRounds error:', error);
    res.status(500).json({ success: false, error: 'Failed to get round history' });
  }
}

/**
 * GET /api/history/rounds/:roundId
 * Returns detailed info for a single completed round (including server seed for verification).
 */
export async function getRoundById(req: Request, res: Response): Promise<void> {
  try {
    const { roundId } = req.params;
    const db = getDb();

    const round = await db.collection('game_rounds').findOne({ round_id: roundId });

    if (!round) {
      res.status(404).json({ success: false, error: 'Round not found' });
      return;
    }

    // Only expose server_seed for completed rounds
    const serverSeed = round.status === 'completed' ? round.server_seed : '*** HIDDEN ***';

    res.json({
      success: true,
      data: {
        roundId: round.round_id,
        nonce: round.nonce,
        crashPoint: round.crash_point,
        serverSeed,
        serverSeedHash: round.server_seed_hash,
        clientSeeds: round.client_seeds,
        status: round.status,
        totalBets: round.total_bets,
        totalWagered: round.total_wagered,
        totalPaidOut: round.total_paid_out,
        startedAt: round.started_at,
        crashedAt: round.crashed_at,
      },
    });
  } catch (error) {
    console.error('[HistoryController] getRoundById error:', error);
    res.status(500).json({ success: false, error: 'Failed to get round details' });
  }
}

/**
 * GET /api/history/bets
 * Returns paginated bet history for the authenticated user.
 */
export async function getUserBets(req: Request, res: Response): Promise<void> {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 20));
    const skip = (page - 1) * limit;

    const db = getDb();
    const userId = new ObjectId(req.user!.userId);

    const [bets, total] = await Promise.all([
      db.collection('bets')
        .find({ user_id: userId })
        .sort({ placed_at: -1 })
        .skip(skip)
        .limit(limit)
        .toArray(),
      db.collection('bets').countDocuments({ user_id: userId }),
    ]);

    res.json({
      success: true,
      data: {
        bets: bets.map((b) => ({
          id: b._id.toString(),
          roundId: b.round_id,
          amount: b.amount,
          formattedAmount: (b.amount / 100).toFixed(2),
          autoCashout: b.auto_cashout,
          cashoutMultiplier: b.cashout_multiplier,
          profit: b.profit,
          formattedProfit: b.profit !== null ? (b.profit / 100).toFixed(2) : null,
          status: b.status,
          placedAt: b.placed_at,
          cashedOutAt: b.cashed_out_at,
        })),
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
        },
      },
    });
  } catch (error) {
    console.error('[HistoryController] getUserBets error:', error);
    res.status(500).json({ success: false, error: 'Failed to get bet history' });
  }
}
