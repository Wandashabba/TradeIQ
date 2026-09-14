import request from 'supertest';
import { fetch } from 'undici';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';
import {
  attemptDelivery,
  claimDueDeliveries,
  CLAIM_LEASE_MS,
  dispatchWebhookEvent,
  MAX_ATTEMPTS,
  processDueDeliveries,
  RETRY_DELAYS_MS,
  retryDelayAfter,
  settleInFlightDeliveries,
  signWebhookBody,
  webhookHealth,
} from './webhooks.service';
import { startWebhookDeliveryWorker } from './webhooks.worker';

// No real network: subscribers are a stubbed undici fetch. The DNS pre-check is
// stubbed too — its own behaviour is covered by urlGuard.test.ts, and the
// hostnames here are fictional.
jest.mock('undici', () => ({
  ...jest.requireActual('undici'),
  fetch: jest.fn(),
}));
jest.mock('../../lib/urlGuard', () => ({
  ...jest.requireActual('../../lib/urlGuard'),
  assertPublicHostname: jest.fn().mockResolvedValue(undefined),
}));

const fetchMock = fetch as unknown as jest.Mock;

interface SentRequest {
  url: string;
  headers: Record<string, string>;
  body: string;
}

function sent(callIndex: number): SentRequest {
  const [url, init] = fetchMock.mock.calls[callIndex] as [
    string,
    { headers: Record<string, string>; body: string },
  ];
  return { url, headers: init.headers, body: init.body };
}

/** Waits until the stubbed subscriber has been called `count` times. */
async function untilFetched(count: number) {
  const deadline = Date.now() + 5000;
  while (fetchMock.mock.calls.length < count && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
  expect(fetchMock).toHaveBeenCalledTimes(count);
}

function respondWith(...statuses: number[]) {
  for (const status of statuses) {
    fetchMock.mockResolvedValueOnce({ status, body: null });
  }
}

const SECRET = 'whsec_delivery_test';

describe('webhook delivery (#100)', () => {
  let clientId: string;
  let otherClientId: string;
  let managerToken: string;
  let agentToken: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'DLV-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const other = await prisma.client.create({
      data: { name: 'DLV-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = other.id;

    const manager = await prisma.user.create({
      data: { email: 'dlv-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });
    const agent = await prisma.user.create({
      data: { email: 'dlv-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
  });

  beforeEach(() => {
    fetchMock.mockReset();
  });

  afterEach(async () => {
    await settleInFlightDeliveries();
    // Deliveries cascade with their webhooks. Clearing between tests keeps a
    // leftover due row from being claimed by a later test's processor.
    await prisma.webhook.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
    await prisma.$disconnect();
  });

  async function makeWebhook(overrides: { clientId?: string; event?: string; secret?: string | null; active?: boolean; consecutiveFailures?: number } = {}) {
    return prisma.webhook.create({
      data: {
        clientId: overrides.clientId ?? clientId,
        url: 'https://hooks.example.com/receive',
        event: overrides.event ?? 'order.created',
        secret: overrides.secret === undefined ? SECRET : overrides.secret,
        active: overrides.active ?? true,
        consecutiveFailures: overrides.consecutiveFailures ?? 0,
      },
    });
  }

  async function onlyDeliveryFor(webhookId: string) {
    const rows = await prisma.webhookDelivery.findMany({ where: { webhookId } });
    expect(rows).toHaveLength(1);
    return rows[0];
  }

  /** Makes the next attempt of a failed_retrying row due, then runs it. */
  async function runNextRetry(deliveryId: string) {
    const row = await prisma.webhookDelivery.findUniqueOrThrow({ where: { id: deliveryId } });
    expect(row.nextAttemptAt).not.toBeNull();
    const claimed = await processDueDeliveries(new Date(row.nextAttemptAt!.getTime() + 1));
    expect(claimed).toBe(1);
  }

  describe('schedule constants', () => {
    it('backs off 1m, 5m, 25m, 2h, 6h and gives up on attempt 6', () => {
      expect(RETRY_DELAYS_MS).toEqual([60_000, 300_000, 1_500_000, 7_200_000, 21_600_000]);
      expect(MAX_ATTEMPTS).toBe(6);
      expect([1, 2, 3, 4, 5].map(retryDelayAfter)).toEqual([...RETRY_DELAYS_MS]);
      // Past the table (a redelivered give-up) the cap holds.
      expect(retryDelayAfter(9)).toBe(21_600_000);
    });

    it('derives health from give-ups first, then a pending retry', () => {
      expect(webhookHealth({ consecutiveFailures: 0, lastDeliveryStatus: null })).toBe('healthy');
      expect(webhookHealth({ consecutiveFailures: 0, lastDeliveryStatus: 'succeeded' })).toBe('healthy');
      expect(webhookHealth({ consecutiveFailures: 0, lastDeliveryStatus: 'failed_retrying' })).toBe('failing');
      expect(webhookHealth({ consecutiveFailures: 1, lastDeliveryStatus: 'failed_retrying' })).toBe('unhealthy');
    });
  });

  it('success: records the delivery and signs the request', async () => {
    const webhook = await makeWebhook();
    respondWith(204);

    await dispatchWebhookEvent(clientId, 'order.created', { orderId: 'o-1' });
    await settleInFlightDeliveries();

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const req = sent(0);
    expect(req.url).toBe('https://hooks.example.com/receive');
    expect(JSON.parse(req.body)).toMatchObject({ event: 'order.created', payload: { orderId: 'o-1' } });

    const delivery = await onlyDeliveryFor(webhook.id);
    expect(delivery).toMatchObject({
      status: 'succeeded',
      attempts: 1,
      lastStatusCode: 204,
      lastError: null,
      nextAttemptAt: null,
      clientId,
      event: 'order.created',
    });
    expect(delivery.deliveredAt).not.toBeNull();

    expect(req.headers['X-TradeIQ-Delivery']).toBe(delivery.id);
    expect(req.headers['X-TradeIQ-Delivery-Attempt']).toBe('1');
    expect(req.headers['X-TradeIQ-Event']).toBe('order.created');
    const timestamp = req.headers['X-TradeIQ-Timestamp'];
    expect(req.headers['X-TradeIQ-Signature']).toBe(
      `sha256=${signWebhookBody(SECRET, timestamp, req.body)}`,
    );

    const after = await prisma.webhook.findUniqueOrThrow({ where: { id: webhook.id } });
    expect(after.lastDeliveryStatus).toBe('succeeded');
    expect(after.lastDeliveryAt).not.toBeNull();
    expect(after.consecutiveFailures).toBe(0);
  });

  it('does not block the caller on the subscriber', async () => {
    await makeWebhook();
    let release!: () => void;
    fetchMock.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          release = () => resolve({ status: 200, body: null });
        }),
    );

    // Resolves while the subscriber is still holding the request open.
    await dispatchWebhookEvent(clientId, 'order.created', {});
    await untilFetched(1);

    release();
    await settleInFlightDeliveries();
  });

  it('only fans out to active webhooks for that event and client', async () => {
    await makeWebhook({ event: 'visit.submitted' });
    await makeWebhook({ active: false });
    await makeWebhook({ clientId: otherClientId });

    await dispatchWebhookEvent(clientId, 'order.created', {});
    await settleInFlightDeliveries();

    expect(fetchMock).not.toHaveBeenCalled();
    expect(await prisma.webhookDelivery.count({ where: { clientId: { in: [clientId, otherClientId] } } })).toBe(0);
  });

  it('a failure schedules the retry on the backoff table, re-signed with the same body', async () => {
    const webhook = await makeWebhook();
    respondWith(500, 503);

    await dispatchWebhookEvent(clientId, 'order.created', { orderId: 'o-2' });
    await settleInFlightDeliveries();

    let delivery = await onlyDeliveryFor(webhook.id);
    expect(delivery).toMatchObject({ status: 'failed_retrying', attempts: 1, lastStatusCode: 500, lastError: 'HTTP 500' });
    expect(delivery.nextAttemptAt!.getTime() - delivery.lastAttemptAt!.getTime()).toBe(60_000);

    // Not due yet: nothing is claimed before its time.
    expect(await processDueDeliveries(new Date(delivery.nextAttemptAt!.getTime() - 1000))).toBe(0);

    await runNextRetry(delivery.id);
    delivery = await prisma.webhookDelivery.findUniqueOrThrow({ where: { id: delivery.id } });
    expect(delivery).toMatchObject({ status: 'failed_retrying', attempts: 2, lastStatusCode: 503 });
    expect(delivery.nextAttemptAt!.getTime() - delivery.lastAttemptAt!.getTime()).toBe(300_000);

    const [first, retry] = [sent(0), sent(1)];
    expect(retry.body).toBe(first.body);
    expect(retry.headers['X-TradeIQ-Delivery']).toBe(delivery.id);
    expect(first.headers['X-TradeIQ-Delivery-Attempt']).toBe('1');
    expect(retry.headers['X-TradeIQ-Delivery-Attempt']).toBe('2');
    expect(retry.headers['X-TradeIQ-Signature']).toBe(
      `sha256=${signWebhookBody(SECRET, retry.headers['X-TradeIQ-Timestamp'], retry.body)}`,
    );

    const health = await prisma.webhook.findUniqueOrThrow({ where: { id: webhook.id } });
    expect(health.lastDeliveryStatus).toBe('failed_retrying');
    expect(health.consecutiveFailures).toBe(0);
  });

  it('a network error is a failure with no status code, and the error is truncated', async () => {
    const webhook = await makeWebhook({ secret: null });
    fetchMock.mockRejectedValueOnce(new Error(`connect ECONNREFUSED ${'x'.repeat(2000)}`));

    await dispatchWebhookEvent(clientId, 'order.created', {});
    await settleInFlightDeliveries();

    const delivery = await onlyDeliveryFor(webhook.id);
    expect(delivery.status).toBe('failed_retrying');
    expect(delivery.lastStatusCode).toBeNull();
    expect(delivery.lastError).toMatch(/^connect ECONNREFUSED/);
    expect(delivery.lastError!.length).toBeLessThanOrEqual(500);
    // No secret, no signature — but still the delivery headers.
    expect(sent(0).headers['X-TradeIQ-Signature']).toBeUndefined();
    expect(sent(0).headers['X-TradeIQ-Delivery']).toBe(delivery.id);
  });

  it('a redirect is not a success (redirects are never followed)', async () => {
    const webhook = await makeWebhook();
    respondWith(302);

    await dispatchWebhookEvent(clientId, 'order.created', {});
    await settleInFlightDeliveries();

    expect((await onlyDeliveryFor(webhook.id)).status).toBe('failed_retrying');
  });

  it(`gives up after ${MAX_ATTEMPTS} attempts and marks the webhook unhealthy`, async () => {
    const webhook = await makeWebhook();
    respondWith(...Array(MAX_ATTEMPTS).fill(500));

    await dispatchWebhookEvent(clientId, 'order.created', {});
    await settleInFlightDeliveries();
    const { id } = await onlyDeliveryFor(webhook.id);

    const gaps: number[] = [];
    for (let attempt = 2; attempt <= MAX_ATTEMPTS; attempt += 1) {
      const before = await prisma.webhookDelivery.findUniqueOrThrow({ where: { id } });
      gaps.push(before.nextAttemptAt!.getTime() - before.lastAttemptAt!.getTime());
      await runNextRetry(id);
    }
    expect(gaps).toEqual([...RETRY_DELAYS_MS]);

    const delivery = await prisma.webhookDelivery.findUniqueOrThrow({ where: { id } });
    expect(delivery).toMatchObject({ status: 'gave_up', attempts: MAX_ATTEMPTS, nextAttemptAt: null });
    expect(fetchMock).toHaveBeenCalledTimes(MAX_ATTEMPTS);
    // Nothing left to claim, however far in the future we look.
    expect(await processDueDeliveries(new Date(Date.now() + 365 * 24 * 3600_000))).toBe(0);

    const after = await prisma.webhook.findUniqueOrThrow({ where: { id: webhook.id } });
    expect(after.consecutiveFailures).toBe(1);
    expect(after.lastDeliveryStatus).toBe('gave_up');

    const list = await request(app).get('/webhooks').set('Authorization', `Bearer ${managerToken}`);
    const row = list.body.data.find((w: { id: string }) => w.id === webhook.id);
    expect(row).toMatchObject({ health: 'unhealthy', consecutiveFailures: 1, lastDeliveryStatus: 'gave_up' });
    expect(row.lastDeliveryAt).toEqual(expect.any(String));
  });

  it('a success resets consecutive failures and reads healthy again', async () => {
    const webhook = await makeWebhook({ consecutiveFailures: 3 });
    respondWith(200);

    await dispatchWebhookEvent(clientId, 'order.created', {});
    await settleInFlightDeliveries();

    const after = await prisma.webhook.findUniqueOrThrow({ where: { id: webhook.id } });
    expect(after.consecutiveFailures).toBe(0);
    const list = await request(app).get('/webhooks').set('Authorization', `Bearer ${managerToken}`);
    expect(list.body.data.find((w: { id: string }) => w.id === webhook.id).health).toBe('healthy');
  });

  it('reports a webhook waiting on a retry as failing', async () => {
    const webhook = await makeWebhook();
    respondWith(500);
    await dispatchWebhookEvent(clientId, 'order.created', {});
    await settleInFlightDeliveries();

    const list = await request(app).get('/webhooks').set('Authorization', `Bearer ${managerToken}`);
    expect(list.body.data.find((w: { id: string }) => w.id === webhook.id).health).toBe('failing');
  });

  it('a paused webhook stops its pending retries without counting against health', async () => {
    const webhook = await makeWebhook();
    respondWith(500);
    await dispatchWebhookEvent(clientId, 'order.created', {});
    await settleInFlightDeliveries();
    const { id } = await onlyDeliveryFor(webhook.id);

    await prisma.webhook.update({ where: { id: webhook.id }, data: { active: false } });
    await runNextRetry(id);

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const delivery = await prisma.webhookDelivery.findUniqueOrThrow({ where: { id } });
    expect(delivery).toMatchObject({ status: 'gave_up', lastError: 'Webhook paused', attempts: 1 });
    const after = await prisma.webhook.findUniqueOrThrow({ where: { id: webhook.id } });
    expect(after.consecutiveFailures).toBe(0);
  });

  describe('claiming due work', () => {
    it('concurrent processors never attempt the same delivery twice', async () => {
      const webhook = await makeWebhook();
      const due = new Date(Date.now() - 60_000);
      const payload = { event: 'order.created', payload: {}, timestamp: due.toISOString() };
      await prisma.webhookDelivery.createMany({
        data: Array.from({ length: 12 }, () => ({
          webhookId: webhook.id,
          clientId,
          event: 'order.created',
          payload,
          status: 'failed_retrying' as const,
          attempts: 1,
          nextAttemptAt: due,
        })),
      });
      fetchMock.mockResolvedValue({ status: 200, body: null });

      const now = new Date();
      const counts = await Promise.all([
        processDueDeliveries(now, 5),
        processDueDeliveries(now, 5),
        processDueDeliveries(now, 5),
        processDueDeliveries(now, 5),
      ]);

      expect(counts.reduce((a, b) => a + b, 0)).toBe(12);
      expect(fetchMock).toHaveBeenCalledTimes(12);
      const ids = fetchMock.mock.calls.map((_, i) => sent(i).headers['X-TradeIQ-Delivery']);
      expect(new Set(ids).size).toBe(12);
      const rows = await prisma.webhookDelivery.findMany({ where: { webhookId: webhook.id } });
      expect(rows.every((r) => r.status === 'succeeded' && r.attempts === 2)).toBe(true);
    });

    it('a claim leases the row, so a second claim skips it until the lease runs out', async () => {
      const webhook = await makeWebhook();
      const now = new Date();
      const delivery = await prisma.webhookDelivery.create({
        data: {
          webhookId: webhook.id,
          clientId,
          event: 'order.created',
          payload: {},
          nextAttemptAt: new Date(now.getTime() - 1000),
        },
      });

      expect(await claimDueDeliveries(now, 10)).toEqual([delivery.id]);
      expect(await claimDueDeliveries(now, 10)).toEqual([]);

      const leased = await prisma.webhookDelivery.findUniqueOrThrow({ where: { id: delivery.id } });
      expect(leased.nextAttemptAt!.getTime()).toBe(now.getTime() + CLAIM_LEASE_MS);
      // A crashed processor's row comes back once its lease has expired.
      expect(await claimDueDeliveries(new Date(now.getTime() + CLAIM_LEASE_MS + 1), 10)).toEqual([delivery.id]);
    });

    it('a stale second recording of the same attempt is discarded', async () => {
      const webhook = await makeWebhook();
      const delivery = await prisma.webhookDelivery.create({
        data: { webhookId: webhook.id, clientId, event: 'order.created', payload: {}, nextAttemptAt: new Date() },
      });
      // Two processors both read attempts=0, both send; only one outcome lands.
      let releaseFirst!: () => void;
      fetchMock
        .mockImplementationOnce(
          () => new Promise((resolve) => (releaseFirst = () => resolve({ status: 500, body: null }))),
        )
        .mockResolvedValueOnce({ status: 200, body: null });

      const slow = attemptDelivery(delivery.id);
      await untilFetched(1);
      await attemptDelivery(delivery.id);
      releaseFirst();
      await slow;

      const row = await prisma.webhookDelivery.findUniqueOrThrow({ where: { id: delivery.id } });
      expect(row).toMatchObject({ status: 'succeeded', attempts: 1 });
      const after = await prisma.webhook.findUniqueOrThrow({ where: { id: webhook.id } });
      expect(after.lastDeliveryStatus).toBe('succeeded');
    });

    it('the worker picks up due rows on its interval and stops cleanly', async () => {
      const webhook = await makeWebhook();
      const delivery = await prisma.webhookDelivery.create({
        data: {
          webhookId: webhook.id,
          clientId,
          event: 'order.created',
          payload: {},
          status: 'failed_retrying',
          attempts: 1,
          nextAttemptAt: new Date(Date.now() - 1000),
        },
      });
      fetchMock.mockResolvedValue({ status: 200, body: null });

      const worker = startWebhookDeliveryWorker({ intervalMs: 10, batchSize: 1 });
      const deadline = Date.now() + 5000;
      let status = 'failed_retrying';
      while (status !== 'succeeded' && Date.now() < deadline) {
        await new Promise((resolve) => setTimeout(resolve, 20));
        status = (await prisma.webhookDelivery.findUniqueOrThrow({ where: { id: delivery.id } })).status;
      }
      await worker.stop();

      expect(status).toBe('succeeded');
      expect(fetchMock).toHaveBeenCalledTimes(1);
    });

    it('a worker tick that throws is logged, not fatal', async () => {
      const spy = jest.spyOn(prisma, '$queryRaw').mockRejectedValueOnce(new Error('db down'));
      const errors = jest.spyOn(console, 'error').mockImplementation(() => undefined);

      const worker = startWebhookDeliveryWorker({ intervalMs: 5 });
      const deadline = Date.now() + 2000;
      while (!errors.mock.calls.length && Date.now() < deadline) {
        await new Promise((resolve) => setTimeout(resolve, 10));
      }
      await worker.stop();

      expect(errors).toHaveBeenCalledWith('Webhook delivery worker tick failed:', expect.any(Error));
      spy.mockRestore();
      errors.mockRestore();
    });
  });

  describe('GET /webhooks/:id/deliveries', () => {
    it('lists recent deliveries newest first, honouring limit', async () => {
      const webhook = await makeWebhook();
      await prisma.webhookDelivery.createMany({
        data: [0, 1, 2].map((i) => ({
          webhookId: webhook.id,
          clientId,
          event: 'order.created',
          payload: { i },
          status: 'succeeded' as const,
          attempts: 1,
          createdAt: new Date(`2026-09-1${i}T00:00:00.000Z`),
        })),
      });

      const res = await request(app)
        .get(`/webhooks/${webhook.id}/deliveries?limit=2`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(2);
      expect(res.body.data.map((d: { payload: { i: number } }) => d.payload.i)).toEqual([2, 1]);
      expect(res.body.nextCursor).toEqual(expect.any(String));
    });

    it("404s for another client's webhook", async () => {
      const foreign = await makeWebhook({ clientId: otherClientId });
      await prisma.webhookDelivery.create({
        data: { webhookId: foreign.id, clientId: otherClientId, event: 'order.created', payload: {} },
      });

      const res = await request(app)
        .get(`/webhooks/${foreign.id}/deliveries`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(404);
    });

    it('forbids a field agent and rejects a bad limit', async () => {
      const webhook = await makeWebhook();
      const forbidden = await request(app)
        .get(`/webhooks/${webhook.id}/deliveries`)
        .set('Authorization', `Bearer ${agentToken}`);
      expect(forbidden.status).toBe(403);

      const bad = await request(app)
        .get(`/webhooks/${webhook.id}/deliveries?limit=0`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(bad.status).toBe(400);
    });
  });

  describe('POST /webhook-deliveries/:id/redeliver', () => {
    async function givenUp(forClientId = clientId) {
      const webhook = await makeWebhook({ clientId: forClientId, consecutiveFailures: 1 });
      return prisma.webhookDelivery.create({
        data: {
          webhookId: webhook.id,
          clientId: forClientId,
          event: 'order.created',
          payload: { event: 'order.created', payload: {}, timestamp: '2026-09-14T00:00:00.000Z' },
          status: 'gave_up',
          attempts: MAX_ATTEMPTS,
          lastStatusCode: 500,
        },
      });
    }

    it('re-queues a gave_up delivery and attempts it now', async () => {
      const delivery = await givenUp();
      respondWith(200);

      const res = await request(app)
        .post(`/webhook-deliveries/${delivery.id}/redeliver`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(202);
      expect(res.body.id).toBe(delivery.id);
      await settleInFlightDeliveries();

      expect(sent(0).headers['X-TradeIQ-Delivery']).toBe(delivery.id);
      expect(sent(0).headers['X-TradeIQ-Delivery-Attempt']).toBe(String(MAX_ATTEMPTS + 1));
      const row = await prisma.webhookDelivery.findUniqueOrThrow({ where: { id: delivery.id } });
      expect(row).toMatchObject({ status: 'succeeded', attempts: MAX_ATTEMPTS + 1 });
      const webhook = await prisma.webhook.findUniqueOrThrow({ where: { id: delivery.webhookId } });
      expect(webhook.consecutiveFailures).toBe(0);
    });

    it('a redelivered give-up that fails again gives up again', async () => {
      const delivery = await givenUp();
      respondWith(500);

      await request(app)
        .post(`/webhook-deliveries/${delivery.id}/redeliver`)
        .set('Authorization', `Bearer ${managerToken}`);
      await settleInFlightDeliveries();

      const row = await prisma.webhookDelivery.findUniqueOrThrow({ where: { id: delivery.id } });
      expect(row).toMatchObject({ status: 'gave_up', nextAttemptAt: null });
      const webhook = await prisma.webhook.findUniqueOrThrow({ where: { id: delivery.webhookId } });
      expect(webhook.consecutiveFailures).toBe(2);
    });

    it('409s for a delivery that already succeeded', async () => {
      const delivery = await givenUp();
      await prisma.webhookDelivery.update({ where: { id: delivery.id }, data: { status: 'succeeded' } });

      const res = await request(app)
        .post(`/webhook-deliveries/${delivery.id}/redeliver`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(409);
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it("404s for another client's delivery and 403s for a field agent", async () => {
      const foreign = await givenUp(otherClientId);
      const notFound = await request(app)
        .post(`/webhook-deliveries/${foreign.id}/redeliver`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(notFound.status).toBe(404);

      const own = await givenUp();
      const forbidden = await request(app)
        .post(`/webhook-deliveries/${own.id}/redeliver`)
        .set('Authorization', `Bearer ${agentToken}`);
      expect(forbidden.status).toBe(403);
      expect(fetchMock).not.toHaveBeenCalled();
      const untouched = await prisma.webhookDelivery.findUniqueOrThrow({ where: { id: foreign.id } });
      expect(untouched.status).toBe('gave_up');
    });
  });

  it('dispatch swallows a database failure rather than failing the caller', async () => {
    const spy = jest.spyOn(prisma.webhook, 'findMany').mockRejectedValueOnce(new Error('db down'));
    const errors = jest.spyOn(console, 'error').mockImplementation(() => undefined);

    await expect(dispatchWebhookEvent(clientId, 'order.created', {})).resolves.toBeUndefined();
    expect(errors).toHaveBeenCalled();

    spy.mockRestore();
    errors.mockRestore();
  });

  it('an attempt whose recording fails is logged and left to its lease', async () => {
    const webhook = await makeWebhook();
    const delivery = await prisma.webhookDelivery.create({
      data: { webhookId: webhook.id, clientId, event: 'order.created', payload: {}, nextAttemptAt: new Date() },
    });
    respondWith(200);
    const spy = jest.spyOn(prisma, '$transaction').mockRejectedValueOnce(new Error('db down'));
    const errors = jest.spyOn(console, 'error').mockImplementation(() => undefined);

    await expect(attemptDelivery(delivery.id)).resolves.toBeUndefined();
    expect(errors).toHaveBeenCalled();
    const row = await prisma.webhookDelivery.findUniqueOrThrow({ where: { id: delivery.id } });
    expect(row).toMatchObject({ status: 'pending', attempts: 0 });

    spy.mockRestore();
    errors.mockRestore();
  });
});
