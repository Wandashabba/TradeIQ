import {
  contestDaysLeft,
  contestStatus,
  formatCalendarDate,
  isContestEventType,
  localToday,
  parseCalendarDate,
  rankStandings,
} from './contestRules';

const day = (iso: string) => new Date(`${iso}T00:00:00.000Z`);

describe('parseCalendarDate', () => {
  it('reads YYYY-MM-DD as UTC midnight of that date', () => {
    expect(parseCalendarDate('2026-07-31')?.toISOString()).toBe('2026-07-31T00:00:00.000Z');
  });

  it.each([['2026-02-30'], ['2026-7-31'], ['2026-07-31T10:00:00Z'], [''], [20260731], [null]])(
    'refuses %p',
    (value) => {
      expect(parseCalendarDate(value)).toBeNull();
    },
  );

  it('formats a stored date back to the same string', () => {
    expect(formatCalendarDate(day('2026-09-01'))).toBe('2026-09-01');
  });
});

describe('contestStatus / contestDaysLeft', () => {
  const contest = { startDate: day('2026-07-01'), endDate: day('2026-07-31'), cancelledAt: null };

  it('is upcoming before the first day', () => {
    expect(contestStatus(contest, day('2026-06-30'))).toBe('upcoming');
    expect(contestDaysLeft(contest, day('2026-06-30'))).toBeNull();
  });

  it('is active on both inclusive ends, counting today in the days left', () => {
    expect(contestStatus(contest, day('2026-07-01'))).toBe('active');
    expect(contestDaysLeft(contest, day('2026-07-01'))).toBe(31);
    expect(contestStatus(contest, day('2026-07-31'))).toBe('active');
    expect(contestDaysLeft(contest, day('2026-07-31'))).toBe(1);
  });

  it('is ended the day after', () => {
    expect(contestStatus(contest, day('2026-08-01'))).toBe('ended');
    expect(contestDaysLeft(contest, day('2026-08-01'))).toBeNull();
  });

  it('is cancelled whatever the dates say', () => {
    const cancelled = { ...contest, cancelledAt: new Date('2026-07-05T10:00:00Z') };
    expect(contestStatus(cancelled, day('2026-07-10'))).toBe('cancelled');
    expect(contestDaysLeft(cancelled, day('2026-07-10'))).toBeNull();
  });

  it('takes "today" in the client zone, not UTC', () => {
    // 23:30Z on 31 Jul is already 1 Aug in Johannesburg.
    const now = new Date('2026-07-31T23:30:00Z');
    expect(contestStatus(contest, localToday('UTC', now))).toBe('active');
    expect(contestStatus(contest, localToday('Africa/Johannesburg', now))).toBe('ended');
  });
});

describe('isContestEventType', () => {
  it('accepts the ledger reasons only', () => {
    expect(isContestEventType('task_closed')).toBe(true);
    expect(isContestEventType('manual')).toBe(false);
    expect(isContestEventType(5)).toBe(false);
  });
});

describe('rankStandings', () => {
  it('shares a rank on equal points and skips the ranks the tie used', () => {
    const ranked = rankStandings([
      { agentId: 'z', email: 'carol@x.test', points: 3 },
      { agentId: 'y', email: 'bob@x.test', points: 7 },
      { agentId: 'x', email: 'alice@x.test', points: 7 },
      { agentId: 'w', email: 'dan@x.test', points: 0 },
    ]);
    expect(ranked.map((r) => [r.email, r.rank])).toEqual([
      ['alice@x.test', 1],
      ['bob@x.test', 1],
      ['carol@x.test', 3],
      ['dan@x.test', 4],
    ]);
  });

  it('orders a tie by code unit, not locale, then by id', () => {
    const ranked = rankStandings([
      { agentId: 'b', email: 'a@x.test', points: 1 },
      { agentId: 'a', email: 'a@x.test', points: 1 },
      { agentId: 'c', email: 'B@x.test', points: 1 },
    ]);
    expect(ranked.map((r) => r.agentId)).toEqual(['c', 'a', 'b']);
    expect(ranked.every((r) => r.rank === 1)).toBe(true);
  });
});
