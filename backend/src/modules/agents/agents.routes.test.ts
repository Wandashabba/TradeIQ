import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';

describe('agents routes', () => {
  let clientId: string;
  let otherClientId: string;
  let managerToken: string;
  let agentToken: string;
  let agentId: string;
  let otherAgentId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'AGTR-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'AGTR-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const agent = await prisma.user.create({
      data: { email: 'AGTR-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    // A second tenant, used only by the isolation test below — a manager on
    // AGTR-Client must never see this tenant's agents in the response body.
    const otherClient = await prisma.client.create({
      data: { name: 'AGTR-Other-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;

    const otherAgent = await prisma.user.create({
      data: {
        email: 'AGTR-other-agent@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    otherAgentId = otherAgent.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
  });

  describe('GET /agents/activity', () => {
    const qs = '?from=2026-07-22T00:00:00Z&to=2026-07-23T00:00:00Z';

    it('returns 200 with the single field agent in the tenant, idle and stop-free', async () => {
      const res = await request(app)
        .get(`/agents/activity${qs}`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(res.body.data).toEqual([
        {
          agentId,
          // No display name set, so the label falls back to the email (#280).
          name: 'AGTR-agent@example.com',
          displayName: null,
          email: 'AGTR-agent@example.com',
          state: 'idle',
          currentOutlet: null,
          lastSeenAt: null,
          stops: [],
        },
      ]);
      expect(res.body.nextCursor).toBeNull();
    });

    it('refuses a field agent', async () => {
      const res = await request(app)
        .get(`/agents/activity${qs}`)
        .set('Authorization', `Bearer ${agentToken}`);
      expect(res.status).toBe(403);
    });

    it('requires both from and to', async () => {
      const res = await request(app)
        .get('/agents/activity?from=2026-07-22T00:00:00Z')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });

    it('rejects a malformed instant', async () => {
      const res = await request(app)
        .get('/agents/activity?from=yesterday&to=2026-07-23T00:00:00Z')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });

    // A bare calendar date has no time-of-day and no offset — `new Date()`
    // would silently treat it as UTC midnight, which is exactly the
    // server-side timezone reasoning this endpoint is designed never to do.
    it('rejects a bare calendar date with no time component', async () => {
      const res = await request(app)
        .get('/agents/activity?from=2026-07-22&to=2026-07-23T00:00:00Z')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });

    // No `Z` and no numeric offset — `new Date()` would parse this against
    // the server process's local `TZ`, not the manager's. Must be rejected
    // rather than silently resolved to some timezone nobody chose.
    it('rejects an instant with no timezone offset', async () => {
      const res = await request(app)
        .get('/agents/activity?from=2026-07-22T00:00&to=2026-07-23T00:00:00Z')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });

    it('rejects an inverted range', async () => {
      const res = await request(app)
        .get('/agents/activity?from=2026-07-23T00:00:00Z&to=2026-07-22T00:00:00Z')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });

    // The 48h cap is the second bound, alongside the paged agent list (#141).
    it('rejects a range wider than 48 hours', async () => {
      const res = await request(app)
        .get('/agents/activity?from=2026-07-01T00:00:00Z&to=2026-07-30T00:00:00Z')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });

    it("never returns another tenant's agents", async () => {
      const res = await request(app)
        .get(`/agents/activity${qs}`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      const agentIds = (res.body.data as Array<{ agentId: string }>).map((a) => a.agentId);
      expect(agentIds).not.toContain(otherAgentId);
      expect(agentIds).toEqual([agentId]);
    });

    // The client-facing contract is a Territory.id (matching every other
    // dashboard endpoint) — see the comment in agents.service.ts.
    it('scopes results to agents assigned to the given territory', async () => {
      const territory = await prisma.territory.create({
        data: { clientId, name: 'AGTR-Territory', code: 'AGTR-TC1' },
      });
      await prisma.userTerritory.create({ data: { userId: agentId, territoryId: territory.id } });

      try {
        const res = await request(app)
          .get(`/agents/activity${qs}&territoryId=${territory.id}`)
          .set('Authorization', `Bearer ${managerToken}`);
        expect(res.status).toBe(200);
        expect((res.body.data as Array<{ agentId: string }>).map((a) => a.agentId)).toEqual([
          agentId,
        ]);
      } finally {
        await prisma.userTerritory.deleteMany({ where: { territoryId: territory.id } });
        await prisma.territory.delete({ where: { id: territory.id } });
      }
    });

    // #153: an id sent, a code matched, silently returning zero agents. Pins
    // the contract in the other direction so this cannot regress.
    it('returns no agents when a territory code is passed instead of its id', async () => {
      const territory = await prisma.territory.create({
        data: { clientId, name: 'AGTR-Territory-2', code: 'AGTR-TC2' },
      });
      await prisma.userTerritory.create({ data: { userId: agentId, territoryId: territory.id } });

      try {
        const res = await request(app)
          .get(`/agents/activity${qs}&territoryId=${territory.code}`)
          .set('Authorization', `Bearer ${managerToken}`);
        expect(res.status).toBe(200);
        expect((res.body.data as Array<{ agentId: string }>).map((a) => a.agentId)).toEqual([]);
      } finally {
        await prisma.userTerritory.deleteMany({ where: { territoryId: territory.id } });
        await prisma.territory.delete({ where: { id: territory.id } });
      }
    });

    it('pages a second agent via the cursor from the first page', async () => {
      const agent2 = await prisma.user.create({
        data: { email: 'AGTR-agent2@example.com', passwordHash: 'x', role: 'field_agent', clientId },
      });

      try {
        const first = await request(app)
          .get(`/agents/activity${qs}&limit=1`)
          .set('Authorization', `Bearer ${managerToken}`);
        expect(first.status).toBe(200);
        expect(first.body.data).toHaveLength(1);
        expect(first.body.nextCursor).not.toBeNull();

        const second = await request(app)
          .get(`/agents/activity${qs}&limit=1&cursor=${first.body.nextCursor}`)
          .set('Authorization', `Bearer ${managerToken}`);
        expect(second.status).toBe(200);
        expect(second.body.data).toHaveLength(1);
        expect(second.body.data[0].agentId).not.toBe(first.body.data[0].agentId);
        expect(second.body.nextCursor).toBeNull();
      } finally {
        await prisma.user.delete({ where: { id: agent2.id } });
      }
    });
  });
});
