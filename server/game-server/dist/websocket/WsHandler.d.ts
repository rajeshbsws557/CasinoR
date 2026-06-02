import { WsMessage } from '../types';
import { BetManager } from '../game/BetManager';
import { ChatManager } from '../chat/ChatManager';
import { GameLoop } from '../game/GameLoop';
interface AuthenticatedWebSocket {
    userId: string;
    username: string;
    send(data: string): void;
}
type BroadcastFn = (message: WsMessage) => void;
type GetPlayerCountFn = () => number;
export declare class WsHandler {
    private betManager;
    private chatManager;
    private gameLoop;
    private broadcastFn?;
    private getPlayerCount?;
    constructor(betManager: BetManager, chatManager: ChatManager, gameLoop: GameLoop, broadcastFn?: BroadcastFn | undefined, getPlayerCount?: GetPlayerCountFn | undefined);
    /**
     * Routes incoming WebSocket messages to the appropriate handler.
     */
    handle(ws: AuthenticatedWebSocket, message: WsMessage): void;
    private handleBet;
    private handleCashout;
    private handleChat;
}
export {};
//# sourceMappingURL=WsHandler.d.ts.map