// ============================================
// Game Server — TypeScript Types
// ============================================

export type GamePhase = 'BETTING' | 'RUNNING' | 'CRASHED' | 'COOLDOWN';

export interface RoundState {
  roundId: string;
  nonce: number;
  phase: GamePhase;
  crashPoint: number;
  serverSeedHash: string;
  currentMultiplier: number;
  startTime: number;       // Unix timestamp ms
  bettingEndsAt: number;   // Unix timestamp ms
}

export interface ActiveBet {
  betId: string;
  userId: string;
  username: string;
  amount: number;
  autoCashout: number | null;
  clientSeed: string;
  placedAt: Date;
}

export interface CashedOutBet extends ActiveBet {
  cashoutMultiplier: number;
  profit: number;
}

// ─── WebSocket Message Types ───

export type WsMessageType =
  | 'ROUND_START'
  | 'TICK'
  | 'CRASH'
  | 'BET'
  | 'BET_CONFIRMED'
  | 'BET_ERROR'
  | 'CASHOUT'
  | 'CASHOUT_CONFIRMED'
  | 'CASHOUT_ERROR'
  | 'CHAT'
  | 'CHAT_HISTORY'
  | 'PLAYERS_UPDATE'
  | 'PLAYER_CASHOUT'
  | 'GAME_STATE'
  | 'BALANCE_UPDATE'
  | 'ERROR'
  | 'PONG';

export interface WsMessage {
  type: WsMessageType;
  data: Record<string, any>;
}

export interface WsClientInfo {
  userId: string;
  username: string;
  isAlive: boolean;
  lastPing: number;
}

// ─── Crypto Service Types ───

export interface CryptoGenerateResponse {
  success: boolean;
  data?: {
    roundId: string;
    nonce: number;
    serverSeedHash: string;
    crashPoint: number;
  };
  error?: string;
}

export interface CryptoCrashPointResponse {
  success: boolean;
  data?: {
    crashPoint: number;
  };
  error?: string;
}
