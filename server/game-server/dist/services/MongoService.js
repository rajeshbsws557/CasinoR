"use strict";
// ============================================
// Game Server — MongoDB Service
// ============================================
Object.defineProperty(exports, "__esModule", { value: true });
exports.connectMongo = connectMongo;
exports.getDb = getDb;
exports.getClient = getClient;
exports.closeMongo = closeMongo;
const mongodb_1 = require("mongodb");
const env_1 = require("../config/env");
let client = null;
let db = null;
async function connectMongo() {
    if (db)
        return db;
    client = new mongodb_1.MongoClient(env_1.config.mongo.url, {
        maxPoolSize: 20,
        minPoolSize: 5,
        serverSelectionTimeoutMS: 5000,
        connectTimeoutMS: 10000,
    });
    await client.connect();
    db = client.db(env_1.config.mongo.dbName);
    console.log('[MongoDB] Connected to', env_1.config.mongo.dbName);
    return db;
}
function getDb() {
    if (!db)
        throw new Error('[MongoDB] Not connected.');
    return db;
}
function getClient() {
    if (!client)
        throw new Error('[MongoDB] Not connected.');
    return client;
}
async function closeMongo() {
    if (client) {
        await client.close();
        client = null;
        db = null;
    }
}
//# sourceMappingURL=MongoService.js.map