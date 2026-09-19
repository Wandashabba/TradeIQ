import { createServer } from 'http';
import express from 'express';
import request from 'supertest';
import type { AuthedRequest } from './auth';
import {
  createChangePasswordRateLimiter,
  createResetCodeIssueRateLimiter,
  createResetRedeemEmailRateLimiter,
  createResetRedeemIpRateLimiter,
} from './rateLimit';

/**
 * The password limiters, built with tiny explicit limits (#400).
 *
 * Exercised here rather than in password.routes.test.ts on purpose: proving a
 * limiter by exhausting the real one would spend the shared process-wide budget
 * and 429 whichever suite ran next in the same worker.
 *
 * **One listening server for the whole file**, per #227 — see
 * rateLimit.assistant.test.ts, whose shape this follows, for what a
 * per-test `listen(0)`/`close()` cycle does to a run.
 */
let user: { userId: string; role: 'manager'; clientId: string } | undefined;
let chain: express.RequestHandler[] = [];

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
expressApp.use(express.json());
expressApp.use((req, _res, next) => {
  (req as AuthedRequest).user = user;
  next();
});
expressApp.post('/try', runChain, (_req, res) => {
  res.status(200).json({ ok: true });
});
const app = createServer(expressApp).listen(0);
app.unref();

function using(...limiters: express.RequestHandler[]) {
  chain = limiters;
}

describe('password rate limiting (#400)', () => {
  beforeEach(() => {
    user = undefined;
    chain = [];
  });

  describe('change-password, keyed on the user', () => {
    it('lets a user through up to the limit, then 429s', async () => {
      using(createChangePasswordRateLimiter({ windowMs: 60_000, limit: 2 }));
      user = { userId: 'cp-a', role: 'manager', clientId: 'c1' };

      expect((await request(app).post('/try').send({})).status).toBe(200);
      expect((await request(app).post('/try').send({})).status).toBe(200);
      const blocked = await request(app).post('/try').send({});
      expect(blocked.status).toBe(429);
      expect(blocked.body.error).toMatch(/password change/i);
    });

    // A depot's whole field team shares one NAT. Keying on IP would throttle
    // colleagues for each other's password changes while an attacker holding a
    // stolen token, on their own connection, would be unaffected.
    it('gives a second user their own budget', async () => {
      const limiter = createChangePasswordRateLimiter({ windowMs: 60_000, limit: 1 });
      using(limiter);

      user = { userId: 'cp-b', role: 'manager', clientId: 'c1' };
      expect((await request(app).post('/try').send({})).status).toBe(200);
      expect((await request(app).post('/try').send({})).status).toBe(429);

      user = { userId: 'cp-c', role: 'manager', clientId: 'c1' };
      expect((await request(app).post('/try').send({})).status).toBe(200);
    });
  });

  describe('reset-code issuing, keyed on the manager', () => {
    it('bounds one identity minting codes for the whole tenant', async () => {
      using(createResetCodeIssueRateLimiter({ windowMs: 60_000, limit: 1 }));
      user = { userId: 'issue-a', role: 'manager', clientId: 'c1' };

      expect((await request(app).post('/try').send({})).status).toBe(200);
      const blocked = await request(app).post('/try').send({});
      expect(blocked.status).toBe(429);
      expect(blocked.body.error).toMatch(/reset codes/i);
    });
  });

  describe('reset redemption, keyed on the email in the body', () => {
    it('bounds guessing at one named account', async () => {
      using(createResetRedeemEmailRateLimiter({ windowMs: 60_000, limit: 2 }));

      const attempt = () => request(app).post('/try').send({ email: 'agent@example.test' });
      expect((await attempt()).status).toBe(200);
      expect((await attempt()).status).toBe(200);
      expect((await attempt()).status).toBe(429);

      // A different account is a different bucket.
      const other = await request(app).post('/try').send({ email: 'someone-else@example.test' });
      expect(other.status).toBe(200);
    });

    // Two spellings of one address must not be two budgets, or the limit is
    // worth double to anyone who notices.
    it('normalises the email before keying', async () => {
      using(createResetRedeemEmailRateLimiter({ windowMs: 60_000, limit: 1 }));

      expect((await request(app).post('/try').send({ email: 'a@b.test' })).status).toBe(200);
      const shouted = await request(app).post('/try').send({ email: '  A@B.TEST  ' });
      expect(shouted.status).toBe(429);
    });

    // The limiter runs BEFORE any database lookup, so it cannot itself become
    // the enumeration oracle the endpoint is careful not to be: a 429 is the
    // same answer whether or not the address exists.
    it('throttles an address that matches nobody exactly the same way', async () => {
      using(createResetRedeemEmailRateLimiter({ windowMs: 60_000, limit: 1 }));

      expect((await request(app).post('/try').send({ email: 'ghost@nowhere.test' })).status).toBe(200);
      expect((await request(app).post('/try').send({ email: 'ghost@nowhere.test' })).status).toBe(429);
    });

    it('falls back to one shared bucket when no email is given', async () => {
      using(createResetRedeemEmailRateLimiter({ windowMs: 60_000, limit: 1 }));

      expect((await request(app).post('/try').send({})).status).toBe(200);
      expect((await request(app).post('/try').send({ email: 42 })).status).toBe(429);
    });
  });

  describe('reset redemption, keyed on IP', () => {
    // The companion to the per-email limiter: that one stops a thousand guesses
    // at one account, this one stops one guess each at a thousand accounts.
    it('429s regardless of which account each attempt names', async () => {
      using(createResetRedeemIpRateLimiter({ windowMs: 60_000, limit: 2 }));

      expect((await request(app).post('/try').send({ email: 'one@x.test' })).status).toBe(200);
      expect((await request(app).post('/try').send({ email: 'two@x.test' })).status).toBe(200);
      expect((await request(app).post('/try').send({ email: 'three@x.test' })).status).toBe(429);
    });
  });
});
