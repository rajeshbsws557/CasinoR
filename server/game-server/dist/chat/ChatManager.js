"use strict";
// ============================================
// Chat Manager — Real-Time Chat
// ============================================
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChatManager = void 0;
const RedisService_1 = require("../services/RedisService");
const CHAT_KEY = 'chat:messages';
const MAX_MESSAGES = 100;
const MESSAGE_MAX_LENGTH = 200;
class ChatManager {
    broadcast;
    constructor(broadcastFn) {
        this.broadcast = broadcastFn;
    }
    /**
     * Sends a chat message from a user.
     * Rate limited to 1 message per 2 seconds per user.
     */
    async sendMessage(userId, username, text) {
        // Validate message length
        if (text.length === 0 || text.length > MESSAGE_MAX_LENGTH) {
            throw new Error(`Message must be 1-${MESSAGE_MAX_LENGTH} characters`);
        }
        // Rate limiting
        const redis = (0, RedisService_1.getRedisClient)();
        const rateLimitKey = `ratelimit:chat:${userId}`;
        const isLimited = await redis.get(rateLimitKey);
        if (isLimited) {
            throw new Error('Please wait before sending another message');
        }
        await redis.setex(rateLimitKey, 2, '1');
        // Build message
        const chatMessage = {
            user: username,
            userId,
            message: text,
            timestamp: Date.now(),
        };
        // Store in Redis (capped list)
        const serialized = JSON.stringify(chatMessage);
        await redis.lpush(CHAT_KEY, serialized);
        await redis.ltrim(CHAT_KEY, 0, MAX_MESSAGES - 1);
        // Broadcast to all connected clients
        this.broadcast({
            type: 'CHAT',
            data: {
                user: username,
                message: text,
                timestamp: chatMessage.timestamp,
            },
        });
    }
    /**
     * Returns recent chat history for newly connected users.
     */
    async getHistory() {
        const redis = (0, RedisService_1.getRedisClient)();
        const messages = await redis.lrange(CHAT_KEY, 0, 49); // Last 50 messages
        return messages
            .map((msg) => {
            try {
                return JSON.parse(msg);
            }
            catch {
                return null;
            }
        })
            .filter((msg) => msg !== null)
            .reverse(); // Oldest first
    }
}
exports.ChatManager = ChatManager;
//# sourceMappingURL=ChatManager.js.map