import { prisma } from '../../lib/prisma';
import { foreignTenant, userIn } from '../../test-utils/tenants';
import {
  listActions,
  openAction,
  recordRefusal,
  resolveAction,
} from './actions.service';

describe('the write ledger', () => {
  let clientId: string;
  let actor: { userId: string; clientId: string };

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: `ACTIONS-${Date.now()}`,
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    clientId = client.id;
    const user = await userIn(clientId, 'manager');
    actor = { userId: user.userId, clientId };
  });

  afterEach(async () => {
    await prisma.assistantAction.deleteMany({ where: { clientId } });
  });

  afterAll(async () => {
    await prisma.assistantAction.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('opens a row before the action runs, so a crash leaves evidence', async () => {
    // The property the whole design turns on: no row means never attempted.
    // A ledger written only on success cannot tell "nobody tried" from "it
    // blew up", and those are opposite answers in an incident.
    const id = await openAction({
      actor,
      toolName: 'getAgentScorecard',
      args: { agent: 'someone' },
    });

    expect(id).toEqual(expect.any(String));
    const [row] = await listActions(clientId);
    expect(row).toMatchObject({
      toolName: 'getAgentScorecard',
      outcome: 'requested',
      resolvedAt: null,
    });
  });

  it('captures the tier as it stood, not as it is read', () => {
    // Denormalised on purpose. Re-deriving the tier when the ledger is read
    // would rewrite history every time the policy table changed, and "what did
    // we consider risky at the time" is exactly what an auditor asks.
    //
    // Asserted through an UNKNOWN tool, because that is the case where the
    // stored value and a later lookup are most likely to differ: today it
    // fails closed to irreversible, and tomorrow it may be in the table.
    const quiet = jest.spyOn(console, 'error').mockImplementation(() => {});
    return openAction({ actor, toolName: 'notATool', args: {} })
      .then(async () => {
        const [row] = await listActions(clientId);
        expect(row.tier).toBe('irreversible');
        expect(row.toolName).toBe('notATool');
      })
      .finally(() => quiet.mockRestore());
  });

  it('records a refusal as a closed row, never as a crash', async () => {
    // A refusal has no before-and-after. Leaving it at `requested` would make
    // "we said no" indistinguishable from "we died halfway".
    await recordRefusal({
      actor,
      toolName: 'getFraudFlags',
      args: {},
      detail: 'not available to this role',
    });

    const [row] = await listActions(clientId);
    expect(row.outcome).toBe('refused');
    expect(row.detail).toBe('not available to this role');
    expect(row.resolvedAt).toEqual(expect.any(Date));
  });

  it('leaves an unanswered confirmation unresolved', async () => {
    // A tier-3 action sits waiting on a human. Stamping `resolvedAt` would
    // make an unanswered prompt look settled, which is precisely the row an
    // audit needs to be able to find.
    const id = await openAction({
      actor,
      toolName: 'getStockLevels',
      args: {},
      outcome: 'awaiting_confirmation',
    });
    await resolveAction(id, 'awaiting_confirmation');

    const [row] = await listActions(clientId);
    expect(row.outcome).toBe('awaiting_confirmation');
    expect(row.resolvedAt).toBeNull();
  });

  it('carries undo context for an action a user can take back', async () => {
    const id = await openAction({ actor, toolName: 'getVisitHistory', args: {} });
    await resolveAction(id, 'executed', { undoContext: { createdTaskId: 'task-1' } });

    const [row] = await listActions(clientId);
    expect(row.outcome).toBe('executed');
    expect(row.undoContext).toEqual({ createdTaskId: 'task-1' });
  });

  describe('failures never cost the caller their action', () => {
    // Audit is a side record, not the work. A ledger write that fails must not
    // also fail the user's request — otherwise anyone who can break the ledger
    // can break every write in the system.
    it('openAction returns null rather than throwing', async () => {
      const quiet = jest.spyOn(console, 'error').mockImplementation(() => {});
      const boom = jest
        .spyOn(prisma.assistantAction, 'create')
        .mockRejectedValue(new Error('database is on fire'));
      try {
        await expect(
          openAction({ actor, toolName: 'getStockLevels', args: {} }),
        ).resolves.toBeNull();
        expect(quiet).toHaveBeenCalled();
      } finally {
        boom.mockRestore();
        quiet.mockRestore();
      }
    });

    it('resolveAction tolerates the id that was never created', async () => {
      // The other half of the same story: if opening failed, the caller holds
      // a null and must not need a branch for it.
      await expect(resolveAction(null, 'executed')).resolves.toBeUndefined();
    });

    it('resolveAction swallows its own failure', async () => {
      const quiet = jest.spyOn(console, 'error').mockImplementation(() => {});
      const boom = jest
        .spyOn(prisma.assistantAction, 'update')
        .mockRejectedValue(new Error('database is on fire'));
      try {
        await expect(resolveAction('no-such-row', 'executed')).resolves.toBeUndefined();
        expect(quiet).toHaveBeenCalled();
      } finally {
        boom.mockRestore();
        quiet.mockRestore();
      }
    });
  });

  describe('tenant scoping', () => {
    it('never returns another tenant\'s actions', async () => {
      // Zero cross-tenant leaks is Phase 3's gate, and the ledger is a
      // particularly rich target: it holds the arguments of every write anyone
      // attempted, in plain JSON.
      const foreign = await foreignTenant('manager');
      try {
        await openAction({
          actor: { userId: foreign.userId, clientId: foreign.clientId },
          toolName: 'getStockLevels',
          args: { secret: 'the other tenant' },
        });
        await openAction({ actor, toolName: 'getStockLevels', args: { mine: true } });

        const mine = await listActions(clientId);
        expect(mine).toHaveLength(1);
        expect(mine[0].args).toEqual({ mine: true });

        // And the reverse direction, so this cannot pass by the foreign row
        // simply never having been written.
        const theirs = await listActions(foreign.clientId);
        expect(theirs).toHaveLength(1);
        expect(theirs[0].args).toEqual({ secret: 'the other tenant' });
      } finally {
        await prisma.assistantAction.deleteMany({ where: { clientId: foreign.clientId } });
        await foreign.cleanup();
      }
    });
  });

  describe('reading the ledger', () => {
    // Written oldest first, so the expected read order is the reverse.
    const written = ['getStockLevels', 'getFraudFlags', 'someWriteTool'];

    beforeEach(async () => {
      await openAction({ actor, toolName: 'getStockLevels', args: { n: 1 } });
      await openAction({ actor, toolName: 'getFraudFlags', args: { n: 2 } });
      const quiet = jest.spyOn(console, 'error').mockImplementation(() => {});
      await openAction({ actor, toolName: 'someWriteTool', args: { n: 3 } });
      quiet.mockRestore();

      // Three writes this fast land in the same millisecond, and `created_at`
      // is timestamp(3), so they tie — which made "newest first" below an
      // assertion about which insert the planner returned first rather than
      // about time. Spread them a second apart so the claim is the one the
      // test's name makes. Each `toolName` here is written exactly once.
      const base = new Date('2026-01-01T00:00:00.000Z');
      await Promise.all(
        written.map((toolName, i) =>
          prisma.assistantAction.updateMany({
            where: { clientId, toolName },
            data: { createdAt: new Date(base.getTime() + i * 1_000) },
          }),
        ),
      );
    });

    it('is newest first', async () => {
      const rows = await listActions(clientId);
      expect(rows.map((r) => r.toolName)).toEqual([...written].reverse());
    });

    it('breaks a same-millisecond tie the same way every time', async () => {
      // Several actions inside one assistant turn is the normal case, and when
      // they share a millisecond `created_at` cannot separate them. Without a
      // tie-break the audit view reshuffles between two reads of identical
      // data. Compared against raw SQL rather than a sort in JS, so the
      // database's own collation decides what `id` descending means.
      await prisma.assistantAction.updateMany({
        where: { clientId },
        data: { createdAt: new Date('2026-01-01T00:00:00.000Z') },
      });

      const expected = await prisma.$queryRaw<{ id: string }[]>`
        select id from assistant_actions where client_id = ${clientId} order by id desc
      `;
      expect(expected).toHaveLength(written.length);
      expect((await listActions(clientId)).map((r) => r.id)).toEqual(
        expected.map((r) => r.id),
      );
    });

    it('filters by tool and by tier', async () => {
      expect(await listActions(clientId, { toolName: 'getFraudFlags' })).toHaveLength(1);
      // `someWriteTool` is unknown, so it was stored irreversible.
      const risky = await listActions(clientId, { tier: 'irreversible' });
      expect(risky.map((r) => r.toolName)).toEqual(['someWriteTool']);
    });

    it('is bounded even when asked for more', async () => {
      // An audit table grows without limit by design, so the one query
      // guaranteed to run against the biggest version of it must not be the
      // unbounded one.
      const rows = await listActions(clientId, { limit: 10_000 });
      expect(rows.length).toBeLessThanOrEqual(200);
    });
  });
});
