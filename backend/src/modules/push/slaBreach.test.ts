import { readFileSync } from 'fs';
import { resolve } from 'path';
import { prisma } from '../../lib/prisma';
import { RecordingPushSender } from '../../test-utils/pushSender';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';
import { setPushSender } from './push.sender';
import { registerDeviceToken, updateNotificationPreferences } from './push.service';
import { SLA_BREACH_LOOKBACK_MS, sweepSlaBreaches } from './slaBreach';
import { slaBreachSweepEnabled, startSlaBreachWorker } from './slaBreach.worker';

const HOUR = 60 * 60 * 1000;

/**
 * #67 — SLA breaches. Nothing computed a breach server-side before this: the
 * app's SlaPill compared slaDueAt with the device clock. The sweep is the
 * event, and it announces each recent breach once.
 */
describe('SLA breach sweep (#67)', () => {
  const sender = new RecordingPushSender();
  const now = new Date('2026-09-15T12:00:00.000Z');
  let clientId: string;
  let outletId: string;
  let agent: TestUser;
  let manager: TestUser;
  let mutedManager: TestUser;
  let foreign: Awaited<ReturnType<typeof foreignTenant>>;
  const tok = (user: TestUser) => `sla-${user.userId}`;

  const task = (slaDueAt: Date, status: 'open' | 'in_progress' | 'closed' = 'open', extra = {}) =>
    prisma.task.create({
      data: {
        outletId,
        ownerId: agent.userId,
        findingType: 'stockout',
        requiredFix: 'Restock shelf 4',
        priority: 'critical',
        slaDueAt,
        status,
        ...extra,
      },
    });

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'PUSH-SLA', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    agent = await userIn(clientId, 'field_agent');
    manager = await userIn(clientId, 'manager');
    mutedManager = await userIn(clientId, 'manager');
    foreign = await foreignTenant('manager');
    for (const user of [agent, manager, mutedManager, foreign]) {
      await registerDeviceToken({ userId: user.userId, clientId: user.clientId, platform: 'android', token: tok(user) });
    }
    await updateNotificationPreferences({ userId: mutedManager.userId, clientId, changes: { sla: false } });
    const outlet = await prisma.outlet.create({
      data: {
        name: 'Checkers Hyde Park',
        code: `SLA-${Date.now()}`,
        channelType: 'hypermarket',
        lat: -26.12,
        lng: 28.03,
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
    setPushSender(null);
    await prisma.task.deleteMany({ where: { outletId } });
    await prisma.outlet.delete({ where: { id: outletId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
  });

  it('announces a fresh breach once, to the owner and opted-in managers of the tenant', async () => {
    const breached = await task(new Date(now.getTime() - HOUR), 'in_progress');

    await sweepSlaBreaches(now, 1000);

    const pushes = Object.fromEntries(
      sender.to(tok(agent), tok(manager), tok(mutedManager), tok(foreign)).map((m) => [m.token, m.data.route]),
    );
    expect(pushes).toEqual({ [tok(agent)]: '/today', [tok(manager)]: '/tasks' });
    expect(sender.to(tok(agent))[0]).toMatchObject({
      title: 'Task overdue',
      body: 'Checkers Hyde Park: Restock shelf 4',
      data: { category: 'sla' },
    });
    expect((await prisma.task.findUniqueOrThrow({ where: { id: breached.id } })).slaBreachNotifiedAt).toEqual(now);

    sender.reset();
    await sweepSlaBreaches(new Date(now.getTime() + 10 * 60_000), 1000);
    expect(sender.to(tok(agent))).toEqual([]);
  });

  it('ignores tasks that are closed, not yet due, already announced, or breached before the lookback', async () => {
    const ignored = await Promise.all([
      task(new Date(now.getTime() - HOUR), 'closed'),
      task(new Date(now.getTime() + HOUR)),
      task(new Date(now.getTime() - HOUR), 'open', { slaBreachNotifiedAt: new Date(now.getTime() - 30 * 60_000) }),
      task(new Date(now.getTime() - SLA_BREACH_LOOKBACK_MS - HOUR)),
    ]);

    await sweepSlaBreaches(now, 1000);

    expect(sender.to(tok(agent), tok(manager))).toEqual([]);
    const rows = await prisma.task.findMany({ where: { id: { in: ignored.map((t) => t.id) } } });
    expect(rows.filter((r) => r.slaBreachNotifiedAt?.getTime() === now.getTime())).toEqual([]);
  });

  it('keeps sweeping when one push fails', async () => {
    const error = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    const a = await task(new Date(now.getTime() - 2 * HOUR));
    const b = await task(new Date(now.getTime() - HOUR));
    sender.failWith = new Error('FCM down');

    await sweepSlaBreaches(now, 1000);

    const rows = await prisma.task.findMany({ where: { id: { in: [a.id, b.id] } } });
    expect(rows.map((r) => r.slaBreachNotifiedAt)).toEqual([now, now]);
    expect(error).toHaveBeenCalledWith(expect.stringContaining(`task ${a.id}`), expect.any(Error));
    error.mockRestore();
  });

  describe('worker', () => {
    const until = async (check: () => boolean) => {
      const deadline = Date.now() + 2000;
      while (!check()) {
        if (Date.now() > deadline) throw new Error('timed out');
        await new Promise((r) => setTimeout(r, 5));
      }
    };

    it('is registered in server.ts behind SLA_BREACH_SWEEP_ENABLED and stopped on shutdown', () => {
      const server = readFileSync(resolve(__dirname, '../../server.ts'), 'utf8');
      expect(server).toMatch(/slaBreachSweepEnabled\(\)\s*\?\s*startSlaBreachWorker\(\)/);
      expect(server).toMatch(/slaBreachWorker\?\.stop\(\)/);
      expect(slaBreachSweepEnabled({})).toBe(true);
      expect(slaBreachSweepEnabled({ SLA_BREACH_SWEEP_ENABLED: ' FALSE ' })).toBe(false);
    });

    it('does not sweep while push is unconfigured', async () => {
      const sweep = jest.fn().mockResolvedValue({ claimed: 0 });
      const worker = startSlaBreachWorker({ intervalMs: 5, sweep, isPushEnabled: () => false });
      await new Promise((r) => setTimeout(r, 40));
      await worker.stop();
      expect(sweep).not.toHaveBeenCalled();
    });

    it('sweeps while push is configured, draining full batches, and survives a failed sweep', async () => {
      const error = jest.spyOn(console, 'error').mockImplementation(() => undefined);
      const sweep = jest
        .fn()
        .mockRejectedValueOnce(new Error('db blip'))
        .mockResolvedValueOnce({ claimed: 50 })
        .mockResolvedValue({ claimed: 0 });
      const worker = startSlaBreachWorker({ intervalMs: 5, sweep, now: () => now });
      await until(() => sweep.mock.calls.length >= 3);
      await worker.stop();
      expect(sweep).toHaveBeenCalledWith(now, 50);
      expect(error).toHaveBeenCalledWith(expect.stringContaining('sweep failed'), expect.any(Error));
      error.mockRestore();
    });
  });
});
