import { describe, it, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { WebSocketServer, WebSocket } from 'ws';
import { SessionRegistry } from './SessionRegistry.js';

// We test the relay logic by spinning up a server in-process with the same
// handler logic as server.js, but on a random port so tests don't conflict.

function createTestRelay() {
  const registry = new SessionRegistry();
  const wss = new WebSocketServer({ port: 0 }); // random port

  wss.on('connection', (ws) => {
    ws.isAlive = true;
    ws.role = null;

    ws.on('message', (raw) => {
      const msg = JSON.parse(raw);
      handleMessage(ws, msg);
    });

    ws.on('close', () => handleDisconnect(ws));
  });

  function handleMessage(ws, msg) {
    switch (msg.type) {
      case 'host_create_session': {
        const code = registry.createSession(ws);
        ws.role = 'host';
        ws.sessionCode = code;
        sendTo(ws, { type: 'session_created', payload: { code } });
        break;
      }
      case 'player_join': {
        const { code, name } = msg.payload ?? {};
        const session = registry.getSession(code);
        if (!session) {
          sendTo(ws, { type: 'error', payload: { message: 'Session not found' } });
          return;
        }
        const playerId = `player_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
        registry.addClient(session.code, playerId, ws);
        ws.role = 'client';
        ws.sessionCode = session.code;
        ws.playerId = playerId;
        sendTo(session.host, { type: 'player_join', payload: { playerId, name }, from: playerId });
        break;
      }
      default: {
        if (!ws.role || !ws.sessionCode) return;
        const session = registry.getSession(ws.sessionCode);
        if (!session) return;

        if (ws.role === 'client') {
          sendTo(session.host, { ...msg, from: ws.playerId });
        } else if (ws.role === 'host') {
          const to = msg.to;
          const forwarded = { ...msg, from: 'host' };
          delete forwarded.to;
          if (to === 'all') {
            for (const [, clientWs] of session.clients) sendTo(clientWs, forwarded);
          } else {
            const clientWs = session.clients.get(to);
            if (clientWs) sendTo(clientWs, forwarded);
          }
        }
      }
    }
  }

  function handleDisconnect(ws) {
    if (ws._disconnected) return;
    ws._disconnected = true;

    if (ws.role === 'host' && ws.sessionCode) {
      const session = registry.getSession(ws.sessionCode);
      if (session) {
        for (const [, clientWs] of session.clients) {
          sendTo(clientWs, { type: 'host_disconnected', from: 'relay' });
        }
        registry.removeSession(ws.sessionCode);
      }
    } else if (ws.role === 'client' && ws.sessionCode) {
      const session = registry.getSession(ws.sessionCode);
      if (session) {
        registry.removeClient(ws.sessionCode, ws.playerId);
        sendTo(session.host, { type: 'player_disconnected', payload: { playerId: ws.playerId }, from: ws.playerId });
      }
    }
  }

  function sendTo(ws, msg) {
    if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg));
  }

  const port = wss.address().port;
  return { wss, registry, port };
}

function connect(port) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}`);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

function waitForMessage(ws, predicate = () => true) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('Timed out waiting for message')), 3000);
    ws.on('message', function handler(raw) {
      const msg = JSON.parse(raw);
      if (predicate(msg)) {
        clearTimeout(timeout);
        ws.removeListener('message', handler);
        resolve(msg);
      }
    });
  });
}

function send(ws, msg) {
  ws.send(JSON.stringify(msg));
}

describe('Relay Integration', () => {
  let relay;
  let connections = [];

  beforeEach(() => {
    relay = createTestRelay();
    connections = [];
  });

  afterEach(() => {
    connections.forEach((ws) => ws.close());
    relay.wss.close();
  });

  async function connectAndTrack() {
    const ws = await connect(relay.port);
    connections.push(ws);
    return ws;
  }

  async function createHostSession() {
    const host = await connectAndTrack();
    const responsePromise = waitForMessage(host, (m) => m.type === 'session_created');
    send(host, { type: 'host_create_session' });
    const response = await responsePromise;
    return { host, code: response.payload.code };
  }

  async function joinAsPlayer(code, name) {
    const client = await connectAndTrack();
    send(client, { type: 'player_join', payload: { code, name } });
    // Small delay to let the relay process
    await new Promise((r) => setTimeout(r, 50));
    return client;
  }

  it('host can create a session and get a code', async () => {
    const { code } = await createHostSession();
    assert.equal(code.length, 6);
  });

  it('player can join a session by code', async () => {
    const { host, code } = await createHostSession();

    const joinPromise = waitForMessage(host, (m) => m.type === 'player_join');
    const client = await connectAndTrack();
    send(client, { type: 'player_join', payload: { code, name: 'Alice' } });

    const joinMsg = await joinPromise;
    assert.equal(joinMsg.payload.name, 'Alice');
    assert.ok(joinMsg.payload.playerId);
    assert.ok(joinMsg.from);
  });

  it('player joining unknown code gets error', async () => {
    const client = await connectAndTrack();
    const errPromise = waitForMessage(client, (m) => m.type === 'error');
    send(client, { type: 'player_join', payload: { code: 'ZZZZZZ', name: 'Bob' } });
    const err = await errPromise;
    assert.equal(err.payload.message, 'Session not found');
  });

  it('client messages are forwarded to host with from=playerId', async () => {
    const { host, code } = await createHostSession();

    // Wait for join message to get playerId
    const joinPromise = waitForMessage(host, (m) => m.type === 'player_join');
    const client = await connectAndTrack();
    send(client, { type: 'player_join', payload: { code, name: 'Alice' } });
    const joinMsg = await joinPromise;
    const playerId = joinMsg.payload.playerId;

    // Client sends a game message
    const gamePromise = waitForMessage(host, (m) => m.type === 'submit_emoji');
    send(client, { type: 'submit_emoji', payload: { emojiString: '🎬🧙‍♂️' } });
    const gameMsg = await gamePromise;

    assert.equal(gameMsg.type, 'submit_emoji');
    assert.equal(gameMsg.payload.emojiString, '🎬🧙‍♂️');
    assert.equal(gameMsg.from, playerId);
  });

  it('host can broadcast to all clients', async () => {
    const { host, code } = await createHostSession();

    // Two players join
    const joinP1 = waitForMessage(host, (m) => m.type === 'player_join');
    const client1 = await connectAndTrack();
    send(client1, { type: 'player_join', payload: { code, name: 'Alice' } });
    await joinP1;

    const joinP2 = waitForMessage(host, (m) => m.type === 'player_join');
    const client2 = await connectAndTrack();
    send(client2, { type: 'player_join', payload: { code, name: 'Bob' } });
    await joinP2;

    // Host broadcasts
    const msg1Promise = waitForMessage(client1, (m) => m.type === 'game_started');
    const msg2Promise = waitForMessage(client2, (m) => m.type === 'game_started');

    send(host, { type: 'game_started', payload: { phase: 'dealing' }, to: 'all' });

    const [msg1, msg2] = await Promise.all([msg1Promise, msg2Promise]);
    assert.equal(msg1.payload.phase, 'dealing');
    assert.equal(msg2.payload.phase, 'dealing');
    assert.equal(msg1.from, 'host');
  });

  it('host can send targeted message to specific player', async () => {
    const { host, code } = await createHostSession();

    const joinPromise = waitForMessage(host, (m) => m.type === 'player_join');
    const client1 = await connectAndTrack();
    send(client1, { type: 'player_join', payload: { code, name: 'Alice' } });
    const joinMsg = await joinPromise;
    const playerId = joinMsg.payload.playerId;

    // Second player joins but should NOT receive the targeted message
    const joinP2 = waitForMessage(host, (m) => m.type === 'player_join');
    const client2 = await connectAndTrack();
    send(client2, { type: 'player_join', payload: { code, name: 'Bob' } });
    await joinP2;

    const targetPromise = waitForMessage(client1, (m) => m.type === 'phrase_assigned');

    send(host, {
      type: 'phrase_assigned',
      payload: { phrase: { id: '1', text: 'Harry Potter', category: 'movies', difficulty: 'easy' } },
      to: playerId,
    });

    const targetMsg = await targetPromise;
    assert.equal(targetMsg.payload.phrase.text, 'Harry Potter');

    // Verify client2 did NOT receive it (give it a moment)
    let client2Received = false;
    client2.on('message', (raw) => {
      const m = JSON.parse(raw);
      if (m.type === 'phrase_assigned') client2Received = true;
    });
    await new Promise((r) => setTimeout(r, 200));
    assert.equal(client2Received, false);
  });

  it('host disconnect notifies all clients', async () => {
    const { host, code } = await createHostSession();

    const client = await joinAsPlayer(code, 'Alice');
    const disconnPromise = waitForMessage(client, (m) => m.type === 'host_disconnected');

    host.close();
    const msg = await disconnPromise;
    assert.equal(msg.type, 'host_disconnected');
  });

  it('client disconnect notifies host', async () => {
    const { host, code } = await createHostSession();

    const joinPromise = waitForMessage(host, (m) => m.type === 'player_join');
    const client = await connectAndTrack();
    send(client, { type: 'player_join', payload: { code, name: 'Alice' } });
    const joinMsg = await joinPromise;
    const playerId = joinMsg.payload.playerId;

    const disconnPromise = waitForMessage(host, (m) => m.type === 'player_disconnected');
    client.close();
    const msg = await disconnPromise;
    assert.equal(msg.payload.playerId, playerId);
  });
});
