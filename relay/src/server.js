import { WebSocketServer } from 'ws';
import { SessionRegistry } from './SessionRegistry.js';

const PORT = parseInt(process.env.PORT ?? '8080', 10);
const HEARTBEAT_INTERVAL_MS = 30_000;
const STALE_SESSION_MAX_AGE_MS = 24 * 60 * 60 * 1000;

const registry = new SessionRegistry();

const wss = new WebSocketServer({ port: PORT });

console.log(`Relay server listening on port ${PORT}`);

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.role = null; // 'host' | 'client'

  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      sendTo(ws, { type: 'error', payload: { message: 'Invalid JSON' } });
      return;
    }

    if (!msg.type) {
      sendTo(ws, { type: 'error', payload: { message: 'Missing message type' } });
      return;
    }

    handleMessage(ws, msg);
  });

  ws.on('close', () => handleDisconnect(ws));
  ws.on('error', () => handleDisconnect(ws));
});

function handleMessage(ws, msg) {
  switch (msg.type) {
    case 'host_create_session':
      return handleHostCreate(ws, msg);
    case 'player_join':
      return handlePlayerJoin(ws, msg);
    default:
      return handleGameMessage(ws, msg);
  }
}

function handleHostCreate(ws, msg) {
  if (ws.role) {
    sendTo(ws, { type: 'error', payload: { message: 'Connection already has a role' } });
    return;
  }

  const code = registry.createSession(ws);
  ws.role = 'host';
  ws.sessionCode = code;

  console.log(`Session ${code} created`);
  sendTo(ws, { type: 'session_created', payload: { code } });
}

function handlePlayerJoin(ws, msg) {
  if (ws.role) {
    sendTo(ws, { type: 'error', payload: { message: 'Connection already has a role' } });
    return;
  }

  const { code, name } = msg.payload ?? {};
  if (!code || !name) {
    sendTo(ws, { type: 'error', payload: { message: 'Missing code or name' } });
    return;
  }

  const session = registry.getSession(code.toUpperCase());
  if (!session) {
    sendTo(ws, { type: 'error', payload: { message: 'Session not found' } });
    return;
  }

  const playerId = crypto.randomUUID();
  if (!registry.addClient(session.code, playerId, ws)) {
    sendTo(ws, { type: 'error', payload: { message: 'Failed to join session' } });
    return;
  }

  ws.role = 'client';
  ws.sessionCode = session.code;
  ws.playerId = playerId;

  console.log(`Player "${name}" (${playerId}) joined session ${session.code}`);

  // Forward the join to the host so it can process game logic
  sendTo(session.host, {
    type: 'player_join',
    payload: { playerId, name },
    from: playerId,
  });
}

function handleGameMessage(ws, msg) {
  if (!ws.role || !ws.sessionCode) {
    sendTo(ws, { type: 'error', payload: { message: 'Not in a session' } });
    return;
  }

  const session = registry.getSession(ws.sessionCode);
  if (!session) {
    sendTo(ws, { type: 'error', payload: { message: 'Session no longer exists' } });
    return;
  }

  if (ws.role === 'client') {
    // Client messages always go to the host
    sendTo(session.host, {
      ...msg,
      from: ws.playerId,
    });
  } else if (ws.role === 'host') {
    routeHostMessage(session, msg);
  }
}

function routeHostMessage(session, msg) {
  const to = msg.to;
  if (!to) return;

  // Strip routing field before forwarding
  const forwarded = { ...msg };
  delete forwarded.to;
  forwarded.from = 'host';

  if (to === 'all') {
    for (const [, clientWs] of session.clients) {
      sendTo(clientWs, forwarded);
    }
  } else {
    const clientWs = session.clients.get(to);
    if (clientWs) {
      sendTo(clientWs, forwarded);
    }
  }
}

function handleDisconnect(ws) {
  if (ws._disconnected) return;
  ws._disconnected = true;

  if (ws.role === 'host' && ws.sessionCode) {
    const session = registry.getSession(ws.sessionCode);
    if (session) {
      console.log(`Host disconnected from session ${ws.sessionCode}`);
      // Notify all clients that the host is gone
      for (const [, clientWs] of session.clients) {
        sendTo(clientWs, { type: 'host_disconnected', from: 'relay' });
      }
      registry.removeSession(ws.sessionCode);
    }
  } else if (ws.role === 'client' && ws.sessionCode) {
    const session = registry.getSession(ws.sessionCode);
    if (session) {
      console.log(`Player ${ws.playerId} disconnected from session ${ws.sessionCode}`);
      registry.removeClient(ws.sessionCode, ws.playerId);
      // Notify the host
      sendTo(session.host, {
        type: 'player_disconnected',
        payload: { playerId: ws.playerId },
        from: ws.playerId,
      });
    }
  }
}

function sendTo(ws, msg) {
  if (ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify(msg));
  }
}

// Heartbeat: detect dead connections
const heartbeat = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) {
      ws.terminate();
      return;
    }
    ws.isAlive = false;
    ws.ping();
  });
}, HEARTBEAT_INTERVAL_MS);

// Periodic cleanup of stale sessions
const cleanup = setInterval(() => {
  const removed = registry.cleanupStaleSessions(STALE_SESSION_MAX_AGE_MS);
  if (removed > 0) console.log(`Cleaned up ${removed} stale sessions`);
}, 60 * 60 * 1000);

wss.on('close', () => {
  clearInterval(heartbeat);
  clearInterval(cleanup);
});

export { wss, registry };
