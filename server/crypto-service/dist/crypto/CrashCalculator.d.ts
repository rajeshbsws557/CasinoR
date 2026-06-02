export interface CrashCalculationInput {
    serverSeed: string;
    clientSeeds: string[];
    nonce: number;
}
export interface CrashCalculationResult {
    crashPoint: number;
    hash: string;
    intFromHash: number;
}
/**
 * Calculates the crash multiplier using HMAC-SHA256 and the 2^32 method.
 *
 * Algorithm:
 * 1. Combine client seeds and nonce into a message string
 * 2. HMAC-SHA256(server_seed, message) to produce a hash
 * 3. Take first 8 hex chars → 32-bit integer
 * 4. If integer % houseEdgeDivisor === 0 → instant crash (1.00x)
 * 5. Otherwise: crashPoint = floor((2^32 / (int + 1)) * 100) / 100
 */
export declare function calculateCrashPoint(input: CrashCalculationInput): CrashCalculationResult;
/**
 * Verifies a crash point by recalculating from the given inputs.
 * Returns true if the recalculated crash point matches.
 */
export declare function verifyCrashPoint(input: CrashCalculationInput, expectedCrashPoint: number): boolean;
/**
 * Returns the raw HMAC-SHA256 hash for verification display purposes.
 */
export declare function computeGameHash(serverSeed: string, clientSeeds: string[], nonce: number): string;
//# sourceMappingURL=CrashCalculator.d.ts.map