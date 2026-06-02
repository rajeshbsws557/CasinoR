import { IncomingMessage } from 'http';
export interface AuthPayload {
    userId: string;
    username: string;
    email: string;
}
/**
 * Extracts and verifies JWT token from WebSocket upgrade request.
 * Token can be in:
 *   1. Query parameter: ws://host/ws?token=xxx
 *   2. Authorization header: Bearer xxx
 */
export declare function authenticateWsConnection(req: IncomingMessage): AuthPayload | null;
//# sourceMappingURL=WsAuth.d.ts.map