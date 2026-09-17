import {
  addCalendarDays,
  DEFAULT_CLIENT_TIME_ZONE,
  isValidTimeZone,
  localCalendarDate,
  localClockMs,
  localInstantAt,
  mondayOfCalendarWeek,
  startOfLocalDay,
} from './clientTime';

const date = (iso: string) => new Date(`${iso}T00:00:00.000Z`);

describe('isValidTimeZone', () => {
  it.each(['Africa/Johannesburg', 'America/New_York', 'Europe/London', 'UTC'])(
    'accepts %s',
    (zone) => {
      expect(isValidTimeZone(zone)).toBe(true);
    },
  );

  it.each([
    'Mars/Olympus_Mons',
    'africa/johannesburg', // case-folded: not the canonical name
    '+02:00', // an offset has no DST rules
    'SAST', // an abbreviation, not a zone
    '',
    42,
    null,
  ])('rejects %p', (value) => {
    expect(isValidTimeZone(value)).toBe(false);
  });

  it('accepts the default', () => {
    expect(isValidTimeZone(DEFAULT_CLIENT_TIME_ZONE)).toBe(true);
  });
});

describe('localCalendarDate', () => {
  it('puts 00:30 SAST on the local date, not the UTC one (#309)', () => {
    const halfPastMidnight = new Date('2026-09-14T22:30:00.000Z');
    expect(localCalendarDate(halfPastMidnight, 'Africa/Johannesburg')).toEqual(date('2026-09-15'));
    expect(localCalendarDate(halfPastMidnight, 'UTC')).toEqual(date('2026-09-14'));
  });

  it('follows DST in America/New_York', () => {
    // 23:30 local on 7 Mar (EST, -5) and 23:30 local on 8 Mar (EDT, -4).
    expect(localCalendarDate(new Date('2026-03-08T04:30:00.000Z'), 'America/New_York')).toEqual(
      date('2026-03-07'),
    );
    expect(localCalendarDate(new Date('2026-03-09T03:30:00.000Z'), 'America/New_York')).toEqual(
      date('2026-03-08'),
    );
  });
});

describe('calendar stepping', () => {
  it('steps whole calendar days and finds the Monday of a week', () => {
    expect(addCalendarDays(date('2026-02-28'), 1)).toEqual(date('2026-03-01'));
    expect(mondayOfCalendarWeek(date('2026-09-20'))).toEqual(date('2026-09-14')); // Sunday
    expect(mondayOfCalendarWeek(date('2026-09-14'))).toEqual(date('2026-09-14')); // Monday
  });
});

describe('startOfLocalDay', () => {
  it('is local midnight as an instant', () => {
    expect(startOfLocalDay(date('2026-09-15'), 'Africa/Johannesburg').toISOString()).toBe(
      '2026-09-14T22:00:00.000Z',
    );
    expect(startOfLocalDay(date('2026-09-15'), 'UTC').toISOString()).toBe(
      '2026-09-15T00:00:00.000Z',
    );
  });

  it('uses the offset in force on that day either side of a DST change', () => {
    expect(startOfLocalDay(date('2026-03-08'), 'America/New_York').toISOString()).toBe(
      '2026-03-08T05:00:00.000Z',
    );
    expect(startOfLocalDay(date('2026-03-09'), 'America/New_York').toISOString()).toBe(
      '2026-03-09T04:00:00.000Z',
    );
    expect(startOfLocalDay(date('2026-11-02'), 'America/New_York').toISOString()).toBe(
      '2026-11-02T05:00:00.000Z',
    );
  });

  it('starts at the first real instant where DST skips midnight itself', () => {
    // America/Santiago springs forward at 00:00 → 01:00 on 6 Sep 2026. Midnight
    // never happens; the day begins at 01:00 local (-03), i.e. 04:00Z.
    const start = startOfLocalDay(date('2026-09-06'), 'America/Santiago');
    expect(start.toISOString()).toBe('2026-09-06T04:00:00.000Z');
    expect(localCalendarDate(start, 'America/Santiago')).toEqual(date('2026-09-06'));
    expect(localCalendarDate(new Date(start.getTime() - 1), 'America/Santiago')).toEqual(
      date('2026-09-05'),
    );
  });
});

describe('localClockMs / localInstantAt', () => {
  it('reads the wall clock and finds the same clock time on another date', () => {
    const now = new Date('2026-09-17T10:15:30.250Z'); // 12:15:30.250 SAST
    const clock = localClockMs(now, 'Africa/Johannesburg');
    expect(clock).toBe(((12 * 60 + 15) * 60 + 30) * 1000 + 250);
    expect(localInstantAt(date('2026-09-16'), clock, 'Africa/Johannesburg').toISOString()).toBe(
      '2026-09-16T10:15:30.250Z',
    );
  });

  it('keeps the clock time across a DST change, not the elapsed time', () => {
    // 10:30 on 7 Mar 2026 in New York is EST; on 8 Mar it is EDT.
    expect(localInstantAt(date('2026-03-07'), 10.5 * 3_600_000, 'America/New_York').toISOString()).toBe(
      '2026-03-07T15:30:00.000Z',
    );
    expect(localInstantAt(date('2026-03-08'), 10.5 * 3_600_000, 'America/New_York').toISOString()).toBe(
      '2026-03-08T14:30:00.000Z',
    );
  });

  it('never lands before the day starts where DST skips midnight', () => {
    // Santiago springs forward at midnight on 6 Sep 2026: 00:30 never happens,
    // and the day begins at 01:00 (-03), 04:00Z.
    expect(localInstantAt(date('2026-09-06'), 30 * 60_000, 'America/Santiago').toISOString()).toBe(
      '2026-09-06T04:00:00.000Z',
    );
  });
});
