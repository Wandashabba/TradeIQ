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

describe('CORS policy by environment', () => {
  const originalEnv = { ...process.env };

  afterEach(() => {
    process.env = { ...originalEnv };
    jest.resetModules();
  });

  /** Reloads app.ts so the module-level CORS decision is re-evaluated. */
  async function appWith(env: Record<string, string | undefined>) {
    jest.resetModules();
    for (const [key, value] of Object.entries(env)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    const mod: { app: import('express').Express } = await import('./app');
    return mod.app;
  }

  it('refuses cross-origin browser requests in production when CORS_ORIGINS is unset', async () => {
    // The regression this guards. The fallback used to key off the variable
    // being absent, so a production deploy that never set it got the OPEN
    // policy — which is exactly what the live backend was running.
    const prodApp = await appWith({ NODE_ENV: 'production', CORS_ORIGINS: undefined });

    const res = await request(prodApp)
      .get('/health')
      .set('Origin', 'https://evil.example');

    expect(res.status).toBe(200);
    expect(res.headers['access-control-allow-origin']).toBeUndefined();
  });

  it('still serves native clients in production, which send no Origin', async () => {
    // Why this fails closed rather than throwing: the mobile app sends no
    // Origin header, so a restrictive policy costs it nothing. Refusing to
    // boot would take down a working API over a setting none of its current
    // callers use.
    const prodApp = await appWith({ NODE_ENV: 'production', CORS_ORIGINS: undefined });

    const res = await request(prodApp).get('/health');

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('honours an explicit allowlist in production', async () => {
    const prodApp = await appWith({
      NODE_ENV: 'production',
      CORS_ORIGINS: 'https://console.tradeiq.example',
    });

    const allowed = await request(prodApp)
      .get('/health')
      .set('Origin', 'https://console.tradeiq.example');
    expect(allowed.headers['access-control-allow-origin']).toBe(
      'https://console.tradeiq.example',
    );

    const refused = await request(prodApp)
      .get('/health')
      .set('Origin', 'https://evil.example');
    expect(refused.headers['access-control-allow-origin']).toBeUndefined();
  });

  it('keeps the open policy outside production', async () => {
    // `flutter run -d chrome` picks a port dynamically, so there is no fixed
    // dev origin to allowlist. That convenience is the whole reason the
    // fallback exists — it just must not reach production.
    const devApp = await appWith({ NODE_ENV: 'development', CORS_ORIGINS: undefined });

    const res = await request(devApp)
      .get('/health')
      .set('Origin', 'http://localhost:53421');

    expect(res.headers['access-control-allow-origin']).toBeDefined();
  });
});
