import { createServer } from 'http';
import express from 'express';
import request from 'supertest';
import { APP_UPDATE_REQUIRED_CODE, appVersionGate, VersionedRequest } from './appVersion';

/**
 * The gate, on its own tiny app (#400).
 *
 * Not on the real one: `MIN_APP_VERSION` is process-wide, and setting it around
 * a test that shares `testHttpServer` would gate every other suite running in
 * the same worker.
 *
 * One listening server for the whole file, per #227 — see testHttpServer.ts for
 * what a per-request `listen(0)`/`close()` cycle does to a run.
 */
const expressApp = express();
// The gate is mounted FIRST here, ahead of /health, on purpose. In app.ts
// /health is declared above it and so never reaches the gate at all — which
// means the middleware's own `/health` exemption would be dead code that no
// test touched, until someone reordered app.ts and discovered it had never
// worked. Mounting it first makes the exemption itself the thing under test.
expressApp.use(appVersionGate);
expressApp.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});
expressApp.get('/thing', (req, res) => {
  res.status(200).json({ ok: true, seen: (req as VersionedRequest).appVersion ?? null });
});
const app = createServer(expressApp).listen(0);
app.unref();

describe('X-App-Version gate (#400)', () => {
  const saved = {
    min: process.env.MIN_APP_VERSION,
    requireHeader: process.env.MIN_APP_VERSION_REQUIRE_HEADER,
  };

  afterEach(() => {
    if (saved.min === undefined) delete process.env.MIN_APP_VERSION;
    else process.env.MIN_APP_VERSION = saved.min;
    if (saved.requireHeader === undefined) delete process.env.MIN_APP_VERSION_REQUIRE_HEADER;
    else process.env.MIN_APP_VERSION_REQUIRE_HEADER = saved.requireHeader;
  });

  describe('with no minimum configured (the default)', () => {
    beforeEach(() => {
      delete process.env.MIN_APP_VERSION;
    });

    it('lets a request with no version header through', async () => {
      const res = await request(app).get('/thing');
      expect(res.status).toBe(200);
      expect(res.body.seen).toBeNull();
    });

    it('records the version it was sent', async () => {
      const res = await request(app).get('/thing').set('X-App-Version', '1.4.2+318');
      expect(res.status).toBe(200);
      expect(res.body.seen).toBe('1.4.2+318');
    });

    it('lets an ancient build through — recording is not refusing', async () => {
      const res = await request(app).get('/thing').set('X-App-Version', '0.0.1');
      expect(res.status).toBe(200);
    });
  });

  describe('with a minimum configured', () => {
    beforeEach(() => {
      process.env.MIN_APP_VERSION = '1.5.0';
      delete process.env.MIN_APP_VERSION_REQUIRE_HEADER;
    });

    it('refuses an older build with 426 and a machine-readable code', async () => {
      const res = await request(app).get('/thing').set('X-App-Version', '1.4.9');
      expect(res.status).toBe(426);
      expect(res.body.code).toBe(APP_UPDATE_REQUIRED_CODE);
      expect(res.body.minimumVersion).toBe('1.5.0');
      expect(typeof res.body.error).toBe('string');
    });

    it('lets the exact minimum through', async () => {
      const res = await request(app).get('/thing').set('X-App-Version', '1.5.0');
      expect(res.status).toBe(200);
    });

    it('lets a newer build through', async () => {
      const res = await request(app).get('/thing').set('X-App-Version', '2.0.0');
      expect(res.status).toBe(200);
    });

    // The whole reason the floor ships off: every build in the field today
    // sends no header, and treating that as "too old" would take the fleet
    // offline the moment an operator set the variable.
    it('lets a header-less request through by default', async () => {
      const res = await request(app).get('/thing');
      expect(res.status).toBe(200);
    });

    it('refuses a header-less request once MIN_APP_VERSION_REQUIRE_HEADER is on', async () => {
      process.env.MIN_APP_VERSION_REQUIRE_HEADER = 'true';
      const res = await request(app).get('/thing');
      expect(res.status).toBe(426);
      expect(res.body.code).toBe(APP_UPDATE_REQUIRED_CODE);
    });

    it('treats an unparseable header the same as none', async () => {
      const res = await request(app).get('/thing').set('X-App-Version', 'latest');
      expect(res.status).toBe(200);
      process.env.MIN_APP_VERSION_REQUIRE_HEADER = 'true';
      const strict = await request(app).get('/thing').set('X-App-Version', 'latest');
      expect(strict.status).toBe(426);
    });

    // An ops probe is not an app build. A load balancer pulling every instance
    // out of rotation because of an app-version setting would be an outage of
    // our own making.
    it('never gates /health', async () => {
      process.env.MIN_APP_VERSION_REQUIRE_HEADER = 'true';
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
    });

    it('bounds what it keeps from an attacker-controlled header', async () => {
      const res = await request(app)
        .get('/thing')
        .set('X-App-Version', `1.5.0+${'9'.repeat(500)}`);
      expect(res.status).toBe(200);
      expect(res.body.seen.length).toBeLessThanOrEqual(64);
    });
  });

  // Fail open, loudly. A typo in an env var must not lock every agent out of
  // the product: the failure mode of the safe direction is a gate that is not
  // enforcing, which is exactly where the system was yesterday.
  it('does not enforce — and warns — when MIN_APP_VERSION is unparseable', async () => {
    process.env.MIN_APP_VERSION = 'nonsense';
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
    try {
      const res = await request(app).get('/thing').set('X-App-Version', '0.0.1');
      expect(res.status).toBe(200);
      expect(warn).toHaveBeenCalled();
    } finally {
      warn.mockRestore();
    }
  });
});
