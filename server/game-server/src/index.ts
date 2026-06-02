// ============================================
// Game Server — Entry Point
// ============================================

import { config } from './config/env';
import { getRedisClient, closeRedis } from './services/RedisService';
import { connectMongo, closeMongo } from './services/MongoService';
import { WsServer } from './websocket/WsServer';
import { WsHandler } from './websocket/WsHandler';
import { GameState } from './game/GameState';
import { GameLoop } from './game/GameLoop';
import { BetManager } from './game/BetManager';
import { ChatManager } from './chat/ChatManager';

async function start(): Promise<void> {
  try {
    // Connect to data stores
    await connectMongo();
    getRedisClient();

    // Initialize WebSocket server
    const wsServer = new WsServer();

    // Initialize game components
    const gameState = new GameState();
    const betManager = new BetManager(gameState);
    const chatManager = new ChatManager((msg) => wsServer.broadcast(msg));

    const gameLoop = new GameLoop(
      gameState,
      betManager,
      (msg) => wsServer.broadcast(msg),
      (userId, msg) => wsServer.sendToUser(userId, msg),
    );

    // Initialize message handler (pass broadcast and player count for leaderboard)
    const wsHandler = new WsHandler(
      betManager,
      chatManager,
      gameLoop,
      (msg) => wsServer.broadcast(msg),
      () => wsServer.getConnectionCount(),
    );

    // Wire up WebSocket message handling
    wsServer.onMessage((ws, message) => {
      wsHandler.handle(ws as any, message);
    });

    // Start WebSocket server
    wsServer.listen();

    // Start the game loop
    await gameLoop.start();

    console.log(`🎮 Game Server fully initialized`);
    console.log(`   WebSocket: ws://localhost:${config.port}/ws`);
    console.log(`   Environment: ${config.nodeEnv}`);
    console.log(`   Tick interval: ${config.game.tickIntervalMs}ms`);
    console.log(`   Betting phase: ${config.game.bettingPhaseMs}ms`);
    console.log(`   Cooldown: ${config.game.cooldownPhaseMs}ms`);

    // Graceful shutdown
    const shutdown = async () => {
      console.log('\n🎮 Shutting down Game Server...');
      gameLoop.stop();
      await wsServer.close();
      await closeRedis();
      await closeMongo();
      process.exit(0);
    };

    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
  } catch (error) {
    console.error('Failed to start Game Server:', error);
    process.exit(1);
  }
}

start();
