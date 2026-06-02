"use strict";
// ============================================
// Bet Manager — Bet Placement, Cashout, Payout
// ============================================
Object.defineProperty(exports, "__esModule", { value: true });
exports.BetManager = void 0;
const mongodb_1 = require("mongodb");
const MongoService_1 = require("../services/MongoService");
const RedisService_1 = require("../services/RedisService");
const env_1 = require("../config/env");
class BetManager {
    gameState;
    // Active bets for the current round (in-memory for speed)
    activeBets = new Map();
    cashedOutBets = new Map();
    constructor(gameState) {
        this.gameState = gameState;
    }
    /**
     * Places a bet for a user during the BETTING phase.
     * Atomically debits balance and records the bet.
     * Returns the user's new balance after the debit.
     */
    async placeBet(userId, username, amount, autoCashout, clientSeed) {
        // Validate game phase
        if (this.gameState.getPhase() !== 'BETTING') {
            throw new Error('Bets can only be placed during the betting phase');
        }
        // Validate bet amount (integer only — no floating point for money)
        if (!Number.isInteger(amount)) {
            throw new Error('Bet amount must be an integer (in paisa)');
        }
        if (amount < env_1.config.game.minBet) {
            throw new Error(`Minimum bet is ${env_1.config.game.minBet} (৳${(env_1.config.game.minBet / 100).toFixed(2)})`);
        }
        if (amount > env_1.config.game.maxBet) {
            throw new Error(`Maximum bet is ${env_1.config.game.maxBet} (৳${(env_1.config.game.maxBet / 100).toFixed(2)})`);
        }
        // Validate auto-cashout
        if (autoCashout !== null && autoCashout < 1.01) {
            throw new Error('Auto-cashout must be at least 1.01x');
        }
        // Check for max bets in this round
        let userBetCount = 0;
        for (const bet of this.activeBets.values()) {
            if (bet.userId === userId)
                userBetCount++;
        }
        if (userBetCount >= 2) {
            throw new Error('You can only place up to 2 bets per round');
        }
        // Rate limiting (500ms to allow quick double bets)
        const redis = (0, RedisService_1.getRedisClient)();
        const rateLimitKey = `ratelimit:bet:${userId}`;
        const isLimited = await redis.get(rateLimitKey);
        if (isLimited) {
            throw new Error('Please wait before placing another bet');
        }
        await redis.psetex(rateLimitKey, 500, '1');
        // Atomic MongoDB transaction: debit balance + record bet + ledger
        const db = (0, MongoService_1.getDb)();
        const mongoClient = (0, MongoService_1.getClient)();
        const session = mongoClient.startSession();
        let newBalance = 0;
        try {
            await session.withTransaction(async () => {
                const userOid = new mongodb_1.ObjectId(userId);
                // Debit balance (fail if insufficient)
                const userResult = await db.collection('users').findOneAndUpdate({ _id: userOid, balance: { $gte: amount } }, {
                    $inc: { balance: -amount, total_wagered: amount },
                    $set: { updated_at: new Date() },
                }, { returnDocument: 'after', session });
                if (!userResult) {
                    throw new Error('Insufficient balance');
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
                await db.collection('game_rounds').updateOne({ round_id: roundId }, { $inc: { total_bets: 1, total_wagered: amount } }, { session });
            });
            const betId = new mongodb_1.ObjectId().toHexString();
            // Store in memory for fast access during the round
            const bet = {
                betId,
                userId,
                username,
                amount,
                autoCashout,
                clientSeed,
                placedAt: new Date(),
            };
            this.activeBets.set(betId, bet);
            // Register client seed with crypto service
            try {
                await fetch(`${env_1.config.cryptoService.url}/api/crypto/register-client-seed`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        roundId: this.gameState.getRoundId(),
                        clientSeed,
                        userId,
                    }),
                });
            }
            catch (error) {
                // Non-critical — don't fail the bet if crypto service is slow
                console.warn('[BetManager] Failed to register client seed:', error.message);
            }
            console.log(`[BetManager] Bet placed: ${username} → ৳${(amount / 100).toFixed(2)} (auto: ${autoCashout || 'none'}) | Balance: ৳${(newBalance / 100).toFixed(2)}`);
            return { betId, newBalance };
        }
        finally {
            await session.endSession();
        }
    }
    /**
     * Cashes out a user's bet at the current multiplier.
     * Returns full result including the user's new balance.
     */
    async cashout(userId, betId) {
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
        const payout = Math.floor(bet.amount * multiplier);
        const profit = payout - bet.amount;
        // Atomic MongoDB transaction: credit balance + update bet + ledger
        const db = (0, MongoService_1.getDb)();
        const mongoClient = (0, MongoService_1.getClient)();
        const session = mongoClient.startSession();
        let newBalance = 0;
        try {
            await session.withTransaction(async () => {
                const userOid = new mongodb_1.ObjectId(userId);
                const roundId = this.gameState.getRoundId();
                const now = new Date();
                // Credit balance
                const userResult = await db.collection('users').findOneAndUpdate({ _id: userOid }, {
                    $inc: { balance: payout, total_profit: profit },
                    $set: { updated_at: now },
                }, { returnDocument: 'after', session });
                if (!userResult) {
                    throw new Error('User not found');
                }
                newBalance = userResult.balance;
                // Update bet record
                await db.collection('bets').updateOne({ round_id: roundId, user_id: userOid, status: 'pending' }, {
                    $set: {
                        cashout_multiplier: Math.floor(multiplier * 100) / 100,
                        profit,
                        status: 'won',
                        cashed_out_at: now,
                    },
                }, { session });
                // Insert ledger entry
                await db.collection('transactions').insertOne({
                    user_id: userOid,
                    type: 'bet_win',
                    amount: payout,
                    balance_after: newBalance,
                    reference_id: `win_${roundId}_${userId}`,
                    created_at: now,
                }, { session });
                // Update round stats
                await db.collection('game_rounds').updateOne({ round_id: roundId }, { $inc: { total_paid_out: payout } }, { session });
            });
            // Move from active to cashed out
            const cashedOut = {
                ...bet,
                cashoutMultiplier: Math.floor(multiplier * 100) / 100,
                profit,
                newBalance,
            };
            this.activeBets.delete(betId);
            this.cashedOutBets.set(betId, cashedOut);
            console.log(`[BetManager] Cashout: ${bet.username} @ ${multiplier.toFixed(2)}x → profit ৳${(profit / 100).toFixed(2)} | Balance: ৳${(newBalance / 100).toFixed(2)}`);
            return cashedOut;
        }
        finally {
            await session.endSession();
        }
    }
    /**
     * Processes auto-cashouts for all active bets whose target has been reached.
     * Called on every tick during the RUNNING phase.
     */
    async processAutoCashouts(currentMultiplier) {
        const autoCashouts = [];
        for (const [betId, bet] of this.activeBets) {
            if (bet.autoCashout !== null && currentMultiplier >= bet.autoCashout) {
                try {
                    const result = await this.cashout(bet.userId, betId);
                    autoCashouts.push(result);
                }
                catch (error) {
                    console.error(`[BetManager] Auto-cashout failed for ${bet.userId}:`, error.message);
                }
            }
        }
        return autoCashouts;
    }
    /**
     * Processes all remaining active bets as losses when the round crashes.
     * Returns the list of users who lost, with their current balances.
     */
    async processRoundEnd() {
        const db = (0, MongoService_1.getDb)();
        const roundId = this.gameState.getRoundId();
        const lostBets = [];
        for (const [betId, bet] of this.activeBets) {
            try {
                const userOid = new mongodb_1.ObjectId(bet.userId);
                // Mark bet as lost
                await db.collection('bets').updateOne({ round_id: roundId, user_id: userOid, status: 'pending' }, { $set: { status: 'lost', profit: -bet.amount } });
                // Fetch user's current balance for the balance update
                const user = await db.collection('users').findOne({ _id: userOid }, { projection: { balance: 1 } });
                if (user) {
                    lostBets.push({
                        userId: bet.userId,
                        username: bet.username,
                        amount: bet.amount,
                        currentBalance: user.balance,
                    });
                }
            }
            catch (error) {
                console.error(`[BetManager] Failed to process loss for ${bet.userId}:`, error.message);
            }
        }
        console.log(`[BetManager] Round ended: ${this.activeBets.size} bets lost, ${this.cashedOutBets.size} cashed out`);
        return lostBets;
    }
    /**
     * Resets bet tracking for a new round.
     */
    resetForNewRound() {
        this.activeBets.clear();
        this.cashedOutBets.clear();
    }
    /**
     * Returns all active bets as an array (for broadcasting to clients).
     */
    getActiveBets() {
        return Array.from(this.activeBets.values());
    }
    /**
     * Returns all cashed-out bets for display.
     */
    getCashedOutBets() {
        return Array.from(this.cashedOutBets.values());
    }
    /**
     * Returns all bets (active + cashed out) for player list display.
     */
    getAllBetsForDisplay() {
        const bets = [];
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
exports.BetManager = BetManager;
//# sourceMappingURL=BetManager.js.map