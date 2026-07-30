import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';

describe('users routes', () => {
  let clientId: string;
  let otherClientId: string;
  let adminToken: string;
  let managerToken: string;
  let fieldAgentToken: string;
  let patchTargetId: string;
  let otherUserId: string;
  let otherManagerToken: string;

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
    const otherManager = await prisma.user.create({
      data: {
        email: 'USERS-other-manager@example.com',
        passwordHash: 'x',
        role: 'manager',
        clientId: otherClientId,
      },
    });
    otherManagerToken = issueToken({ userId: otherManager.id, role: 'manager', clientId: otherClientId });
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
    expect(Array.isArray(res.body.data)).toBe(true);
    for (const user of res.body.data) {
      expect(user.passwordHash).toBeUndefined();
      expect(typeof user.active).toBe('boolean');
      // Pin the whole allowlist, not just the hash's absence: safeUserSelect is
      // shared with /territories/:id/coverage, so widening it here widens both.
      expect(Object.keys(user).sort()).toEqual(['active', 'email', 'id', 'lastSeenAt', 'role']);
    }
    const emails = res.body.data.map((u: { email: string }) => u.email);
    expect(emails).toContain('USERS-admin@example.com');
  });

  it('rejects listing users by a field_agent with 403', async () => {
    const res = await request(app).get('/users').set('Authorization', `Bearer ${fieldAgentToken}`);
    expect(res.status).toBe(403);
  });

  it('lists users for an admin (200)', async () => {
    const res = await request(app).get('/users').set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
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

  describe('GET /users pagination', () => {
    const pagedUserIds: string[] = [];
    const PAGE_SEED_COUNT = 25;

    beforeAll(async () => {
      // Email is globally unique (issue #188), so the padded index makes
      // every seeded address unique both within this describe block and
      // across the whole test database, and zero-padding keeps lexical order
      // equal to numeric order for the alphabetical-by-email assertion.
      for (let i = 0; i < PAGE_SEED_COUNT; i++) {
        const padded = String(i).padStart(2, '0');
        const user = await prisma.user.create({
          data: {
            email: `USERS-paging-${padded}@example.com`,
            passwordHash: 'x',
            role: 'field_agent',
            clientId,
          },
        });
        pagedUserIds.push(user.id);
      }
    });

    it('returns an envelope with data and nextCursor, alphabetical by email', async () => {
      const res = await request(app)
        .get('/users')
        .query({ limit: 200 })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('nextCursor');
      const emails = (res.body.data as Array<{ email: string }>)
        .map((u) => u.email)
        .filter((e) => e.startsWith('USERS-paging-'));
      expect(emails).toEqual([...emails].sort());
    });

    it('default page size caps the result at 50', async () => {
      const res = await request(app)
        .get('/users')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(res.body.data.length).toBeLessThanOrEqual(50);
    });

    it('honours ?limit=N', async () => {
      const res = await request(app)
        .get('/users')
        .query({ limit: 5 })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(5);
      expect(res.body.nextCursor).not.toBeNull();
    });

    it.each([['0'], ['abc'], ['-1']])('rejects ?limit=%s with 400', async (limit) => {
      const res = await request(app)
        .get('/users')
        .query({ limit })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });

    it('pages through with no gap and no overlap across the seeded set', async () => {
      const seen: string[] = [];
      let cursor: string | undefined;
      let guard = 0;

      do {
        const res: request.Response = await request(app)
          .get('/users')
          .query({
            limit: 10,
            ...(cursor ? { cursor } : {}),
          })
          .set('Authorization', `Bearer ${managerToken}`);
        expect(res.status).toBe(200);
        seen.push(...res.body.data.map((u: { id: string }) => u.id));
        cursor = res.body.nextCursor ?? undefined;
        guard++;
      } while (cursor && guard < 20);

      // No overlap: every id appears exactly once across all pages.
      expect(new Set(seen).size).toBe(seen.length);
      // No gap: every seeded id was eventually returned somewhere.
      for (const id of pagedUserIds) {
        expect(seen).toContain(id);
      }
    });

    it("never returns another client's users even across pages, and that client's own token sees its own", async () => {
      const res = await request(app)
        .get('/users')
        .query({ limit: 200 })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      const ids = res.body.data.map((u: { id: string }) => u.id);
      expect(ids).not.toContain(otherUserId);

      // The other tenant's own token DOES see its user — proves the scoping
      // is per-tenant, not a global filter that happens to exclude it.
      const otherRes = await request(app)
        .get('/users')
        .set('Authorization', `Bearer ${otherManagerToken}`);
      expect(otherRes.status).toBe(200);
      const otherIds = otherRes.body.data.map((u: { id: string }) => u.id);
      expect(otherIds).toContain(otherUserId);
    });
  });
});
