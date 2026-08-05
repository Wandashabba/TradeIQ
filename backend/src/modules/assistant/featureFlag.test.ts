import { createServer } from 'http';
import express from 'express';
import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { errorHandler } from '../../middleware/errorHandler';
import type { AuthedRequest } from '../../middleware/auth';
import { isAssistantEnabled, requireAssistantEnabled } from './featureFlag';

// A stand-in for requireAuth so these tests exercise the flag rather than the
// JWT path. `user` is mutated per test to move the caller between tenants.
let user: { userId: string; role: 'manager'; clientId: string } | undefined;

const expressApp = express();
expressApp.use((req, _res, next) => {
  (req as AuthedRequest).user = user;
  next();
});
expressApp.get('/assistant/ping', requireAssistantEnabled, (_req, res) => {
  res.status(200).json({ ok: true });
});
expressApp.use(errorHandler);
const app = createServer(expressApp).listen(0);
app.unref();

describe('assistant feature flag', () => {
  let onClientId: string;
  let offClientId: string;

  beforeAll(async () => {
    const on = await prisma.client.create({
      data: {
        name: 'FLAG-Client-On',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
        assistantEnabled: true,
      },
    });
    onClientId = on.id;

    const off = await prisma.client.create({
      data: { name: 'FLAG-Client-Off', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    offClientId = off.id;
  });

  afterAll(async () => {
    await prisma.client.deleteMany({ where: { id: { in: [onClientId, offClientId] } } });
    await prisma.$disconnect();
  });

  beforeEach(() => {
    user = undefined;
  });

  describe('isAssistantEnabled', () => {
    it('is false by default — a client nobody has considered is not in the rollout', () => {
      return expect(isAssistantEnabled(offClientId)).resolves.toBe(false);
    });

    it('is true once switched on', () => {
      return expect(isAssistantEnabled(onClientId)).resolves.toBe(true);
    });

    it('is false for a client that does not exist', () => {
      return expect(isAssistantEnabled('no-such-client')).resolves.toBe(false);
    });
  });

  describe('requireAssistantEnabled', () => {
    it('lets an enabled tenant through', async () => {
      user = { userId: 'u1', role: 'manager', clientId: onClientId };
      const res = await request(app).get('/assistant/ping');
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ ok: true });
    });

    it('answers 404, not 403, for a tenant outside the rollout', async () => {
      // 403 would concede the feature exists and that this tenant merely is not
      // entitled to it — an invitation to keep probing. 404 also makes the kill
      // switch indistinguishable from the feature never having shipped.
      user = { userId: 'u1', role: 'manager', clientId: offClientId };
      const res = await request(app).get('/assistant/ping');
      expect(res.status).toBe(404);
      expect(res.body.error).toBe('Not found');
    });

    it('does not leak the flag to an unauthenticated caller', async () => {
      user = undefined;
      const res = await request(app).get('/assistant/ping');
      expect(res.status).toBe(401);
    });

    it('is not fooled by a client id that does not exist', async () => {
      user = { userId: 'u1', role: 'manager', clientId: 'no-such-client' };
      const res = await request(app).get('/assistant/ping');
      expect(res.status).toBe(404);
    });

    it('fails closed when the database is unreachable', async () => {
      // The dangerous direction is defaulting a metered feature open on an
      // infrastructure blip. A 500 is correct; a 200 would be a spend incident.
      const spy = jest
        .spyOn(prisma.client, 'findUnique')
        .mockRejectedValueOnce(new Error('connection lost'));
      user = { userId: 'u1', role: 'manager', clientId: onClientId };

      const res = await request(app).get('/assistant/ping');
      expect(res.status).toBe(500);
      spy.mockRestore();
    });
  });
});
