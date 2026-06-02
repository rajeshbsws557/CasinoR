export declare const config: {
    readonly port: number;
    readonly nodeEnv: string;
    readonly redis: {
        readonly url: string;
    };
    readonly mongo: {
        readonly url: string;
        readonly dbName: "crashgame";
    };
    readonly jwt: {
        readonly secret: string;
    };
    readonly cryptoService: {
        readonly url: string;
    };
    readonly game: {
        readonly bettingPhaseMs: number;
        readonly cooldownPhaseMs: number;
        readonly tickIntervalMs: number;
        readonly growthRate: number;
        readonly minBet: number;
        readonly maxBet: number;
    };
    readonly ws: {
        readonly heartbeatIntervalMs: 30000;
        readonly heartbeatTimeoutMs: 60000;
    };
};
//# sourceMappingURL=env.d.ts.map