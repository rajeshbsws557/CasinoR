// ============================================
// Chat Manager — Real-Time Chat
// ============================================

import { getRedisClient } from '../services/RedisService';

interface ChatMessage {
  user: string;
  userId: string;
  message: string;
  timestamp: number;
}

type BroadcastFn = (message: any) => void;

const CHAT_KEY = 'chat:messages';
const MAX_MESSAGES = 100;
const MESSAGE_MAX_LENGTH = 200;

export class ChatManager {
  private broadcast: BroadcastFn;

  constructor(broadcastFn: BroadcastFn) {
    this.broadcast = broadcastFn;
  }

  /**
   * Sends a chat message from a user.
   * Rate limited to 1 message per 2 seconds per user.
   */
  async sendMessage(userId: string, username: string, text: string): Promise<void> {
    // Validate message length
    if (text.length === 0 || text.length > MESSAGE_MAX_LENGTH) {
      throw new Error(`Message must be 1-${MESSAGE_MAX_LENGTH} characters`);
    }

    // Rate limiting
    const redis = getRedisClient();
    const rateLimitKey = `ratelimit:chat:${userId}`;
    const isLimited = await redis.get(rateLimitKey);
    if (isLimited) {
      throw new Error('Please wait before sending another message');
    }
    await redis.setex(rateLimitKey, 2, '1');

    // Build message
    const chatMessage: ChatMessage = {
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
  async getHistory(): Promise<ChatMessage[]> {
    const redis = getRedisClient();
    const messages = await redis.lrange(CHAT_KEY, 0, 49); // Last 50 messages

    return messages
      .map((msg) => {
        try {
          return JSON.parse(msg) as ChatMessage;
        } catch {
          return null;
        }
      })
      .filter((msg): msg is ChatMessage => msg !== null)
      .reverse(); // Oldest first
  }
}
