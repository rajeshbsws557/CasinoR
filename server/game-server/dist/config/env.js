"use strict";
// ============================================
// Game Server — Environment Configuration
// ============================================
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const dotenv = __importStar(require("dotenv"));
dotenv.config();
exports.config = {
    port: parseInt(process.env.PORT || '3000', 10),
    nodeEnv: process.env.NODE_ENV || 'development',
    redis: {
        url: process.env.REDIS_URL || 'redis://localhost:6379',
    },
    mongo: {
        url: process.env.MONGO_URL || 'mongodb://localhost:27017/crashgame',
        dbName: 'crashgame',
    },
    jwt: {
        secret: process.env.JWT_SECRET || 'dev-secret-change-me',
    },
    cryptoService: {
        url: process.env.CRYPTO_SERVICE_URL || 'http://localhost:3002',
    },
    game: {
        bettingPhaseMs: parseInt(process.env.BETTING_PHASE_MS || '7000', 10),
        cooldownPhaseMs: parseInt(process.env.COOLDOWN_PHASE_MS || '3000', 10),
        tickIntervalMs: parseInt(process.env.TICK_INTERVAL_MS || '50', 10),
        growthRate: parseFloat(process.env.GROWTH_RATE || '0.00006'),
        minBet: parseInt(process.env.MIN_BET || '100', 10),
        maxBet: parseInt(process.env.MAX_BET || '1000000', 10),
    },
    ws: {
        heartbeatIntervalMs: 30000,
        heartbeatTimeoutMs: 60000,
    },
};
//# sourceMappingURL=env.js.map