import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';
import { countTaskStates } from './tasks.service';

/**
 * THE WHOLE-SET BREAKDOWN.
 *
 * `GET /tasks` served one page and a total, so the worklist derived every
 * figure on its screen from the fifty rows it happened to hold — and on the
 * real database those fifty are all *closed*, because the page is ordered by
 * deadline and 31,178 of 32,368 tasks are closed. The screen therefore read
 * `Open 0 · Overdue 0 · Done 50` over an account with 1,190 open tasks, and
 * had to withhold its lead figure as an unknown rather than print a zero it
 * had not measured.
 *
 * What is asserted here is the four things that make the breakdown safe to
 * believe: it is scoped to the caller's tenant, it is scoped identically
 * whoever asks, its "overdue" is the app's own definition to the boundary
 * instant, and a zero it reports is a measured zero rather than a silence.
 */
describe('GET /tasks — the whole-set counts', () => {
  let clientId: string;
  let otherClientId: string;
  let outletId: string;
  let secondOutletId: string;
  let agentId: string;
  let agentToken: string;
  let managerToken: string;
  let otherToken: string;

  /**
   * The instant every figure here is read at.
   *
   * It is the wall clock rather than a pinned date on purpose: the route
   * cannot be handed a clock over HTTP, so a fixture dated 2026-07-24 would be
   * "in the future" to this test and in the past to the server, and the
   * `overdue` assertions would drift from green to red as the calendar moved.
   * The service-level tests below pin the instant properly.
   */
  const now = new Date();
  const hours = (n: number) => new Date(now.getTime() + n * 3600_000);

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Counts Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const agent = await prisma.user.create({
      data: { email: 'counts-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    const manager = await prisma.user.create({
      data: { email: 'counts-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Counts Outlet',
        code: 'COUNTS-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;
    const second = await prisma.outlet.create({
      data: {
        name: 'Counts Outlet Two',
        code: 'COUNTS-002',
        channelType: 'spaza',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    secondOutletId = second.id;

    // ── The tenant's own tasks, one per case the breakdown has to separate.
    await prisma.task.createMany({
      data: [
        // Outstanding and late: the boundary case first — due at EXACTLY the
        // instant being measured. The app reads `!now.isBefore(slaDueAt)`, so
        // this is overdue, and `lt` instead of `lte` would silently drop it.
        mk('boundary', outletId, agentId, { slaDueAt: now }),
        mk('late-open', outletId, agentId, { slaDueAt: hours(-48) }),
        // Started, and still late. `in_progress` is not `open` in the column
        // and IS open on the worklist — a task somebody picked up is still
        // outstanding.
        mk('late-progress', outletId, agentId, {
          slaDueAt: hours(-6),
          status: 'in_progress',
        }),
        // Outstanding, not late.
        mk('future-open', outletId, agentId, { slaDueAt: hours(48) }),
        mk('future-progress', secondOutletId, agentId, {
          slaDueAt: hours(72),
          status: 'in_progress',
          priority: 'high',
        }),
        // Closed and past its deadline — NOT overdue. A closed task owes
        // nobody anything, whenever it was due.
        mk('closed-late', outletId, agentId, { slaDueAt: hours(-96), status: 'closed' }),
        // Closed, awaiting a manager's verification.
        mk('closed-unverified', outletId, agentId, { slaDueAt: hours(-2), status: 'closed' }),
        // Closed and verified.
        mk('closed-verified', secondOutletId, agentId, {
          slaDueAt: hours(-2),
          status: 'closed',
          closureVerified: true,
        }),
      ],
    });

    // ── A second tenant, with work of its own that must never be counted.
    const otherClient = await prisma.client.create({
      data: { name: 'Counts Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherUser = await prisma.user.create({
      data: {
        email: 'counts-other@example.com',
        passwordHash: 'x',
        role: 'manager',
        clientId: otherClientId,
      },
    });
    otherToken = issueToken({ userId: otherUser.id, role: 'manager', clientId: otherClientId });
    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'Counts Other Outlet',
        code: 'COUNTS-OTHER',
        channelType: 'hypermarket',
        lat: 0,
        lng: 0,
        territoryId: 't9',
        clientId: otherClientId,
      },
    });
    // Deliberately a shape that would be visible in the numbers if it leaked:
    // five overdue tasks, which is more than this tenant has.
    await prisma.task.createMany({
      data: [1, 2, 3, 4, 5].map((n) =>
        mk(`other-${n}`, otherOutlet.id, otherUser.id, { slaDueAt: hours(-24) }),
      ),
    });
  });

  afterAll(async () => {
    const ids = [clientId, otherClientId];
    await prisma.task.deleteMany({ where: { outlet: { clientId: { in: ids } } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: ids } } });
    await prisma.user.deleteMany({ where: { clientId: { in: ids } } });
    await prisma.client.deleteMany({ where: { id: { in: ids } } });
    await prisma.$disconnect();
  });

  function mk(
    fix: string,
    outlet: string,
    owner: string,
    over: { slaDueAt: Date; status?: 'open' | 'in_progress' | 'closed'; closureVerified?: boolean; priority?: 'critical' | 'high' | 'normal' },
  ) {
    return {
      findingType: 'stockout',
      requiredFix: fix,
      outletId: outlet,
      ownerId: owner,
      priority: over.priority ?? 'normal',
      status: over.status ?? 'open',
      closureVerified: over.closureVerified ?? false,
      slaDueAt: over.slaDueAt,
    } as const;
  }

  const get = (token: string, query = '') =>
    request(app).get(`/tasks${query}`).set('Authorization', `Bearer ${token}`);

  it('answers the four chips and the subordinate figure the worklist prints', async () => {
    const res = await get(managerToken);
    expect(res.status).toBe(200);
    // 8 tasks: 5 outstanding (2 open + 1 in_progress late, 1 open + 1
    // in_progress future), 3 closed.
    expect(res.body.counts).toEqual({
      all: 8,
      open: 5,
      overdue: 3,
      done: 3,
      awaitingVerification: 2,
    });
  });

  it('counts only the caller’s tenant — the other account is invisible', async () => {
    const mine = await get(managerToken);
    const theirs = await get(otherToken);

    expect(mine.body.counts.all).toBe(8);
    expect(mine.body.counts.overdue).toBe(3);
    // The other tenant holds five overdue tasks. If the scope were dropped,
    // this tenant's overdue would read 8 and its total 13.
    expect(theirs.body.counts).toEqual({
      all: 5,
      open: 5,
      overdue: 5,
      done: 0,
      awaitingVerification: 0,
    });
  });

  it('counts the same for every role that can read the list', async () => {
    // `GET /tasks` carries `requireAuth` and no `requireRole`, and its `where`
    // has never filtered rows by the caller's ownership. The breakdown is
    // built from the same scope, so the guard being asserted is that the two
    // agree — a count computed under a different filter to the list is how a
    // figure starts describing work the reader cannot open.
    const asAgent = await get(agentToken);
    const asManager = await get(managerToken);
    expect(asAgent.status).toBe(200);
    expect(asAgent.body.counts).toEqual(asManager.body.counts);
    expect(asAgent.body.counts.all).toBe(asAgent.body.data.length);
  });

  it('is unauthenticated callers’ business not at all', async () => {
    const res = await request(app).get('/tasks');
    expect(res.status).toBe(401);
    expect(res.body.counts).toBeUndefined();
  });

  describe('overdue, defined exactly as the app defines it', () => {
    // The app: `TasksView._slaStateFor` returns `overdue` when the status is
    // not `closed` and `!now.isBefore(task.slaDueAt)`. Both halves matter, and
    // the boundary is `<=` rather than `<`.
    const scope = () => ({ clientId });

    it('includes a task due at exactly this instant', async () => {
      const counts = await countTaskStates(scope(), now);
      expect(counts.overdue).toBe(3);
      // One second earlier the boundary task is not yet due, so the same rows
      // answer 2. This is the assertion that fails if `lte` becomes `lt`.
      const justBefore = await countTaskStates(scope(), new Date(now.getTime() - 1000));
      expect(justBefore.overdue).toBe(2);
    });

    it('counts a started task as overdue, because started is not closed', async () => {
      const counts = await countTaskStates(scope(), now);
      // boundary + late-open + late-progress. Drop `in_progress` from the
      // definition and this is 2.
      expect(counts.overdue).toBe(3);
      const progressRows = await prisma.task.count({
        where: { outlet: { clientId }, status: 'in_progress', slaDueAt: { lte: now } },
      });
      expect(progressRows).toBe(1);
    });

    it('never counts a closed task, however late it was', async () => {
      const counts = await countTaskStates(scope(), now);
      const closedAndLate = await prisma.task.count({
        where: { outlet: { clientId }, status: 'closed', slaDueAt: { lte: now } },
      });
      expect(closedAndLate).toBe(3);
      // Three closed tasks are past their deadline and none of them is in the
      // overdue figure.
      expect(counts.overdue).toBe(3);
      expect(counts.overdue + closedAndLate).not.toBe(counts.all);
    });

    it('moves with the clock rather than with the rows', async () => {
      const later = await countTaskStates(scope(), hours(72));
      // Every outstanding task is past its deadline by then.
      expect(later.overdue).toBe(later.open);
      expect(later.open).toBe(5);
    });
  });

  describe('a zero that is genuinely zero', () => {
    let emptyClientId: string;
    let emptyToken: string;
    let quietOutletId: string;

    beforeAll(async () => {
      const client = await prisma.client.create({
        data: { name: 'Counts Quiet', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
      });
      emptyClientId = client.id;
      const user = await prisma.user.create({
        data: {
          email: 'counts-quiet@example.com',
          passwordHash: 'x',
          role: 'manager',
          clientId: emptyClientId,
        },
      });
      emptyToken = issueToken({ userId: user.id, role: 'manager', clientId: emptyClientId });
      const outlet = await prisma.outlet.create({
        data: {
          name: 'Quiet Outlet',
          code: 'COUNTS-QUIET',
          channelType: 'spaza',
          lat: 0,
          lng: 0,
          territoryId: 't1',
          clientId: emptyClientId,
        },
      });
      quietOutletId = outlet.id;
      // Real work, all of it comfortably inside its deadline. Nothing overdue
      // is a FACT about this account, not an absence of information — and the
      // screen renders it as `0` with an on-target mark rather than as an em
      // dash, which is only correct if the server really did look.
      await prisma.task.createMany({
        data: [1, 2, 3].map((n) =>
          mk(`quiet-${n}`, outlet.id, user.id, { slaDueAt: hours(24 * n) }),
        ),
      });
    });

    afterAll(async () => {
      await prisma.task.deleteMany({ where: { outletId: quietOutletId } });
      await prisma.outlet.deleteMany({ where: { clientId: emptyClientId } });
      await prisma.user.deleteMany({ where: { clientId: emptyClientId } });
      await prisma.client.deleteMany({ where: { id: emptyClientId } });
    });

    it('reports 0 rather than omitting the field', async () => {
      const res = await get(emptyToken);
      expect(res.body.counts).toEqual({
        all: 3,
        open: 3,
        overdue: 0,
        done: 0,
        awaitingVerification: 0,
      });
      // The distinction the client draws: a present 0 is a measured nought, a
      // missing key is an unknown. Every key is present.
      for (const key of ['all', 'open', 'overdue', 'done', 'awaitingVerification']) {
        expect(res.body.counts).toHaveProperty(key);
        expect(typeof res.body.counts[key]).toBe('number');
      }
    });

    // Last in this group, because it empties the account it inherits.
    it('reports every field as 0 for an account with no tasks at all', async () => {
      await prisma.task.deleteMany({ where: { outletId: quietOutletId } });
      const res = await get(emptyToken);
      expect(res.body.data).toEqual([]);
      expect(res.body.counts).toEqual({
        all: 0,
        open: 0,
        overdue: 0,
        done: 0,
        awaitingVerification: 0,
      });
    });
  });

  describe('the state filter', () => {
    it('narrows the rows without narrowing the counts', async () => {
      const open = await get(managerToken, '?state=open');
      const done = await get(managerToken, '?state=done');
      const overdue = await get(managerToken, '?state=overdue');

      expect(open.body.data).toHaveLength(5);
      expect(done.body.data).toHaveLength(3);
      expect(overdue.body.data).toHaveLength(3);

      // The chips describe the whole set whichever one is pressed. A
      // breakdown computed after the state filter would make every chip print
      // the selected one's own number.
      expect(open.body.counts).toEqual(done.body.counts);
      expect(overdue.body.counts).toEqual(done.body.counts);
      expect(open.body.counts.all).toBe(8);
    });

    it('state=open means not closed, which includes in_progress', async () => {
      const res = await get(managerToken, '?state=open');
      const statuses = (res.body.data as Array<{ status: string }>).map((t) => t.status).sort();
      expect(statuses).toEqual(['in_progress', 'in_progress', 'open', 'open', 'open']);
      expect(res.body.total).toBe(5);
    });

    it('state=overdue is the same rows the overdue count counts', async () => {
      const res = await get(managerToken, '?state=overdue');
      expect(res.body.data).toHaveLength(res.body.counts.overdue);
      expect(res.body.total).toBe(res.body.counts.overdue);
      for (const task of res.body.data as Array<{ status: string; slaDueAt: string }>) {
        expect(task.status).not.toBe('closed');
        expect(new Date(task.slaDueAt).getTime()).toBeLessThanOrEqual(Date.now());
      }
    });

    it('total follows the state that was asked for', async () => {
      expect((await get(managerToken, '?state=all')).body.total).toBe(8);
      expect((await get(managerToken, '?state=done')).body.total).toBe(3);
      expect((await get(managerToken)).body.total).toBe(8);
    });

    it('rejects an unknown state', async () => {
      const res = await get(managerToken, '?state=pending');
      expect(res.status).toBe(400);
      expect(res.body.error).toContain('state must be');
    });

    it('refuses status and state together rather than picking one', async () => {
      const res = await get(managerToken, '?state=open&status=open');
      expect(res.status).toBe(400);
      expect(res.body.error).toContain('two spellings of the same filter');
    });

    it('still answers the exact-status filter it always did', async () => {
      const res = await get(managerToken, '?status=in_progress');
      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(2);
      expect(res.body.total).toBe(2);
      // And the chips above that list still describe the whole account.
      expect(res.body.counts.all).toBe(8);
    });
  });

  describe('the other filters do scope the counts', () => {
    // priority and outlet are not the chips' axis — they narrow the universe
    // the chips describe, so a breakdown that ignored them would put a chip
    // count above a list it does not describe.
    it('an outlet filter narrows both halves of the answer', async () => {
      const res = await get(managerToken, `?outletId=${secondOutletId}`);
      expect(res.body.counts).toEqual({
        all: 2,
        open: 1,
        overdue: 0,
        done: 1,
        awaitingVerification: 0,
      });
      expect(res.body.data).toHaveLength(2);
    });

    it('a priority filter narrows both halves of the answer', async () => {
      const res = await get(managerToken, '?priority=high');
      expect(res.body.counts).toEqual({
        all: 1,
        open: 1,
        overdue: 0,
        done: 0,
        awaitingVerification: 0,
      });
    });

    it('an outlet in another tenant answers nothing rather than that outlet', async () => {
      const res = await get(otherToken, `?outletId=${outletId}`);
      expect(res.status).toBe(200);
      expect(res.body.data).toEqual([]);
      expect(res.body.counts.all).toBe(0);
    });
  });

  describe('the page, against the counts', () => {
    it('a cut page still states the whole set', async () => {
      const res = await get(managerToken, '?state=open&limit=2');
      expect(res.body.data).toHaveLength(2);
      expect(res.body.nextCursor).not.toBeNull();
      // The defect this endpoint exists to end: the page is two rows and the
      // account holds five open tasks, and the answer says so.
      expect(res.body.total).toBe(5);
      expect(res.body.counts.open).toBe(5);
      expect(res.body.counts.overdue).toBe(3);
    });
  });
});
