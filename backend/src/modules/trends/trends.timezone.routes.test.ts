import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { userIn } from '../../test-utils/tenants';
import { bucketStart } from './trends.service';

/**
 * #309 — trend day/week buckets are the CLIENT's calendar, not UTC.
 *
 * Three tenants hold scorecards at deliberately awkward instants:
 *
 * SAST client (created without a timezone → Africa/Johannesburg, UTC+2):
 *   s1 2026-03-01T22:30Z  Mon 2 Mar 00:30 SAST  (UTC says Sunday 1 Mar)   60
 *   s2 2026-03-02T10:00Z  Mon 2 Mar 12:00 SAST                             80
 *   s3 2026-03-08T21:59Z  Sun 8 Mar 23:59 SAST  (last minute of the week) 100
 *
 * UTC client — the SAME three instants, so any difference is the zone alone.
 *
 * New York client, across the spring-forward change on Sun 8 Mar 2026:
 *   n1 2026-03-08T04:30Z  Sat 7 Mar 23:30 EST (-5)                         90
 *   n2 2026-03-09T03:30Z  Sun 8 Mar 23:30 EDT (-4)  (UTC says Monday 9th)  50
 *   n3 2026-03-09T04:30Z  Mon 9 Mar 00:30 EDT (-4)  (fixed -5 says Sunday) 70
 */
const S1 = new Date('2026-03-01T22:30:00.000Z');
const S2 = new Date('2026-03-02T10:00:00.000Z');
const S3 = new Date('2026-03-08T21:59:00.000Z');
const N1 = new Date('2026-03-08T04:30:00.000Z');
const N2 = new Date('2026-03-09T03:30:00.000Z');
const N3 = new Date('2026-03-09T04:30:00.000Z');

const day = (iso: string) => `${iso}T00:00:00.000Z`;

type Point = { period: string; value: number; count: number };
const points = (body: { points: Point[] }) =>
  body.points.map(({ period, value, count }) => ({ period, value, count }));

describe('trend buckets in the client timezone (#309)', () => {
  const tenants: string[] = [];
  let sast: { clientId: string; token: string };
  let utc: { clientId: string; token: string };
  let ny: { clientId: string; token: string };

  async function tenant(name: string, timezone: string | undefined, cards: Array<[Date, number]>) {
    const client = await prisma.client.create({
      data: {
        name: `TZTREND-${name}`,
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
        ...(timezone ? { timezone } : {}),
      },
    });
    tenants.push(client.id);
    const manager = await userIn(client.id, 'manager');
    const agent = await userIn(client.id, 'field_agent');
    const code = `tz-${name.toLowerCase()}`;
    await prisma.territory.create({ data: { clientId: client.id, name: `TZTREND ${name}`, code } });
    const outlet = await prisma.outlet.create({
      data: {
        name: `TZTREND ${name} outlet`,
        code: `TZTREND-${name}`,
        channelType: 'hypermarket',
        lat: -26.2,
        lng: 28.0,
        territoryId: code,
        clientId: client.id,
      },
    });
    for (const [at, weightedTotal] of cards) {
      const visit = await prisma.visit.create({
        data: {
          outletId: outlet.id,
          agentId: agent.userId,
          clientId: client.id,
          checkinTs: at,
          checkinLat: -26.2,
          checkinLng: 28.0,
          geofencePass: true,
          status: 'submitted',
        },
      });
      await prisma.scorecard.create({
        data: {
          visitId: visit.id,
          dimensionScores: {},
          weightedTotal,
          ratingBand: weightedTotal >= 80 ? 'green' : 'amber',
          createdAt: at,
        },
      });
    }
    return { clientId: client.id, token: manager.token };
  }

  beforeAll(async () => {
    const instants: Array<[Date, number]> = [
      [S1, 60],
      [S2, 80],
      [S3, 100],
    ];
    sast = await tenant('Sast', undefined, instants);
    utc = await tenant('Utc', 'UTC', instants);
    ny = await tenant('Ny', 'America/New_York', [
      [N1, 90],
      [N2, 50],
      [N3, 70],
    ]);
  });

  afterAll(async () => {
    for (const id of tenants) {
      await prisma.scorecard.deleteMany({ where: { visit: { clientId: id } } });
      await prisma.visit.deleteMany({ where: { clientId: id } });
      await prisma.outlet.deleteMany({ where: { clientId: id } });
      await prisma.territory.deleteMany({ where: { clientId: id } });
      await prisma.user.deleteMany({ where: { clientId: id } });
      await prisma.client.delete({ where: { id } });
    }
    await prisma.$disconnect();
  });

  const trend = (token: string, interval: 'day' | 'week') =>
    request(app)
      .get(`/trends/scorecards?interval=${interval}`)
      .set('Authorization', `Bearer ${token}`);

  describe('bucketStart', () => {
    it('keys a row by its local calendar date, encoded as UTC midnight', () => {
      expect(bucketStart(S1, 'day', 'Africa/Johannesburg').toISOString()).toBe(day('2026-03-02'));
      expect(bucketStart(S1, 'day', 'UTC').toISOString()).toBe(day('2026-03-01'));
      expect(bucketStart(S1, 'week', 'Africa/Johannesburg').toISOString()).toBe(day('2026-03-02'));
      expect(bucketStart(S1, 'week', 'UTC').toISOString()).toBe(day('2026-02-23'));
    });

    it('follows DST rules rather than a fixed offset', () => {
      expect(bucketStart(N2, 'day', 'America/New_York').toISOString()).toBe(day('2026-03-08'));
      expect(bucketStart(N3, 'day', 'America/New_York').toISOString()).toBe(day('2026-03-09'));
      expect(bucketStart(N2, 'week', 'America/New_York').toISOString()).toBe(day('2026-03-02'));
      expect(bucketStart(N3, 'week', 'America/New_York').toISOString()).toBe(day('2026-03-09'));
    });
  });

  it('buckets a 00:30 SAST row into its local day, not the UTC one', async () => {
    const res = await trend(sast.token, 'day');
    expect(res.status).toBe(200);
    expect(points(res.body)).toEqual([
      { period: day('2026-03-02'), value: 70, count: 2 },
      { period: day('2026-03-08'), value: 100, count: 1 },
    ]);
  });

  it('starts SAST weeks at local Monday midnight and ends them at local Sunday 23:59', async () => {
    const res = await trend(sast.token, 'week');
    expect(res.status).toBe(200);
    expect(points(res.body)).toEqual([{ period: day('2026-03-02'), value: 80, count: 3 }]);
  });

  it('buckets the same instants differently for a UTC client — the zone is per tenant', async () => {
    const days = await trend(utc.token, 'day');
    expect(points(days.body)).toEqual([
      { period: day('2026-03-01'), value: 60, count: 1 },
      { period: day('2026-03-02'), value: 80, count: 1 },
      { period: day('2026-03-08'), value: 100, count: 1 },
    ]);
    const weeks = await trend(utc.token, 'week');
    expect(points(weeks.body)).toEqual([
      { period: day('2026-02-23'), value: 60, count: 1 },
      { period: day('2026-03-02'), value: 90, count: 2 },
    ]);

    // And the UTC tenant's request did not bleed into SAST's view or vice versa.
    const sastWeeks = await trend(sast.token, 'week');
    expect(points(sastWeeks.body)).toEqual([{ period: day('2026-03-02'), value: 80, count: 3 }]);
  });

  it('buckets a New York client by local day across the DST change', async () => {
    const res = await trend(ny.token, 'day');
    expect(res.status).toBe(200);
    expect(points(res.body)).toEqual([
      { period: day('2026-03-07'), value: 90, count: 1 },
      { period: day('2026-03-08'), value: 50, count: 1 },
      { period: day('2026-03-09'), value: 70, count: 1 },
    ]);
  });

  it('buckets a New York client by local week across the DST change', async () => {
    const res = await trend(ny.token, 'week');
    expect(points(res.body)).toEqual([
      { period: day('2026-03-02'), value: 70, count: 2 },
      { period: day('2026-03-09'), value: 70, count: 1 },
    ]);
  });

  it('buckets the territory benchmark in the client timezone too', async () => {
    const res = await request(app)
      .get('/trends/benchmark?metric=scorecards&interval=day')
      .set('Authorization', `Bearer ${sast.token}`);
    expect(res.status).toBe(200);
    const expected = [
      { period: day('2026-03-02'), value: 70, count: 2 },
      { period: day('2026-03-08'), value: 100, count: 1 },
    ];
    expect(points(res.body.client)).toEqual(expected);
    expect(res.body.territories).toHaveLength(1);
    expect(points(res.body.territories[0])).toEqual(expected);

    const nyRes = await request(app)
      .get('/trends/benchmark?metric=scorecards&interval=week')
      .set('Authorization', `Bearer ${ny.token}`);
    expect(points(nyRes.body.client)).toEqual([
      { period: day('2026-03-02'), value: 70, count: 2 },
      { period: day('2026-03-09'), value: 70, count: 1 },
    ]);
  });
});
