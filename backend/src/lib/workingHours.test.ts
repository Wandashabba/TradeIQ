import {
  DEFAULT_WORKING_HOURS,
  WorkingHours,
  formatTimeOfDay,
  isWithinWorkingHours,
  parseTimeOfDay,
  validateWorkingHours,
  workingHoursOf,
  workingWindowAt,
} from './workingHours';

/**
 * #153 T2 — the window background tracking is allowed to run in. It is the only
 * thing standing between "tracking between stores" and "tracking", so most of
 * this is about what falls OUTSIDE it.
 */
describe('working hours (#153 T2)', () => {
  const SAST = 'Africa/Johannesburg'; // UTC+2, no DST
  const NY = 'America/New_York'; // UTC-4/-5, with DST

  describe('parseTimeOfDay', () => {
    it.each([
      ['00:00', 0],
      ['07:00', 420],
      ['17:00', 1020],
      ['23:59', 1439],
    ])('reads %s', (value, minutes) => expect(parseTimeOfDay(value)).toBe(minutes));

    it.each([
      ['a single-digit hour', '7:00'],
      ['seconds', '07:00:00'],
      ['a 12-hour clock', '7am'],
      ['hour 24', '24:00'],
      ['minute 60', '07:60'],
      ['empty', ''],
      ['a number', 700],
      ['null', null],
    ])('refuses %s rather than guessing', (_label, value) => {
      expect(parseTimeOfDay(value)).toBeUndefined();
    });
  });

  it('formatTimeOfDay round-trips every minute of the day', () => {
    for (let m = 0; m < 24 * 60; m += 1) {
      expect(parseTimeOfDay(formatTimeOfDay(m))).toBe(m);
    }
  });

  describe('validateWorkingHours', () => {
    it('defaults to a Monday-to-Friday 07:00-17:00 field day', () => {
      expect(DEFAULT_WORKING_HOURS).toEqual({ start: '07:00', end: '17:00', days: [1, 2, 3, 4, 5] });
      const parsed = validateWorkingHours({});
      expect(parsed.ok && parsed.value).toEqual(DEFAULT_WORKING_HOURS);
    });

    it('accepts a whole window', () => {
      const parsed = validateWorkingHours({ start: '06:30', end: '18:15', days: [1, 2, 3, 4, 5, 6] });
      expect(parsed.ok && parsed.value).toEqual({ start: '06:30', end: '18:15', days: [1, 2, 3, 4, 5, 6] });
    });

    it('sorts and keeps the days a manager sent in any order', () => {
      const parsed = validateWorkingHours({ days: [6, 1, 3] });
      expect(parsed.ok && parsed.value.days).toEqual([1, 3, 6]);
    });

    it('checks start-before-end against the value that WOULD be stored, not the one field that changed', () => {
      // Only the end moves, and it moves to before the stored start.
      const narrowing = validateWorkingHours({ end: '06:00' }, { start: '07:00', end: '17:00', days: [1] });
      expect(narrowing).toEqual({ ok: false, error: expect.stringContaining('before') });

      // Both move together, and together they are fine.
      const shifting = validateWorkingHours({ start: '04:00', end: '06:00' }, { start: '07:00', end: '17:00', days: [1] });
      expect(shifting.ok && shifting.value).toMatchObject({ start: '04:00', end: '06:00' });
    });

    it.each([
      ['a start equal to the end', { start: '08:00', end: '08:00' }],
      ['a start after the end', { start: '18:00', end: '09:00' }],
      ['a malformed start', { start: '7' }],
      ['a malformed end', { end: 'five' }],
      ['an empty day list', { days: [] }],
      ['a non-array day list', { days: 'weekdays' }],
      ['day 0', { days: [0, 1] }],
      ['day 8', { days: [8] }],
      ['a fractional day', { days: [1.5] }],
      ['a repeated day', { days: [1, 1] }],
    ])('refuses %s', (_label, input) => {
      expect(validateWorkingHours(input).ok).toBe(false);
    });
  });

  describe('workingHoursOf', () => {
    it('reads a client row', () => {
      expect(workingHoursOf({ workHoursStart: '08:00', workHoursEnd: '16:30', workDays: [1, 2] })).toEqual({
        start: '08:00',
        end: '16:30',
        days: [1, 2],
      });
    });

    it.each([
      ['a missing client', null],
      ['an empty row', {}],
      ['nulls', { workHoursStart: null, workHoursEnd: null, workDays: null }],
      ['a start after the end', { workHoursStart: '19:00', workHoursEnd: '06:00', workDays: [1] }],
      ['an empty day list', { workHoursStart: '07:00', workHoursEnd: '17:00', workDays: [] }],
    ])('falls back to the default for %s rather than throwing', (_label, row) => {
      expect(workingHoursOf(row)).toEqual(DEFAULT_WORKING_HOURS);
    });
  });

  describe('isWithinWorkingHours', () => {
    const hours = DEFAULT_WORKING_HOURS;
    // 2026-09-17 is a Thursday; 2026-09-19 a Saturday, 2026-09-20 a Sunday.
    const sast = (iso: string) => new Date(iso);

    it('is open inside the window on a working day', () => {
      expect(isWithinWorkingHours(sast('2026-09-17T08:00:00+02:00'), SAST, hours)).toBe(true);
      expect(isWithinWorkingHours(sast('2026-09-17T16:59:00+02:00'), SAST, hours)).toBe(true);
    });

    it('opens exactly at the start and closes exactly at the end', () => {
      // Half-open [start, end): 07:00 is in, 17:00 is already out.
      expect(isWithinWorkingHours(sast('2026-09-17T07:00:00+02:00'), SAST, hours)).toBe(true);
      expect(isWithinWorkingHours(sast('2026-09-17T06:59:00+02:00'), SAST, hours)).toBe(false);
      expect(isWithinWorkingHours(sast('2026-09-17T17:00:00+02:00'), SAST, hours)).toBe(false);
    });

    it('is shut at night', () => {
      expect(isWithinWorkingHours(sast('2026-09-17T22:30:00+02:00'), SAST, hours)).toBe(false);
      expect(isWithinWorkingHours(sast('2026-09-17T03:00:00+02:00'), SAST, hours)).toBe(false);
    });

    it('is shut at the weekend, even in the middle of the window', () => {
      expect(isWithinWorkingHours(sast('2026-09-19T10:00:00+02:00'), SAST, hours)).toBe(false);
      expect(isWithinWorkingHours(sast('2026-09-20T10:00:00+02:00'), SAST, hours)).toBe(false);
    });

    it('opens the weekend for a client that works it', () => {
      const sixDay: WorkingHours = { ...hours, days: [1, 2, 3, 4, 5, 6] };
      expect(isWithinWorkingHours(sast('2026-09-19T10:00:00+02:00'), SAST, sixDay)).toBe(true);
      expect(isWithinWorkingHours(sast('2026-09-20T10:00:00+02:00'), SAST, sixDay)).toBe(false);
    });

    describe('the window is the CLIENT’s wall clock, not the server’s', () => {
      // One instant, read by two clients. 12:00 UTC is 14:00 in Johannesburg
      // (inside the window) and 08:00 in New York (also inside it) — so pick an
      // instant where the two genuinely disagree instead.
      const instant = new Date('2026-09-17T20:00:00Z');

      it('is shut for a Johannesburg client (22:00 local)', () => {
        expect(isWithinWorkingHours(instant, SAST, hours)).toBe(false);
      });

      it('is open for a New York client (16:00 local)', () => {
        expect(isWithinWorkingHours(instant, NY, hours)).toBe(true);
      });

      it('separates the two across a local midnight', () => {
        // 2026-09-18T05:30Z — Friday 07:30 in Johannesburg, still Thursday
        // 01:30 in New York.
        const earlyMorning = new Date('2026-09-18T05:30:00Z');
        expect(isWithinWorkingHours(earlyMorning, SAST, hours)).toBe(true);
        expect(isWithinWorkingHours(earlyMorning, NY, hours)).toBe(false);
      });

      it('reads a UTC client on UTC', () => {
        expect(isWithinWorkingHours(new Date('2026-09-17T08:00:00Z'), 'UTC', hours)).toBe(true);
        expect(isWithinWorkingHours(new Date('2026-09-17T18:00:00Z'), 'UTC', hours)).toBe(false);
      });
    });
  });

  describe('workingWindowAt', () => {
    const hours = DEFAULT_WORKING_HOURS;

    it('says when an open window closes', () => {
      const window = workingWindowAt(new Date('2026-09-17T08:00:00+02:00'), SAST, hours);
      expect(window.open).toBe(true);
      expect(window.opensAt).toBeNull();
      expect(window.closesAt?.toISOString()).toBe(new Date('2026-09-17T17:00:00+02:00').toISOString());
    });

    it('says when the next window opens, later the same day', () => {
      const window = workingWindowAt(new Date('2026-09-17T05:00:00+02:00'), SAST, hours);
      expect(window.open).toBe(false);
      expect(window.closesAt).toBeNull();
      expect(window.opensAt?.toISOString()).toBe(new Date('2026-09-17T07:00:00+02:00').toISOString());
    });

    it('rolls to tomorrow once today has closed', () => {
      const window = workingWindowAt(new Date('2026-09-17T19:00:00+02:00'), SAST, hours);
      expect(window.opensAt?.toISOString()).toBe(new Date('2026-09-18T07:00:00+02:00').toISOString());
    });

    it('skips the weekend: Friday evening points at Monday morning', () => {
      const window = workingWindowAt(new Date('2026-09-18T19:00:00+02:00'), SAST, hours);
      expect(window.open).toBe(false);
      expect(window.opensAt?.toISOString()).toBe(new Date('2026-09-21T07:00:00+02:00').toISOString());
    });

    it('resolves the edges on the client’s clock, not the server’s', () => {
      const window = workingWindowAt(new Date('2026-09-17T20:00:00Z'), NY, hours);
      expect(window.open).toBe(true);
      // 17:00 in New York on 17 September is 21:00Z (EDT, UTC-4).
      expect(window.closesAt?.toISOString()).toBe('2026-09-17T21:00:00.000Z');
    });

    it('lands on a real local 07:00 across a DST change', () => {
      // New York leaves DST on Sunday 1 November 2026, so Monday the 2nd is
      // EST (UTC-5) while the Friday before was EDT (UTC-4). Adding 7h to a
      // local midnight would put the Monday edge an hour out.
      const window = workingWindowAt(new Date('2026-10-30T22:00:00Z'), NY, hours);
      expect(window.opensAt?.toISOString()).toBe('2026-11-02T12:00:00.000Z');
    });

    it('has no edges at all when the window is unusable', () => {
      expect(workingWindowAt(new Date(), SAST, { start: '07:00', end: '17:00', days: [] })).toEqual({
        open: false,
        closesAt: null,
        opensAt: null,
      });
    });
  });
});
