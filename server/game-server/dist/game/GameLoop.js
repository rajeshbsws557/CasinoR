"use strict";
// ============================================
// Game Loop — Tick-Based Game Engine
// ============================================
Object.defineProperty(exports, "__esModule", { value: true });
exports.GameLoop = void 0;
const uuid_1 = require("uuid");
const env_1 = require("../config/env");
const RedisService_1 = require("../services/RedisService");
const MongoService_1 = require("../services/MongoService");
class GameLoop {
    gameState;
    betManager;
    broadcast;
    sendToUser;
    tickTimer = null;
    nonce = 0;
    isRunning = false;
    constructor(gameState, betManager, broadcastFn, sendToUserFn) {
        this.gameState = gameState;
        this.betManager = betManager;
        this.broadcast = broadcastFn;
        this.sendToUser = sendToUserFn;
    }
    /**
     * Starts the game loop. Runs indefinitely.
     */
    async start() {
        if (this.isRunning)
            return;
        this.isRunning = true;
        // Load the latest nonce from the database
        await this.loadNonce();
        console.log(`[GameLoop] Starting game loop at nonce ${this.nonce}`);
        // Start the first round
        this.runRound();
    }
    /**
     * Stops the game loop.
     */
    stop() {
        this.isRunning = false;
        if (this.tickTimer) {
            clearInterval(this.tickTimer);
            this.tickTimer = null;
        }
    }
    /**
     * Returns the current game state for newly connected users.
     */
    getStateForNewClient() {
        const state = this.gameState.getState();
        return {
            type: 'GAME_STATE',
            data: {
                phase: state.phase,
                roundId: state.roundId,
                serverSeedHash: state.serverSeedHash,
                multiplier: state.currentMultiplier,
                elapsedMs: state.startTime > 0 ? Date.now() - state.startTime : 0,
                bettingEndsAt: state.bettingEndsAt,
                bets: this.betManager.getAllBetsForDisplay(),
            },
        };
    }
    // ─── Private Methods ───
    /**
     * Runs a complete round: BETTING → RUNNING → CRASH → COOLDOWN → repeat
     */
    async runRound() {
        if (!this.isRunning)
            return;
        try {
            // ────── PHASE 1: BETTING ──────
            this.nonce++;
            const roundId = `rnd_${(0, uuid_1.v4)().substring(0, 12)}`;
            console.log(`\n[GameLoop] ═══════════════════════════════════════`);
            console.log(`[GameLoop] Round ${this.nonce} (${roundId}) — BETTING PHASE`);
            // Request crypto materials from the crypto service
            const cryptoData = await this.requestCryptoRound(roundId, this.nonce);
            // Reset bet tracking
            this.betManager.resetForNewRound();
            // Transition to BETTING phase
            await this.gameState.startBettingPhase(roundId, this.nonce, cryptoData.serverSeedHash, env_1.config.game.bettingPhaseMs);
            // Broadcast ROUND_START to all clients
            this.broadcast({
                type: 'ROUND_START',
                data: {
                    round_id: roundId,
                    server_seed_hash: cryptoData.serverSeedHash,
                    countdown_ms: env_1.config.game.bettingPhaseMs,
                    nonce: this.nonce,
                },
            });
            // Wait for betting phase to complete
            await this.sleep(env_1.config.game.bettingPhaseMs);
            if (!this.isRunning)
                return;
            // ────── PHASE 2: RUNNING ──────
            // Fetch the final crash point (may have been updated by client seeds)
            const crashPoint = await this.fetchCrashPoint(roundId);
            console.log(`[GameLoop] Round ${this.nonce} — RUNNING (crash @ ${crashPoint.toFixed(2)}x)`);
            await this.gameState.startRunningPhase(crashPoint);
            // Start the tick engine
            await this.runTickEngine(crashPoint);
            if (!this.isRunning)
                return;
            // ────── PHASE 3: CRASH ──────
            console.log(`[GameLoop] Round ${this.nonce} — CRASHED @ ${crashPoint.toFixed(2)}x`);
            await this.gameState.crash();
            // Process all remaining bets as losses and get balance info
            const lostBets = await this.betManager.processRoundEnd();
            // Finalize the round in MongoDB
            await this.finalizeRound(roundId, crashPoint);
            // Add to history
            await this.addToHistory(crashPoint);
            // Broadcast CRASH event
            this.broadcast({
                type: 'CRASH',
                data: {
                    crash_point: crashPoint,
                    round_id: roundId,
                    server_seed_hash: cryptoData.serverSeedHash,
                },
            });
            // ── Send BALANCE_UPDATE to each user who lost ──
            for (const lostBet of lostBets) {
                this.sendToUser(lostBet.userId, {
                    type: 'BALANCE_UPDATE',
                    data: {
                        balance: lostBet.currentBalance,
                        formatted: `৳${(lostBet.currentBalance / 100).toFixed(2)}`,
                        reason: 'bet_loss',
                        round_id: roundId,
                    },
                });
            }
            // ────── PHASE 4: COOLDOWN ──────
            await this.gameState.startCooldown();
            console.log(`[GameLoop] Round ${this.nonce} — COOLDOWN (${env_1.config.game.cooldownPhaseMs}ms)`);
            await this.sleep(env_1.config.game.cooldownPhaseMs);
            // ────── REPEAT ──────
            this.runRound();
        }
        catch (error) {
            console.error('[GameLoop] Critical error in round:', error);
            // Wait a bit and try to restart
            await this.sleep(5000);
            if (this.isRunning) {
                this.runRound();
            }
        }
    }
    /**
     * The core tick engine: calculates multiplier every 50ms and broadcasts.
     */
    runTickEngine(crashPoint) {
        return new Promise((resolve) => {
            const startTime = Date.now();
            this.tickTimer = setInterval(async () => {
                const elapsed = Date.now() - startTime;
                // Calculate multiplier: m(t) = e^(k * t)
                const multiplier = Math.pow(Math.E, env_1.config.game.growthRate * elapsed);
                const roundedMultiplier = Math.floor(multiplier * 100) / 100;
                // Check if we've hit the crash point
                if (roundedMultiplier >= crashPoint) {
                    if (this.tickTimer) {
                        clearInterval(this.tickTimer);
                        this.tickTimer = null;
                    }
                    resolve();
                    return;
                }
                // Update state
                this.gameState.updateMultiplier(roundedMultiplier);
                // Process auto-cashouts
                const autoCashouts = await this.betManager.processAutoCashouts(roundedMultiplier);
                // Broadcast tick to all clients
                this.broadcast({
                    type: 'TICK',
                    data: {
                        multiplier: roundedMultiplier,
                        elapsed_ms: elapsed,
                    },
                });
                // Broadcast auto-cashout events + send balance updates
                for (const cashout of autoCashouts) {
                    this.broadcast({
                        type: 'PLAYER_CASHOUT',
                        data: {
                            username: cashout.username,
                            multiplier: cashout.cashoutMultiplier,
                            profit: cashout.profit,
                        },
                    });
                    // Send personal cashout confirmation WITH balance
                    this.sendToUser(cashout.userId, {
                        type: 'CASHOUT_CONFIRMED',
                        data: {
                            betId: cashout.betId,
                            multiplier: cashout.cashoutMultiplier,
                            profit: cashout.profit,
                            payout: cashout.amount + cashout.profit,
                        },
                    });
                    // Send BALANCE_UPDATE separately for clean separation
                    this.sendToUser(cashout.userId, {
                        type: 'BALANCE_UPDATE',
                        data: {
                            balance: cashout.newBalance,
                            formatted: `৳${(cashout.newBalance / 100).toFixed(2)}`,
                            reason: 'cashout',
                        },
                    });
                }
                // Broadcast updated bets list for leaderboard after cashouts
                if (autoCashouts.length > 0) {
                    this.broadcast({
                        type: 'PLAYERS_UPDATE',
                        data: {
                            bets: this.betManager.getAllBetsForDisplay(),
                        },
                    });
                }
            }, env_1.config.game.tickIntervalMs);
        });
    }
    /**
     * Requests a new round from the crypto service.
     */
    async requestCryptoRound(roundId, nonce) {
        try {
            const response = await fetch(`${env_1.config.cryptoService.url}/api/crypto/generate-round`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ roundId, nonce }),
            });
            const data = (await response.json());
            if (!data.success || !data.data) {
                throw new Error(data.error || 'Crypto service returned invalid data');
            }
            return { serverSeedHash: data.data.serverSeedHash };
        }
        catch (error) {
            console.error('[GameLoop] Crypto service error:', error);
            throw new Error('Failed to initialize round cryptography');
        }
    }
    /**
     * Fetches the final crash point from the crypto service.
     */
    async fetchCrashPoint(roundId) {
        try {
            const response = await fetch(`${env_1.config.cryptoService.url}/api/crypto/crash-point/${roundId}`);
            const data = (await response.json());
            if (!data.success || !data.data) {
                throw new Error('Failed to fetch crash point');
            }
            return data.data.crashPoint;
        }
        catch (error) {
            console.error('[GameLoop] Failed to fetch crash point:', error);
            // Fallback: generate a basic crash point
            return 1.00 + Math.random() * 10;
        }
    }
    /**
     * Finalizes the round in MongoDB (reveals server seed, updates stats).
     */
    async finalizeRound(roundId, crashPoint) {
        try {
            const db = (0, MongoService_1.getDb)();
            await db.collection('game_rounds').updateOne({ round_id: roundId }, {
                $set: {
                    crash_point: crashPoint,
                    status: 'completed',
                    crashed_at: new Date(),
                },
            });
        }
        catch (error) {
            console.error('[GameLoop] Failed to finalize round:', error);
        }
    }
    /**
     * Adds crash point to Redis history (capped list of last 50).
     */
    async addToHistory(crashPoint) {
        try {
            const redis = (0, RedisService_1.getRedisClient)();
            await redis.lpush('game:history', crashPoint.toString());
            await redis.ltrim('game:history', 0, 49);
        }
        catch (error) {
            console.error('[GameLoop] Failed to update history:', error);
        }
    }
    /**
     * Loads the latest nonce from MongoDB.
     */
    async loadNonce() {
        try {
            const db = (0, MongoService_1.getDb)();
            const lastRound = await db.collection('game_rounds')
                .find()
                .sort({ nonce: -1 })
                .limit(1)
                .toArray();
            this.nonce = lastRound.length > 0 ? lastRound[0].nonce : 0;
        }
        catch (error) {
            console.warn('[GameLoop] Failed to load nonce, starting from 0');
            this.nonce = 0;
        }
    }
    /**
     * Utility: non-blocking sleep.
     */
    sleep(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }
}
exports.GameLoop = GameLoop;
//# sourceMappingURL=GameLoop.js.map