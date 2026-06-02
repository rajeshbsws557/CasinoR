"use strict";
// ============================================
// Crypto Controller — Business Logic
// ============================================
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateRound = generateRound;
exports.registerClientSeed = registerClientSeed;
exports.verifyRoundHandler = verifyRoundHandler;
exports.getCrashPoint = getCrashPoint;
const SeedGenerator_1 = require("../crypto/SeedGenerator");
const CrashCalculator_1 = require("../crypto/CrashCalculator");
const Verifier_1 = require("../crypto/Verifier");
const RedisService_1 = require("../services/RedisService");
const MongoService_1 = require("../services/MongoService");
const MAX_CLIENT_SEEDS = 3;
/**
 * POST /api/crypto/generate-round
 * Internal endpoint: Called by the game server to generate a new round's crypto data.
 *
 * Flow:
 * 1. Generate a random server seed
 * 2. Hash the server seed (this hash is published to players)
 * 3. Store the seed data in Redis for the active round
 * 4. Insert the round record into MongoDB
 * 5. Return the hash (NOT the seed) and a placeholder crash point
 *    (final crash point depends on client seeds)
 */
async function generateRound(req, res) {
    try {
        const { roundId, nonce } = req.body;
        if (!roundId || nonce === undefined) {
            res.status(400).json({
                success: false,
                error: 'Missing roundId or nonce',
            });
            return;
        }
        // Generate cryptographic materials
        const serverSeed = (0, SeedGenerator_1.generateServerSeed)();
        const serverSeedHash = (0, SeedGenerator_1.hashServerSeed)(serverSeed);
        // Store in Redis for fast access during the round
        const redis = (0, RedisService_1.getRedisClient)();
        await redis.hset(`crypto:round:${roundId}`, {
            server_seed: serverSeed,
            server_seed_hash: serverSeedHash,
            nonce: nonce.toString(),
            client_seeds: JSON.stringify([]),
        });
        // TTL: 1 hour (cleanup after round)
        await redis.expire(`crypto:round:${roundId}`, 3600);
        // Insert round record into MongoDB (server_seed hidden until round ends)
        const db = (0, MongoService_1.getDb)();
        await db.collection('game_rounds').insertOne({
            round_id: roundId,
            nonce,
            server_seed: serverSeed,
            server_seed_hash: serverSeedHash,
            client_seeds: [],
            crash_point: 0, // Will be calculated when round starts
            status: 'active',
            started_at: new Date(),
            crashed_at: null,
            total_bets: 0,
            total_wagered: mongodb_1.Long.fromNumber(0),
            total_paid_out: mongodb_1.Long.fromNumber(0),
        });
        const response = {
            success: true,
            data: {
                roundId,
                nonce,
                serverSeedHash,
                crashPoint: 0, // Not yet calculated
            },
        };
        res.status(201).json(response);
    }
    catch (error) {
        console.error('[CryptoController] generateRound error:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to generate round',
        });
    }
}
/**
 * POST /api/crypto/register-client-seed
 * Internal endpoint: Called when a player places a bet.
 * Collects up to 3 client seeds, then calculates the final crash point.
 */
async function registerClientSeed(req, res) {
    try {
        const { roundId, clientSeed, userId } = req.body;
        if (!roundId || !clientSeed || !userId) {
            res.status(400).json({
                success: false,
                error: 'Missing roundId, clientSeed, or userId',
            });
            return;
        }
        const redis = (0, RedisService_1.getRedisClient)();
        const roundData = await redis.hgetall(`crypto:round:${roundId}`);
        if (!roundData || !roundData.server_seed) {
            res.status(404).json({
                success: false,
                error: 'Round not found or expired',
            });
            return;
        }
        let clientSeeds = JSON.parse(roundData.client_seeds || '[]');
        // Only accept up to MAX_CLIENT_SEEDS
        if (clientSeeds.length < MAX_CLIENT_SEEDS) {
            clientSeeds.push(clientSeed);
            // Update Redis
            await redis.hset(`crypto:round:${roundId}`, 'client_seeds', JSON.stringify(clientSeeds));
            // Update MongoDB
            const db = (0, MongoService_1.getDb)();
            await db.collection('game_rounds').updateOne({ round_id: roundId }, { $push: { client_seeds: clientSeed } });
        }
        // If we just collected the first client seed, calculate crash point
        // (We calculate on first seed so the round can proceed even with 1 bettor)
        if (clientSeeds.length === 1) {
            const result = (0, CrashCalculator_1.calculateCrashPoint)({
                serverSeed: roundData.server_seed,
                clientSeeds,
                nonce: parseInt(roundData.nonce, 10),
            });
            // Store the crash point in Redis (game server reads this)
            await redis.hset(`crypto:round:${roundId}`, 'crash_point', result.crashPoint.toString());
        }
        // Recalculate with updated seeds (crash point evolves as seeds are added)
        const finalResult = (0, CrashCalculator_1.calculateCrashPoint)({
            serverSeed: roundData.server_seed,
            clientSeeds,
            nonce: parseInt(roundData.nonce, 10),
        });
        await redis.hset(`crypto:round:${roundId}`, 'crash_point', finalResult.crashPoint.toString());
        const response = {
            success: true,
            data: {
                roundId,
                clientSeedsCount: clientSeeds.length,
                maxSeeds: MAX_CLIENT_SEEDS,
            },
        };
        res.status(200).json(response);
    }
    catch (error) {
        console.error('[CryptoController] registerClientSeed error:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to register client seed',
        });
    }
}
/**
 * GET /api/crypto/verify/:roundId
 * Public endpoint: Anyone can verify a completed round.
 */
async function verifyRoundHandler(req, res) {
    try {
        const { roundId } = req.params;
        if (!roundId) {
            res.status(400).json({
                success: false,
                error: 'Missing roundId',
            });
            return;
        }
        const result = await (0, Verifier_1.verifyRound)(roundId);
        res.status(result.status === 'round_not_found' ? 404 : 200).json({
            success: result.status === 'verified',
            data: result,
        });
    }
    catch (error) {
        console.error('[CryptoController] verifyRound error:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to verify round',
        });
    }
}
/**
 * GET /api/crypto/crash-point/:roundId
 * Internal endpoint: Game server fetches the current crash point.
 */
async function getCrashPoint(req, res) {
    try {
        const { roundId } = req.params;
        const redis = (0, RedisService_1.getRedisClient)();
        const crashPoint = await redis.hget(`crypto:round:${roundId}`, 'crash_point');
        if (!crashPoint) {
            // No client seeds yet — calculate with empty array
            const roundData = await redis.hgetall(`crypto:round:${roundId}`);
            if (!roundData || !roundData.server_seed) {
                res.status(404).json({ success: false, error: 'Round not found' });
                return;
            }
            const result = (0, CrashCalculator_1.calculateCrashPoint)({
                serverSeed: roundData.server_seed,
                clientSeeds: [],
                nonce: parseInt(roundData.nonce, 10),
            });
            await redis.hset(`crypto:round:${roundId}`, 'crash_point', result.crashPoint.toString());
            res.json({ success: true, data: { crashPoint: result.crashPoint } });
            return;
        }
        res.json({ success: true, data: { crashPoint: parseFloat(crashPoint) } });
    }
    catch (error) {
        console.error('[CryptoController] getCrashPoint error:', error);
        res.status(500).json({ success: false, error: 'Failed to get crash point' });
    }
}
// MongoDB Long type for large integers
const mongodb_1 = require("mongodb");
//# sourceMappingURL=crypto.controller.js.map