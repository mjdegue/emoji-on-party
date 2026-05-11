import { useEffect, useRef, useCallback } from "react";

const RELAY_URL = import.meta.env.VITE_RELAY_URL || "ws://localhost:8080";
const RECONNECT_DELAY = 3000;

type MessageHandler = (type: string, payload: Record<string, unknown>, from: string) => void;

export function useWebSocket(onMessage: MessageHandler) {
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimer = useRef<number | null>(null);
  const onMessageRef = useRef(onMessage);
  onMessageRef.current = onMessage;

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;

    const ws = new WebSocket(RELAY_URL);

    ws.onopen = () => {
      console.log("Connected to relay");
      onMessageRef.current("__connected", {}, "");
    };

    ws.onclose = () => {
      console.log("Disconnected from relay");
      onMessageRef.current("__disconnected", {}, "");
      reconnectTimer.current = window.setTimeout(connect, RECONNECT_DELAY);
    };

    ws.onerror = () => {
      ws.close();
    };

    ws.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        onMessageRef.current(msg.type || "", msg.payload || {}, msg.from || "");
      } catch {
        console.warn("Failed to parse message", event.data);
      }
    };

    wsRef.current = ws;
  }, []);

  const send = useCallback((type: string, payload: Record<string, unknown> = {}) => {
    if (wsRef.current?.readyState !== WebSocket.OPEN) {
      console.warn("Cannot send, WebSocket not open");
      return;
    }
    wsRef.current.send(JSON.stringify({ type, payload }));
  }, []);

  useEffect(() => {
    return () => {
      if (reconnectTimer.current) clearTimeout(reconnectTimer.current);
      wsRef.current?.close();
    };
  }, []);

  return { connect, send };
}
