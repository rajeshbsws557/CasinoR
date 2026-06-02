import { GameState } from './GameState';
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
export declare class BetManager {
    private gameState;
    private activeBets;
    private cashedOutBets;
    constructor(gameState: GameState);
    /**
     * Places a bet for a user during the BETTING phase.
     * Atomically debits balance and records the bet.
     * Returns the user's new balance after the debit.
     */
    placeBet(userId: string, username: string, amount: number, autoCashout: number | null, clientSeed: string): Promise<{
        betId: string;
        newBalance: number;
    }>;
    /**
     * Cashes out a user's bet at the current multiplier.
     * Returns full result including the user's new balance.
     */
    cashout(userId: string, betId: string): Promise<CashoutResult>;
    /**
     * Processes auto-cashouts for all active bets whose target has been reached.
     * Called on every tick during the RUNNING phase.
     */
    processAutoCashouts(currentMultiplier: number): Promise<CashoutResult[]>;
    /**
     * Processes all remaining active bets as losses when the round crashes.
     * Returns the list of users who lost, with their current balances.
     */
    processRoundEnd(): Promise<LostBetResult[]>;
    /**
     * Resets bet tracking for a new round.
     */
    resetForNewRound(): void;
    /**
     * Returns all active bets as an array (for broadcasting to clients).
     */
    getActiveBets(): ActiveBet[];
    /**
     * Returns all cashed-out bets for display.
     */
    getCashedOutBets(): CashedOutBet[];
    /**
     * Returns all bets (active + cashed out) for player list display.
     */
    getAllBetsForDisplay(): Array<{
        username: string;
        amount: number;
        status: 'active' | 'cashed_out';
        cashoutMultiplier?: number;
        profit?: number;
    }>;
}
//# sourceMappingURL=BetManager.d.ts.map