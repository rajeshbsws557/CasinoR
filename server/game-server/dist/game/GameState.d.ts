import { GamePhase, RoundState } from '../types';
export declare class GameState {
    private state;
    getState(): RoundState;
    getPhase(): GamePhase;
    getCurrentMultiplier(): number;
    getRoundId(): string;
    getCrashPoint(): number;
    /**
     * Transitions to BETTING phase for a new round.
     */
    startBettingPhase(roundId: string, nonce: number, serverSeedHash: string, bettingDurationMs: number): Promise<void>;
    /**
     * Transitions to RUNNING phase — multiplier starts ticking.
     */
    startRunningPhase(crashPoint: number): Promise<void>;
    /**
     * Updates the current multiplier during RUNNING phase.
     */
    updateMultiplier(multiplier: number): void;
    /**
     * Transitions to CRASHED phase.
     */
    crash(): Promise<void>;
    /**
     * Transitions to COOLDOWN phase.
     */
    startCooldown(): Promise<void>;
    /**
     * Persists the current state to Redis for recovery and cross-service access.
     */
    private persistToRedis;
    /**
     * Attempts to recover state from Redis on server restart.
     */
    recoverFromRedis(): Promise<boolean>;
}
//# sourceMappingURL=GameState.d.ts.map