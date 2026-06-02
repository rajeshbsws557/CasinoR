"use strict";
// ============================================
// Seed Generator — Cryptographically Secure
// ============================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateServerSeed = generateServerSeed;
exports.hashServerSeed = hashServerSeed;
exports.verifyServerSeedHash = verifyServerSeedHash;
const crypto_1 = __importDefault(require("crypto"));
const env_1 = require("../config/env");
/**
 * Generates a cryptographically secure server seed.
 * Returns a 16-character hexadecimal string (8 random bytes).
 */
function generateServerSeed() {
    const bytes = env_1.config.game.serverSeedLength / 2; // 16 hex chars = 8 bytes
    return crypto_1.default.randomBytes(bytes).toString('hex');
}
/**
 * Computes the SHA-256 hash of a server seed.
 * This hash is published to clients BEFORE the round begins,
 * committing the server to that specific seed without revealing it.
 */
function hashServerSeed(serverSeed) {
    return crypto_1.default
        .createHash('sha256')
        .update(serverSeed)
        .digest('hex');
}
/**
 * Verifies that a given server seed matches its hash.
 * Used post-round to prove the seed was not changed.
 */
function verifyServerSeedHash(serverSeed, expectedHash) {
    const computedHash = hashServerSeed(serverSeed);
    // Use timing-safe comparison to prevent timing attacks
    try {
        return crypto_1.default.timingSafeEqual(Buffer.from(computedHash, 'hex'), Buffer.from(expectedHash, 'hex'));
    }
    catch {
        return false;
    }
}
//# sourceMappingURL=SeedGenerator.js.map