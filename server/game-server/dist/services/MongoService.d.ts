import { MongoClient, Db } from 'mongodb';
export declare function connectMongo(): Promise<Db>;
export declare function getDb(): Db;
export declare function getClient(): MongoClient;
export declare function closeMongo(): Promise<void>;
//# sourceMappingURL=MongoService.d.ts.map