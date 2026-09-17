import { computeSlaDueAt } from '../../src/lib/slaClock';
import { localInstant } from './calendar';
import { FlatHistory, FIXTURE_ANCHOR, FIXTURE_CLOSURE_PHOTO, generateFlatHistory } from './historyFixture';
import { ALERT_WINDOW_DAYS, CLOSURE_PHOTO_DAYS, INCENTIVE_SCHEMES } from './ops';
import { STANDOUT_AGENT_ID, STRUGGLING_AGENT_ID } from './scenario';

jest.setTimeout(120_000);

let H: FlatHistory;
const NOW = localInstant(FIXTURE_ANCHOR, 0, 'Africa/Johannesburg');
const DAY_MS = 86_400_000;

beforeAll(() => {
  // Six months is enough history for every task and alert state.
  H = generateFlatHistory({ historyMonths: 6 });
});

describe('tasks', () => {
  it('uses the product SLA clock for every task', () => {
    for (const task of H.tasks) {
      expect(task.slaDueAt.toISOString()).toBe(computeSlaDueAt(task.priority, task.createdAt).toISOString());
    }
  });

  it('never raises a task before the visit that found it', () => {
    const visit = new Map(H.visits.map((v) => [v.id, v]));
    for (const task of H.tasks) {
      expect(task.createdAt.getTime()).toBeGreaterThan(visit.get(task.visitId)!.checkinTs.getTime());
      expect(task.ownerId).toBe(visit.get(task.visitId)!.agentId);
    }
  });

  it('closes most tasks, some on time and some after breaching their SLA', () => {
    const closed = H.tasks.filter((t) => t.status === 'closed');
    expect(closed.length).toBeGreaterThan(H.tasks.length * 0.8);
    expect(closed.some((t) => t.slaBreachNotifiedAt === null)).toBe(true);
    expect(closed.some((t) => t.slaBreachNotifiedAt !== null)).toBe(true);
  });

  it('leaves some open tasks genuinely overdue', () => {
    const overdue = H.tasks.filter((t) => t.status !== 'closed' && t.slaDueAt.getTime() < NOW.getTime());
    expect(overdue.length).toBeGreaterThan(0);
  });

  // The running server's breach sweep (#67) pushes for any open task that went
  // overdue in the last day and has not been announced. Seeded history must not
  // set that off.
  it('marks every overdue open task as already announced', () => {
    for (const task of H.tasks.filter((t) => t.status !== 'closed' && t.slaDueAt.getTime() <= NOW.getTime())) {
      expect(task.slaBreachNotifiedAt).not.toBeNull();
    }
  });

  it('keeps closure photos for recent closures only, and never on an open task', () => {
    for (const task of H.tasks) {
      if (task.status !== 'closed') expect(task.closurePhotoUrl).toBeNull();
      if (task.closurePhotoUrl !== null) {
        expect(task.closurePhotoUrl).toBe(FIXTURE_CLOSURE_PHOTO);
        expect(NOW.getTime() - task.createdAt.getTime()).toBeLessThanOrEqual(CLOSURE_PHOTO_DAYS * DAY_MS);
      }
    }
    expect(H.tasks.some((t) => t.closurePhotoUrl !== null)).toBe(true);
  });

  it('shows the struggling agent breaching far more SLAs than the standout', () => {
    const breachRate = (agentId: string) => {
      const own = H.tasks.filter((t) => t.ownerId === agentId);
      return own.filter((t) => t.slaBreachNotifiedAt !== null).length / Math.max(1, own.length);
    };
    expect(breachRate(STRUGGLING_AGENT_ID)).toBeGreaterThan(breachRate(STANDOUT_AGENT_ID) + 0.3);
  });
});

describe('alerts', () => {
  it('only raises alerts for the recent window', () => {
    expect(H.alerts.length).toBeGreaterThan(0);
    for (const alert of H.alerts) {
      expect(NOW.getTime() - alert.createdAt.getTime()).toBeLessThanOrEqual((ALERT_WINDOW_DAYS + 1) * DAY_MS);
      expect(alert.createdAt.getTime()).toBeLessThan(NOW.getTime());
    }
  });

  it('leaves some unacknowledged for the demo to triage, across every rule', () => {
    expect(H.alerts.some((a) => !a.acknowledged)).toBe(true);
    const metrics = new Set(H.alerts.map((a) => a.metric));
    for (const metric of ['out_of_stock', 'price_deviation', 'low_scorecard', 'sla_breach']) {
      expect(metrics.has(metric)).toBe(true);
    }
  });
});

describe('incentive schemes', () => {
  it('defines an active scheme', () => {
    expect(INCENTIVE_SCHEMES.some((s) => s.active)).toBe(true);
  });
});
