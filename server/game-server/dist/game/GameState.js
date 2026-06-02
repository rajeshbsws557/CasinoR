"use strict";
// ============================================
// Game State — Round State Machine
// ============================================
Object.defineProperty(exports, "__esModule", { value: true });
exports.GameState = void 0;
const RedisService_1 = require("../services/RedisService");
const GAME_STATE_KEY = 'game:current_round';
class GameState {
    state = {
        roundId: '',
        nonce: 0,
        phase: 'COOLDOWN',
        crashPoint: 0,
        serverSeedHash: '',
        currentMultiplier: 1.00,
        startTime: 0,
        bettingEndsAt: 0,
    };
    getState() {
        return { ...this.state };
    }
    getPhase() {
        return this.state.phase;
    }
    getCurrentMultiplier() {
        return this.state.currentMultiplier;
    }
    getRoundId() {
        return this.state.roundId;
    }
    getCrashPoint() {
        return this.state.crashPoint;
    }
    /**
     * Transitions to BETTING phase for a new round.
     */
    async startBettingPhase(roundId, nonce, serverSeedHash, bettingDurationMs) {
        this.state = {
            roundId,
            nonce,
            phase: 'BETTING',
            crashPoint: 0,
            serverSeedHash,
            currentMultiplier: 1.00,
            startTime: 0,
            bettingEndsAt: Date.now() + bettingDurationMs,
        };
        await this.persistToRedis();
    }
    /**
     * Transitions to RUNNING phase — multiplier starts ticking.
     */
    async startRunningPhase(crashPoint) {
        this.state.phase = 'RUNNING';
        this.state.crashPoint = crashPoint;
        this.state.startTime = Date.now();
        await this.persistToRedis();
    }
    /**
     * Updates the current multiplier during RUNNING phase.
     */
    updateMultiplier(multiplier) {
        this.state.currentMultiplier = multiplier;
    }
    /**
     * Transitions to CRASHED phase.
     */
    async crash() {
        this.state.phase = 'CRASHED';
        this.state.currentMultiplier = this.state.crashPoint;
        await this.persistToRedis();
    }
    /**
     * Transitions to COOLDOWN phase.
     */
    async startCooldown() {
        this.state.phase = 'COOLDOWN';
        await this.persistToRedis();
    }
    /**
     * Persists the current state to Redis for recovery and cross-service access.
     */
    async persistToRedis() {
        try {
            const redis = (0, RedisService_1.getRedisClient)();
            await redis.hset(GAME_STATE_KEY, {
                round_id: this.state.roundId,
                nonce: this.state.nonce.toString(),
                phase: this.state.phase,
                crash_point: this.state.crashPoint.toString(),
                server_seed_hash: this.state.serverSeedHash,
                current_multiplier: this.state.currentMultiplier.toString(),
                start_time: this.state.startTime.toString(),
                betting_ends_at: this.state.bettingEndsAt.toString(),
            });
        }
        catch (error) {
            console.error('[GameState] Redis persist error:', error);
        }
    }
    /**
     * Attempts to recover state from Redis on server restart.
     */
    async recoverFromRedis() {
        try {
            const redis = (0, RedisService_1.getRedisClient)();
            const data = await redis.hgetall(GAME_STATE_KEY);
            if (!data || !data.round_id) {
                return false;
            }
            this.state = {
                roundId: data.round_id,
                nonce: parseInt(data.nonce, 10),
                phase: data.phase,
                crashPoint: parseFloat(data.crash_point),
                serverSeedHash: data.server_seed_hash,
                currentMultiplier: parseFloat(data.current_multiplier),
                startTime: parseInt(data.start_time, 10),
                bettingEndsAt: parseInt(data.betting_ends_at, 10),
            };
            console.log(`[GameState] Recovered round ${this.state.roundId} in phase ${this.state.phase}`);
            return true;
        }
        catch (error) {
            console.error('[GameState] Recovery failed:', error);
            return false;
        }
    }
}
exports.GameState = GameState;
//# sourceMappingURL=GameState.js.map