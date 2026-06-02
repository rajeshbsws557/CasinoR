import { GameState } from './GameState';
import { BetManager } from './BetManager';
import { WsMessage } from '../types';
type BroadcastFn = (message: WsMessage) => void;
type SendToUserFn = (userId: string, message: WsMessage) => void;
export declare class GameLoop {
    private gameState;
    private betManager;
    private broadcast;
    private sendToUser;
    private tickTimer;
    private nonce;
    private isRunning;
    constructor(gameState: GameState, betManager: BetManager, broadcastFn: BroadcastFn, sendToUserFn: SendToUserFn);
    /**
     * Starts the game loop. Runs indefinitely.
     */
    start(): Promise<void>;
    /**
     * Stops the game loop.
     */
    stop(): void;
    /**
     * Returns the current game state for newly connected users.
     */
    getStateForNewClient(): WsMessage;
    /**
     * Runs a complete round: BETTING → RUNNING → CRASH → COOLDOWN → repeat
     */
    private runRound;
    /**
     * The core tick engine: calculates multiplier every 50ms and broadcasts.
     */
    private runTickEngine;
    /**
     * Requests a new round from the crypto service.
     */
    private requestCryptoRound;
    /**
     * Fetches the final crash point from the crypto service.
     */
    private fetchCrashPoint;
    /**
     * Finalizes the round in MongoDB (reveals server seed, updates stats).
     */
    private finalizeRound;
    /**
     * Adds crash point to Redis history (capped list of last 50).
     */
    private addToHistory;
    /**
     * Loads the latest nonce from MongoDB.
     */
    private loadNonce;
    /**
     * Utility: non-blocking sleep.
     */
    private sleep;
}
export {};
//# sourceMappingURL=GameLoop.d.ts.map