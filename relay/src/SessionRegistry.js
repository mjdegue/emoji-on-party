import { randomBytes } from 'node:crypto';

const CODE_LENGTH = 6;
const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1 to avoid confusion

export class SessionRegistry {
  constructor() {
    this.sessions = new Map();  // code → Session
  }

  generateCode() {
    for (let attempt = 0; attempt < 100; attempt++) {
      const bytes = randomBytes(CODE_LENGTH);
      let code = '';
      for (let i = 0; i < CODE_LENGTH; i++) {
        code += CODE_CHARS[bytes[i] % CODE_CHARS.length];
      }
      if (!this.sessions.has(code)) return code;
    }
    throw new Error('Failed to generate unique session code');
  }

  createSession(hostWs) {
    const code = this.generateCode();
    const session = {
      code,
      host: hostWs,
      clients: new Map(), // playerId → ws
      createdAt: Date.now(),
    };
    this.sessions.set(code, session);
    return code;
  }

  getSession(code) {
    return this.sessions.get(code) ?? null;
  }

  addClient(code, playerId, ws) {
    const session = this.sessions.get(code);
    if (!session) return false;
    session.clients.set(playerId, ws);
    return true;
  }

  removeClient(code, playerId) {
    const session = this.sessions.get(code);
    if (!session) return;
    session.clients.delete(playerId);
  }

  removeSession(code) {
    this.sessions.delete(code);
  }

  findSessionByHost(hostWs) {
    for (const [code, session] of this.sessions) {
      if (session.host === hostWs) return session;
    }
    return null;
  }

  findSessionByClient(clientWs) {
    for (const [code, session] of this.sessions) {
      for (const [playerId, ws] of session.clients) {
        if (ws === clientWs) return { session, playerId };
      }
    }
    return null;
  }

  cleanupStaleSessions(maxAgeMs = 24 * 60 * 60 * 1000) {
    const now = Date.now();
    let removed = 0;
    for (const [code, session] of this.sessions) {
      if (now - session.createdAt > maxAgeMs) {
        this.sessions.delete(code);
        removed++;
      }
    }
    return removed;
  }

  get size() {
    return this.sessions.size;
  }
}
