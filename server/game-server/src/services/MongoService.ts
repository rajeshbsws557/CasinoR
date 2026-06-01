// ============================================
// Game Server — MongoDB Service
// ============================================

import { MongoClient, Db } from 'mongodb';
import { config } from '../config/env';

let client: MongoClient | null = null;
let db: Db | null = null;

export async function connectMongo(): Promise<Db> {
  if (db) return db;

  client = new MongoClient(config.mongo.url, {
    maxPoolSize: 20,
    minPoolSize: 5,
    serverSelectionTimeoutMS: 5000,
    connectTimeoutMS: 10000,
  });

  await client.connect();
  db = client.db(config.mongo.dbName);
  console.log('[MongoDB] Connected to', config.mongo.dbName);
  return db;
}

export function getDb(): Db {
  if (!db) throw new Error('[MongoDB] Not connected.');
  return db;
}

export function getClient(): MongoClient {
  if (!client) throw new Error('[MongoDB] Not connected.');
  return client;
}

export async function closeMongo(): Promise<void> {
  if (client) {
    await client.close();
    client = null;
    db = null;
  }
}
