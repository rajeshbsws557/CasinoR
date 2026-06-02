"use strict";
// ============================================
// Crypto Service — Routes
// ============================================
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const crypto_controller_1 = require("../controllers/crypto.controller");
const router = (0, express_1.Router)();
// Internal endpoints (called by game-server)
router.post('/generate-round', crypto_controller_1.generateRound);
router.post('/register-client-seed', crypto_controller_1.registerClientSeed);
router.get('/crash-point/:roundId', crypto_controller_1.getCrashPoint);
// Public endpoint (called by clients for verification)
router.get('/verify/:roundId', crypto_controller_1.verifyRoundHandler);
exports.default = router;
//# sourceMappingURL=crypto.routes.js.map