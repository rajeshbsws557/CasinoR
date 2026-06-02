"use strict";
// ============================================
// Crypto Service — Entry Point
// ============================================
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const env_1 = require("./config/env");
const RedisService_1 = require("./services/RedisService");
const MongoService_1 = require("./services/MongoService");
const crypto_routes_1 = __importDefault(require("./routes/crypto.routes"));
const app = (0, express_1.default)();
// Middleware
app.use((0, cors_1.default)());
app.use(express_1.default.json());
// Health check
app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'crypto-service' });
});
// Routes
app.use('/api/crypto', crypto_routes_1.default);
// Startup
async function start() {
    try {
        // Connect to data stores
        await (0, MongoService_1.connectMongo)();
        (0, RedisService_1.getRedisClient)(); // Initialize Redis connection
        app.listen(env_1.config.port, () => {
            console.log(`🔐 Crypto Service running on port ${env_1.config.port}`);
            console.log(`   Environment: ${env_1.config.nodeEnv}`);
        });
    }
    catch (error) {
        console.error('Failed to start Crypto Service:', error);
        process.exit(1);
    }
}
// Graceful shutdown
async function shutdown() {
    console.log('\n🔐 Shutting down Crypto Service...');
    await (0, RedisService_1.closeRedis)();
    await (0, MongoService_1.closeMongo)();
    process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
start();
//# sourceMappingURL=index.js.map