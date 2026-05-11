import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { SessionRegistry } from './SessionRegistry.js';

describe('SessionRegistry', () => {
  let registry;
  const fakeWs = (id = 'ws1') => ({ id, readyState: 1, OPEN: 1 });

  beforeEach(() => {
    registry = new SessionRegistry();
  });

  describe('createSession', () => {
    it('creates a session and returns a 6-char code', () => {
      const code = registry.createSession(fakeWs());
      assert.equal(code.length, 6);
      assert.equal(registry.size, 1);
    });

    it('generates unique codes', () => {
      const codes = new Set();
      for (let i = 0; i < 50; i++) {
        codes.add(registry.createSession(fakeWs(`ws${i}`)));
      }
      assert.equal(codes.size, 50);
    });

    it('code uses only unambiguous characters', () => {
      const code = registry.createSession(fakeWs());
      assert.match(code, /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]+$/);
    });
  });

  describe('getSession', () => {
    it('returns session by code', () => {
      const host = fakeWs();
      const code = registry.createSession(host);
      const session = registry.getSession(code);
      assert.equal(session.host, host);
      assert.equal(session.code, code);
    });

    it('returns null for unknown code', () => {
      assert.equal(registry.getSession('XXXXXX'), null);
    });
  });

  describe('addClient / removeClient', () => {
    it('adds a client to a session', () => {
      const code = registry.createSession(fakeWs());
      const client = fakeWs('client1');
      assert.equal(registry.addClient(code, 'player1', client), true);

      const session = registry.getSession(code);
      assert.equal(session.clients.get('player1'), client);
    });

    it('returns false for unknown session', () => {
      assert.equal(registry.addClient('XXXXXX', 'p1', fakeWs()), false);
    });

    it('removes a client', () => {
      const code = registry.createSession(fakeWs());
      registry.addClient(code, 'p1', fakeWs('c1'));
      registry.removeClient(code, 'p1');

      const session = registry.getSession(code);
      assert.equal(session.clients.size, 0);
    });
  });

  describe('findSessionByHost', () => {
    it('finds session by host ws reference', () => {
      const host = fakeWs();
      const code = registry.createSession(host);
      const session = registry.findSessionByHost(host);
      assert.equal(session.code, code);
    });

    it('returns null for unrecognized ws', () => {
      assert.equal(registry.findSessionByHost(fakeWs('unknown')), null);
    });
  });

  describe('findSessionByClient', () => {
    it('finds session and playerId by client ws', () => {
      const code = registry.createSession(fakeWs());
      const client = fakeWs('c1');
      registry.addClient(code, 'player1', client);

      const result = registry.findSessionByClient(client);
      assert.equal(result.session.code, code);
      assert.equal(result.playerId, 'player1');
    });

    it('returns null for unrecognized ws', () => {
      assert.equal(registry.findSessionByClient(fakeWs('unknown')), null);
    });
  });

  describe('removeSession', () => {
    it('removes a session entirely', () => {
      const code = registry.createSession(fakeWs());
      registry.removeSession(code);
      assert.equal(registry.size, 0);
      assert.equal(registry.getSession(code), null);
    });
  });

  describe('cleanupStaleSessions', () => {
    it('removes sessions older than maxAge', () => {
      const code = registry.createSession(fakeWs());
      const session = registry.getSession(code);
      session.createdAt = Date.now() - 2 * 60 * 60 * 1000; // 2 hours ago

      const removed = registry.cleanupStaleSessions(60 * 60 * 1000); // 1 hour max
      assert.equal(removed, 1);
      assert.equal(registry.size, 0);
    });

    it('keeps fresh sessions', () => {
      registry.createSession(fakeWs());
      const removed = registry.cleanupStaleSessions(60 * 60 * 1000);
      assert.equal(removed, 0);
      assert.equal(registry.size, 1);
    });
  });
});
