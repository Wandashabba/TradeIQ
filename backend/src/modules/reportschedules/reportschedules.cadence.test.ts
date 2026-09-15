import {
  cadencePeriodMs,
  DAY_MS,
  firstRunAt,
  nextRunAfter,
  rescheduleForCadence,
} from './reportschedules.cadence';
import { nextRunAtAfterUpdate } from './reportschedules.service';

const at = (iso: string) => new Date(iso);

describe('report schedule cadence (#66)', () => {
  it('daily is 24h and weekly 7 days; an unknown cadence is daily', () => {
    expect(cadencePeriodMs('daily')).toBe(DAY_MS);
    expect(cadencePeriodMs('weekly')).toBe(7 * DAY_MS);
    expect(cadencePeriodMs('hourly')).toBe(DAY_MS);
  });

  it('a new schedule first fires one period from now', () => {
    const now = at('2026-09-15T09:30:00.000Z');
    expect(firstRunAt('daily', now)).toEqual(at('2026-09-16T09:30:00.000Z'));
    expect(firstRunAt('weekly', now)).toEqual(at('2026-09-22T09:30:00.000Z'));
  });

  it('on time: the next run is one period after the due time, not after the run', () => {
    const due = at('2026-09-15T09:00:00.000Z');
    // The run finished 40 minutes late; the grid does not move.
    const finished = new Date(due.getTime() + 40 * 60_000);
    expect(nextRunAfter('daily', due, finished)).toEqual(at('2026-09-16T09:00:00.000Z'));
    expect(nextRunAfter('weekly', due, finished)).toEqual(at('2026-09-22T09:00:00.000Z'));
  });

  it('catch-up fires once: after missed periods the next run is the first slot still ahead', () => {
    const due = at('2026-09-10T09:00:00.000Z');
    // Down for five and a half days: slots on the 11th..15th were all missed.
    const now = at('2026-09-15T21:00:00.000Z');
    const next = nextRunAfter('daily', due, now);
    expect(next).toEqual(at('2026-09-16T09:00:00.000Z'));
    // Strictly in the future, so the next poll finds nothing due.
    expect(next.getTime()).toBeGreaterThan(now.getTime());

    // Weekly slots 17th, 24th, 1st 09:00 — the 1st at 09:00 is still ahead.
    const weekly = nextRunAfter('weekly', due, at('2026-10-01T00:00:00.000Z'));
    expect(weekly).toEqual(at('2026-10-01T09:00:00.000Z'));
  });

  it('a slot exactly at now is not ahead, so it is skipped too', () => {
    const due = at('2026-09-14T09:00:00.000Z');
    expect(nextRunAfter('daily', due, at('2026-09-15T09:00:00.000Z'))).toEqual(
      at('2026-09-16T09:00:00.000Z'),
    );
  });

  it('is deterministic in UTC: the time of day holds across a DST change elsewhere', () => {
    // 2026-10-25 is the EU clocks-back night; a UTC day is still 24h.
    const due = at('2026-10-24T07:00:00.000Z');
    expect(nextRunAfter('daily', due, at('2026-10-24T08:00:00.000Z'))).toEqual(
      at('2026-10-25T07:00:00.000Z'),
    );
  });

  it('a cadence change keeps the previous due time in place', () => {
    const now = at('2026-09-17T12:00:00.000Z');
    // Weekly, last due Mon 14th 09:00, next Mon 21st 09:00. Becomes daily:
    // next is the first 09:00 still ahead.
    expect(
      rescheduleForCadence('weekly', 'daily', at('2026-09-21T09:00:00.000Z'), now),
    ).toEqual(at('2026-09-18T09:00:00.000Z'));
    // Daily, last due 17th 09:00, next 18th 09:00. Becomes weekly: 24th 09:00.
    expect(
      rescheduleForCadence('daily', 'weekly', at('2026-09-18T09:00:00.000Z'), now),
    ).toEqual(at('2026-09-24T09:00:00.000Z'));
    // Nothing to work from: one new period from now.
    expect(rescheduleForCadence('daily', 'weekly', null, now)).toEqual(
      at('2026-09-24T12:00:00.000Z'),
    );
  });

  describe('nextRunAtAfterUpdate', () => {
    const now = at('2026-09-15T10:00:00.000Z');
    const next = at('2026-09-16T09:00:00.000Z');
    const active = { active: true, cadence: 'daily', nextRunAt: next };
    const paused = { active: false, cadence: 'daily', nextRunAt: null };

    it('pausing clears the next run', () => {
      expect(nextRunAtAfterUpdate(active, { active: false }, now)).toBeNull();
      // Paused and edited while paused: still no next run.
      expect(nextRunAtAfterUpdate(paused, { cadence: 'weekly' }, now)).toBeNull();
    });

    it('resuming schedules the next run one period from now', () => {
      expect(nextRunAtAfterUpdate(paused, { active: true }, now)).toEqual(
        new Date(now.getTime() + DAY_MS),
      );
      expect(nextRunAtAfterUpdate(paused, { active: true, cadence: 'weekly' }, now)).toEqual(
        new Date(now.getTime() + 7 * DAY_MS),
      );
    });

    it('recipients alone, or re-sending the same state, leave it unchanged', () => {
      expect(nextRunAtAfterUpdate(active, { recipients: ['a@b.test'] }, now)).toBeUndefined();
      expect(nextRunAtAfterUpdate(active, { active: true, cadence: 'daily' }, now)).toBeUndefined();
    });

    it('a cadence change on an active schedule reschedules from the last due time', () => {
      expect(nextRunAtAfterUpdate(active, { cadence: 'weekly' }, now)).toEqual(
        at('2026-09-22T09:00:00.000Z'),
      );
    });

    it('an active schedule with no next run is put back on its cadence', () => {
      expect(
        nextRunAtAfterUpdate({ active: true, cadence: 'daily', nextRunAt: null }, {}, now),
      ).toEqual(new Date(now.getTime() + DAY_MS));
    });
  });
});
