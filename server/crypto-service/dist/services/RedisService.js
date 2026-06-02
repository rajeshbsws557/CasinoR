"use strict";
// ============================================
// Redis Service — Client Wrapper
// ============================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getRedisClient = getRedisClient;
exports.closeRedis = closeRedis;
const ioredis_1 = __importDefault(require("ioredis"));
const env_1 = require("../config/env");
let redisClient = null;
function getRedisClient() {
    if (!redisClient) {
        redisClient = new ioredis_1.default(env_1.config.redis.url, {
            maxRetriesPerRequest: 3,
            retryStrategy: (times) => {
                if (times > 10)
                    return null;
                return Math.min(times * 200, 3000);
            },
            lazyConnect: false,
        });
        redisClient.on('connect', () => {
            console.log('[Redis] Connected');
        });
        redisClient.on('error', (err) => {
            console.error('[Redis] Error:', err.message);
        });
    }
    return redisClient;
}
async function closeRedis() {
    if (redisClient) {
        await redisClient.quit();
        redisClient = null;
    }
}
//# sourceMappingURL=RedisService.js.map