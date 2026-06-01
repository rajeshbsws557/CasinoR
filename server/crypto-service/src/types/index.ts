// ============================================
// Crypto Service — TypeScript Types
// ============================================

export interface GenerateRoundRequest {
  roundId: string;
  nonce: number;
}

export interface GenerateRoundResponse {
  roundId: string;
  nonce: number;
  serverSeedHash: string;
  crashPoint: number;
}

export interface RegisterClientSeedRequest {
  roundId: string;
  clientSeed: string;
  userId: string;
}

export interface RegisterClientSeedResponse {
  roundId: string;
  clientSeedsCount: number;
  maxSeeds: number;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
}
