import { createServer } from 'http';
import express from 'express';
import request from 'supertest';
import type { AuthedRequest } from './auth';
import { createAssistantTenantRateLimiter, createAssistantUserRateLimiter } from './rateLimit';

/** Identity the fake auth layer stamps on the next request. */
let user: { userId: string; role: 'manager'; clientId: string } | undefined;

/** The limiters under test for the current case. Swapped, never re-mounted. */
let chain: express.RequestHandler[] = [];

/**
 * **One listening server for the whole file**, per #227.
 *
 * The obvious shape — build a fresh app-and-server inside each test so it can
 * have its own limiter config — binds an ephemeral port per test and closes it
 * again. Ports linger in TIME_WAIT, and at enough bind/close cycles one gets
 * rebound while a previous connection is still draining, crossing a response
 * into the wrong client. That surfaces somewhere else entirely: an earlier
 * draft of this file made `errorHandler.test.ts` fail intermittently with a 404
 * on a route that can only ever produce a 400 — the exact signature #227
 * documents.
 *
 * So the server is built once and the limiters are swapped through `chain`.
 */
function runChain(req: express.Request, res: express.Response, next: express.NextFunction) {
  let i = 0;
  const step = (err?: unknown): void => {
    if (err) {
      next(err);
      return;
    }
    const handler = chain[i++];
    if (!handler) {
      next();
      return;
    }
    handler(req, res, step);
  };
  step();
}

const expressApp = express();
expressApp.set('trust proxy', false);
expressApp.use((req, _res, next) => {
  (req as AuthedRequest).user = user;
  next();
});
expressApp.get('/chat', runChain, (_req, res) => {
  res.status(200).json({ ok: true });
});
const app = createServer(expressApp).listen(0);
app.unref();

/** Point the single server at a fresh set of limiters for this test. */
function using(...limiters: express.RequestHandler[]) {
  chain = limiters;
}

describe('assistant rate limiting', () => {
  beforeEach(() => {
    user = undefined;
    chain = [];
  });

  describe('per-user', () => {
    it('lets a user through up to the limit, then 429s', async () => {
      using(createAssistantUserRateLimiter({ windowMs: 60_000, limit: 2 }));
      user = { userId: 'user-a', role: 'manager', clientId: 'client-1' };

      expect((await request(app).get('/chat')).status).toBe(200);
      expect((await request(app).get('/chat')).status).toBe(200);
      const blocked = await request(app).get('/chat');
      expect(blocked.status).toBe(429);
      expect(blocked.body.error).toMatch(/slow down/i);
    });

    it('counts each user separately, not the shared IP', async () => {
      // Every request here comes from 127.0.0.1. A field team behind one
      // corporate NAT is the real version of this: an IP-keyed limiter would
      // throttle colleagues for each other's usage.
      using(createAssistantUserRateLimiter({ windowMs: 60_000, limit: 1 }));

      user = { userId: 'user-a', role: 'manager', clientId: 'client-1' };
      expect((await request(app).get('/chat')).status).toBe(200);
      expect((await request(app).get('/chat')).status).toBe(429);

      user = { userId: 'user-b', role: 'manager', clientId: 'client-1' };
      expect((await request(app).get('/chat')).status).toBe(200);
    });
  });

  describe('per-tenant', () => {
    it('bounds a whole organisation, not just one person', async () => {
      // This is the limiter that protects the bill. Three different users, all
      // within their own per-user allowance, still cannot exceed the tenant cap.
      using(createAssistantTenantRateLimiter({ windowMs: 60_000, limit: 2 }));

      user = { userId: 'user-a', role: 'manager', clientId: 'client-1' };
      expect((await request(app).get('/chat')).status).toBe(200);

      user = { userId: 'user-b', role: 'manager', clientId: 'client-1' };
      expect((await request(app).get('/chat')).status).toBe(200);

      user = { userId: 'user-c', role: 'manager', clientId: 'client-1' };
      const blocked = await request(app).get('/chat');
      expect(blocked.status).toBe(429);
      expect(blocked.body.error).toMatch(/organisation/i);
    });

    it('does not let one tenant exhaust another tenant’s budget', async () => {
      using(createAssistantTenantRateLimiter({ windowMs: 60_000, limit: 1 }));

      user = { userId: 'user-a', role: 'manager', clientId: 'client-1' };
      expect((await request(app).get('/chat')).status).toBe(200);
      expect((await request(app).get('/chat')).status).toBe(429);

      user = { userId: 'user-z', role: 'manager', clientId: 'client-2' };
      expect((await request(app).get('/chat')).status).toBe(200);
    });
  });

  describe('both together — the mounted arrangement', () => {
    it('the tenant cap bites even while every user is individually compliant', async () => {
      // The gap the second limiter exists to close: a per-user cap of 5 across
      // forty managers is forty times the traffic, all of it "within limits".
      using(createAssistantUserRateLimiter({ windowMs: 60_000, limit: 5 }),
        createAssistantTenantRateLimiter({ windowMs: 60_000, limit: 2 }),
      );

      user = { userId: 'user-a', role: 'manager', clientId: 'client-1' };
      expect((await request(app).get('/chat')).status).toBe(200);

      user = { userId: 'user-b', role: 'manager', clientId: 'client-1' };
      expect((await request(app).get('/chat')).status).toBe(200);

      user = { userId: 'user-c', role: 'manager', clientId: 'client-1' };
      expect((await request(app).get('/chat')).status).toBe(429);
    });
  });

  describe('failure modes', () => {
    it('collapses an unauthenticated caller onto one strict bucket', async () => {
      // Should be unreachable — these mount after requireAuth. If a mounting
      // mistake ever exposes them, the strictest treatment is the safe default,
      // not a free pass.
      using(createAssistantUserRateLimiter({ windowMs: 60_000, limit: 1 }));
      user = undefined;

      expect((await request(app).get('/chat')).status).toBe(200);
      expect((await request(app).get('/chat')).status).toBe(429);
    });
  });
});
