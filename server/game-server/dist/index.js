"use strict";
// ============================================
// Game Server — Entry Point
// ============================================
Object.defineProperty(exports, "__esModule", { value: true });
const env_1 = require("./config/env");
const RedisService_1 = require("./services/RedisService");
const MongoService_1 = require("./services/MongoService");
const WsServer_1 = require("./websocket/WsServer");
const WsHandler_1 = require("./websocket/WsHandler");
const GameState_1 = require("./game/GameState");
const GameLoop_1 = require("./game/GameLoop");
const BetManager_1 = require("./game/BetManager");
const ChatManager_1 = require("./chat/ChatManager");
async function start() {
    try {
        // Connect to data stores
        await (0, MongoService_1.connectMongo)();
        (0, RedisService_1.getRedisClient)();
        // Initialize WebSocket server
        const wsServer = new WsServer_1.WsServer();
        // Initialize game components
        const gameState = new GameState_1.GameState();
        const betManager = new BetManager_1.BetManager(gameState);
        const chatManager = new ChatManager_1.ChatManager((msg) => wsServer.broadcast(msg));
        const gameLoop = new GameLoop_1.GameLoop(gameState, betManager, (msg) => wsServer.broadcast(msg), (userId, msg) => wsServer.sendToUser(userId, msg));
        // Initialize message handler (pass broadcast and player count for leaderboard)
        const wsHandler = new WsHandler_1.WsHandler(betManager, chatManager, gameLoop, (msg) => wsServer.broadcast(msg), () => wsServer.getConnectionCount());
        // Wire up WebSocket message handling
        wsServer.onMessage((ws, message) => {
            wsHandler.handle(ws, message);
        });
        // Start WebSocket server
        wsServer.listen();
        // Start the game loop
        await gameLoop.start();
        console.log(`🎮 Game Server fully initialized`);
        console.log(`   WebSocket: ws://localhost:${env_1.config.port}/ws`);
        console.log(`   Environment: ${env_1.config.nodeEnv}`);
        console.log(`   Tick interval: ${env_1.config.game.tickIntervalMs}ms`);
        console.log(`   Betting phase: ${env_1.config.game.bettingPhaseMs}ms`);
        console.log(`   Cooldown: ${env_1.config.game.cooldownPhaseMs}ms`);
        // Graceful shutdown
        const shutdown = async () => {
            console.log('\n🎮 Shutting down Game Server...');
            gameLoop.stop();
            await wsServer.close();
            await (0, RedisService_1.closeRedis)();
            await (0, MongoService_1.closeMongo)();
            process.exit(0);
        };
        process.on('SIGINT', shutdown);
        process.on('SIGTERM', shutdown);
    }
    catch (error) {
        console.error('Failed to start Game Server:', error);
        process.exit(1);
    }
}
start();
//# sourceMappingURL=index.js.map