import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { RecordingPushSender } from '../../test-utils/pushSender';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';
import { settleInFlightPushes } from './push.notify';
import { NoopPushSender, setPushSender } from './push.sender';
import { registerDeviceToken, updateNotificationPreferences } from './push.service';

/**
 * #67 — each existing event raises a push to the right people, through the real
 * routes, with a recording sender in place of FCM.
 */
describe('push triggers (#67)', () => {
  const sender = new RecordingPushSender();
  let clientId: string;
  let manager: TestUser;
  let admin: TestUser;
  let agentA: TestUser;
  let agentB: TestUser;
  let foreign: Awaited<ReturnType<typeof foreignTenant>>;
  let outletId: string;
  const tok = (user: TestUser) => `trigger-${user.userId}`;
  const auth = (user: TestUser) => ({ Authorization: `Bearer ${user.token}` });
  /** Settled pushes, as `{token: route}` for the tokens of `users`. */
  const routesFor = async (...users: TestUser[]) => {
    await settleInFlightPushes();
    return Object.fromEntries(sender.to(...users.map(tok)).map((m) => [m.token, m.data.route]));
  };

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'PUSH-Triggers', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    manager = await userIn(clientId, 'manager');
    admin = await userIn(clientId, 'admin');
    agentA = await userIn(clientId, 'field_agent');
    agentB = await userIn(clientId, 'field_agent');
    foreign = await foreignTenant('manager');
    for (const user of [manager, admin, agentA, agentB, foreign]) {
      await registerDeviceToken({ userId: user.userId, clientId: user.clientId, platform: 'android', token: tok(user) });
    }
    const outlet = await prisma.outlet.create({
      data: {
        name: 'Spar Rosebank',
        code: `PUSH-${Date.now()}`,
        channelType: 'supermarket',
        lat: -26.14,
        lng: 28.04,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;
  });

  beforeEach(() => {
    sender.reset();
    setPushSender(sender);
  });

  afterAll(async () => {
    await settleInFlightPushes();
    setPushSender(null);
    await prisma.alert.deleteMany({ where: { clientId } });
    await prisma.alertRule.deleteMany({ where: { clientId } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId } } });
    await prisma.task.deleteMany({ where: { outletId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.announcement.deleteMany({ where: { clientId } });
    await prisma.message.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
  });

  describe('alert.raised', () => {
    it("pushes to the tenant's managers and admins, not agents or other tenants", async () => {
      const visit = await prisma.visit.create({
        data: {
          outletId,
          agentId: agentA.userId,
          clientId,
          checkinTs: new Date(),
          checkinLat: -26.14,
          checkinLng: 28.04,
          geofencePass: true,
          status: 'submitted',
        },
      });
      const sku = await prisma.sku.create({
        data: { clientId, name: 'PUSH SKU', category: 'beverage', minFacingsStandard: 1, rrp: 10 },
      });
      await prisma.visitStock.create({
        data: {
          visitId: visit.id,
          skuId: sku.id,
          unitsAvailable: 0,
          lastStockinDate: new Date(),
          daysOutOfStock: 1,
          velocityAvg: 1,
          coverageDaysPredicted: 0,
        },
      });
      await prisma.alertRule.create({ data: { clientId, name: 'OOS', metric: 'out_of_stock' } });

      const res = await request(app).post('/alerts/evaluate').set(auth(manager)).send({ visitId: visit.id });
      expect(res.status).toBe(201);
      expect(res.body.created).toHaveLength(1);

      expect(await routesFor(manager, admin, agentA, agentB, foreign)).toEqual({
        [tok(manager)]: '/alerts',
        [tok(admin)]: '/alerts',
      });
      const [push] = sender.to(tok(manager));
      expect(push.title).toBe('Alert at Spar Rosebank');
      expect(push.body).toBe(`SKU ${sku.id} is out of stock`);
      expect(push.data.category).toBe('alerts');
    });
  });

  describe('task assigned', () => {
    const task = (ownerId?: string) => ({
      outletId,
      findingType: 'stockout',
      requiredFix: 'Restock the chiller',
      priority: 'critical',
      ...(ownerId ? { ownerId } : {}),
    });

    it('pushes to the assignee, routed to the agent app', async () => {
      const res = await request(app).post('/tasks').set(auth(manager)).send(task(agentA.userId));
      expect(res.status).toBe(201);
      expect(await routesFor(manager, admin, agentA, agentB)).toEqual({ [tok(agentA)]: '/today' });
      expect(sender.to(tok(agentA))[0]).toMatchObject({
        title: 'Critical task assigned to you',
        body: 'Spar Rosebank: Restock the chiller',
        data: { category: 'tasks' },
      });
    });

    it('routes a manager assignee to the console task list', async () => {
      await request(app).post('/tasks').set(auth(agentA)).send({ ...task(manager.userId), priority: 'normal' });
      expect(await routesFor(manager, agentA)).toEqual({ [tok(manager)]: '/tasks' });
      expect(sender.to(tok(manager))[0].title).toBe('New task assigned to you');
    });

    it('raises nothing for a task the caller assigned to themselves', async () => {
      const res = await request(app).post('/tasks').set(auth(agentA)).send(task());
      expect(res.status).toBe(201);
      await settleInFlightPushes();
      expect(sender.batches).toEqual([]);
    });

    it("respects the assignee's tasks preference", async () => {
      await updateNotificationPreferences({ userId: agentB.userId, clientId, changes: { tasks: false } });
      await request(app).post('/tasks').set(auth(manager)).send(task(agentB.userId));
      await settleInFlightPushes();
      expect(sender.batches).toEqual([]);
      await updateNotificationPreferences({ userId: agentB.userId, clientId, changes: { tasks: true } });
    });
  });

  describe('messages and announcements', () => {
    it('pushes a direct message to its recipient only', async () => {
      const res = await request(app)
        .post('/messages')
        .set(auth(agentA))
        .send({ body: 'Chiller is\nbroken again', recipientId: agentB.userId, clientMessageId: `m-${Date.now()}` });
      expect(res.status).toBe(201);
      expect(await routesFor(manager, admin, agentA, agentB, foreign)).toEqual({ [tok(agentB)]: '/messages' });
      expect(sender.to(tok(agentB))[0]).toMatchObject({
        title: 'New message',
        body: 'Chiller is broken again',
        data: { category: 'messages' },
      });
    });

    it('does not push again when a send is replayed', async () => {
      const body = { body: 'Once only', recipientId: agentB.userId, clientMessageId: `replay-${Date.now()}` };
      await request(app).post('/messages').set(auth(agentA)).send(body);
      await settleInFlightPushes();
      sender.reset();
      const replay = await request(app).post('/messages').set(auth(agentA)).send(body);
      expect(replay.status).toBe(200);
      await settleInFlightPushes();
      expect(sender.batches).toEqual([]);
    });

    it('pushes a broadcast to everyone in the tenant but the sender, respecting preferences', async () => {
      await updateNotificationPreferences({ userId: admin.userId, clientId, changes: { messages: false } });
      const res = await request(app).post('/messages').set(auth(manager)).send({ body: 'Team huddle at 3' });
      expect(res.status).toBe(201);
      expect(await routesFor(manager, admin, agentA, agentB, foreign)).toEqual({
        [tok(agentA)]: '/messages',
        [tok(agentB)]: '/messages',
      });
      expect(sender.to(tok(agentA))[0].title).toBe('New team message');
      await updateNotificationPreferences({ userId: admin.userId, clientId, changes: { messages: true } });
    });

    it('pushes an announcement to everyone in the tenant but its author', async () => {
      const res = await request(app)
        .post('/announcements')
        .set(auth(admin))
        .send({ title: 'Price change', body: 'New RRPs from Monday' });
      expect(res.status).toBe(201);
      expect(await routesFor(manager, admin, agentA, agentB, foreign)).toEqual({
        [tok(manager)]: '/messages',
        [tok(agentA)]: '/messages',
        [tok(agentB)]: '/messages',
      });
      expect(sender.to(tok(agentA))[0]).toMatchObject({
        title: 'Announcement: Price change',
        body: 'New RRPs from Monday',
      });
    });
  });

  describe('never in the way of the request', () => {
    it('a failing sender does not fail or delay the triggering request', async () => {
      const error = jest.spyOn(console, 'error').mockImplementation(() => undefined);
      sender.failWith = new Error('FCM down');
      const res = await request(app).post('/messages').set(auth(agentA)).send({ body: 'Still sent', recipientId: agentB.userId });
      expect(res.status).toBe(201);
      await settleInFlightPushes();
      expect(error).toHaveBeenCalledWith('[push] message push failed:', expect.any(Error));
      error.mockRestore();
    });

    it('with push unconfigured, every trigger is a no-op and requests behave as before', async () => {
      const noop = new NoopPushSender();
      const send = jest.spyOn(noop, 'send');
      jest.spyOn(console, 'debug').mockImplementation(() => undefined);
      setPushSender(noop);
      try {
        expect((await request(app).post('/tasks').set(auth(manager)).send(task(agentA.userId))).status).toBe(201);
        expect((await request(app).post('/messages').set(auth(manager)).send({ body: 'hi' })).status).toBe(201);
        expect(
          (await request(app).post('/announcements').set(auth(manager)).send({ title: 'a', body: 'b' })).status,
        ).toBe(201);
        await settleInFlightPushes();
        expect(send).not.toHaveBeenCalled();
      } finally {
        jest.restoreAllMocks();
      }
    });

    function task(ownerId: string) {
      return { outletId, findingType: 'x', requiredFix: 'y', priority: 'normal', ownerId };
    }
  });
});
