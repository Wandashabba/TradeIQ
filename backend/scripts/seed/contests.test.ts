import { contestStatus } from '../../src/modules/contests/contestRules';
import { TERRITORIES } from './catalog';
import { buildContests } from './contests';
import { FIXTURE_ANCHOR, FIXTURE_HOME } from './historyFixture';
import { buildWorld, campaignStatus } from './world';

const WORLD = buildWorld({ anchor: FIXTURE_ANCHOR, home: FIXTURE_HOME, outletFraction: 0.2, historyMonths: 1 });
const CONTESTS = buildContests(WORLD);

describe('buildContests', () => {
  it('has active, recently ended, upcoming and cancelled contests', () => {
    const statuses = CONTESTS.map((c) =>
      contestStatus({ startDate: c.startDate, endDate: c.endDate, cancelledAt: c.cancelledAt }, FIXTURE_ANCHOR),
    );
    for (const status of ['active', 'ended', 'upcoming', 'cancelled']) {
      expect(statuses).toContain(status);
    }
  });

  it('stores dates as calendar dates and never ends before it starts', () => {
    for (const c of CONTESTS) {
      expect(c.startDate.getUTCHours()).toBe(0);
      expect(c.endDate.getTime()).toBeGreaterThanOrEqual(c.startDate.getTime());
    }
  });

  it('scopes territory contests to real territories and uses only ledger reasons', () => {
    const ids = new Set(TERRITORIES.map((t) => t.id));
    for (const c of CONTESTS) {
      if (c.territoryId) expect(ids.has(c.territoryId)).toBe(true);
      for (const reason of c.eventTypes) expect(['visit_submitted', 'task_closed', 'scorecard']).toContain(reason);
    }
  });
});

describe('campaigns', () => {
  it('has completed, active and draft campaigns whose windows never overlap on an outlet', () => {
    const statuses = new Set(WORLD.campaigns.map((c) => campaignStatus(c, FIXTURE_ANCHOR)));
    expect(statuses).toEqual(new Set(['completed', 'active', 'draft']));
    for (const a of WORLD.campaigns) {
      for (const b of WORLD.campaigns) {
        if (a.id >= b.id) continue;
        const overlapInTime = a.startDate <= b.endDate && b.startDate <= a.endDate;
        const shared = WORLD.campaignOutlets.get(a.id)!.some((id) => WORLD.campaignOutletSets.get(b.id)!.has(id));
        expect(overlapInTime && shared).toBe(false);
      }
    }
  });
});
