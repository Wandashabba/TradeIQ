import { prisma } from '../../lib/prisma';
import { RecordingPushSender } from '../../test-utils/pushSender';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';
import { firePush, notifyUsers, previewText, settleInFlightPushes } from './push.notify';
import { NoopPushSender, setPushSender } from './push.sender';
import { registerDeviceToken, updateNotificationPreferences } from './push.service';

/**
 * #67 — who a push reaches: active users of the event's tenant who have not
 * switched the category off, on tokens registered in that tenant; and a token
 * FCM rejects is deleted.
 */
describe('notifyUsers (#67)', () => {
  const sender = new RecordingPushSender();
  let clientId: string;
  let agent: TestUser;
  let manager: TestUser;
  let muted: TestUser;
  let inactive: TestUser;
  let foreign: Awaited<ReturnType<typeof foreignTenant>>;
  const tok = (user: TestUser, n = 1) => `notify-${user.userId}-${n}`;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'PUSH-Notify', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    agent = await userIn(clientId, 'field_agent');
    manager = await userIn(clientId, 'manager');
    muted = await userIn(clientId, 'manager');
    inactive = await userIn(clientId, 'field_agent');
    foreign = await foreignTenant('manager');

    for (const user of [agent, manager, muted, inactive, foreign]) {
      await registerDeviceToken({
        userId: user.userId,
        clientId: user.clientId,
        platform: 'android',
        token: tok(user),
      });
    }
    // The agent has two phones.
    await registerDeviceToken({ userId: agent.userId, clientId, platform: 'ios', token: tok(agent, 2) });
    await updateNotificationPreferences({ userId: muted.userId, clientId, changes: { tasks: false } });
    await prisma.user.update({ where: { id: inactive.userId }, data: { active: false } });
  });

  beforeEach(() => {
    sender.reset();
    setPushSender(sender);
  });

  afterAll(async () => {
    setPushSender(null);
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
  });

  const everyone = () => [agent, manager, muted, inactive, foreign].map((u) => u.userId);

  it('reaches every active, opted-in user of the tenant, on each of their devices', async () => {
    const result = await notifyUsers({
      clientId,
      userIds: [...everyone(), agent.userId],
      category: 'alerts',
      title: 'Alert at Store',
      body: 'SKU 1 is out of stock',
      route: '/alerts',
    });

    expect(sender.messages.map((m) => m.token).sort()).toEqual(
      [tok(agent), tok(agent, 2), tok(manager), tok(muted)].sort(),
    );
    expect(sender.messages[0]).toMatchObject({
      title: 'Alert at Store',
      body: 'SKU 1 is out of stock',
      data: { route: '/alerts', category: 'alerts' },
    });
    expect(result).toEqual({ recipients: 3, sent: 4, invalidTokensRemoved: 0 });
  });

  it('respects a switched-off category, and only that category', async () => {
    await notifyUsers({ clientId, userIds: everyone(), category: 'tasks', title: 't', body: 'b', route: '/tasks' });
    const tokens = sender.messages.map((m) => m.token);
    expect(tokens).not.toContain(tok(muted));
    expect(tokens).toContain(tok(manager));
  });

  it('never reaches another tenant, even when its user id is passed', async () => {
    await notifyUsers({ clientId, userIds: everyone(), category: 'alerts', title: 't', body: 'b', route: '/alerts' });
    expect(sender.to(tok(foreign))).toEqual([]);

    // Nor a token of this tenant's user that was registered under another tenant.
    const stray = `notify-stray-${Date.now()}`;
    await prisma.deviceToken.create({
      data: { userId: manager.userId, clientId: foreign.clientId, platform: 'web', token: stray, lastSeenAt: new Date() },
    });
    sender.reset();
    await notifyUsers({ clientId, userIds: [manager.userId], category: 'alerts', title: 't', body: 'b', route: '/alerts' });
    expect(sender.messages.map((m) => m.token)).toEqual([tok(manager)]);
    await prisma.deviceToken.delete({ where: { token: stray } });
  });

  it('routes per recipient role when the route depends on it', async () => {
    await notifyUsers({
      clientId,
      userIds: [agent.userId, manager.userId],
      category: 'tasks',
      title: 't',
      body: 'b',
      route: (role) => (role === 'field_agent' ? '/today' : '/tasks'),
    });
    expect(sender.to(tok(agent)).map((m) => m.data.route)).toEqual(['/today']);
    expect(sender.to(tok(manager)).map((m) => m.data.route)).toEqual(['/tasks']);
  });

  it('deletes tokens FCM reports as unregistered or invalid, and keeps the rest', async () => {
    const dead = `notify-dead-${Date.now()}`;
    await registerDeviceToken({ userId: manager.userId, clientId, platform: 'android', token: dead });
    sender.invalid.add(dead);

    const result = await notifyUsers({
      clientId,
      userIds: [manager.userId],
      category: 'messages',
      title: 't',
      body: 'b',
      route: '/messages',
    });

    expect(result.invalidTokensRemoved).toBe(1);
    expect(await prisma.deviceToken.count({ where: { token: dead } })).toBe(0);
    expect(await prisma.deviceToken.count({ where: { token: tok(manager) } })).toBe(1);
  });

  it('sends nothing when nobody is left to reach', async () => {
    expect(
      await notifyUsers({ clientId, userIds: [], category: 'sla', title: 't', body: 'b', route: '/tasks' }),
    ).toEqual({ recipients: 0, sent: 0, invalidTokensRemoved: 0 });
    const tokenless = await userIn(clientId, 'manager');
    expect(
      await notifyUsers({ clientId, userIds: [tokenless.userId], category: 'sla', title: 't', body: 'b', route: '/tasks' }),
    ).toEqual({ recipients: 1, sent: 0, invalidTokensRemoved: 0 });
    expect(sender.batches).toEqual([]);
  });

  describe('when push is unconfigured', () => {
    it('does no lookups and sends nothing', async () => {
      const noop = new NoopPushSender();
      const send = jest.spyOn(noop, 'send');
      const debug = jest.spyOn(console, 'debug').mockImplementation(() => undefined);
      const findMany = jest.spyOn(prisma.user, 'findMany');
      setPushSender(noop);
      try {
        const result = await notifyUsers({
          clientId,
          userIds: everyone(),
          category: 'alerts',
          title: 't',
          body: 'b',
          route: '/alerts',
        });
        const build = jest.fn();
        firePush('test push', build);
        await settleInFlightPushes();

        expect(result).toEqual({ recipients: 0, sent: 0, invalidTokensRemoved: 0 });
        expect(build).not.toHaveBeenCalled();
        expect(send).not.toHaveBeenCalled();
        expect(findMany).not.toHaveBeenCalled();
        expect(debug).toHaveBeenCalledTimes(1);
      } finally {
        jest.restoreAllMocks();
      }
    });
  });

  describe('firePush', () => {
    it('never throws into the caller; a failure is logged', async () => {
      const error = jest.spyOn(console, 'error').mockImplementation(() => undefined);
      sender.failWith = new Error('FCM unreachable');
      expect(() =>
        firePush('failing push', async () => ({
          clientId,
          userIds: [manager.userId],
          category: 'alerts',
          title: 't',
          body: 'b',
          route: '/alerts',
        })),
      ).not.toThrow();
      await settleInFlightPushes();
      expect(error).toHaveBeenCalledWith('[push] failing push failed:', expect.any(Error));
      error.mockRestore();
    });

    it('skips a build that decides there is nothing to send', async () => {
      firePush('empty push', async () => null);
      await settleInFlightPushes();
      expect(sender.batches).toEqual([]);
    });
  });

  it('previews text on one bounded line', () => {
    expect(previewText('  a\n\nb  ')).toBe('a b');
    expect(previewText('x'.repeat(200), 10)).toBe(`${'x'.repeat(9)}…`);
  });
});
