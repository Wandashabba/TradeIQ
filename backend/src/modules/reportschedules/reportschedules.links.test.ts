import { createHmac } from 'node:crypto';
import request from 'supertest';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { DAY_MS } from './reportschedules.cadence';
import {
  REPORT_LINK_TTL_MS,
  reportDownloadPath,
  reportLinkSecret,
  signedReportLink,
  signReportLinkToken,
  verifyReportLinkToken,
} from './reportschedules.links';
import { runCsvForClient } from './reportschedules.service';

const SECRET = 'links-test-secret-0123456789abcdefghijkl';

describe('signed report links (#66)', () => {
  const claims = {
    clientId: 'client-a',
    scheduleId: 'schedule-a',
    runId: 'run-a',
    expiresAt: new Date('2026-09-22T06:00:00.000Z'),
  };
  const now = new Date('2026-09-15T06:00:00.000Z');

  it('a valid token verifies to exactly its claims', () => {
    const token = signReportLinkToken(SECRET, claims);
    expect(verifyReportLinkToken(SECRET, token, now)).toEqual({ ok: true, claims });
  });

  it('expires: good a second before expiry, refused at and after it', () => {
    const token = signReportLinkToken(SECRET, claims);
    const at = claims.expiresAt.getTime();
    expect(verifyReportLinkToken(SECRET, token, new Date(at - 1000)).ok).toBe(true);
    expect(verifyReportLinkToken(SECRET, token, new Date(at))).toEqual({ ok: false, reason: 'expired' });
    expect(verifyReportLinkToken(SECRET, token, new Date(at + DAY_MS))).toEqual({ ok: false, reason: 'expired' });
  });

  it('a payload swapped for another run, schedule, tenant or expiry fails the signature', () => {
    const [, signature] = signReportLinkToken(SECRET, claims).split('.');
    const forgeries = [
      { ...claims, runId: 'run-b' },
      { ...claims, scheduleId: 'schedule-b' },
      { ...claims, clientId: 'client-b' },
      { ...claims, expiresAt: new Date('2030-01-01T00:00:00.000Z') },
    ];
    for (const forged of forgeries) {
      // The payload half does not depend on the key, so this is exactly what
      // an attacker holding one real link could build.
      const [payload] = signReportLinkToken('any-key', forged).split('.');
      expect(verifyReportLinkToken(SECRET, `${payload}.${signature}`, now)).toEqual({
        ok: false,
        reason: 'bad_signature',
      });
    }
  });

  it('a tampered signature, or a token signed with another key, fails', () => {
    const token = signReportLinkToken(SECRET, claims);
    const [payload, signature] = token.split('.');
    const flipped = `${signature.slice(0, -1)}${signature.endsWith('A') ? 'B' : 'A'}`;
    expect(verifyReportLinkToken(SECRET, `${payload}.${flipped}`, now)).toEqual({ ok: false, reason: 'bad_signature' });
    expect(verifyReportLinkToken(`${SECRET}-rotated`, token, now)).toEqual({ ok: false, reason: 'bad_signature' });
  });

  it('malformed tokens are refused without being parsed', () => {
    for (const token of ['', 'abc', 'a.b.c', '.sig', 'payload.']) {
      expect(verifyReportLinkToken(SECRET, token, now)).toEqual({ ok: false, reason: 'malformed' });
    }
  });

  it('a correctly signed payload of the wrong version or shape is refused', () => {
    const signed = (body: unknown) => {
      const payload = Buffer.from(JSON.stringify(body)).toString('base64url');
      const sig = createHmac('sha256', SECRET).update(`report-csv.${payload}`).digest('base64url');
      return `${payload}.${sig}`;
    };
    const exp = Math.floor(claims.expiresAt.getTime() / 1000);
    expect(verifyReportLinkToken(SECRET, signed({ v: 2, c: 'c', s: 's', r: 'r', e: exp }), now).ok).toBe(false);
    expect(verifyReportLinkToken(SECRET, signed({ v: 1, c: 'c', s: 's', e: exp }), now).ok).toBe(false);
    expect(verifyReportLinkToken(SECRET, signed({ v: 1, c: 'c', s: 's', r: 'r', e: 'soon' }), now).ok).toBe(false);
    // Without the domain prefix: a signature over the same bytes for any other
    // purpose does not verify as a download token.
    const payload = Buffer.from(JSON.stringify({ v: 1, c: 'c', s: 's', r: 'r', e: exp })).toString('base64url');
    const undomained = createHmac('sha256', SECRET).update(payload).digest('base64url');
    expect(verifyReportLinkToken(SECRET, `${payload}.${undomained}`, now)).toEqual({ ok: false, reason: 'bad_signature' });
  });

  it('links need PUBLIC_API_URL and a REPORT_LINK_SECRET of at least 32 characters', () => {
    const run = { clientId: 'c', scheduleId: 's', runId: 'r', generatedAt: now };
    expect(signedReportLink(run, {})).toBeNull();
    expect(signedReportLink(run, { PUBLIC_API_URL: 'https://api.test' })).toBeNull();
    expect(signedReportLink(run, { REPORT_LINK_SECRET: SECRET })).toBeNull();
    expect(signedReportLink(run, { PUBLIC_API_URL: 'https://api.test', REPORT_LINK_SECRET: 'short' })).toBeNull();
    expect(reportLinkSecret({ REPORT_LINK_SECRET: 'short' })).toEqual({
      ok: false,
      reason: 'REPORT_LINK_SECRET is shorter than 32 characters',
    });

    const link = signedReportLink(run, { PUBLIC_API_URL: 'https://api.test/', REPORT_LINK_SECRET: SECRET })!;
    expect(link.expiresAt).toEqual(new Date(now.getTime() + REPORT_LINK_TTL_MS));
    expect(link.url.startsWith('https://api.test/report-downloads/')).toBe(true);
    // Fixed by the run, so the webhook and every email attempt carry the same link.
    expect(signedReportLink(run, { PUBLIC_API_URL: 'https://api.test', REPORT_LINK_SECRET: SECRET })).toEqual(link);
  });
});

describe('GET /report-downloads/:token (#66)', () => {
  let clientId: string;
  let otherClientId: string;
  let scheduleId: string;
  let runId: string;
  let secondRunId: string;
  let otherScheduleId: string;
  let otherRunId: string;
  let previousSecret: string | undefined;

  beforeAll(async () => {
    previousSecret = process.env.REPORT_LINK_SECRET;
    process.env.REPORT_LINK_SECRET = SECRET;

    const client = await prisma.client.create({
      data: { name: 'RDL-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const other = await prisma.client.create({
      data: { name: 'RDL-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = other.id;

    const agent = await prisma.user.create({
      data: { email: 'rdl-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    const outlet = await prisma.outlet.create({
      data: {
        name: 'RDL-Outlet',
        code: 'RDL-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date(Date.now() - 60 * 60_000),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });

    const makeScheduleWithRuns = async (owner: string, runs: number) => {
      const definition = await prisma.reportDefinition.create({
        data: { clientId: owner, name: 'RDL-Visits', type: 'visits', filters: {} },
      });
      const schedule = await prisma.reportSchedule.create({
        data: {
          clientId: owner,
          reportDefinitionId: definition.id,
          cadence: 'daily',
          recipients: ['ops@example.com'] as Prisma.InputJsonValue,
          nextRunAt: new Date(Date.now() + DAY_MS),
        },
      });
      const ids: string[] = [];
      for (let i = 0; i < runs; i += 1) {
        const run = await prisma.reportScheduleRun.create({
          data: {
            scheduleId: schedule.id,
            clientId: owner,
            trigger: 'manual',
            generatedAt: new Date(),
            rowCount: 1,
            deliveries: [],
          },
        });
        ids.push(run.id);
      }
      return { scheduleId: schedule.id, runIds: ids };
    };

    const mine = await makeScheduleWithRuns(clientId, 2);
    scheduleId = mine.scheduleId;
    [runId, secondRunId] = mine.runIds;
    const theirs = await makeScheduleWithRuns(otherClientId, 1);
    otherScheduleId = theirs.scheduleId;
    [otherRunId] = theirs.runIds;
  });

  afterAll(async () => {
    const clients = { in: [clientId, otherClientId] };
    await prisma.reportSchedule.deleteMany({ where: { clientId: clients } });
    await prisma.reportDefinition.deleteMany({ where: { clientId: clients } });
    await prisma.visit.deleteMany({ where: { clientId: clients } });
    await prisma.outlet.deleteMany({ where: { clientId: clients } });
    await prisma.user.deleteMany({ where: { clientId: clients } });
    await prisma.client.deleteMany({ where: { id: clients } });
    await prisma.$disconnect();
    if (previousSecret === undefined) delete process.env.REPORT_LINK_SECRET;
    else process.env.REPORT_LINK_SECRET = previousSecret;
  });

  const tokenFor = (overrides: Partial<{ clientId: string; scheduleId: string; runId: string; expiresAt: Date }> = {}) =>
    signReportLinkToken(SECRET, {
      clientId,
      scheduleId,
      runId,
      expiresAt: new Date(Date.now() + DAY_MS),
      ...overrides,
    });

  it('downloads the run CSV with no bearer token', async () => {
    const res = await request(app).get(reportDownloadPath(tokenFor()));
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/^text\/csv/);
    expect(res.headers['content-disposition']).toBe(`attachment; filename="report-${runId}.csv"`);
    expect(res.headers['cache-control']).toBe('private, no-store');
    const { csv } = await runCsvForClient(scheduleId, runId, clientId);
    expect(csv.split('\n')).toHaveLength(2);
    expect(res.text).toBe(csv);
  });

  it('an expired link is 410', async () => {
    const res = await request(app).get(reportDownloadPath(tokenFor({ expiresAt: new Date(Date.now() - 1000) })));
    expect(res.status).toBe(410);
    expect(res.body).toEqual({ error: 'This download link has expired' });
  });

  it('a tampered link is 401: its payload cannot be pointed at another run', async () => {
    const [, signature] = tokenFor().split('.');
    const [secondPayload] = tokenFor({ runId: secondRunId }).split('.');
    const res = await request(app).get(reportDownloadPath(`${secondPayload}.${signature}`));
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: 'Invalid download link' });
    expect((await request(app).get(reportDownloadPath('not-a-token'))).status).toBe(401);
  });

  it("a link naming another tenant, or pairing ids across tenants, opens nothing (404)", async () => {
    // Even correctly signed, the claims must name a real run of that tenant.
    const cases = [
      tokenFor({ clientId: otherClientId }),
      tokenFor({ runId: otherRunId }),
      tokenFor({ scheduleId: otherScheduleId, runId: otherRunId }),
      tokenFor({ scheduleId: otherScheduleId }),
    ];
    for (const token of cases) {
      const res = await request(app).get(reportDownloadPath(token));
      expect(res.status).toBe(404);
      expect(res.text).not.toContain('RDL');
    }
  });

  it("each run's link opens only that run", async () => {
    const res = await request(app).get(reportDownloadPath(tokenFor({ runId: secondRunId })));
    expect(res.status).toBe(200);
    expect(res.headers['content-disposition']).toBe(`attachment; filename="report-${secondRunId}.csv"`);
  });

  it('with REPORT_LINK_SECRET unset, no link works (401)', async () => {
    const token = tokenFor();
    delete process.env.REPORT_LINK_SECRET;
    try {
      expect((await request(app).get(reportDownloadPath(token))).status).toBe(401);
    } finally {
      process.env.REPORT_LINK_SECRET = SECRET;
    }
  });

  it('after rotating REPORT_LINK_SECRET, old links are 401', async () => {
    const token = tokenFor();
    process.env.REPORT_LINK_SECRET = `${SECRET}-rotated`;
    try {
      expect((await request(app).get(reportDownloadPath(token))).status).toBe(401);
    } finally {
      process.env.REPORT_LINK_SECRET = SECRET;
    }
  });
});
