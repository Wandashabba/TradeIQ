import { createServer } from 'http';
import express from 'express';
import request from 'supertest';
import { app as realApp } from '../app';
import { createLoginRateLimiter, createResetRedeemIpRateLimiter } from './rateLimit';

/**
 * The IP-keyed limiters, and the bucket they key into.
 *
 * ## The failure these are written as
 *
 * Both of these limiters used plain `req.ip`. Express leaves `trust proxy` off,
 * so behind Fly's proxy `req.ip` is the proxy — one address for every caller
 * alive. The limiters were therefore not per-caller at all:
 *
 *   - login, at 10 per 15 minutes, was a cap on the WHOLE FLEET. The twelfth
 *     honest sign-in anywhere in any tenant locked everyone out for the rest of
 *     the window. On a product built for shared cheap phones in the field this
 *     is an outage, and it is the first test below.
 *   - reset-password's per-IP backstop, whose whole job is to stop "one guess
 *     each at a thousand accounts", was a single global counter that told you
 *     nothing about who was guessing.
 *
 * So these tests are the outage, not a proxy for it: distinct callers each
 * making ONE request, asserting that none of them is refused.
 *
 * ## And the two traps beside it
 *
 * The obvious fix — `app.set('trust proxy', 1)` — does not work here and the
 * next one along is worse, so both are pinned by tests too: `X-Forwarded-For`
 * must never decide the key, and `Fly-Client-IP` must be ignored unless we are
 * genuinely on a Fly Machine. See `lib/clientIp.ts`.
 *
 * ## Shape
 *
 * Tiny explicit limits against a swappable middleware chain, on **one**
 * listening server for the file (#227) — the same shape as
 * rateLimit.password.test.ts, and for the same two reasons: exhausting the real
 * process-wide limiters would 429 whichever suite ran next in this worker, and
 * a `listen(0)` per request is what #227 was about.
 */
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
// Exactly what app.ts does, and the reason these tests can speak to production:
// if this were `1` or `2`, `req.ip` would be decided by X-Forwarded-For and the
// spoofing tests below would be testing a different application.
expressApp.set('trust proxy', false);
expressApp.use(express.json());
expressApp.post('/try', runChain, (_req, res) => {
  res.status(200).json({ ok: true });
});
const app = createServer(expressApp).listen(0);
app.unref();

function using(...limiters: express.RequestHandler[]) {
  chain = limiters;
}

/** Runs on a Fly Machine for the duration of the callback. */
async function onFly<T>(run: () => Promise<T>): Promise<T> {
  const previous = process.env.FLY_APP_NAME;
  process.env.FLY_APP_NAME = 'tradeiq-backend';
  try {
    return await run();
  } finally {
    if (previous === undefined) delete process.env.FLY_APP_NAME;
    else process.env.FLY_APP_NAME = previous;
  }
}

/** One request, claiming to come from `ip` by every header a caller can set. */
function from(ip: string) {
  return request(app).post('/try').set('Fly-Client-IP', ip).send({});
}

describe('IP-keyed limiters key on the caller, not on Fly’s proxy', () => {
  const originalFlyApp = process.env.FLY_APP_NAME;

  beforeEach(() => {
    chain = [];
    delete process.env.FLY_APP_NAME;
  });

  afterAll(() => {
    if (originalFlyApp === undefined) delete process.env.FLY_APP_NAME;
    else process.env.FLY_APP_NAME = originalFlyApp;
  });

  describe('login', () => {
    it('does not lock the whole fleet out when separate agents sign in', async () => {
      // THE REGRESSION. Six agents at six outlets, one sign-in each, against a
      // limit of two. Every one of them must get through: the limit is two per
      // agent, not two per deployment.
      //
      // Before the fix all six shared Fly's proxy address as their key and the
      // third agent onwards got a 429 — for signing in once, because two other
      // people had signed in first.
      await onFly(async () => {
        using(createLoginRateLimiter({ windowMs: 60_000, limit: 2 }));

        const agents = [
          '41.13.0.1',
          '41.13.0.2',
          '105.4.8.9',
          '197.214.1.1',
          '160.119.7.3',
          '102.132.0.4',
        ];

        const statuses = await Promise.all(agents.map(async (ip) => (await from(ip)).status));

        expect(statuses).toEqual([200, 200, 200, 200, 200, 200]);
      });
    });

    it('still stops one caller brute-forcing, and only that caller', async () => {
      // The limiter must not have been defanged into uselessness by the fix:
      // the attacker's own bucket still fills and still 429s, while the agent
      // next to them is untouched.
      await onFly(async () => {
        using(createLoginRateLimiter({ windowMs: 60_000, limit: 2 }));

        expect((await from('198.51.100.7')).status).toBe(200);
        expect((await from('198.51.100.7')).status).toBe(200);

        const blocked = await from('198.51.100.7');
        expect(blocked.status).toBe(429);
        expect(blocked.body).toEqual({
          error: 'Too many login attempts, please try again later',
        });

        expect((await from('198.51.100.8')).status).toBe(200);
      });
    });
  });

  describe('reset-password per-IP backstop', () => {
    it('counts one guess each at many accounts against the guesser, not the fleet', async () => {
      // "One guess each at a thousand accounts" is what this limiter exists to
      // stop (rateLimit.ts). That only means anything if the key is the
      // guesser: one attacker spending their budget must not spend everyone
      // else's with it.
      await onFly(async () => {
        using(createResetRedeemIpRateLimiter({ windowMs: 60_000, limit: 3 }));

        const attacker = '203.0.113.9';
        expect((await from(attacker)).status).toBe(200);
        expect((await from(attacker)).status).toBe(200);
        expect((await from(attacker)).status).toBe(200);
        expect((await from(attacker)).status).toBe(429);

        // An agent who has genuinely forgotten their password, mid-attack.
        expect((await from('41.13.9.9')).status).toBe(200);
      });
    });
  });

  describe('the header is only believed on Fly', () => {
    it('ignores Fly-Client-IP off-platform, where anyone could have written it', async () => {
      // FLY_APP_NAME unset: not a Fly Machine, so `Fly-Client-IP` is just a
      // string a caller typed. Honouring it here would turn every per-IP
      // limiter into a no-op for anyone who read this file — a fresh key per
      // request and an unlimited budget.
      //
      // All three of these are one client on one socket, so all three share a
      // bucket and the third is refused.
      using(createLoginRateLimiter({ windowMs: 60_000, limit: 2 }));

      expect((await from('1.1.1.1')).status).toBe(200);
      expect((await from('2.2.2.2')).status).toBe(200);
      expect((await from('3.3.3.3')).status).toBe(429);
    });

    it('ignores a Fly-Client-IP that is not an address, even on Fly', async () => {
      // Garbage must fall back to the socket, not become a key of its own.
      await onFly(async () => {
        using(createLoginRateLimiter({ windowMs: 60_000, limit: 2 }));

        expect((await from('not-an-ip')).status).toBe(200);
        expect((await from('also-not-an-ip')).status).toBe(200);
        expect((await from('still-not-an-ip')).status).toBe(429);
      });
    });
  });

  describe('X-Forwarded-For never decides the key', () => {
    it.each([
      ['off Fly', false],
      ['on Fly', true],
    ])('ignores a forged X-Forwarded-For (%s)', async (_label, fly) => {
      // The trap this pins shut. `trust proxy: 1` reads the RIGHTMOST entry,
      // which Fly documents as the app's own shared address — a constant, so it
      // would fix nothing. `trust proxy: 2` reads the LEFTMOST, which is
      // whatever the client sent — so an attacker would invent a new address
      // per request and walk past every limiter here.
      //
      // Either setting breaks this test, which is the point of writing it.
      const run = async () => {
        using(createLoginRateLimiter({ windowMs: 60_000, limit: 2 }));

        const forge = (xff: string) =>
          request(app).post('/try').set('X-Forwarded-For', xff).send({});

        expect((await forge('9.9.9.1, 203.0.113.50')).status).toBe(200);
        expect((await forge('9.9.9.2, 203.0.113.51')).status).toBe(200);
        expect((await forge('9.9.9.3, 203.0.113.52')).status).toBe(429);
      };

      if (fly) await onFly(run);
      else await run();
    });

    it('is pinned off on the real app', async () => {
      // Asserted as a setting rather than by behaviour on purpose: proving it
      // by request would mean exhausting the real 10/15min login limiter, which
      // is process-wide and would 429 the next suite in this worker.
      expect(realApp.get('trust proxy')).toBe(false);
    });
  });

  describe('IPv6', () => {
    it('buckets a caller by /56, so they cannot hop addresses within their own subnet', async () => {
      // A residential IPv6 allocation hands out far more addresses than a
      // limiter has patience for. Keying on the full address would let one
      // caller take a new one per request; the library validates for exactly
      // this and would refuse a keyGenerator that skipped the masking.
      await onFly(async () => {
        using(createLoginRateLimiter({ windowMs: 60_000, limit: 2 }));

        expect((await from('2001:db8:aaaa:bb00::1')).status).toBe(200);
        expect((await from('2001:db8:aaaa:bbff::9')).status).toBe(200);
        expect((await from('2001:db8:aaaa:bb12::7')).status).toBe(429);

        // A genuinely different allocation is a genuinely different bucket.
        expect((await from('2001:db8:aaaa:cc00::1')).status).toBe(200);
      });
    });
  });
});
