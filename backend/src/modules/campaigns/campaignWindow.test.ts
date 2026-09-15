import {
  baselineWindow,
  campaignRunningAt,
  campaignWindow,
  storedCampaignDate,
  type LocalDayWindow,
} from './campaignWindow';

/** How the campaign form's `YYYY-MM-DD` is stored: UTC midnight of that date. */
const plain = (ymd: string) => new Date(ymd);
const at = (iso: string) => new Date(iso);
const contains = (w: LocalDayWindow, instant: Date) =>
  instant.getTime() >= w.from.getTime() && instant.getTime() < w.to.getTime();

const SAST = 'Africa/Johannesburg';
const NEW_YORK = 'America/New_York';

describe('storedCampaignDate', () => {
  it('keeps a plain date as its own calendar date', () => {
    expect(storedCampaignDate(plain('2026-09-30')).toISOString()).toBe('2026-09-30T00:00:00.000Z');
  });

  it('normalises a stored instant to its UTC calendar date', () => {
    expect(storedCampaignDate(at('2026-07-31T23:59:59.000Z')).toISOString()).toBe(
      '2026-07-31T00:00:00.000Z',
    );
    // Even where that instant is already the next day locally: the stored value
    // names a date, and the UTC date is the one a plain date would have had.
    expect(storedCampaignDate(at('2026-09-30T22:00:00.000Z')).toISOString()).toBe(
      '2026-09-30T00:00:00.000Z',
    );
  });
});

describe('campaignWindow (#324)', () => {
  const window = campaignWindow(plain('2026-09-01'), plain('2026-09-30'), SAST);

  it('runs from local midnight of the start date to local midnight after the end date', () => {
    expect(window.from.toISOString()).toBe('2026-08-31T22:00:00.000Z');
    expect(window.to.toISOString()).toBe('2026-09-30T22:00:00.000Z');
    expect(window.days).toBe(30);
  });

  it('counts 15:00 local on the end date', () => {
    expect(contains(window, at('2026-09-30T13:00:00.000Z'))).toBe(true);
  });

  it('does not count 00:30 local on the day after the end date', () => {
    expect(contains(window, at('2026-09-30T22:30:00.000Z'))).toBe(false);
  });

  it('does not count 23:30 local on the day before the start date', () => {
    expect(contains(window, at('2026-08-31T21:30:00.000Z'))).toBe(false);
  });

  it('counts local midnight of the start date itself', () => {
    expect(contains(window, at('2026-08-31T22:00:00.000Z'))).toBe(true);
  });

  it('is one whole day when start and end are the same date', () => {
    const oneDay = campaignWindow(plain('2026-05-05'), plain('2026-05-05'), SAST);
    expect(oneDay.days).toBe(1);
    expect(oneDay.to.getTime() - oneDay.from.getTime()).toBe(24 * 60 * 60 * 1000);
  });

  it('is empty, not negative, when the end date precedes the start date', () => {
    const backwards = campaignWindow(plain('2026-05-10'), plain('2026-05-05'), SAST);
    expect(backwards.days).toBe(0);
    expect(backwards.to.getTime()).toBe(backwards.from.getTime());
    const base = baselineWindow(backwards, SAST);
    expect(base.to.getTime()).toBe(base.from.getTime());
  });

  it('follows the DST change in America/New_York (ends 2 Nov 2025)', () => {
    const ny = campaignWindow(plain('2025-10-27'), plain('2025-11-02'), NEW_YORK);

    expect(ny.from.toISOString()).toBe('2025-10-27T04:00:00.000Z'); // 00:00 EDT
    expect(ny.to.toISOString()).toBe('2025-11-03T05:00:00.000Z'); // 00:00 EST
    expect(ny.days).toBe(7);

    expect(contains(ny, at('2025-11-02T20:00:00.000Z'))).toBe(true); // 15:00 EST, end date
    // 23:30 EST on the end date: a stale EDT offset would put this on 3 Nov.
    expect(contains(ny, at('2025-11-03T04:30:00.000Z'))).toBe(true);
    expect(contains(ny, at('2025-11-03T05:30:00.000Z'))).toBe(false); // 00:30 EST, 3 Nov
    expect(contains(ny, at('2025-10-27T03:30:00.000Z'))).toBe(false); // 23:30 EDT, 26 Oct
  });
});

describe('baselineWindow', () => {
  it('is the equal-length run of local days immediately before the campaign', () => {
    const june = campaignWindow(plain('2026-06-01'), plain('2026-06-30'), SAST);
    const base = baselineWindow(june, SAST);

    // 2 May – 31 May, local.
    expect(base.from.toISOString()).toBe('2026-05-01T22:00:00.000Z');
    expect(base.to.toISOString()).toBe('2026-05-31T22:00:00.000Z');
    expect(base.days).toBe(june.days);
  });

  it('is contiguous with the campaign, leaving no unmeasured gap', () => {
    const w = campaignWindow(plain('2026-03-10'), plain('2026-03-17'), SAST);
    expect(baselineWindow(w, SAST).to.getTime()).toBe(w.from.getTime());
  });

  it('counts local days, not milliseconds, across a DST change (starts 8 Mar 2026)', () => {
    const w = campaignWindow(plain('2026-03-09'), plain('2026-03-15'), NEW_YORK);
    const base = baselineWindow(w, NEW_YORK);

    // 2 Mar – 8 Mar local: seven days, one of them 23 hours long.
    expect(base.from.toISOString()).toBe('2026-03-02T05:00:00.000Z'); // 00:00 EST
    expect(base.to.toISOString()).toBe('2026-03-09T04:00:00.000Z'); // 00:00 EDT
    expect(base.days).toBe(7);
    expect(base.to.getTime()).toBe(w.from.getTime());

    expect(contains(base, at('2026-03-09T03:30:00.000Z'))).toBe(true); // 23:30 EDT, 8 Mar
    expect(contains(base, at('2026-03-09T04:30:00.000Z'))).toBe(false); // 00:30 EDT, 9 Mar
    expect(contains(w, at('2026-03-09T04:30:00.000Z'))).toBe(true);
  });
});

describe('campaignRunningAt', () => {
  it('matches on the local calendar date the instant falls on', () => {
    // 00:30 SAST on 1 Oct is still 30 Sep in UTC; the filter must use 1 Oct.
    expect(campaignRunningAt(at('2026-09-30T22:30:00.000Z'), SAST)).toEqual({
      startDate: { lt: new Date('2026-10-02T00:00:00.000Z') },
      endDate: { gte: new Date('2026-10-01T00:00:00.000Z') },
    });
  });
});
