"use strict";
// ============================================
// Verifier — Post-Round Verification Logic
// ============================================
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyRound = verifyRound;
const MongoService_1 = require("../services/MongoService");
const SeedGenerator_1 = require("./SeedGenerator");
const CrashCalculator_1 = require("./CrashCalculator");
/**
 * Verifies a completed round by:
 * 1. Fetching round data from MongoDB
 * 2. Confirming SHA-256(server_seed) matches the published hash
 * 3. Recalculating the crash point from seeds + nonce
 * 4. Comparing recalculated crash point to the recorded one
 */
async function verifyRound(roundId) {
    const db = (0, MongoService_1.getDb)();
    // Fetch the round from the database
    const round = await db.collection('game_rounds').findOne({ round_id: roundId });
    if (!round) {
        return {
            roundId,
            nonce: 0,
            serverSeed: '',
            serverSeedHash: '',
            clientSeeds: [],
            crashPoint: 0,
            gameHash: '',
            hashVerified: false,
            crashPointVerified: false,
            status: 'round_not_found',
            message: `Round ${roundId} not found in database.`,
        };
    }
    // Active rounds cannot be verified (server seed is still secret)
    if (round.status === 'active') {
        return {
            roundId,
            nonce: round.nonce,
            serverSeed: '*** HIDDEN (round in progress) ***',
            serverSeedHash: round.server_seed_hash,
            clientSeeds: round.client_seeds || [],
            crashPoint: 0,
            gameHash: '',
            hashVerified: false,
            crashPointVerified: false,
            status: 'round_active',
            message: 'Round is still active. Verification available after crash.',
        };
    }
    const serverSeed = round.server_seed;
    const serverSeedHash = round.server_seed_hash;
    const clientSeeds = round.client_seeds || [];
    const nonce = round.nonce;
    const recordedCrashPoint = round.crash_point;
    // Step 1: Verify server seed hash
    const hashVerified = (0, SeedGenerator_1.verifyServerSeedHash)(serverSeed, serverSeedHash);
    // Step 2: Recalculate crash point
    const calcResult = (0, CrashCalculator_1.calculateCrashPoint)({
        serverSeed,
        clientSeeds,
        nonce,
    });
    const crashPointVerified = Math.abs(calcResult.crashPoint - recordedCrashPoint) < 0.001;
    // Step 3: Compute the game hash for display
    const gameHash = (0, CrashCalculator_1.computeGameHash)(serverSeed, clientSeeds, nonce);
    const allVerified = hashVerified && crashPointVerified;
    return {
        roundId,
        nonce,
        serverSeed,
        serverSeedHash,
        clientSeeds,
        crashPoint: calcResult.crashPoint,
        gameHash,
        hashVerified,
        crashPointVerified,
        status: allVerified ? 'verified' : 'failed',
        message: allVerified
            ? 'Round verified successfully. The crash point was fairly generated.'
            : `Verification failed: ${!hashVerified ? 'Server seed hash mismatch. ' : ''}${!crashPointVerified ? 'Crash point mismatch.' : ''}`,
    };
}
//# sourceMappingURL=Verifier.js.map