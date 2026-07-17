import request from 'supertest';
import { app } from './app';

describe('GET /health', () => {
  it('returns 200 with status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('sets CORS headers so the Flutter web app can call the API cross-origin', async () => {
    const res = await request(app).get('/health').set('Origin', 'http://localhost:8766');
    expect(res.headers['access-control-allow-origin']).toBeDefined();
  });

  it('sets baseline security headers via helmet', async () => {
    const res = await request(app).get('/health');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });

  it('answers 404 — not 401 — for an unknown route', async () => {
    const res = await request(app).get('/definitely-not-a-real-route');
    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: 'Not found' });
  });

  it('still answers 401 for a real protected route with no token', async () => {
    const res = await request(app).get('/outlets');
    expect(res.status).toBe(401);
  });
});
