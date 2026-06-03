// ============================================
// Bet Manager — Bet Placement, Cashout, Payout
// ============================================

import { ObjectId } from 'mongodb';
import { getDb, getClient } from '../services/MongoService';
import { getRedisClient } from '../services/RedisService';
import { GameState } from './GameState';
import { config } from '../config/env';
import { ActiveBet, CashedOutBet } from '../types';

export interface CashoutResult extends CashedOutBet {
  newBalance: number;
}

export interface LostBetResult {
  userId: string;
  username: string;
  amount: number;
  currentBalance: number;
}

export class BetManager {
  // Active bets for the current round (in-memory for speed)
  private activeBets: Map<string, ActiveBet> = new Map();
  private cashedOutBets: Map<string, CashedOutBet> = new Map();
  
  // Anti-Abuse: Track consecutive same auto-cashout values
  private userCashoutHistory: Map<string, { multiplier: number, count: number }> = new Map();

  constructor(private gameState: GameState) {}

  /**
   * Places a bet for a user during the BETTING phase.
   * Atomically debits balance and records the bet.
   * Returns the user's new balance after the debit.
   */
  async placeBet(
    userId: string,
    username: string,
    amount: number,
    autoCashout: number | null,
    clientSeed: string,
    panelId: number,
  ): Promise<{ betId: string, newBalance: number }> {
    // Validate game phase
    if (this.gameState.getPhase() !== 'BETTING') {
      throw new Error('Bets can only be placed during the betting phase');
    }

    // Validate bet amount (integer only — no floating point for money)
    if (!Number.isInteger(amount)) {
      throw new Error('Bet amount must be an integer (in paisa)');
    }
    if (amount < config.game.minBet) {
      throw new Error(`Minimum bet is ${config.game.minBet} (৳${(config.game.minBet / 100).toFixed(2)})`);
    }
    if (amount > config.game.maxBet) {
      throw new Error(`Maximum bet is ${config.game.maxBet} (৳${(config.game.maxBet / 100).toFixed(2)})`);
    }

    // Validate auto-cashout
    if (autoCashout !== null && autoCashout < 1.01) {
      throw new Error('Auto-cashout must be at least 1.01x');
    }

    // Bot detection heuristic: track repetitive exact auto-cashouts
    if (autoCashout !== null) {
      const history = this.userCashoutHistory.get(userId);
      if (history && history.multiplier === autoCashout) {
        history.count++;
        if (history.count > 10) {
          console.warn(`[Anti-Abuse] Flagging user ${username} (${userId}) for repetitive auto-cashout at ${autoCashout}x (${history.count} times)`);
          // Here we could flag the user in the DB for admin review, or add a random delay
          // For now, we log the warning and add a tiny random offset to break exact scripts
          autoCashout += (Math.random() * 0.05);
        }
      } else {
        this.userCashoutHistory.set(userId, { multiplier: autoCashout, count: 1 });
      }
    }

    // Check for max bets in this round
    let userBetCount = 0;
    for (const bet of this.activeBets.values()) {
      if (bet.userId === userId) userBetCount++;
    }
    if (userBetCount >= 2) {
      throw new Error('You can only place up to 2 bets per round');
    }

    // Rate limiting (500ms per panel to allow quick dual bets)
    const redis = getRedisClient();
    const rateLimitKey = `ratelimit:bet:${userId}:${panelId}`;
    const isLimited = await redis.get(rateLimitKey);
    if (isLimited) {
      throw new Error('Please wait before placing another bet on this panel');
    }
    await redis.psetex(rateLimitKey, 500, '1');

    // Atomic MongoDB transaction: debit balance + record bet + ledger
    const db = getDb();
    const mongoClient = getClient();
    const session = mongoClient.startSession();
    let newBalance = 0;

    try {
      await session.withTransaction(async () => {
        const userOid = new ObjectId(userId);

        // Debit balance (fail if insufficient) and update required wager
        const user = await db.collection('users').findOne({ _id: userOid }, { session });
        if (!user || user.balance < amount) {
          throw new Error('Insufficient balance');
        }

        let newRequiredWager = (user.required_wager || 0) - amount;
        if (newRequiredWager < 0) newRequiredWager = 0;

        const userResult = await db.collection('users').findOneAndUpdate(
          { _id: userOid },
          {
            $inc: { balance: -amount, total_wagered: amount },
            $set: { updated_at: new Date(), required_wager: newRequiredWager },
          },
          { returnDocument: 'after', session }
        );

        if (!userResult) {
          throw new Error('Failed to update user balance');
        }

        newBalance = userResult.balance;
        const roundId = this.gameState.getRoundId();
        const now = new Date();

        // Insert bet record
        await db.collection('bets').insertOne({
          round_id: roundId,
          user_id: userOid,
          amount,
          auto_cashout: autoCashout,
          cashout_multiplier: null,
          profit: null,
          status: 'pending',
          placed_at: now,
          cashed_out_at: null,
        }, { session });

        // Insert ledger entry
        await db.collection('transactions').insertOne({
          user_id: userOid,
          type: 'bet_place',
          amount: -amount,
          balance_after: newBalance,
          reference_id: `bet_${roundId}_${userId}`,
          created_at: now,
        }, { session });

        // Update round stats
        await db.collection('game_rounds').updateOne(
          { round_id: roundId },
          { $inc: { total_bets: 1, total_wagered: amount } },
          { session }
        );
      });

      const betId = new ObjectId().toHexString();

      // Store in memory for fast access during the round
      const bet: ActiveBet = {
        betId,
        userId,
        username,
        amount,
        autoCashout,
        clientSeed,
        panelId,
        placedAt: new Date(),
      };

      this.activeBets.set(betId, bet);

      // Register client seed with crypto service
      try {
        await fetch(`${config.cryptoService.url}/api/crypto/register-client-seed`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            roundId: this.gameState.getRoundId(),
            clientSeed,
            userId,
          }),
        });
      } catch (error) {
        // Non-critical — don't fail the bet if crypto service is slow
        console.warn('[BetManager] Failed to register client seed:', (error as Error).message);
      }

      console.log(`[BetManager] Bet placed: ${username} → ৳${(amount / 100).toFixed(2)} (auto: ${autoCashout || 'none'}) | Balance: ৳${(newBalance / 100).toFixed(2)}`);

      return { betId, newBalance };
    } finally {
      await session.endSession();
    }
  }

  /**
   * Cashes out a user's bet at the current multiplier.
   * Returns full result including the user's new balance.
   */
  async cashout(userId: string, betId: string): Promise<CashoutResult> {
    if (this.gameState.getPhase() !== 'RUNNING') {
      throw new Error('Cashout only available during the running phase');
    }

    const bet = this.activeBets.get(betId);
    if (!bet) {
      throw new Error('No active bet found');
    }
    if (bet.userId !== userId) {
      throw new Error('You do not own this bet');
    }

    const multiplier = this.gameState.getCurrentMultiplier();
    let payout = Math.floor(bet.amount * multiplier);

    // Apply Max Payout Limit
    if (payout > config.game.maxPayout) {
      payout = config.game.maxPayout;
      console.log(`[BetManager] Payout capped at ৳${(config.game.maxPayout / 100).toFixed(2)} for ${bet.username}`);
    }

    let profit = payout - bet.amount;
    let rake = 0;

    // Apply Rake on Profit
    if (profit > 0) {
      rake = Math.floor(profit * config.game.rakePercentage);
    }

    const finalPayout = payout - rake;
    const finalProfit = finalPayout - bet.amount;

    // Atomic MongoDB transaction: credit balance + update bet + ledger
    const db = getDb();
    const mongoClient = getClient();
    const session = mongoClient.startSession();
    let newBalance = 0;

    try {
      await session.withTransaction(async () => {
        const userOid = new ObjectId(userId);
        const roundId = this.gameState.getRoundId();
        const now = new Date();

        // Credit balance
        const userResult = await db.collection('users').findOneAndUpdate(
          { _id: userOid },
          {
            $inc: { balance: finalPayout, total_profit: finalProfit },
            $set: { updated_at: now },
          },
          { returnDocument: 'after', session }
        );

        if (!userResult) {
          throw new Error('User not found');
        }

        newBalance = userResult.balance;

        // Update bet record
        await db.collection('bets').updateOne(
          { round_id: roundId, user_id: userOid, status: 'pending' },
          {
            $set: {
              cashout_multiplier: Math.floor(multiplier * 100) / 100,
              profit: finalProfit,
              status: 'won',
              cashed_out_at: now,
            },
          },
          { session }
        );

        // Insert ledger entry
        await db.collection('transactions').insertOne({
          user_id: userOid,
          type: 'bet_win',
          amount: finalPayout,
          balance_after: newBalance,
          reference_id: `win_${roundId}_${userId}`,
          created_at: now,
        }, { session });

        // Update round stats
        await db.collection('game_rounds').updateOne(
          { round_id: roundId },
          { $inc: { total_paid_out: finalPayout } },
          { session }
        );
      });

      // Move from active to cashed out
      const cashedOut: CashoutResult = {
        ...bet,
        cashoutMultiplier: Math.floor(multiplier * 100) / 100,
        profit: finalProfit,
        newBalance,
      };

      this.activeBets.delete(betId);
      this.cashedOutBets.set(betId, cashedOut);

      console.log(`[BetManager] Cashout: ${bet.username} @ ${multiplier.toFixed(2)}x → profit ৳${(finalProfit / 100).toFixed(2)} (Rake: ৳${(rake/100).toFixed(2)}) | Balance: ৳${(newBalance / 100).toFixed(2)}`);

      return cashedOut;
    } finally {
      await session.endSession();
    }
  }

  /**
   * Processes auto-cashouts for all active bets whose target has been reached.
   * Called on every tick during the RUNNING phase.
   */
  async processAutoCashouts(currentMultiplier: number): Promise<CashoutResult[]> {
    const autoCashouts: CashoutResult[] = [];

    for (const [betId, bet] of this.activeBets) {
      if (bet.autoCashout !== null && currentMultiplier >= bet.autoCashout) {
        try {
          const result = await this.cashout(bet.userId, betId);
          autoCashouts.push(result);
        } catch (error) {
          console.error(`[BetManager] Auto-cashout failed for ${bet.userId}:`, (error as Error).message);
        }
      }
    }

    return autoCashouts;
  }

  /**
   * Processes all remaining active bets as losses when the round crashes.
   * Returns the list of users who lost, with their current balances.
   */
  async processRoundEnd(): Promise<LostBetResult[]> {
    const db = getDb();
    const roundId = this.gameState.getRoundId();
    const lostBets: LostBetResult[] = [];

    for (const [betId, bet] of this.activeBets) {
      try {
        const userOid = new ObjectId(bet.userId);

        // Mark bet as lost
        await db.collection('bets').updateOne(
          { round_id: roundId, user_id: userOid, status: 'pending' },
          { $set: { status: 'lost', profit: -bet.amount } }
        );

        // Fetch user's current balance for the balance update
        const user = await db.collection('users').findOne(
          { _id: userOid },
          { projection: { balance: 1 } }
        );

        if (user) {
          lostBets.push({
            userId: bet.userId,
            username: bet.username,
            amount: bet.amount,
            currentBalance: user.balance,
          });
        }
      } catch (error) {
        console.error(`[BetManager] Failed to process loss for ${bet.userId}:`, (error as Error).message);
      }
    }

    console.log(`[BetManager] Round ended: ${this.activeBets.size} bets lost, ${this.cashedOutBets.size} cashed out`);
    return lostBets;
  }

  /**
   * Resets bet tracking for a new round.
   */
  resetForNewRound(): void {
    this.activeBets.clear();
    this.cashedOutBets.clear();
  }

  /**
   * Returns all active bets as an array (for broadcasting to clients).
   */
  getActiveBets(): ActiveBet[] {
    return Array.from(this.activeBets.values());
  }

  /**
   * Returns all cashed-out bets for display.
   */
  getCashedOutBets(): CashedOutBet[] {
    return Array.from(this.cashedOutBets.values());
  }

  /**
   * Returns all bets (active + cashed out) for player list display.
   */
  getAllBetsForDisplay(): Array<{
    username: string;
    amount: number;
    status: 'active' | 'cashed_out';
    cashoutMultiplier?: number;
    profit?: number;
  }> {
    const bets: Array<{
      username: string;
      amount: number;
      status: 'active' | 'cashed_out';
      cashoutMultiplier?: number;
      profit?: number;
    }> = [];

    // Cashed out first
    for (const bet of this.cashedOutBets.values()) {
      bets.push({
        username: bet.username,
        amount: bet.amount,
        status: 'cashed_out',
        cashoutMultiplier: bet.cashoutMultiplier,
        profit: bet.profit,
      });
    }

    // Active bets
    for (const bet of this.activeBets.values()) {
      bets.push({
        username: bet.username,
        amount: bet.amount,
        status: 'active',
      });
    }

    return bets;
  }
}
