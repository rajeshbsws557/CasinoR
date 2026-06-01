// ============================================
// WebSocket Handler — Message Router
// ============================================

import { WsMessage } from '../types';
import { BetManager } from '../game/BetManager';
import { ChatManager } from '../chat/ChatManager';
import { GameLoop } from '../game/GameLoop';

// Extend WebSocket with auth info
interface AuthenticatedWebSocket {
  userId: string;
  username: string;
  send(data: string): void;
}

export class WsHandler {
  constructor(
    private betManager: BetManager,
    private chatManager: ChatManager,
    private gameLoop: GameLoop,
  ) {}

  /**
   * Routes incoming WebSocket messages to the appropriate handler.
   */
  handle(ws: AuthenticatedWebSocket, message: WsMessage): void {
    // ── Type validation ──
    if (!message || typeof message.type !== 'string') {
      ws.send(JSON.stringify({
        type: 'ERROR',
        data: { message: 'Invalid message format' },
      }));
      return;
    }

    switch (message.type) {
      case 'BET':
        this.handleBet(ws, message);
        break;

      case 'CASHOUT':
        this.handleCashout(ws, message);
        break;

      case 'CHAT':
        this.handleChat(ws, message);
        break;

      default:
        ws.send(JSON.stringify({
          type: 'ERROR',
          data: { message: `Unknown message type: ${message.type}` },
        }));
    }
  }

  private async handleBet(ws: AuthenticatedWebSocket, message: WsMessage): Promise<void> {
    try {
      if (!message.data || typeof message.data !== 'object') {
        ws.send(JSON.stringify({
          type: 'BET_ERROR',
          data: { message: 'Invalid bet data' },
        }));
        return;
      }

      const { amount, auto_cashout, client_seed } = message.data;

      // ── Strict input validation ──
      if (amount === undefined || amount === null || typeof amount !== 'number') {
        ws.send(JSON.stringify({
          type: 'BET_ERROR',
          data: { message: 'Invalid bet amount' },
        }));
        return;
      }

      // Must be a positive integer (paisa, no floating point for money)
      if (!Number.isInteger(amount) || amount <= 0) {
        ws.send(JSON.stringify({
          type: 'BET_ERROR',
          data: { message: 'Bet amount must be a positive integer (in paisa)' },
        }));
        return;
      }

      // Validate auto_cashout if provided
      if (auto_cashout !== undefined && auto_cashout !== null) {
        if (typeof auto_cashout !== 'number' || auto_cashout < 1.01 || auto_cashout > 1000000) {
          ws.send(JSON.stringify({
            type: 'BET_ERROR',
            data: { message: 'Auto-cashout must be between 1.01x and 1,000,000x' },
          }));
          return;
        }
      }

      // Validate client_seed if provided (must be a string, max 64 chars)
      let sanitizedClientSeed = '';
      if (client_seed !== undefined && client_seed !== null) {
        if (typeof client_seed !== 'string' || client_seed.length > 64) {
          ws.send(JSON.stringify({
            type: 'BET_ERROR',
            data: { message: 'Client seed must be a string (max 64 characters)' },
          }));
          return;
        }
        // Sanitize: only allow alphanumeric + basic characters
        sanitizedClientSeed = client_seed.replace(/[^a-zA-Z0-9\-_]/g, '');
      }

      const result = await this.betManager.placeBet(
        ws.userId,
        ws.username,
        amount,
        auto_cashout || null,
        sanitizedClientSeed,
      );

      // Confirm bet
      ws.send(JSON.stringify({
        type: 'BET_CONFIRMED',
        data: { betId: result.betId, amount, auto_cashout: auto_cashout || null },
      }));

      // Send balance update after bet placement
      ws.send(JSON.stringify({
        type: 'BALANCE_UPDATE',
        data: {
          balance: result.newBalance,
          formatted: `৳${(result.newBalance / 100).toFixed(2)}`,
          reason: 'bet_placed',
        },
      }));
    } catch (error) {
      ws.send(JSON.stringify({
        type: 'BET_ERROR',
        data: { message: (error as Error).message },
      }));
    }
  }

  private async handleCashout(ws: AuthenticatedWebSocket, message: WsMessage): Promise<void> {
    try {
      const { betId } = message.data || {};
      if (!betId || typeof betId !== 'string') {
        ws.send(JSON.stringify({
          type: 'CASHOUT_ERROR',
          data: { message: 'Missing betId for cashout' },
        }));
        return;
      }

      const result = await this.betManager.cashout(ws.userId, betId);

      ws.send(JSON.stringify({
        type: 'CASHOUT_CONFIRMED',
        data: {
          betId,
          multiplier: result.cashoutMultiplier,
          profit: result.profit,
          payout: result.amount + result.profit,
        },
      }));

      // Send balance update after cashout
      ws.send(JSON.stringify({
        type: 'BALANCE_UPDATE',
        data: {
          balance: result.newBalance,
          formatted: `৳${(result.newBalance / 100).toFixed(2)}`,
          reason: 'cashout',
        },
      }));
    } catch (error) {
      ws.send(JSON.stringify({
        type: 'CASHOUT_ERROR',
        data: { message: (error as Error).message },
      }));
    }
  }

  private async handleChat(ws: AuthenticatedWebSocket, message: WsMessage): Promise<void> {
    try {
      if (!message.data || typeof message.data !== 'object') {
        return;
      }

      const { message: text } = message.data;

      if (!text || typeof text !== 'string') {
        return;
      }

      // Sanitize chat input: max 200 chars, strip HTML
      const sanitized = text.trim().substring(0, 200).replace(/<[^>]*>/g, '');

      if (sanitized.length === 0) {
        return;
      }

      await this.chatManager.sendMessage(ws.userId, ws.username, sanitized);
    } catch (error) {
      // Chat errors are silent — don't disrupt gameplay
      console.warn('[WsHandler] Chat error:', (error as Error).message);
    }
  }
}
