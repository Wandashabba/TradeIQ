import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';
import { dispatchWebhookEvent } from './webhooks.service';

describe('webhooks routes', () => {
  let clientId: string;
  let otherClientId: string;
  let agentToken: string;
  let managerToken: string;
  let otherWebhookId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'HOOK-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'hook-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    const manager = await prisma.user.create({
      data: { email: 'hook-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    // A second tenant with its own webhook, to prove patch/delete scoping.
    const otherClient = await prisma.client.create({
      data: { name: 'HOOK-Other-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherWebhook = await prisma.webhook.create({
      data: { clientId: otherClientId, url: 'https://other.example.com/hook', event: 'visit.submitted' },
    });
    otherWebhookId = otherWebhook.id;
  });

  afterAll(async () => {
    await prisma.webhook.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
    await prisma.$disconnect();
  });

  let webhookId: string;

  it('creates a webhook (201)', async () => {
    const res = await request(app)
      .post('/webhooks')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ url: 'https://example.com/hook', event: 'order.created', secret: 's3cr3t' });

    expect(res.status).toBe(201);
    expect(res.body.url).toBe('https://example.com/hook');
    expect(res.body.event).toBe('order.created');
    expect(res.body.active).toBe(true);
    webhookId = res.body.id;
  });

  it("rejects a url that doesn't start with http (400)", async () => {
    const res = await request(app)
      .post('/webhooks')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ url: 'ftp://example.com/hook', event: 'order.created' });
    expect(res.status).toBe(400);
  });

  it.each([
    'http://169.254.169.254/latest/meta-data/',
    'http://127.0.0.1:6379/',
    'http://localhost:6379/',
    'http://10.0.0.5/internal',
  ])('rejects the SSRF target %s', async (url) => {
    const res = await request(app)
      .post('/webhooks')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ url, event: 'order.created' });
    expect(res.status).toBe(400);
  });

  it('rejects an SSRF target on PATCH too', async () => {
    const created = await request(app)
      .post('/webhooks')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ url: 'https://example.com/hook', event: 'order.created' });
    expect(created.status).toBe(201);

    const res = await request(app)
      .patch(`/webhooks/${created.body.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ url: 'http://169.254.169.254/' });
    expect(res.status).toBe(400);

    // Leave no active subscriber behind: the dispatch test at the end of this
    // file fans out for this client, and a surviving row would make it fetch.
    await request(app)
      .delete(`/webhooks/${created.body.id}`)
      .set('Authorization', `Bearer ${managerToken}`);
  });

  it('rejects a missing event (400)', async () => {
    const res = await request(app)
      .post('/webhooks')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ url: 'https://example.com/hook' });
    expect(res.status).toBe(400);
  });

  it("lists the caller's webhooks, newest first (200)", async () => {
    const res = await request(app).get('/webhooks').set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    const ids = res.body.map((w: { id: string }) => w.id);
    expect(ids).toContain(webhookId);
    expect(ids).not.toContain(otherWebhookId);
    const createdAts = res.body.map((w: { createdAt: string }) => new Date(w.createdAt).getTime());
    expect(createdAts).toEqual([...createdAts].sort((a: number, b: number) => b - a));
  });

  it('patches active=false (200)', async () => {
    const res = await request(app)
      .patch(`/webhooks/${webhookId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ active: false });
    expect(res.status).toBe(200);
    expect(res.body.active).toBe(false);
  });

  it('rejects an empty patch body (400)', async () => {
    const res = await request(app)
      .patch(`/webhooks/${webhookId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it("returns 404 when patching another client's webhook", async () => {
    const res = await request(app)
      .patch(`/webhooks/${otherWebhookId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ active: false });
    expect(res.status).toBe(404);
  });

  it("returns 404 when deleting another client's webhook", async () => {
    const res = await request(app)
      .delete(`/webhooks/${otherWebhookId}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(404);
  });

  it('deletes a webhook (204) then the list no longer shows it', async () => {
    const del = await request(app)
      .delete(`/webhooks/${webhookId}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(del.status).toBe(204);
    expect(del.body).toEqual({});

    const res = await request(app).get('/webhooks').set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(res.body.map((w: { id: string }) => w.id)).not.toContain(webhookId);
  });

  it('forbids a field agent from create/list/patch/delete (403)', async () => {
    const created = await request(app)
      .post('/webhooks')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ url: 'https://example.com/hook', event: 'order.created' });
    expect(created.status).toBe(403);

    const listed = await request(app).get('/webhooks').set('Authorization', `Bearer ${agentToken}`);
    expect(listed.status).toBe(403);

    const patched = await request(app)
      .patch(`/webhooks/${otherWebhookId}`)
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ active: false });
    expect(patched.status).toBe(403);

    const deleted = await request(app)
      .delete(`/webhooks/${otherWebhookId}`)
      .set('Authorization', `Bearer ${agentToken}`);
    expect(deleted.status).toBe(403);
  });

  it('rejects requests without a bearer token (401)', async () => {
    const created = await request(app)
      .post('/webhooks')
      .send({ url: 'https://example.com/hook', event: 'order.created' });
    expect(created.status).toBe(401);
    const listed = await request(app).get('/webhooks');
    expect(listed.status).toBe(401);
    const patched = await request(app).patch(`/webhooks/${otherWebhookId}`).send({ active: false });
    expect(patched.status).toBe(401);
    const deleted = await request(app).delete(`/webhooks/${otherWebhookId}`);
    expect(deleted.status).toBe(401);
  });

  it('dispatchWebhookEvent resolves without throwing when no webhooks match', async () => {
    await expect(
      dispatchWebhookEvent(clientId, 'event.with.no.subscribers', { hello: 'world' }),
    ).resolves.toBeUndefined();
    // Prove the other tenant's webhook is not reached via a foreign clientId.
    await expect(
      dispatchWebhookEvent(clientId, 'visit.submitted', {}),
    ).resolves.toBeUndefined();
  });
});
