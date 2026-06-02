interface ChatMessage {
    user: string;
    userId: string;
    message: string;
    timestamp: number;
}
type BroadcastFn = (message: any) => void;
export declare class ChatManager {
    private broadcast;
    constructor(broadcastFn: BroadcastFn);
    /**
     * Sends a chat message from a user.
     * Rate limited to 1 message per 2 seconds per user.
     */
    sendMessage(userId: string, username: string, text: string): Promise<void>;
    /**
     * Returns recent chat history for newly connected users.
     */
    getHistory(): Promise<ChatMessage[]>;
}
export {};
//# sourceMappingURL=ChatManager.d.ts.map