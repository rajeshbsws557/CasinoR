// ============================================
// WebSocket Server — Connection Management
// ============================================

import { WebSocketServer, WebSocket, RawData } from 'ws';
import { IncomingMessage } from 'http';
import http from 'http';
import { config } from '../config/env';
import { authenticateWsConnection, AuthPayload } from './WsAuth';
import { WsMessage, WsClientInfo } from '../types';

// Extend WebSocket with custom properties
interface AuthenticatedWebSocket extends WebSocket {
  userId: string;
  username: string;
  isAlive: boolean;
  lastPing: number;
  msgCount: number;      // Message rate limiting counter
  msgWindowStart: number; // Start of current rate limit window
  clientIp: string;      // Client IP for connection limiting
}

type MessageHandler = (ws: AuthenticatedWebSocket, message: WsMessage) => void;

export class WsServer {
  private wss: WebSocketServer;
  private httpServer: http.Server;
  private clients: Map<string, AuthenticatedWebSocket> = new Map();
  private ipConnectionCounts: Map<string, number> = new Map();
  private messageHandler: MessageHandler | null = null;
  private heartbeatInterval: NodeJS.Timeout | null = null;

  // Security: max connections per IP and messages per second per user
  private static readonly MAX_CONNECTIONS_PER_IP = 3;
  private static readonly MAX_MESSAGES_PER_SECOND = 10;

  constructor() {
    this.httpServer = http.createServer((_req, res) => {
      // Health check endpoint
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', service: 'game-server', connections: this.clients.size }));
    });

    this.wss = new WebSocketServer({
      server: this.httpServer,
      path: '/ws',
      maxPayload: 4096, // 4KB max message size
    });

    this.setupConnectionHandler();
    this.startHeartbeat();
  }

  /**
   * Registers the message handler function.
   */
  onMessage(handler: MessageHandler): void {
    this.messageHandler = handler;
  }

  /**
   * Starts listening on the configured port.
   */
  listen(): void {
    this.httpServer.listen(config.port, () => {
      console.log(`🎮 Game Server WebSocket listening on port ${config.port}`);
    });
  }

  /**
   * Broadcasts a message to ALL connected clients.
   */
  broadcast(message: WsMessage): void {
    const data = JSON.stringify(message);
    for (const [, client] of this.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data);
      }
    }
  }

  /**
   * Sends a message to a specific user.
   */
  sendToUser(userId: string, message: WsMessage): void {
    const client = this.clients.get(userId);
    if (client && client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(message));
    }
  }

  /**
   * Returns the count of connected clients.
   */
  getConnectionCount(): number {
    return this.clients.size;
  }

  /**
   * Returns info about all connected clients.
   */
  getConnectedUsers(): WsClientInfo[] {
    const users: WsClientInfo[] = [];
    for (const [userId, ws] of this.clients) {
      users.push({
        userId,
        username: ws.username,
        isAlive: ws.isAlive,
        lastPing: ws.lastPing,
      });
    }
    return users;
  }

  /**
   * Gracefully shuts down the WebSocket server.
   */
  async close(): Promise<void> {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }

    // Close all connections
    for (const [, client] of this.clients) {
      client.close(1001, 'Server shutting down');
    }

    return new Promise((resolve) => {
      this.wss.close(() => {
        this.httpServer.close(() => {
          resolve();
        });
      });
    });
  }

  // ─── Private Methods ───

  private setupConnectionHandler(): void {
    this.wss.on('connection', (ws: WebSocket, req: IncomingMessage) => {
      const authWs = ws as AuthenticatedWebSocket;

      // Get client IP
      const clientIp = (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim()
        || req.socket.remoteAddress
        || 'unknown';

      // ── IP-based connection limiting ──
      const currentIpCount = this.ipConnectionCounts.get(clientIp) || 0;
      if (currentIpCount >= WsServer.MAX_CONNECTIONS_PER_IP) {
        console.warn(`[WS] Connection rejected: IP ${clientIp} exceeded max connections (${WsServer.MAX_CONNECTIONS_PER_IP})`);
        ws.close(4003, 'Too many connections from this IP');
        return;
      }

      // Authenticate
      const auth = authenticateWsConnection(req);
      if (!auth) {
        ws.close(4001, 'Authentication required');
        return;
      }

      // If user already connected, reject the new connection
      const existing = this.clients.get(auth.userId);
      if (existing) {
        ws.send(JSON.stringify({
          type: 'ERROR',
          data: { message: 'You are already logged in on another device' }
        }));
        // We close the new connection
        ws.close(4002, 'New connection from same account rejected');
        
        // Decrement IP count for the rejected connection
        const newIpCount = this.ipConnectionCounts.get(clientIp) || 0;
        if (newIpCount > 1) {
          this.ipConnectionCounts.set(clientIp, newIpCount - 1);
        } else {
          this.ipConnectionCounts.delete(clientIp);
        }
        return;
      }

      // Set up authenticated WebSocket
      authWs.userId = auth.userId;
      authWs.username = auth.username;
      authWs.isAlive = true;
      authWs.lastPing = Date.now();
      authWs.msgCount = 0;
      authWs.msgWindowStart = Date.now();
      authWs.clientIp = clientIp;

      this.clients.set(auth.userId, authWs);
      this.ipConnectionCounts.set(clientIp, (this.ipConnectionCounts.get(clientIp) || 0) + 1);

      console.log(`[WS] Client connected: ${auth.username} (${auth.userId}) | IP: ${clientIp} | Total: ${this.clients.size}`);

      // Handle incoming messages
      authWs.on('message', (raw: RawData) => {
        try {
          // ── Per-user message rate limiting ──
          const now = Date.now();
          if (now - authWs.msgWindowStart > 1000) {
            // Reset window
            authWs.msgCount = 0;
            authWs.msgWindowStart = now;
          }
          authWs.msgCount++;

          if (authWs.msgCount > WsServer.MAX_MESSAGES_PER_SECOND) {
            authWs.send(JSON.stringify({
              type: 'ERROR',
              data: { message: 'Rate limited: too many messages' },
            }));
            return;
          }

          const message = JSON.parse(raw.toString()) as WsMessage;

          // Handle ping/pong internally
          if (message.type === 'PONG' as any) {
            authWs.isAlive = true;
            authWs.lastPing = Date.now();
            return;
          }

          if (this.messageHandler) {
            this.messageHandler(authWs, message);
          }
        } catch (error) {
          // Invalid JSON — ignore
          console.warn(`[WS] Invalid message from ${auth.username}:`, (error as Error).message);
        }
      });

      // Handle pong frames
      authWs.on('pong', () => {
        authWs.isAlive = true;
        authWs.lastPing = Date.now();
      });

      // Handle disconnect
      authWs.on('close', (code: number, reason: Buffer) => {
        this.clients.delete(auth.userId);
        // Decrement IP connection count
        const ipCount = this.ipConnectionCounts.get(clientIp) || 0;
        if (ipCount > 1) {
          this.ipConnectionCounts.set(clientIp, ipCount - 1);
        } else {
          this.ipConnectionCounts.delete(clientIp);
        }
        console.log(`[WS] Client disconnected: ${auth.username} (code: ${code}) | Total: ${this.clients.size}`);
      });

      // Handle errors
      authWs.on('error', (error: Error) => {
        console.error(`[WS] Error from ${auth.username}:`, error.message);
        this.clients.delete(auth.userId);
        const ipCount = this.ipConnectionCounts.get(clientIp) || 0;
        if (ipCount > 1) {
          this.ipConnectionCounts.set(clientIp, ipCount - 1);
        } else {
          this.ipConnectionCounts.delete(clientIp);
        }
      });
    });
  }

  /**
   * Heartbeat: ping all clients every 30s.
   * Terminate connections that haven't responded in 60s.
   */
  private startHeartbeat(): void {
    this.heartbeatInterval = setInterval(() => {
      const now = Date.now();

      for (const [userId, ws] of this.clients) {
        if (!ws.isAlive || (now - ws.lastPing > config.ws.heartbeatTimeoutMs)) {
          console.log(`[WS] Heartbeat timeout for ${ws.username}, terminating`);
          ws.terminate();
          this.clients.delete(userId);
          continue;
        }

        ws.isAlive = false;
        ws.ping();
      }
    }, config.ws.heartbeatIntervalMs);
  }
}
