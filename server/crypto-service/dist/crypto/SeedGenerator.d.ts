/**
 * Generates a cryptographically secure server seed.
 * Returns a 16-character hexadecimal string (8 random bytes).
 */
export declare function generateServerSeed(): string;
/**
 * Computes the SHA-256 hash of a server seed.
 * This hash is published to clients BEFORE the round begins,
 * committing the server to that specific seed without revealing it.
 */
export declare function hashServerSeed(serverSeed: string): string;
/**
 * Verifies that a given server seed matches its hash.
 * Used post-round to prove the seed was not changed.
 */
export declare function verifyServerSeedHash(serverSeed: string, expectedHash: string): boolean;
//# sourceMappingURL=SeedGenerator.d.ts.map