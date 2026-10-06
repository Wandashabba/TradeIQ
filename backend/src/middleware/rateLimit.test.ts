import express from 'express';
import request from 'supertest';
import { createLoginRateLimiter } from './rateLimit';

describe('login rate limiter', () => {
  /** A route that refuses, the way a wrong password does. */
  function refusingApp(limit: number) {
    const app = express();
    app.post('/login', createLoginRateLimiter({ limit }), (_req, res) => {
      res.status(401).json({ error: 'Invalid credentials' });
    });
    return app;
  }

  it('allows attempts up to the limit then responds 429', async () => {
    // Driven with REFUSED attempts because the limiter counts failures and not
    // sign-ins: a route that always answered 200 would never fill the bucket,
    // and this test would pass while asserting nothing.
    const app = refusingApp(2);

    expect((await request(app).post('/login')).status).toBe(401);
    expect((await request(app).post('/login')).status).toBe(401);

    const blocked = await request(app).post('/login');
    expect(blocked.status).toBe(429);
    expect(blocked.body).toEqual({ error: 'Too many login attempts, please try again later' });
  });

  it('does not spend the budget on sign-ins that work', async () => {
    // The complaint this answers: ten honest sign-ins in a quarter of an hour
    // used to lock a person out of their own account.
    const app = express();
    app.post('/login', createLoginRateLimiter({ limit: 2 }), (_req, res) => {
      res.status(200).json({ ok: true });
    });

    for (let i = 0; i < 6; i += 1) {
      expect((await request(app).post('/login')).status).toBe(200);
    }
  });
});
