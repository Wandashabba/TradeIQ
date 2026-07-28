import { buildOutlets, PROBLEM_OUTLET_CODES, SKUS, USERS } from './catalog';
import { SECTION_TINTS, demoPhotoDataUrl } from './photos';
import { buildVisitHistory } from './visits';
import { buildOps, OpsBundle } from './ops';

const ANCHOR = new Date('2026-07-28T00:00:00.000Z');
const OUTLETS = buildOutlets({ lat: -26.1076, lng: 28.0567, source: 'fallback' });
const AGENTS = USERS.filter((u) => u.role === 'field_agent');
const HISTORY = buildVisitHistory({ anchor: ANCHOR, outlets: OUTLETS, agents: AGENTS, skus: SKUS });

// A real generated JPEG, not a stub — otherwise the closure-photo assertion
// below would pass against any string that merely starts with the data-URL
// prefix, which is exactly the bug #209 is about.
let closurePhotoUrl: string;
let OPS: OpsBundle;

beforeAll(async () => {
  closurePhotoUrl = await demoPhotoDataUrl(SECTION_TINTS.closure);
  OPS = buildOps({ anchor: ANCHOR, visits: HISTORY, outlets: OUTLETS, agents: AGENTS, closurePhotoUrl });
});

describe('buildOps', () => {
  it('raises alerts, and leaves some unacknowledged for the demo to triage', () => {
    expect(OPS.alerts.length).toBeGreaterThan(0);
    expect(OPS.alerts.some((a) => !a.acknowledged)).toBe(true);
  });

  it('concentrates open alerts on the problem outlets', () => {
    const problemIds = new Set(
      OUTLETS.filter((o) => (PROBLEM_OUTLET_CODES as readonly string[]).includes(o.code))
        .map((o) => o.id),
    );
    const open = OPS.alerts.filter((a) => !a.acknowledged);
    const onProblem = open.filter((a) => a.outletId && problemIds.has(a.outletId));
    expect(onProblem.length).toBeGreaterThan(open.length / 2);
  });

  it('creates both closed and open tasks, so the demo shows a working loop', () => {
    expect(OPS.tasks.some((t) => t.status === 'closed')).toBe(true);
    expect(OPS.tasks.some((t) => t.status === 'open')).toBe(true);
  });

  it('leaves some open tasks genuinely overdue', () => {
    const overdue = OPS.tasks.filter(
      (t) => t.status === 'open' && t.slaDueAt.getTime() < ANCHOR.getTime(),
    );
    expect(overdue.length).toBeGreaterThan(0);
  });

  it('never gives a task an SLA due before the visit that raised it', () => {
    const visitById = new Map(HISTORY.map((v) => [v.id, v]));
    for (const task of OPS.tasks) {
      if (!task.visitId) continue;
      const visit = visitById.get(task.visitId)!;
      expect(task.slaDueAt.getTime()).toBeGreaterThan(visit.checkinTs.getTime());
    }
  });

  it('assigns every task to a real agent', () => {
    const agentIds = new Set(AGENTS.map((a) => a.id));
    for (const task of OPS.tasks) expect(agentIds.has(task.ownerId)).toBe(true);
  });

  it('gives closed tasks the real closure photo, not a placeholder URL', () => {
    const closed = OPS.tasks.filter((t) => t.status === 'closed');
    expect(closed.length).toBeGreaterThan(0);
    for (const task of closed) {
      expect(task.closurePhotoUrl).toBe(closurePhotoUrl);
    }
  });

  it('leaves open tasks without a closure photo', () => {
    for (const task of OPS.tasks.filter((t) => t.status === 'open')) {
      expect(task.closurePhotoUrl).toBeUndefined();
    }
  });

  it('defines an active incentive scheme', () => {
    expect(OPS.incentiveSchemes.length).toBeGreaterThan(0);
    expect(OPS.incentiveSchemes.some((s) => s.active)).toBe(true);
  });

  it('is deterministic', () => {
    const again = buildOps({ anchor: ANCHOR, visits: HISTORY, outlets: OUTLETS, agents: AGENTS, closurePhotoUrl });
    expect(again.tasks.map((t) => t.id)).toEqual(OPS.tasks.map((t) => t.id));
    expect(again.alerts.map((a) => a.id)).toEqual(OPS.alerts.map((a) => a.id));
  });
});
