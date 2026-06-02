import { WebSocket } from 'ws';
import { WsMessage, WsClientInfo } from '../types';
interface AuthenticatedWebSocket extends WebSocket {
    userId: string;
    username: string;
    isAlive: boolean;
    lastPing: number;
    msgCount: number;
    msgWindowStart: number;
    clientIp: string;
}
type MessageHandler = (ws: AuthenticatedWebSocket, message: WsMessage) => void;
export declare class WsServer {
    private wss;
    private httpServer;
    private clients;
    private ipConnectionCounts;
    private messageHandler;
    private heartbeatInterval;
    private static readonly MAX_CONNECTIONS_PER_IP;
    private static readonly MAX_MESSAGES_PER_SECOND;
    constructor();
    /**
     * Registers the message handler function.
     */
    onMessage(handler: MessageHandler): void;
    /**
     * Starts listening on the configured port.
     */
    listen(): void;
    /**
     * Broadcasts a message to ALL connected clients.
     */
    broadcast(message: WsMessage): void;
    /**
     * Sends a message to a specific user.
     */
    sendToUser(userId: string, message: WsMessage): void;
    /**
     * Returns the count of connected clients.
     */
    getConnectionCount(): number;
    /**
     * Returns info about all connected clients.
     */
    getConnectedUsers(): WsClientInfo[];
    /**
     * Gracefully shuts down the WebSocket server.
     */
    close(): Promise<void>;
    private setupConnectionHandler;
    /**
     * Heartbeat: ping all clients every 30s.
     * Terminate connections that haven't responded in 60s.
     */
    private startHeartbeat;
}
export {};
//# sourceMappingURL=WsServer.d.ts.map