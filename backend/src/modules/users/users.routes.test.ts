import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('users routes', () => {
  let clientId: string;
  let otherClientId: string;
  let adminToken: string;
  let managerToken: string;
  let fieldAgentToken: string;
  let patchTargetId: string;
  let otherUserId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'USERS-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const admin = await prisma.user.create({
      data: { email: 'USERS-admin@example.com', passwordHash: 'x', role: 'admin', clientId },
    });
    const manager = await prisma.user.create({
      data: { email: 'USERS-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    const fieldAgent = await prisma.user.create({
      data: { email: 'USERS-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    const patchTarget = await prisma.user.create({
      data: { email: 'USERS-target@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    patchTargetId = patchTarget.id;

    adminToken = issueToken({ userId: admin.id, role: 'admin', clientId });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });
    fieldAgentToken = issueToken({ userId: fieldAgent.id, role: 'field_agent', clientId });

    const otherClient = await prisma.client.create({
      data: {
        name: 'USERS-OtherClient',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    otherClientId = otherClient.id;
    const otherUser = await prisma.user.create({
      data: {
        email: 'USERS-other@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    otherUserId = otherUser.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId: otherClientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.client.delete({ where: { id: otherClientId } });
    await prisma.$disconnect();
  });

  it('lets an admin create a user (201, no passwordHash in the body)', async () => {
    const res = await request(app)
      .post('/users')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ email: 'USERS-new@example.com', password: 'supersecret', role: 'manager' });

    expect(res.status).toBe(201);
    expect(res.body.email).toBe('USERS-new@example.com');
    expect(res.body.role).toBe('manager');
    expect(res.body.active).toBe(true);
    expect(res.body.passwordHash).toBeUndefined();
  });

  it('rejects a duplicate email with 409', async () => {
    const res = await request(app)
      .post('/users')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ email: 'USERS-admin@example.com', password: 'supersecret', role: 'field_agent' });

    expect(res.status).toBe(409);
  });

  it('rejects an invalid role with 400', async () => {
    const res = await request(app)
      .post('/users')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ email: 'USERS-badrole@example.com', password: 'supersecret', role: 'superuser' });

    expect(res.status).toBe(400);
  });

  it('rejects a short password with 400', async () => {
    const res = await request(app)
      .post('/users')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ email: 'USERS-shortpw@example.com', password: 'short', role: 'field_agent' });

    expect(res.status).toBe(400);
  });

  it('rejects user creation by a manager with 403', async () => {
    const res = await request(app)
      .post('/users')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ email: 'USERS-nope@example.com', password: 'supersecret', role: 'field_agent' });

    expect(res.status).toBe(403);
  });

  it('lists users for a manager (200, includes active, no passwordHash)', async () => {
    const res = await request(app).get('/users').set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    for (const user of res.body) {
      expect(user.passwordHash).toBeUndefined();
      expect(typeof user.active).toBe('boolean');
    }
    const emails = res.body.map((u: { email: string }) => u.email);
    expect(emails).toContain('USERS-admin@example.com');
  });

  it('rejects listing users by a field_agent with 403', async () => {
    const res = await request(app).get('/users').set('Authorization', `Bearer ${fieldAgentToken}`);
    expect(res.status).toBe(403);
  });

  it('lists users for an admin (200)', async () => {
    const res = await request(app).get('/users').set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('lets an admin deactivate a user (200)', async () => {
    const res = await request(app)
      .patch(`/users/${patchTargetId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ active: false });

    expect(res.status).toBe(200);
    expect(res.body.active).toBe(false);
    expect(res.body.passwordHash).toBeUndefined();
  });

  it("lets an admin change a user's role (200)", async () => {
    const res = await request(app)
      .patch(`/users/${patchTargetId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ role: 'manager' });

    expect(res.status).toBe(200);
    expect(res.body.role).toBe('manager');
    expect(res.body.passwordHash).toBeUndefined();
  });

  it('rejects a PATCH by a manager with 403', async () => {
    const res = await request(app)
      .patch(`/users/${patchTargetId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ active: true });

    expect(res.status).toBe(403);
  });

  it('rejects a cross-tenant PATCH with 404', async () => {
    const res = await request(app)
      .patch(`/users/${otherUserId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ active: false });

    expect(res.status).toBe(404);
  });

  it('rejects unauthenticated requests with 401', async () => {
    const res = await request(app).get('/users');
    expect(res.status).toBe(401);
  });
});
