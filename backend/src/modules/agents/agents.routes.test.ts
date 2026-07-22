import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('agents routes', () => {
  let clientId: string;
  let managerToken: string;
  let agentToken: string;

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
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.deleteMany({ where: { id: clientId } });
  });

  describe('GET /agents/activity', () => {
    const qs = '?from=2026-07-22T00:00:00Z&to=2026-07-23T00:00:00Z';

    it('returns 200 with agents for a manager', async () => {
      const res = await request(app)
        .get(`/agents/activity${qs}`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.agents)).toBe(true);
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
  });
});
