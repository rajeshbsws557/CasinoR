import { calculateCrashPoint, verifyCrashPoint, computeGameHash } from '../src/crypto/CrashCalculator';
import { config } from '../src/config/env';

// Mock config for tests
jest.mock('../src/config/env', () => ({
  config: {
    game: {
      houseEdgeDivisor: 33
    }
  }
}));

describe('CrashCalculator', () => {
  const testInput = {
    serverSeed: '507f1f77bcf86cd799439011',
    clientSeeds: ['client-seed-1', 'client-seed-2'],
    nonce: 1
  };

  it('calculates deterministic crash points', () => {
    const result1 = calculateCrashPoint(testInput);
    const result2 = calculateCrashPoint(testInput);
    
    expect(result1.crashPoint).toBe(result2.crashPoint);
    expect(result1.hash).toBe(result2.hash);
  });

  it('verifies a valid crash point', () => {
    const result = calculateCrashPoint(testInput);
    const isValid = verifyCrashPoint(testInput, result.crashPoint);
    
    expect(isValid).toBe(true);
  });

  it('rejects an invalid crash point', () => {
    const result = calculateCrashPoint(testInput);
    const isInvalid = verifyCrashPoint(testInput, result.crashPoint + 0.5);
    
    expect(isInvalid).toBe(false);
  });

  it('computes expected hash', () => {
    const hash = computeGameHash(testInput.serverSeed, testInput.clientSeeds, testInput.nonce);
    const result = calculateCrashPoint(testInput);
    
    expect(hash).toBe(result.hash);
  });
});
