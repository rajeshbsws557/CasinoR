"use strict";
// ============================================
// Crash Calculator — HMAC-SHA256 → Multiplier
// ============================================
// Implements the "2^32 method" with configurable house edge.
// The crash point is deterministically derived from:
//   - server_seed (secret, revealed after round)
//   - client_seeds (up to 3, from first bettors)
//   - nonce (round number)
// ============================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculateCrashPoint = calculateCrashPoint;
exports.verifyCrashPoint = verifyCrashPoint;
exports.computeGameHash = computeGameHash;
const crypto_1 = __importDefault(require("crypto"));
const env_1 = require("../config/env");
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
function calculateCrashPoint(input) {
    const { serverSeed, clientSeeds, nonce } = input;
    // Step 1: Build message from client seeds and nonce
    const combinedClientSeed = clientSeeds.join(',');
    const message = `${combinedClientSeed}::${nonce}`;
    // Step 2: HMAC-SHA256 with server seed as key
    const hmac = crypto_1.default.createHmac('sha256', serverSeed);
    hmac.update(message);
    const hash = hmac.digest('hex');
    // Step 3: Parse first 8 hex characters as a 32-bit unsigned integer
    const intFromHash = parseInt(hash.substring(0, 8), 16);
    // Step 4: House edge — instant crash check
    // With divisor 33: ~3.03% of rounds crash at 1.00x
    if (intFromHash % env_1.config.game.houseEdgeDivisor === 0) {
        return { crashPoint: 1.00, hash, intFromHash };
    }
    // Step 5: Calculate crash point using 2^32 method
    // This produces a distribution where:
    //   P(crash ≥ x) ≈ 1/x (for large x)
    // Combined with house edge, expected return = ~97%
    const rawCrashPoint = (Math.pow(2, 32) / (intFromHash + 1));
    const crashPoint = Math.min(1000000, Math.floor(rawCrashPoint * 100) / 100);
    return {
        crashPoint: Math.max(1.00, crashPoint),
        hash,
        intFromHash,
    };
}
/**
 * Verifies a crash point by recalculating from the given inputs.
 * Returns true if the recalculated crash point matches.
 */
function verifyCrashPoint(input, expectedCrashPoint) {
    const result = calculateCrashPoint(input);
    return Math.abs(result.crashPoint - expectedCrashPoint) < 0.001;
}
/**
 * Returns the raw HMAC-SHA256 hash for verification display purposes.
 */
function computeGameHash(serverSeed, clientSeeds, nonce) {
    const combinedClientSeed = clientSeeds.join(',');
    const message = `${combinedClientSeed}::${nonce}`;
    const hmac = crypto_1.default.createHmac('sha256', serverSeed);
    hmac.update(message);
    return hmac.digest('hex');
}
//# sourceMappingURL=CrashCalculator.js.map