import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';

/**
 * #67 — device registration and notification preferences. The user and tenant
 * come from the token only; a token is one install, re-pointed when the phone
 * changes hands; and sign-out can only ever remove the caller's own device.
 */
describe('push routes (#67)', () => {
  let clientId: string;
  let agent: TestUser;
  let manager: TestUser;
  let foreign: Awaited<ReturnType<typeof foreignTenant>>;
  let counter = 0;
  const newToken = () => `fcm-routes-${Date.now()}-${++counter}:APA91b_x-y`;

  const register = (user: TestUser, body: object) =>
    request(app).post('/push/devices').set('Authorization', `Bearer ${user.token}`).send(body);
  const unregister = (user: TestUser, token: string) =>
    request(app)
      .delete(`/push/devices/${encodeURIComponent(token)}`)
      .set('Authorization', `Bearer ${user.token}`);
  const prefs = (user: TestUser) =>
    request(app).get('/push/preferences').set('Authorization', `Bearer ${user.token}`);
  const patchPrefs = (user: TestUser, body: unknown) =>
    request(app)
      .patch('/push/preferences')
      .set('Authorization', `Bearer ${user.token}`)
      .send(body as object);

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'PUSH-Routes', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    agent = await userIn(clientId, 'field_agent');
    manager = await userIn(clientId, 'manager');
    foreign = await foreignTenant('manager');
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
  });

  describe('POST /push/devices', () => {
    it('requires authentication', async () => {
      const res = await request(app).post('/push/devices').send({ token: 't', platform: 'android' });
      expect(res.status).toBe(401);
    });

    it('registers a token to the caller and tenant from the auth token', async () => {
      const token = newToken();
      const res = await register(agent, {
        token,
        platform: 'android',
        // Ignored: identity never comes from the body.
        userId: manager.userId,
        clientId: foreign.clientId,
      });
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ platform: 'android', lastSeenAt: expect.any(String) });

      const row = await prisma.deviceToken.findUniqueOrThrow({ where: { token } });
      expect(row).toMatchObject({ userId: agent.userId, clientId, platform: 'android' });
    });

    it('is idempotent: the same token again refreshes lastSeenAt and adds no row', async () => {
      const token = newToken();
      const first = await register(agent, { token, platform: 'ios' });
      await new Promise((r) => setTimeout(r, 5));
      const second = await register(agent, { token, platform: 'ios' });
      expect(second.status).toBe(200);
      expect(new Date(second.body.lastSeenAt).getTime()).toBeGreaterThan(
        new Date(first.body.lastSeenAt).getTime(),
      );
      expect(await prisma.deviceToken.count({ where: { token } })).toBe(1);
    });

    it('re-points a token to whoever registers it next, even across tenants', async () => {
      const token = newToken();
      await register(agent, { token, platform: 'android' });

      await register(manager, { token, platform: 'android' });
      expect(await prisma.deviceToken.findUniqueOrThrow({ where: { token } })).toMatchObject({
        userId: manager.userId,
        clientId,
      });

      await register(foreign, { token, platform: 'web' });
      expect(await prisma.deviceToken.findUniqueOrThrow({ where: { token } })).toMatchObject({
        userId: foreign.userId,
        clientId: foreign.clientId,
        platform: 'web',
      });
      expect(await prisma.deviceToken.count({ where: { token } })).toBe(1);
    });

    it.each([
      [{ platform: 'android' }],
      [{ token: '', platform: 'android' }],
      [{ token: 'has space', platform: 'android' }],
      [{ token: 'x'.repeat(4097), platform: 'android' }],
      [{ token: 'ok-token', platform: 'windows' }],
      [{ token: 42, platform: 'android' }],
    ])('rejects %j with 400', async (body) => {
      const res = await register(agent, body);
      expect(res.status).toBe(400);
    });
  });

  describe('DELETE /push/devices/:token', () => {
    it("removes the caller's own token", async () => {
      const token = newToken();
      await register(agent, { token, platform: 'android' });
      const res = await unregister(agent, token);
      expect(res.status).toBe(204);
      expect(await prisma.deviceToken.count({ where: { token } })).toBe(0);
    });

    it("never removes someone else's token (the phone was re-registered)", async () => {
      const token = newToken();
      await register(manager, { token, platform: 'android' });

      expect((await unregister(agent, token)).status).toBe(204);
      expect((await unregister(foreign, token)).status).toBe(204);
      expect(await prisma.deviceToken.count({ where: { token } })).toBe(1);
    });

    it('answers 204 for a token that does not exist', async () => {
      expect((await unregister(agent, newToken())).status).toBe(204);
    });
  });

  describe('/push/preferences', () => {
    it('defaults every category to on', async () => {
      const res = await prefs(agent);
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ alerts: true, tasks: true, messages: true, sla: true });
    });

    it('updates only the categories sent, and returns the whole set', async () => {
      const res = await patchPrefs(agent, { tasks: false, sla: false });
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ alerts: true, tasks: false, messages: true, sla: false });

      const again = await patchPrefs(agent, { tasks: true });
      expect(again.body).toEqual({ alerts: true, tasks: true, messages: true, sla: false });
      expect((await prefs(agent)).body).toEqual(again.body);
      expect(
        await prisma.notificationPreference.findMany({
          where: { userId: agent.userId },
          select: { clientId: true },
        }),
      ).toEqual([{ clientId }, { clientId }]);
    });

    it("is per user: one user's choices never change another's", async () => {
      await patchPrefs(manager, { messages: false });
      expect((await prefs(foreign)).body).toEqual({
        alerts: true,
        tasks: true,
        messages: true,
        sla: true,
      });
      expect((await prefs(manager)).body.messages).toBe(false);
    });

    it.each([[{}], [{ push: true }], [{ alerts: 'no' }], [{ alerts: true, extra: false }], [[true]]])(
      'rejects %j with 400',
      async (body) => {
        expect((await patchPrefs(agent, body)).status).toBe(400);
      },
    );
  });
});
