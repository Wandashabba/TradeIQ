import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';

import { userIn } from '../../test-utils/tenants';

describe('outlets routes', () => {
  let clientId: string;
  let token: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'Test Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    clientId = client.id;
    token = (await userIn(clientId, 'manager')).token;

    // Outlet creation now requires territoryId to name a real territory of the
    // caller's client, so the territory these tests post has to exist.
    await prisma.territory.create({
      data: { clientId, name: 'Territory One', code: 'territory-1' },
    });
  });

  afterAll(async () => {
    await prisma.outlet.deleteMany({ where: { clientId } });
    // Assignments reference territories, so they go first — the ?mine=true
    // tests create them.
    await prisma.userTerritory.deleteMany({
      where: { territory: { clientId } },
    });
    await prisma.territory.deleteMany({ where: { clientId } });
    // userIn() puts a real user in this tenant now, and the FK blocks
    // deleting a client that still has one.
    await prisma.user.deleteMany({ where: { clientId: clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('creates and lists outlets for the caller\'s client', async () => {
    const createRes = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Test Hypermarket',
        code: 'TH-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
        teamProfile: { headcount: 3 },
      });

    expect(createRes.status).toBe(201);
    expect(createRes.body.name).toBe('Test Hypermarket');

    const listRes = await request(app)
      .get('/outlets')
      .set('Authorization', `Bearer ${token}`);

    expect(listRes.status).toBe(200);
    expect(listRes.body.data).toHaveLength(1);
    expect(listRes.body.data[0].code).toBe('TH-001');
  });

  it('creates an outlet with 201 when teamProfile is omitted', async () => {
    const res = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'No Team Profile Outlet',
        code: 'NTP-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
      });

    expect(res.status).toBe(201);
    expect(res.body.teamProfile).toBeNull();
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/outlets');
    expect(res.status).toBe(401);
  });

  it('forbids a field agent from creating an outlet with 403', async () => {
    const agentToken = (await userIn(clientId, 'field_agent')).token;
    const res = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({
        name: 'Agent Outlet',
        code: 'AGT-403',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
      });

    expect(res.status).toBe(403);

    const outlets = await prisma.outlet.findMany({ where: { code: 'AGT-403' } });
    expect(outlets).toHaveLength(0);
  });

  it('rejects outlet creation with a missing required field', async () => {
    const res = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code: 'MISSING-NAME',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
        teamProfile: {},
      });

    expect(res.status).toBe(400);
  });

  it('rejects a duplicate outlet code with 409', async () => {
    const payload = {
      name: 'Duplicate Outlet',
      code: 'DUP-001',
      channelType: 'hypermarket',
      lat: -26.2041,
      lng: 28.0473,
      territoryId: 'territory-1',
      teamProfile: {},
    };

    const firstRes = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send(payload);
    expect(firstRes.status).toBe(201);

    const secondRes = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send(payload);
    expect(secondRes.status).toBe(409);
  });

  it('rejects an outlet whose territory does not exist', async () => {
    // Previously accepted with 201. The outlet was then silently absent from
    // coverage counts and every territory-scoped view, with nothing to explain
    // why — the failure looked like missing data, not bad input.
    const res = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Typo Outlet',
        code: 'TYPO-001',
        channelType: 'convenience',
        lat: -26.1,
        lng: 28.0,
        territoryId: 'terrritory-1',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('terrritory-1');
  });

  it('rejects a territory NAME where a code is required', async () => {
    // The mistake seen in real use: an outlet created against territory
    // "Hurlingham" whose actual code was "2773u". Looks right to a human,
    // matches nothing.
    const res = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Name Not Code',
        code: 'NNC-001',
        channelType: 'convenience',
        lat: -26.1,
        lng: 28.0,
        territoryId: 'Territory One',
      });

    expect(res.status).toBe(400);
    // The message has to name the distinction, or the caller retries the same
    // string and concludes the API is broken.
    expect(res.body.error).toContain('code');
  });

  it('rejects a territory belonging to a different client', async () => {
    const clientC = await prisma.client.create({
      data: {
        name: 'Third Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    await prisma.territory.create({
      data: { clientId: clientC.id, name: 'Foreign', code: 'foreign-territory' },
    });

    try {
      const res = await request(app)
        .post('/outlets')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Cross Tenant',
          code: 'XT-001',
          channelType: 'convenience',
          lat: -26.1,
          lng: 28.0,
          territoryId: 'foreign-territory',
        });

      // The lookup is scoped by clientId, so another tenant's territory code is
      // as unknown as one that does not exist anywhere.
      expect(res.status).toBe(400);
    } finally {
      await prisma.territory.deleteMany({ where: { clientId: clientC.id } });
      // userIn() puts a real user in this tenant now, and the FK blocks
      // deleting a client that still has one.
      await prisma.user.deleteMany({ where: { clientId: clientC.id } });
      await prisma.client.delete({ where: { id: clientC.id } });
    }
  });

  it('lets a different tenant reuse the same outlet code', async () => {
    // The bug this closes. `code` was globally unique, so the first tenant to
    // register 'SHARED-001' made it permanently unavailable to everyone else —
    // and the 409 told them somebody they cannot see already holds it, which
    // is a cross-tenant existence oracle. Territory already scoped its code
    // per client; Outlet did not.
    const payload = {
      name: 'Shared Code Outlet',
      code: 'SHARED-001',
      channelType: 'hypermarket',
      lat: -26.2041,
      lng: 28.0473,
      territoryId: 'territory-1',
    };

    const mine = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send(payload);
    expect(mine.status).toBe(201);

    const otherClient = await prisma.client.create({
      data: {
        name: 'Code Reuse Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    await prisma.territory.create({
      data: { clientId: otherClient.id, name: 'Theirs', code: 'territory-1' },
    });
    const theirToken = (await userIn(otherClient.id, 'manager')).token;

    try {
      const theirs = await request(app)
        .post('/outlets')
        .set('Authorization', `Bearer ${theirToken}`)
        .send(payload);

      expect(theirs.status).toBe(201);
    } finally {
      await prisma.outlet.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.territory.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.user.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.client.delete({ where: { id: otherClient.id } });
    }
  });

  describe('?mine=true — assigned territories', () => {
    it('narrows the list to the caller\'s territories', async () => {
      const agent = await userIn(clientId, 'field_agent');
      const mineTerritory = await prisma.territory.create({
        data: { clientId, name: 'Mine', code: 'mine-code' },
      });
      await prisma.territory.create({
        data: { clientId, name: 'Theirs', code: 'theirs-code' },
      });
      await prisma.userTerritory.create({
        data: { userId: agent.userId, territoryId: mineTerritory.id },
      });

      await prisma.outlet.createMany({
        data: [
          { name: 'In My Patch', code: 'MINE-1', channelType: 'convenience', lat: -26.1, lng: 28.0, territoryId: 'mine-code', clientId },
          { name: 'Someone Else', code: 'THEIRS-1', channelType: 'convenience', lat: -26.2, lng: 28.1, territoryId: 'theirs-code', clientId },
        ],
      });

      const res = await request(app)
        .get('/outlets?mine=true')
        .set('Authorization', `Bearer ${agent.token}`);

      expect(res.status).toBe(200);
      const names = (res.body.data as Array<{ name: string }>).map((o) => o.name);
      expect(names).toContain('In My Patch');
      expect(names).not.toContain('Someone Else');
    });

    it('matches on territory CODE, not id', async () => {
      // The trap. Outlet.territoryId stores a Territory *code*; a filter
      // written against Territory.id matches nothing and degrades to an empty
      // list rather than erroring — which is exactly how #97 shipped a
      // dashboard filter that silently returned all-zero KPIs.
      const agent = await userIn(clientId, 'field_agent');
      const territory = await prisma.territory.create({
        data: { clientId, name: 'Code Not Id', code: 'code-not-id' },
      });
      await prisma.userTerritory.create({
        data: { userId: agent.userId, territoryId: territory.id },
      });
      await prisma.outlet.create({
        data: { name: 'Found By Code', code: 'CBC-1', channelType: 'convenience', lat: -26.1, lng: 28.0, territoryId: 'code-not-id', clientId },
      });

      const res = await request(app)
        .get('/outlets?mine=true')
        .set('Authorization', `Bearer ${agent.token}`);

      // If this returns [] the filter is matching on id.
      expect((res.body.data as unknown[]).length).toBeGreaterThan(0);
      expect((res.body.data as Array<{ name: string }>).map((o) => o.name)).toContain('Found By Code');
    });

    it('falls back to every outlet when the agent has no assignments', async () => {
      // An empty roster almost always means nobody has set assignments up yet,
      // not that this agent is meant to visit nothing. Returning an empty list
      // would strand them with no way to work and no explanation.
      const agent = await userIn(clientId, 'field_agent');

      const res = await request(app)
        .get('/outlets?mine=true')
        .set('Authorization', `Bearer ${agent.token}`);

      expect(res.status).toBe(200);
      expect((res.body.data as unknown[]).length).toBeGreaterThan(0);
    });

    it('still returns everything without the flag', async () => {
      // The narrowing is a filter the caller asks for, never a wall. An agent
      // covering a colleague's patch must still be able to reach that outlet.
      const agent = await userIn(clientId, 'field_agent');
      const territory = await prisma.territory.create({
        data: { clientId, name: 'Narrow', code: 'narrow-code' },
      });
      await prisma.userTerritory.create({
        data: { userId: agent.userId, territoryId: territory.id },
      });

      const scoped = await request(app)
        .get('/outlets?mine=true')
        .set('Authorization', `Bearer ${agent.token}`);
      const all = await request(app)
        .get('/outlets')
        .set('Authorization', `Bearer ${agent.token}`);

      expect((all.body.data as unknown[]).length).toBeGreaterThan(
        (scoped.body.data as unknown[]).length,
      );
    });
  });

  it('does not leak outlets across clients', async () => {
    const clientB = await prisma.client.create({
      data: {
        name: 'Other Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    const tokenB = (await userIn(clientB.id, 'manager')).token;
    await prisma.territory.create({
      data: { clientId: clientB.id, name: 'Territory Two', code: 'territory-2' },
    });

    try {
      const createResB = await request(app)
        .post('/outlets')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({
          name: 'Client B Outlet',
          code: 'CB-001',
          channelType: 'convenience',
          lat: -25.7461,
          lng: 28.1881,
          territoryId: 'territory-2',
          teamProfile: {},
        });
      expect(createResB.status).toBe(201);

      const listResA = await request(app)
        .get('/outlets')
        .set('Authorization', `Bearer ${token}`);

      expect(listResA.status).toBe(200);
      expect(listResA.body.data.some((outlet: { code: string }) => outlet.code === 'CB-001')).toBe(false);
    } finally {
      await prisma.outlet.deleteMany({ where: { clientId: clientB.id } });
      await prisma.territory.deleteMany({ where: { clientId: clientB.id } });
      // userIn() puts a real user in this tenant now, and the FK blocks
      // deleting a client that still has one.
      await prisma.user.deleteMany({ where: { clientId: clientB.id } });
      await prisma.client.delete({ where: { id: clientB.id } });
    }
  });

  describe('GET /outlets pagination', () => {
    const pagedOutletIds: string[] = [];
    const PAGE_SEED_COUNT = 25;

    beforeAll(async () => {
      // Distinct, sortable names (zero-padded so lexical order == numeric
      // order) and enough rows to require three pages at limit=10.
      for (let i = 0; i < PAGE_SEED_COUNT; i++) {
        const padded = String(i).padStart(2, '0');
        const outlet = await prisma.outlet.create({
          data: {
            name: `zzz-paging-outlet-${padded}`,
            code: `OUT-PAGE-${padded}`,
            channelType: 'convenience',
            lat: -26.1,
            lng: 28.0,
            territoryId: 'territory-1',
            clientId,
          },
        });
        pagedOutletIds.push(outlet.id);
      }
    });

    it('returns an envelope with data and nextCursor, alphabetical by name', async () => {
      const res = await request(app)
        .get('/outlets')
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('nextCursor');
      const names = (res.body.data as Array<{ name: string }>)
        .map((o) => o.name)
        .filter((n) => n.startsWith('zzz-paging-outlet-'));
      expect(names).toEqual([...names].sort());
    });

    it('default page size caps the result at 50', async () => {
      const res = await request(app)
        .get('/outlets')
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.data.length).toBeLessThanOrEqual(50);
    });

    it('honours ?limit=N', async () => {
      const res = await request(app)
        .get('/outlets')
        .query({ limit: 5 })
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(5);
      expect(res.body.nextCursor).not.toBeNull();
    });

    it.each([['0'], ['abc'], ['-1']])('rejects ?limit=%s with 400', async (limit) => {
      const res = await request(app)
        .get('/outlets')
        .query({ limit })
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(400);
    });

    it('pages through with no gap and no overlap across the seeded set', async () => {
      const seen: string[] = [];
      let cursor: string | undefined;
      let guard = 0;

      do {
        const res: request.Response = await request(app)
          .get('/outlets')
          .query({
            limit: 10,
            ...(cursor ? { cursor } : {}),
          })
          .set('Authorization', `Bearer ${token}`);
        expect(res.status).toBe(200);
        seen.push(...res.body.data.map((o: { id: string }) => o.id));
        cursor = res.body.nextCursor ?? undefined;
        guard++;
      } while (cursor && guard < 20);

      // No overlap: every id appears exactly once across all pages.
      expect(new Set(seen).size).toBe(seen.length);
      // No gap: every seeded id was eventually returned somewhere.
      for (const id of pagedOutletIds) {
        expect(seen).toContain(id);
      }
    });

    it("never returns another client's outlets even across pages, and that client's own token sees its own", async () => {
      const otherClient = await prisma.client.create({
        data: {
          name: 'Paging Other Client',
          industry: 'FMCG',
          scorecardWeights: {},
          kpiThresholds: {},
        },
      });
      const otherToken = (await userIn(otherClient.id, 'manager')).token;
      await prisma.territory.create({
        data: { clientId: otherClient.id, name: 'Other Territory', code: 'other-territory' },
      });
      const otherOutlet = await prisma.outlet.create({
        data: {
          name: 'zzz-other-tenant-outlet',
          code: 'OUT-OTHER-PAGE',
          channelType: 'convenience',
          lat: -26.1,
          lng: 28.0,
          territoryId: 'other-territory',
          clientId: otherClient.id,
        },
      });

      try {
        const res = await request(app)
          .get('/outlets')
          .query({ limit: 200 })
          .set('Authorization', `Bearer ${token}`);
        expect(res.status).toBe(200);
        const ids = res.body.data.map((o: { id: string }) => o.id);
        expect(ids).not.toContain(otherOutlet.id);

        // The other tenant's own token DOES see its outlet — proves the
        // scoping is per-tenant, not a global filter that happens to exclude it.
        const otherRes = await request(app)
          .get('/outlets')
          .set('Authorization', `Bearer ${otherToken}`);
        expect(otherRes.status).toBe(200);
        const otherIds = otherRes.body.data.map((o: { id: string }) => o.id);
        expect(otherIds).toContain(otherOutlet.id);
      } finally {
        await prisma.outlet.deleteMany({ where: { clientId: otherClient.id } });
        await prisma.territory.deleteMany({ where: { clientId: otherClient.id } });
        await prisma.user.deleteMany({ where: { clientId: otherClient.id } });
        await prisma.client.delete({ where: { id: otherClient.id } });
      }
    });
  });

  // ── ?territoryId= — "only show the store on that territory" ──────────────
  //
  // The owner's words, and the reason the whole filter exists. Every test in
  // here is written against the same trap: `Outlet.territoryId` stores a
  // Territory *code* and the filter takes a Territory *id*, with no foreign
  // key between them, so an implementation that matches the wrong one does not
  // throw — it returns a plausible list. That is #97's shape, and a plausible
  // wrong list of shops is what a manager plans a day against.
  describe('?territoryId= — one territory', () => {
    let northId: string;
    let southId: string;

    beforeAll(async () => {
      const north = await prisma.territory.create({
        data: { clientId, name: 'Scoped North', code: 'scoped-north' },
      });
      const south = await prisma.territory.create({
        data: { clientId, name: 'Scoped South', code: 'scoped-south' },
      });
      northId = north.id;
      southId = south.id;

      await prisma.outlet.createMany({
        data: [
          { name: 'North Spaza', code: 'SCOPE-N1', channelType: 'convenience', lat: -26.1, lng: 28.0, territoryId: 'scoped-north', clientId },
          { name: 'North Hyper', code: 'SCOPE-N2', channelType: 'hypermarket', lat: -26.2, lng: 28.1, territoryId: 'scoped-north', clientId },
          { name: 'South Spaza', code: 'SCOPE-S1', channelType: 'convenience', lat: -26.3, lng: 28.2, territoryId: 'scoped-south', clientId },
        ],
      });
    });

    it('returns only that territory\'s outlets', async () => {
      const res = await request(app)
        .get('/outlets')
        .query({ territoryId: northId, limit: 200 })
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      const codes = (res.body.data as Array<{ code: string }>).map((o) => o.code);
      expect(codes).toEqual(expect.arrayContaining(['SCOPE-N1', 'SCOPE-N2']));
      expect(codes).not.toContain('SCOPE-S1');
      // And nothing from any other territory in the tenant — this is the
      // owner's complaint verbatim: "not everything else". The seeded paging
      // outlets and the ?mine= fixtures all live elsewhere, so an unfiltered
      // query here would be dozens of rows.
      expect(codes).toHaveLength(2);
    });

    it('resolves the id to a CODE rather than matching the column on id', async () => {
      // If the filter matched `Outlet.territoryId` against the uuid it was
      // handed, this returns [] — a silent empty list that reads as "this
      // territory has no stores". That is the way #97 shipped.
      const res = await request(app)
        .get('/outlets')
        .query({ territoryId: northId })
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect((res.body.data as unknown[]).length).toBeGreaterThan(0);
    });

    it('rejects an unknown territory with 400 rather than ignoring the filter', async () => {
      // The failure this endpoint must never have. An ignored filter hands
      // back every store in the tenant underneath a chip naming one territory,
      // and the manager cannot see that it was ignored.
      const res = await request(app)
        .get('/outlets')
        .query({ territoryId: 'no-such-territory-id' })
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(400);
      expect(res.body.error).toContain('no-such-territory-id');
      expect(res.body.data).toBeUndefined();
    });

    it('rejects a territory CODE where an id is required', async () => {
      // The id/code confusion from the other side. A code silently matching
      // nothing would be indistinguishable from an empty territory.
      const res = await request(app)
        .get('/outlets')
        .query({ territoryId: 'scoped-north' })
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(400);
      expect(res.body.error).toContain('id');
    });

    it('rejects a bare ?territoryId= rather than treating it as unscoped', async () => {
      const res = await request(app)
        .get('/outlets')
        .query({ territoryId: '' })
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(400);
    });

    it('rejects a repeated ?territoryId= rather than picking one', async () => {
      const res = await request(app)
        .get('/outlets?territoryId=a&territoryId=b')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(400);
    });

    it('rejects another tenant\'s territory, and never leaks its outlets', async () => {
      const otherClient = await prisma.client.create({
        data: { name: 'Scoped Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
      });
      const foreign = await prisma.territory.create({
        data: { clientId: otherClient.id, name: 'Foreign Scope', code: 'foreign-scope' },
      });
      await prisma.outlet.create({
        data: { name: 'Foreign Store', code: 'SCOPE-F1', channelType: 'convenience', lat: -26.1, lng: 28.0, territoryId: 'foreign-scope', clientId: otherClient.id },
      });

      try {
        const res = await request(app)
          .get('/outlets')
          .query({ territoryId: foreign.id })
          .set('Authorization', `Bearer ${token}`);

        // The lookup is scoped by clientId, so another tenant's territory id is
        // exactly as unknown as one that exists nowhere — same status, same
        // sentence. A 404 here against a 400 there would tell this caller that
        // an id they cannot see does exist somewhere.
        expect(res.status).toBe(400);
        expect(res.body.data).toBeUndefined();
      } finally {
        await prisma.outlet.deleteMany({ where: { clientId: otherClient.id } });
        await prisma.territory.deleteMany({ where: { clientId: otherClient.id } });
        await prisma.user.deleteMany({ where: { clientId: otherClient.id } });
        await prisma.client.delete({ where: { id: otherClient.id } });
      }
    });

    it('composes with ?mine=true as an intersection', async () => {
      const agent = await userIn(clientId, 'field_agent');
      await prisma.userTerritory.create({
        data: { userId: agent.userId, territoryId: northId },
      });

      const inPatch = await request(app)
        .get('/outlets')
        .query({ mine: 'true', territoryId: northId, limit: 200 })
        .set('Authorization', `Bearer ${agent.token}`);
      expect(inPatch.status).toBe(200);
      expect((inPatch.body.data as Array<{ code: string }>).map((o) => o.code).sort()).toEqual([
        'SCOPE-N1',
        'SCOPE-N2',
      ]);

      // A territory the agent is not assigned: the honest answer to "my stores
      // in Scoped South" is none, not "all of Scoped South" and not "all of my
      // stores". Neither half of the narrowing may win over the other.
      const outOfPatch = await request(app)
        .get('/outlets')
        .query({ mine: 'true', territoryId: southId, limit: 200 })
        .set('Authorization', `Bearer ${agent.token}`);
      expect(outOfPatch.status).toBe(200);
      expect(outOfPatch.body.data).toEqual([]);
      expect(outOfPatch.body.nextCursor).toBeNull();
    });

    it('composes with pagination, with no gap and no overlap', async () => {
      const territory = await prisma.territory.create({
        data: { clientId, name: 'Scoped Paging', code: 'scoped-paging' },
      });
      const seeded: string[] = [];
      for (let i = 0; i < 7; i++) {
        const padded = String(i).padStart(2, '0');
        const outlet = await prisma.outlet.create({
          data: {
            name: `zzz-scoped-paging-${padded}`,
            code: `SCOPE-P-${padded}`,
            channelType: 'convenience',
            lat: -26.1,
            lng: 28.0,
            territoryId: 'scoped-paging',
            clientId,
          },
        });
        seeded.push(outlet.id);
      }

      const seen: string[] = [];
      let cursor: string | undefined;
      let guard = 0;
      do {
        const res: request.Response = await request(app)
          .get('/outlets')
          .query({ territoryId: territory.id, limit: 3, ...(cursor ? { cursor } : {}) })
          .set('Authorization', `Bearer ${token}`);
        expect(res.status).toBe(200);
        seen.push(...res.body.data.map((o: { id: string }) => o.id));
        cursor = res.body.nextCursor ?? undefined;
        guard++;
      } while (cursor && guard < 10);

      // The filter has to survive the cursor. A `where` rebuilt without it on
      // page two would quietly widen to the whole tenant halfway down a list.
      expect(new Set(seen).size).toBe(seen.length);
      expect(seen.sort()).toEqual([...seeded].sort());
    });

    it('does not swallow an outlet whose territoryId holds a NAME', async () => {
      // #97's second incident, pinned. An outlet was created in production with
      // territoryId "Hurlingham" — the territory's *name* — while its code was
      // "2773u". `createOutlet` refuses that now, but imported and legacy rows
      // still carry it, and a filter is the screen where such a store vanishes.
      //
      // Two halves, and the second is the one that matters. The filter must not
      // match on name (or the mis-filed row would appear under a territory it
      // is not in, which is the same lie as the unfiltered list). And the
      // UNSCOPED list must still show it — the filter narrows, it does not
      // delete, and the full list is the only place a mis-filed store can be
      // noticed and corrected.
      const stray = await prisma.territory.create({
        data: { clientId, name: 'Hurlingham Scope', code: '2773u-scope' },
      });
      const orphan = await prisma.outlet.create({
        data: {
          name: 'Mis-filed Corner Store',
          code: 'SCOPE-ORPHAN',
          channelType: 'convenience',
          lat: -26.1,
          lng: 28.0,
          // The NAME, not the code — exactly what the incident wrote.
          territoryId: 'Hurlingham Scope',
          clientId,
        },
      });

      const scoped = await request(app)
        .get('/outlets')
        .query({ territoryId: stray.id, limit: 200 })
        .set('Authorization', `Bearer ${token}`);
      expect(scoped.status).toBe(200);
      expect((scoped.body.data as Array<{ id: string }>).map((o) => o.id)).not.toContain(orphan.id);

      const unscoped = await request(app)
        .get('/outlets')
        .query({ limit: 200 })
        .set('Authorization', `Bearer ${token}`);
      expect(unscoped.status).toBe(200);
      expect((unscoped.body.data as Array<{ id: string }>).map((o) => o.id)).toContain(orphan.id);
    });
  });
});
