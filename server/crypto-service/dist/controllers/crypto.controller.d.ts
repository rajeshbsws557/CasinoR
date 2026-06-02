import { Request, Response } from 'express';
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
export declare function generateRound(req: Request, res: Response): Promise<void>;
/**
 * POST /api/crypto/register-client-seed
 * Internal endpoint: Called when a player places a bet.
 * Collects up to 3 client seeds, then calculates the final crash point.
 */
export declare function registerClientSeed(req: Request, res: Response): Promise<void>;
/**
 * GET /api/crypto/verify/:roundId
 * Public endpoint: Anyone can verify a completed round.
 */
export declare function verifyRoundHandler(req: Request, res: Response): Promise<void>;
/**
 * GET /api/crypto/crash-point/:roundId
 * Internal endpoint: Game server fetches the current crash point.
 */
export declare function getCrashPoint(req: Request, res: Response): Promise<void>;
//# sourceMappingURL=crypto.controller.d.ts.map