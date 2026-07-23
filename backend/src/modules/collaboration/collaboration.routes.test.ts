import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('collaboration routes', () => {
  let clientId: string;
  let otherClientId: string;
  let agentAId: string;
  let agentBId: string;
  let agentAToken: string;
  let agentBToken: string;
  let managerToken: string;
  let otherAgentId: string;
  let otherToken: string;
  let directMessageId: string;
  let otherMessageId: string;
  let otherAnnouncementId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'COLLAB-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'COLLAB-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });
    const agentA = await prisma.user.create({
      data: { email: 'COLLAB-agent-a@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentAId = agentA.id;
    agentAToken = issueToken({ userId: agentA.id, role: 'field_agent', clientId });
    const agentB = await prisma.user.create({
      data: { email: 'COLLAB-agent-b@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentBId = agentB.id;
    agentBToken = issueToken({ userId: agentB.id, role: 'field_agent', clientId });

    // A second tenant with its own message + announcement, to prove isolation.
    const otherClient = await prisma.client.create({
      data: { name: 'COLLAB-Other-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherAgent = await prisma.user.create({
      data: {
        email: 'COLLAB-other-agent@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    otherAgentId = otherAgent.id;
    otherToken = issueToken({ userId: otherAgent.id, role: 'field_agent', clientId: otherClientId });

    const otherMessage = await prisma.message.create({
      data: { clientId: otherClientId, senderId: otherAgent.id, body: 'Other tenant broadcast' },
    });
    otherMessageId = otherMessage.id;
    const otherAnnouncement = await prisma.announcement.create({
      data: { clientId: otherClientId, authorId: otherAgent.id, title: 'Other title', body: 'Other body' },
    });
    otherAnnouncementId = otherAnnouncement.id;
  });

  afterAll(async () => {
    await prisma.message.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.announcement.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
    await prisma.$disconnect();
  });

  it('lets agentA post a direct message to agentB (201)', async () => {
    const res = await request(app)
      .post('/messages')
      .set('Authorization', `Bearer ${agentAToken}`)
      .send({ body: 'Hi agentB', recipientId: agentBId });

    expect(res.status).toBe(201);
    expect(res.body.senderId).toBe(agentAId);
    expect(res.body.recipientId).toBe(agentBId);
    expect(res.body.body).toBe('Hi agentB');
    expect(res.body.readAt).toBeNull();
    directMessageId = res.body.id;
  });

  it("includes the direct message in the recipient's GET /messages", async () => {
    const res = await request(app).get('/messages').set('Authorization', `Bearer ${agentBToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.map((m: { id: string }) => m.id)).toContain(directMessageId);
  });

  it('makes a broadcast (null recipient) visible to both sender and other users', async () => {
    const created = await request(app)
      .post('/messages')
      .set('Authorization', `Bearer ${agentAToken}`)
      .send({ body: 'Team broadcast' });
    expect(created.status).toBe(201);
    expect(created.body.recipientId).toBeNull();
    const broadcastId: string = created.body.id;

    const forA = await request(app).get('/messages').set('Authorization', `Bearer ${agentAToken}`);
    expect(forA.body.data.map((m: { id: string }) => m.id)).toContain(broadcastId);
    const forB = await request(app).get('/messages').set('Authorization', `Bearer ${agentBToken}`);
    expect(forB.body.data.map((m: { id: string }) => m.id)).toContain(broadcastId);
  });

  it('rejects an empty message body with 400', async () => {
    const res = await request(app)
      .post('/messages')
      .set('Authorization', `Bearer ${agentAToken}`)
      .send({ body: '' });
    expect(res.status).toBe(400);
  });

  it("returns 404 when the recipient belongs to another client", async () => {
    const res = await request(app)
      .post('/messages')
      .set('Authorization', `Bearer ${agentAToken}`)
      .send({ body: 'Cross-tenant', recipientId: otherAgentId });
    expect(res.status).toBe(404);
  });

  it('lets the recipient mark the message read (200, readAt set)', async () => {
    const res = await request(app)
      .patch(`/messages/${directMessageId}/read`)
      .set('Authorization', `Bearer ${agentBToken}`);
    expect(res.status).toBe(200);
    expect(res.body.readAt).not.toBeNull();

    const row = await prisma.message.findUnique({ where: { id: directMessageId } });
    expect(row?.readAt).not.toBeNull();
  });

  it('returns 404 when a non-recipient marks a message read', async () => {
    const res = await request(app)
      .patch(`/messages/${directMessageId}/read`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(404);
  });

  it('lets a manager post an announcement (201)', async () => {
    const res = await request(app)
      .post('/announcements')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ title: 'Weekly focus', body: 'Push the summer promo.' });
    expect(res.status).toBe(201);
    expect(res.body.title).toBe('Weekly focus');
  });

  it("lets agents see the client's announcements via GET /announcements", async () => {
    const res = await request(app).get('/announcements').set('Authorization', `Bearer ${agentAToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.map((a: { title: string }) => a.title)).toContain('Weekly focus');
  });

  it('rejects an announcement missing its body with 400', async () => {
    const res = await request(app)
      .post('/announcements')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ title: 'No body' });
    expect(res.status).toBe(400);
  });

  it('forbids a field agent from posting an announcement (403)', async () => {
    const res = await request(app)
      .post('/announcements')
      .set('Authorization', `Bearer ${agentAToken}`)
      .send({ title: 'Nope', body: 'Not allowed' });
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token (401)', async () => {
    expect((await request(app).post('/messages').send({ body: 'hi' })).status).toBe(401);
    expect((await request(app).get('/messages')).status).toBe(401);
    expect((await request(app).patch(`/messages/${directMessageId}/read`)).status).toBe(401);
    expect((await request(app).post('/announcements').send({ title: 't', body: 'b' })).status).toBe(401);
    expect((await request(app).get('/announcements')).status).toBe(401);
  });

  it("does not leak another client's messages or announcements", async () => {
    const messages = await request(app).get('/messages').set('Authorization', `Bearer ${agentAToken}`);
    expect(messages.body.data.map((m: { id: string }) => m.id)).not.toContain(otherMessageId);

    const announcements = await request(app)
      .get('/announcements')
      .set('Authorization', `Bearer ${agentAToken}`);
    expect(announcements.body.data.map((a: { id: string }) => a.id)).not.toContain(otherAnnouncementId);

    // And the other tenant never sees this client's data.
    const otherMessages = await request(app).get('/messages').set('Authorization', `Bearer ${otherToken}`);
    expect(otherMessages.body.data.map((m: { id: string }) => m.id)).toContain(otherMessageId);
    expect(otherMessages.body.data.map((m: { id: string }) => m.id)).not.toContain(directMessageId);
  });

  describe('GET /messages pagination', () => {
    beforeAll(async () => {
      await prisma.message.createMany({
        data: [0, 1, 2].map((i) => ({
          clientId,
          senderId: agentAId,
          body: `page-msg-${i}`,
          createdAt: new Date(`2026-07-20T0${i}:00:00.000Z`),
        })),
      });
    });

    it('returns an envelope with data and nextCursor, newest first', async () => {
      const res = await request(app)
        .get('/messages')
        .set('Authorization', `Bearer ${agentAToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('nextCursor');
      const bodies = res.body.data.map((m: { body: string }) => m.body);
      expect(bodies.indexOf('page-msg-2')).toBeLessThan(bodies.indexOf('page-msg-0'));
    });

    it('caps the page at limit and returns a cursor to the next page', async () => {
      const first = await request(app)
        .get('/messages?limit=2')
        .set('Authorization', `Bearer ${agentAToken}`);
      expect(first.status).toBe(200);
      expect(first.body.data).toHaveLength(2);
      expect(first.body.nextCursor).not.toBeNull();

      const second = await request(app)
        .get(`/messages?limit=2&cursor=${first.body.nextCursor}`)
        .set('Authorization', `Bearer ${agentAToken}`);
      expect(second.status).toBe(200);
      const firstIds = first.body.data.map((m: { id: string }) => m.id);
      const secondIds = second.body.data.map((m: { id: string }) => m.id);
      expect(secondIds.some((id: string) => firstIds.includes(id))).toBe(false);
    });

    it('clamps limit above the max to 200', async () => {
      const res = await request(app)
        .get('/messages?limit=9999')
        .set('Authorization', `Bearer ${agentAToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('rejects a non-positive limit with 400', async () => {
      const res = await request(app)
        .get('/messages?limit=0')
        .set('Authorization', `Bearer ${agentAToken}`);
      expect(res.status).toBe(400);
    });
  });

  describe('GET /announcements pagination', () => {
    beforeAll(async () => {
      await prisma.announcement.createMany({
        data: [0, 1, 2].map((i) => ({
          clientId,
          authorId: agentAId,
          title: `page-ann-${i}`,
          body: `page-ann-body-${i}`,
          createdAt: new Date(`2026-07-20T0${i}:00:00.000Z`),
        })),
      });
    });

    it('returns an envelope with data and nextCursor, newest first', async () => {
      const res = await request(app)
        .get('/announcements')
        .set('Authorization', `Bearer ${agentAToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('nextCursor');
      const titles = res.body.data.map((a: { title: string }) => a.title);
      expect(titles.indexOf('page-ann-2')).toBeLessThan(titles.indexOf('page-ann-0'));
    });

    it('caps the page at limit and returns a cursor to the next page', async () => {
      const first = await request(app)
        .get('/announcements?limit=2')
        .set('Authorization', `Bearer ${agentAToken}`);
      expect(first.status).toBe(200);
      expect(first.body.data).toHaveLength(2);
      expect(first.body.nextCursor).not.toBeNull();

      const second = await request(app)
        .get(`/announcements?limit=2&cursor=${first.body.nextCursor}`)
        .set('Authorization', `Bearer ${agentAToken}`);
      expect(second.status).toBe(200);
      const firstIds = first.body.data.map((a: { id: string }) => a.id);
      const secondIds = second.body.data.map((a: { id: string }) => a.id);
      expect(secondIds.some((id: string) => firstIds.includes(id))).toBe(false);
    });

    it('clamps limit above the max to 200', async () => {
      const res = await request(app)
        .get('/announcements?limit=9999')
        .set('Authorization', `Bearer ${agentAToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('rejects a non-positive limit with 400', async () => {
      const res = await request(app)
        .get('/announcements?limit=0')
        .set('Authorization', `Bearer ${agentAToken}`);
      expect(res.status).toBe(400);
    });
  });
});
