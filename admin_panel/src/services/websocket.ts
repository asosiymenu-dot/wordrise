type EventCallback = (payload: any) => void;

class AdminWebSocketService {
  private ws: WebSocket | null = null;
  private url: string;
  private reconnectInterval = 1000;
  private maxReconnectInterval = 30000;
  private listeners: Map<string, Set<EventCallback>> = new Map();
  private isIntentionalClose = false;
  private token: string | null = null;

  constructor() {
    this.url = import.meta.env.VITE_WS_URL || 'ws://localhost:8080';
  }

  public connect(token: string) {
    this.token = token;
    this.isIntentionalClose = false;
    this.setupConnection();
  }

  private setupConnection() {
    if (this.ws && (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING)) {
      return;
    }

    this.ws = new WebSocket(this.url);

    this.ws.onopen = () => {
      console.log('[AdminWS] Connected');
      // Authenticate
      if (this.token) {
        this.ws?.send(JSON.stringify({
          type: 'auth',
          token: this.token
        }));
      }
      
      // If this is a reconnect (not the first connection), trigger reconnected
      if (this.reconnectInterval > 1000) {
        this.triggerEvent('reconnected', {});
      }
      this.reconnectInterval = 1000;
    };

    this.ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.type) {
          this.triggerEvent(data.type, data.payload || data);
        }
      } catch (e) {
        console.error('[AdminWS] Failed to parse message', e);
      }
    };

    this.ws.onclose = () => {
      console.log('[AdminWS] Disconnected');
      this.ws = null;
      if (!this.isIntentionalClose) {
        this.scheduleReconnect();
      }
    };

    this.ws.onerror = (error) => {
      console.error('[AdminWS] Error', error);
      this.ws?.close();
    };
  }

  private scheduleReconnect() {
    setTimeout(() => {
      console.log(`[AdminWS] Reconnecting in ${this.reconnectInterval}ms`);
      this.setupConnection();
      this.reconnectInterval = Math.min(this.reconnectInterval * 2, this.maxReconnectInterval);
    }, this.reconnectInterval);
  }

  public disconnect() {
    this.isIntentionalClose = true;
    this.token = null;
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  public on(event: string, callback: EventCallback) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)?.add(callback);
    return () => this.off(event, callback); // Returns unsubscribe function
  }

  public off(event: string, callback: EventCallback) {
    this.listeners.get(event)?.delete(callback);
  }

  private triggerEvent(event: string, payload: any) {
    if (this.listeners.has(event)) {
      this.listeners.get(event)?.forEach(callback => callback(payload));
    }
    
    // Also trigger a wildcard event for global logging if needed
    if (this.listeners.has('*')) {
      this.listeners.get('*')?.forEach(callback => callback({ event, payload }));
    }
  }
}

export const wsService = new AdminWebSocketService();
