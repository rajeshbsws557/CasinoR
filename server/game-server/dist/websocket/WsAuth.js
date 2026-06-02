"use strict";
// ============================================
// WebSocket Authentication — JWT on Upgrade
// ============================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.authenticateWsConnection = authenticateWsConnection;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const env_1 = require("../config/env");
/**
 * Extracts and verifies JWT token from WebSocket upgrade request.
 * Token can be in:
 *   1. Query parameter: ws://host/ws?token=xxx
 *   2. Authorization header: Bearer xxx
 */
function authenticateWsConnection(req) {
    try {
        let token = null;
        // Try query parameter first
        const url = new URL(req.url || '', `http://${req.headers.host}`);
        token = url.searchParams.get('token');
        // Fall back to Authorization header
        if (!token) {
            const authHeader = req.headers.authorization;
            if (authHeader && authHeader.startsWith('Bearer ')) {
                token = authHeader.split(' ')[1];
            }
        }
        if (!token) {
            return null;
        }
        const decoded = jsonwebtoken_1.default.verify(token, env_1.config.jwt.secret);
        return decoded;
    }
    catch (error) {
        console.error('[WsAuth] Authentication failed:', error.message);
        return null;
    }
}
//# sourceMappingURL=WsAuth.js.map