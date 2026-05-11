import { createServer } from 'node:http';
import { WebSocketServer } from 'ws';
import { SessionRegistry } from './SessionRegistry.js';

const PORT = parseInt(process.env.PORT ?? '8080', 10);
const HEARTBEAT_INTERVAL_MS = 30_000;
const STALE_SESSION_MAX_AGE_MS = 24 * 60 * 60 * 1000;

const registry = new SessionRegistry();

// HTTP server for health checks (required by cloud platforms)
const httpServer = createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', sessions: registry.size }));
  } else {
    res.writeHead(404);
    res.end();
  }
});

const wss = new WebSocketServer({ server: httpServer });

httpServer.listen(PORT, () => {
  console.log(`Relay server listening on port ${PORT}`);
});

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
    case 'player_rejoin':
      return handlePlayerRejoin(ws, msg);
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

  sendTo(session.host, {
    type: 'player_join',
    payload: { playerId, name },
    from: playerId,
  });
}

function handlePlayerRejoin(ws, msg) {
  if (ws.role) {
    sendTo(ws, { type: 'error', payload: { message: 'Connection already has a role' } });
    return;
  }

  const { code, name, playerId: oldPlayerId } = msg.payload ?? {};
  if (!code || !name) {
    sendTo(ws, { type: 'error', payload: { message: 'Missing code or name' } });
    return;
  }

  const session = registry.getSession(code.toUpperCase());
  if (!session) {
    sendTo(ws, { type: 'error', payload: { message: 'Session not found' } });
    return;
  }

  if (oldPlayerId && session.clients.has(oldPlayerId)) {
    session.clients.set(oldPlayerId, ws);
    ws.role = 'client';
    ws.sessionCode = session.code;
    ws.playerId = oldPlayerId;

    console.log(`Player "${name}" (${oldPlayerId}) reconnected to session ${session.code}`);

    sendTo(session.host, {
      type: 'player_rejoin',
      payload: { playerId: oldPlayerId, name },
      from: oldPlayerId,
    });
    return;
  }

  const tempId = crypto.randomUUID();
  registry.addClient(session.code, tempId, ws);
  ws.role = 'client';
  ws.sessionCode = session.code;
  ws.playerId = tempId;

  console.log(`Player "${name}" (${tempId}) attempting rejoin to session ${session.code}`);

  sendTo(session.host, {
    type: 'player_rejoin',
    payload: { playerId: tempId, name },
    from: tempId,
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

const cleanup = setInterval(() => {
  const removed = registry.cleanupStaleSessions(STALE_SESSION_MAX_AGE_MS);
  if (removed > 0) console.log(`Cleaned up ${removed} stale sessions`);
}, 60 * 60 * 1000);

wss.on('close', () => {
  clearInterval(heartbeat);
  clearInterval(cleanup);
});

export { wss, registry, httpServer };
