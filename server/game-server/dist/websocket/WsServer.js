"use strict";
// ============================================
// WebSocket Server — Connection Management
// ============================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.WsServer = void 0;
const ws_1 = require("ws");
const http_1 = __importDefault(require("http"));
const env_1 = require("../config/env");
const WsAuth_1 = require("./WsAuth");
class WsServer {
    wss;
    httpServer;
    clients = new Map();
    ipConnectionCounts = new Map();
    messageHandler = null;
    heartbeatInterval = null;
    // Security: max connections per IP and messages per second per user
    static MAX_CONNECTIONS_PER_IP = 3;
    static MAX_MESSAGES_PER_SECOND = 10;
    constructor() {
        this.httpServer = http_1.default.createServer((_req, res) => {
            // Health check endpoint
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ status: 'ok', service: 'game-server', connections: this.clients.size }));
        });
        this.wss = new ws_1.WebSocketServer({
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
    onMessage(handler) {
        this.messageHandler = handler;
    }
    /**
     * Starts listening on the configured port.
     */
    listen() {
        this.httpServer.listen(env_1.config.port, () => {
            console.log(`🎮 Game Server WebSocket listening on port ${env_1.config.port}`);
        });
    }
    /**
     * Broadcasts a message to ALL connected clients.
     */
    broadcast(message) {
        const data = JSON.stringify(message);
        for (const [, client] of this.clients) {
            if (client.readyState === ws_1.WebSocket.OPEN) {
                client.send(data);
            }
        }
    }
    /**
     * Sends a message to a specific user.
     */
    sendToUser(userId, message) {
        const client = this.clients.get(userId);
        if (client && client.readyState === ws_1.WebSocket.OPEN) {
            client.send(JSON.stringify(message));
        }
    }
    /**
     * Returns the count of connected clients.
     */
    getConnectionCount() {
        return this.clients.size;
    }
    /**
     * Returns info about all connected clients.
     */
    getConnectedUsers() {
        const users = [];
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
    async close() {
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
    setupConnectionHandler() {
        this.wss.on('connection', (ws, req) => {
            const authWs = ws;
            // Get client IP
            const clientIp = req.headers['x-forwarded-for']?.split(',')[0]?.trim()
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
            const auth = (0, WsAuth_1.authenticateWsConnection)(req);
            if (!auth) {
                ws.close(4001, 'Authentication required');
                return;
            }
            // If user already connected, close the old connection
            const existing = this.clients.get(auth.userId);
            if (existing) {
                // Decrement IP count for the old connection
                const oldIp = existing.clientIp;
                if (oldIp) {
                    const oldCount = this.ipConnectionCounts.get(oldIp) || 0;
                    if (oldCount > 1) {
                        this.ipConnectionCounts.set(oldIp, oldCount - 1);
                    }
                    else {
                        this.ipConnectionCounts.delete(oldIp);
                    }
                }
                existing.close(4002, 'New connection from same account');
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
            authWs.on('message', (raw) => {
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
                    const message = JSON.parse(raw.toString());
                    // Handle ping/pong internally
                    if (message.type === 'PONG') {
                        authWs.isAlive = true;
                        authWs.lastPing = Date.now();
                        return;
                    }
                    if (this.messageHandler) {
                        this.messageHandler(authWs, message);
                    }
                }
                catch (error) {
                    // Invalid JSON — ignore
                    console.warn(`[WS] Invalid message from ${auth.username}:`, error.message);
                }
            });
            // Handle pong frames
            authWs.on('pong', () => {
                authWs.isAlive = true;
                authWs.lastPing = Date.now();
            });
            // Handle disconnect
            authWs.on('close', (code, reason) => {
                this.clients.delete(auth.userId);
                // Decrement IP connection count
                const ipCount = this.ipConnectionCounts.get(clientIp) || 0;
                if (ipCount > 1) {
                    this.ipConnectionCounts.set(clientIp, ipCount - 1);
                }
                else {
                    this.ipConnectionCounts.delete(clientIp);
                }
                console.log(`[WS] Client disconnected: ${auth.username} (code: ${code}) | Total: ${this.clients.size}`);
            });
            // Handle errors
            authWs.on('error', (error) => {
                console.error(`[WS] Error from ${auth.username}:`, error.message);
                this.clients.delete(auth.userId);
                const ipCount = this.ipConnectionCounts.get(clientIp) || 0;
                if (ipCount > 1) {
                    this.ipConnectionCounts.set(clientIp, ipCount - 1);
                }
                else {
                    this.ipConnectionCounts.delete(clientIp);
                }
            });
        });
    }
    /**
     * Heartbeat: ping all clients every 30s.
     * Terminate connections that haven't responded in 60s.
     */
    startHeartbeat() {
        this.heartbeatInterval = setInterval(() => {
            const now = Date.now();
            for (const [userId, ws] of this.clients) {
                if (!ws.isAlive || (now - ws.lastPing > env_1.config.ws.heartbeatTimeoutMs)) {
                    console.log(`[WS] Heartbeat timeout for ${ws.username}, terminating`);
                    ws.terminate();
                    this.clients.delete(userId);
                    continue;
                }
                ws.isAlive = false;
                ws.ping();
            }
        }, env_1.config.ws.heartbeatIntervalMs);
    }
}
exports.WsServer = WsServer;
//# sourceMappingURL=WsServer.js.map