import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';
import { userIn } from '../../test-utils/tenants';

describe('templates routes', () => {
  let clientId: string;
  let managerToken: string;
  let agentToken: string;

  const sampleSchema = {
    sections: [
      {
        id: 'availability',
        fields: [{ id: 'onShelf', type: 'boolean', label: 'On shelf?' }],
      },
    ],
    scoring: { onShelf: 10 },
  };

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'TMPL-Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'tmpl-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const agent = await prisma.user.create({
      data: { email: 'tmpl-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
  });

  afterAll(async () => {
    await prisma.auditTemplate.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('creates a template at version 1 (201)', async () => {
    const res = await request(app)
      .post('/templates')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'TMPL-Standard Audit', schema: sampleSchema, industry: 'FMCG' });

    expect(res.status).toBe(201);
    expect(res.body.name).toBe('TMPL-Standard Audit');
    expect(res.body.version).toBe(1);
    expect(res.body.active).toBe(true);
    expect(res.body.schema).toEqual(sampleSchema);
  });

  it('rejects create with a missing name (400)', async () => {
    const res = await request(app)
      .post('/templates')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ schema: sampleSchema });
    expect(res.status).toBe(400);
  });

  it('rejects create with a missing schema (400)', async () => {
    const res = await request(app)
      .post('/templates')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'TMPL-No Schema' });
    expect(res.status).toBe(400);
  });

  it('rejects create with a non-object schema (400)', async () => {
    const res = await request(app)
      .post('/templates')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'TMPL-Bad Schema', schema: 'not-an-object' });
    expect(res.status).toBe(400);
  });

  it('returns 403 for a field agent creating a template', async () => {
    const res = await request(app)
      .post('/templates')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ name: 'TMPL-Agent Attempt', schema: sampleSchema });
    expect(res.status).toBe(403);
  });

  it('returns 401 without a bearer token', async () => {
    const res = await request(app).get('/templates');
    expect(res.status).toBe(401);
  });

  it('lists only active templates by default and includes inactive with includeInactive=true', async () => {
    const active = await prisma.auditTemplate.create({
      data: { clientId, name: 'TMPL-Active One', schema: sampleSchema },
    });
    const inactive = await prisma.auditTemplate.create({
      data: { clientId, name: 'TMPL-Inactive One', schema: sampleSchema, active: false },
    });

    const defaultRes = await request(app)
      .get('/templates')
      .set('Authorization', `Bearer ${agentToken}`);
    expect(defaultRes.status).toBe(200);
    const defaultIds = (defaultRes.body.data as Array<{ id: string }>).map((t) => t.id);
    expect(defaultIds).toContain(active.id);
    expect(defaultIds).not.toContain(inactive.id);

    const allRes = await request(app)
      .get('/templates?includeInactive=true')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(allRes.status).toBe(200);
    const allIds = (allRes.body.data as Array<{ id: string }>).map((t) => t.id);
    expect(allIds).toContain(active.id);
    expect(allIds).toContain(inactive.id);
  });

  it('gets a template by id (200) and 404s across tenants', async () => {
    const template = await prisma.auditTemplate.create({
      data: { clientId, name: 'TMPL-Fetch Me', schema: sampleSchema },
    });

    const okRes = await request(app)
      .get(`/templates/${template.id}`)
      .set('Authorization', `Bearer ${agentToken}`);
    expect(okRes.status).toBe(200);
    expect(okRes.body.id).toBe(template.id);

    const otherClient = await prisma.client.create({
      data: { name: 'TMPL-Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const otherToken = (await userIn(otherClient.id, 'field_agent')).token;
    try {
      const crossRes = await request(app)
        .get(`/templates/${template.id}`)
        .set('Authorization', `Bearer ${otherToken}`);
      expect(crossRes.status).toBe(404);
    } finally {
      // The cross-tenant token belongs to a real user now, and the FK blocks
      // deleting a client that still has one.
      await prisma.user.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.client.delete({ where: { id: otherClient.id } });
    }
  });

  it('bumps version to 2 when the schema is patched', async () => {
    const template = await prisma.auditTemplate.create({
      data: { clientId, name: 'TMPL-Versioned', schema: sampleSchema },
    });

    const newSchema = { ...sampleSchema, scoring: { onShelf: 20 } };
    const res = await request(app)
      .patch(`/templates/${template.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ schema: newSchema });

    expect(res.status).toBe(200);
    expect(res.body.version).toBe(2);
    expect(res.body.schema).toEqual(newSchema);
  });

  it('does not bump version on a name-only patch', async () => {
    const template = await prisma.auditTemplate.create({
      data: { clientId, name: 'TMPL-Name Only', schema: sampleSchema },
    });

    const res = await request(app)
      .patch(`/templates/${template.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'TMPL-Renamed' });

    expect(res.status).toBe(200);
    expect(res.body.name).toBe('TMPL-Renamed');
    expect(res.body.version).toBe(1);
  });

  it('rejects an empty patch body (400)', async () => {
    const template = await prisma.auditTemplate.create({
      data: { clientId, name: 'TMPL-Empty Patch', schema: sampleSchema },
    });
    const res = await request(app)
      .patch(`/templates/${template.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('rejects a patch with a non-object schema (400)', async () => {
    const template = await prisma.auditTemplate.create({
      data: { clientId, name: 'TMPL-Bad Patch Schema', schema: sampleSchema },
    });
    const res = await request(app)
      .patch(`/templates/${template.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ schema: 42 });
    expect(res.status).toBe(400);
  });

  it('excludes a template from the default list once active=false is patched', async () => {
    const template = await prisma.auditTemplate.create({
      data: { clientId, name: 'TMPL-To Deactivate', schema: sampleSchema },
    });

    const patchRes = await request(app)
      .patch(`/templates/${template.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ active: false });
    expect(patchRes.status).toBe(200);
    expect(patchRes.body.active).toBe(false);

    const listRes = await request(app)
      .get('/templates')
      .set('Authorization', `Bearer ${agentToken}`);
    const ids = (listRes.body.data as Array<{ id: string }>).map((t) => t.id);
    expect(ids).not.toContain(template.id);
  });

  it('returns 403 for a field agent patching a template', async () => {
    const template = await prisma.auditTemplate.create({
      data: { clientId, name: 'TMPL-Guarded Patch', schema: sampleSchema },
    });
    const res = await request(app)
      .patch(`/templates/${template.id}`)
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ name: 'TMPL-Nope' });
    expect(res.status).toBe(403);
  });

  describe('GET /templates pagination', () => {
    const pagedTemplateIds: string[] = [];
    const PAGE_SEED_COUNT = 25;

    beforeAll(async () => {
      // Distinct, sortable names (zero-padded so lexical order == numeric
      // order) and enough rows to require three pages at limit=10.
      for (let i = 0; i < PAGE_SEED_COUNT; i++) {
        const padded = String(i).padStart(2, '0');
        const template = await prisma.auditTemplate.create({
          data: { clientId, name: `zzz-paging-template-${padded}`, schema: sampleSchema },
        });
        pagedTemplateIds.push(template.id);
      }
    });

    it('returns an envelope with data and nextCursor, alphabetical by name', async () => {
      const res = await request(app)
        .get('/templates')
        .query({ includeInactive: 'true' })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('nextCursor');
      const names = (res.body.data as Array<{ name: string }>)
        .map((t) => t.name)
        .filter((n) => n.startsWith('zzz-paging-template-'));
      expect(names).toEqual([...names].sort());
    });

    it('default page size caps the result at 50', async () => {
      const res = await request(app)
        .get('/templates')
        .query({ includeInactive: 'true' })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(res.body.data.length).toBeLessThanOrEqual(50);
    });

    it('honours ?limit=N', async () => {
      const res = await request(app)
        .get('/templates')
        .query({ includeInactive: 'true', limit: 5 })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(5);
      expect(res.body.nextCursor).not.toBeNull();
    });

    it.each([['0'], ['abc'], ['-1']])('rejects ?limit=%s with 400', async (limit) => {
      const res = await request(app)
        .get('/templates')
        .query({ includeInactive: 'true', limit })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });

    it('pages through with no gap and no overlap across the seeded set', async () => {
      const seen: string[] = [];
      let cursor: string | undefined;
      let guard = 0;

      do {
        const res: request.Response = await request(app)
          .get('/templates')
          .query({
            includeInactive: 'true',
            limit: 10,
            ...(cursor ? { cursor } : {}),
          })
          .set('Authorization', `Bearer ${managerToken}`);
        expect(res.status).toBe(200);
        seen.push(...res.body.data.map((t: { id: string }) => t.id));
        cursor = res.body.nextCursor ?? undefined;
        guard++;
      } while (cursor && guard < 20);

      // No overlap: every id appears exactly once across all pages.
      expect(new Set(seen).size).toBe(seen.length);
      // No gap: every seeded id was eventually returned somewhere.
      for (const id of pagedTemplateIds) {
        expect(seen).toContain(id);
      }
    });

    it("never returns another client's templates even across pages", async () => {
      const otherClient = await prisma.client.create({
        data: { name: 'TMPL-Paging Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
      });
      const otherToken = (await userIn(otherClient.id, 'manager')).token;
      const otherTemplate = await prisma.auditTemplate.create({
        data: { clientId: otherClient.id, name: 'zzz-other-tenant-template', schema: sampleSchema },
      });

      try {
        const res = await request(app)
          .get('/templates')
          .query({ includeInactive: 'true', limit: 200 })
          .set('Authorization', `Bearer ${managerToken}`);
        expect(res.status).toBe(200);
        const ids = res.body.data.map((t: { id: string }) => t.id);
        expect(ids).not.toContain(otherTemplate.id);

        // The other tenant's own token DOES see its template — proves the
        // scoping is per-tenant, not a global filter that happens to exclude it.
        const otherRes = await request(app)
          .get('/templates')
          .query({ includeInactive: 'true' })
          .set('Authorization', `Bearer ${otherToken}`);
        expect(otherRes.status).toBe(200);
        const otherIds = otherRes.body.data.map((t: { id: string }) => t.id);
        expect(otherIds).toEqual([otherTemplate.id]);
      } finally {
        await prisma.auditTemplate.deleteMany({ where: { clientId: otherClient.id } });
        await prisma.user.deleteMany({ where: { clientId: otherClient.id } });
        await prisma.client.delete({ where: { id: otherClient.id } });
      }
    });
  });
});
