export interface VerificationResult {
    roundId: string;
    nonce: number;
    serverSeed: string;
    serverSeedHash: string;
    clientSeeds: string[];
    crashPoint: number;
    gameHash: string;
    hashVerified: boolean;
    crashPointVerified: boolean;
    status: 'verified' | 'failed' | 'round_not_found' | 'round_active';
    message: string;
}
/**
 * Verifies a completed round by:
 * 1. Fetching round data from MongoDB
 * 2. Confirming SHA-256(server_seed) matches the published hash
 * 3. Recalculating the crash point from seeds + nonce
 * 4. Comparing recalculated crash point to the recorded one
 */
export declare function verifyRound(roundId: string): Promise<VerificationResult>;
//# sourceMappingURL=Verifier.d.ts.map