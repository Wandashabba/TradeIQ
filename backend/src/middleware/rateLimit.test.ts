import express from 'express';
import request from 'supertest';
import { createLoginRateLimiter } from './rateLimit';

describe('login rate limiter', () => {
  it('allows requests up to the limit then responds 429', async () => {
    const app = express();
    app.post('/login', createLoginRateLimiter({ limit: 2 }), (_req, res) => {
      res.status(200).json({ ok: true });
    });

    expect((await request(app).post('/login')).status).toBe(200);
    expect((await request(app).post('/login')).status).toBe(200);

    const blocked = await request(app).post('/login');
    expect(blocked.status).toBe(429);
    expect(blocked.body).toEqual({ error: 'Too many login attempts, please try again later' });
  });
});
