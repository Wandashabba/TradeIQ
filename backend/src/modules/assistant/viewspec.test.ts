import { z } from 'zod';
import {
  describePeriod,
  InvalidPeriodError,
  periodSchema,
  resolvePeriod,
  type Period,
} from './period';
import { validateViewSpec, VIEW_SPEC_TYPES } from './viewspec';

const NOW = new Date('2026-08-06T14:30:00.000Z'); // a Thursday
// The pre-#309 calendar, which these cases were written against. Client-zone
// behaviour has its own block below.
const UTC = 'UTC';

describe('resolvePeriod', () => {
  it('gives today a half-open range covering exactly one day', () => {
    // Half-open, so a row written at 23:59:59.999 is still "today". An
    // inclusive end of 23:59:59 silently drops the final second's rows.
    const { from, to } = resolvePeriod({ kind: 'today' }, NOW, UTC);
    expect(from.toISOString()).toBe('2026-08-06T00:00:00.000Z');
    expect(to.toISOString()).toBe('2026-08-07T00:00:00.000Z');
  });

  it('gives yesterday the day before, not the last 24 hours', () => {
    const { from, to } = resolvePeriod({ kind: 'yesterday' }, NOW, UTC);
    expect(from.toISOString()).toBe('2026-08-05T00:00:00.000Z');
    expect(to.toISOString()).toBe('2026-08-06T00:00:00.000Z');
  });

  it('gives previous_week the previous calendar week, Monday to Monday', () => {
    // Not "the last 7 days". A manager asking about last week means the week
    // that finished; a rolling window folds today's partial data into it.
    const { from, to } = resolvePeriod({ kind: 'previous_week' }, NOW, UTC);
    expect(from.toISOString()).toBe('2026-07-27T00:00:00.000Z');
    expect(to.toISOString()).toBe('2026-08-03T00:00:00.000Z');
    expect(from.getUTCDay()).toBe(1);
  });

  it('handles previous_week when today is a Monday', () => {
    // The boundary case: on a Monday, "this Monday" is today, so the previous
    // week must not collapse to zero days.
    const monday = new Date('2026-08-03T09:00:00.000Z');
    const { from, to } = resolvePeriod({ kind: 'previous_week' }, monday, UTC);
    expect(from.toISOString()).toBe('2026-07-27T00:00:00.000Z');
    expect(to.toISOString()).toBe('2026-08-03T00:00:00.000Z');
  });

  it('handles previous_week when today is a Sunday', () => {
    const sunday = new Date('2026-08-09T09:00:00.000Z');
    const { from } = resolvePeriod({ kind: 'previous_week' }, sunday, UTC);
    expect(from.toISOString()).toBe('2026-07-27T00:00:00.000Z');
  });

  it('runs mtd from the first of the month through the end of today', () => {
    const { from, to } = resolvePeriod({ kind: 'mtd' }, NOW, UTC);
    expect(from.toISOString()).toBe('2026-08-01T00:00:00.000Z');
    expect(to.toISOString()).toBe('2026-08-07T00:00:00.000Z');
  });

  it('runs ytd from 1 January', () => {
    const { from, to } = resolvePeriod({ kind: 'ytd' }, NOW, UTC);
    expect(from.toISOString()).toBe('2026-01-01T00:00:00.000Z');
    expect(to.toISOString()).toBe('2026-08-07T00:00:00.000Z');
  });

  it('includes the whole of a custom range\'s final day', () => {
    // The user's `to` is the last day they mean. Using it as the exclusive
    // bound drops that entire day — an off-by-one that reads as missing data.
    const { from, to } = resolvePeriod(
      { kind: 'custom', from: '2026-07-01', to: '2026-07-31' },
      NOW,
      UTC,
    );
    expect(from.toISOString()).toBe('2026-07-01T00:00:00.000Z');
    expect(to.toISOString()).toBe('2026-08-01T00:00:00.000Z');
  });

  it('accepts a single-day custom range', () => {
    const { from, to } = resolvePeriod(
      { kind: 'custom', from: '2026-07-15', to: '2026-07-15' },
      NOW,
      UTC,
    );
    expect(to.getTime() - from.getTime()).toBe(86_400_000);
  });

  it('rejects a custom range that runs backwards', () => {
    expect(() =>
      resolvePeriod({ kind: 'custom', from: '2026-07-31', to: '2026-07-01' }, NOW, UTC),
    ).toThrow(InvalidPeriodError);
  });

  it('is stable across a year boundary', () => {
    const newYear = new Date('2027-01-01T02:00:00.000Z');
    expect(resolvePeriod({ kind: 'ytd' }, newYear, UTC).from.toISOString()).toBe(
      '2027-01-01T00:00:00.000Z',
    );
    expect(resolvePeriod({ kind: 'previous_week' }, newYear, UTC).from.toISOString()).toBe(
      '2026-12-21T00:00:00.000Z',
    );
  });

  it('takes now as a parameter rather than reading the clock', () => {
    // A service that reads its own clock is a test that fails on a date nobody
    // chose — the trap that bit the fraud suite in #262.
    const a = resolvePeriod({ kind: 'mtd' }, new Date('2026-03-15T00:00:00Z'), UTC);
    expect(a.from.toISOString()).toBe('2026-03-01T00:00:00.000Z');
  });
});

describe('resolvePeriod in the client timezone (#309)', () => {
  const SAST = 'Africa/Johannesburg';

  it("counts today on the client's calendar, as local-midnight instants", () => {
    // 00:30 SAST on 7 Aug is still 6 Aug in UTC. Today is the 7th.
    const justAfterMidnight = new Date('2026-08-06T22:30:00.000Z');
    const { from, to } = resolvePeriod({ kind: 'today' }, justAfterMidnight, SAST);
    expect(from.toISOString()).toBe('2026-08-06T22:00:00.000Z');
    expect(to.toISOString()).toBe('2026-08-07T22:00:00.000Z');
  });

  it('resolves previous_week, mtd, ytd and custom to SAST midnights', () => {
    expect(resolvePeriod({ kind: 'previous_week' }, NOW, SAST)).toEqual({
      from: new Date('2026-07-26T22:00:00.000Z'),
      to: new Date('2026-08-02T22:00:00.000Z'),
    });
    expect(resolvePeriod({ kind: 'mtd' }, NOW, SAST).from.toISOString()).toBe(
      '2026-07-31T22:00:00.000Z',
    );
    expect(resolvePeriod({ kind: 'ytd' }, NOW, SAST).from.toISOString()).toBe(
      '2025-12-31T22:00:00.000Z',
    );
    expect(
      resolvePeriod({ kind: 'custom', from: '2026-07-01', to: '2026-07-31' }, NOW, SAST),
    ).toEqual({
      from: new Date('2026-06-30T22:00:00.000Z'),
      to: new Date('2026-07-31T22:00:00.000Z'),
    });
  });

  it('gives a day that spans a DST change its real, shorter length', () => {
    // America/New_York springs forward on Sunday 8 March 2026: that local day
    // is 23 hours long. Stepping instants by 24h would end it at 01:00 on the 9th.
    const { from, to } = resolvePeriod(
      { kind: 'today' },
      new Date('2026-03-08T15:00:00.000Z'),
      'America/New_York',
    );
    expect(from.toISOString()).toBe('2026-03-08T05:00:00.000Z');
    expect(to.toISOString()).toBe('2026-03-09T04:00:00.000Z');
    expect(to.getTime() - from.getTime()).toBe(23 * 3_600_000);
  });
});

describe('describePeriod', () => {
  it.each<[Period, string]>([
    [{ kind: 'today' }, 'today'],
    [{ kind: 'mtd' }, 'month to date'],
    [{ kind: 'custom', from: '2026-01-01', to: '2026-01-31' }, '2026-01-01 to 2026-01-31'],
  ])('describes %j', (period, expected) => {
    expect(describePeriod(period)).toBe(expected);
  });
});

describe('validateViewSpec', () => {
  it('accepts a well-formed agent_scorecard', () => {
    const result = validateViewSpec({
      type: 'agent_scorecard',
      params: { agentId: 'agent-1', period: { kind: 'mtd' } },
    });
    expect(result.ok).toBe(true);
  });

  it('rejects a spec type outside the catalog', () => {
    // The catalog is closed. An unknown type must degrade to text, never to a
    // blank card — a blank card reads as an app bug.
    const result = validateViewSpec({ type: 'pie_of_doom', params: {} });
    expect(result.ok).toBe(false);
    expect((result as { reason: string }).reason).toMatch(/Unknown view spec/);
  });

  it('does not resolve a type off the prototype chain', () => {
    // `"constructor" in catalog` is true. Using `in` instead of hasOwnProperty
    // would hand a Function to safeParse and throw inside the orchestrator.
    for (const evil of ['constructor', 'toString', '__proto__', 'hasOwnProperty']) {
      const result = validateViewSpec({ type: evil, params: {} });
      expect(result.ok).toBe(false);
    }
  });

  it('rejects malformed params and says which field', () => {
    const result = validateViewSpec({
      type: 'agent_scorecard',
      params: { agentId: '', period: { kind: 'mtd' } },
    });
    expect(result.ok).toBe(false);
    expect((result as { issues: string[] }).issues.join()).toMatch(/agentId/);
  });

  it('rejects an unknown period kind', () => {
    const result = validateViewSpec({
      type: 'agent_scorecard',
      params: { agentId: 'a', period: { kind: 'last_fortnight' } },
    });
    expect(result.ok).toBe(false);
  });

  it('rejects a custom period without dates', () => {
    const result = validateViewSpec({
      type: 'agent_scorecard',
      params: { agentId: 'a', period: { kind: 'custom' } },
    });
    expect(result.ok).toBe(false);
  });

  it('rejects dates supplied alongside a fixed period', () => {
    // `{kind: 'mtd', from: '2026-01-01'}` is the model contradicting itself.
    // Silently ignoring the dates answers a different question from the one
    // asked, which is the worst way to be wrong here.
    const result = validateViewSpec({
      type: 'agent_scorecard',
      params: { agentId: 'a', period: { kind: 'mtd', from: '2026-01-01', to: '2026-01-31' } },
    });
    expect(result.ok).toBe(false);
  });

  it('declares the period as a flat object, not a oneOf', () => {
    // Gemini's Schema has no `oneOf`, and every tool takes a period — so a
    // discriminated union here is a 400 on literally every turn. Caught once
    // by tools.test.ts; pinned here so the spelling cannot quietly revert.
    const shape = JSON.stringify(z.toJSONSchema(periodSchema, { io: 'input' }));
    expect(shape).not.toContain('oneOf');
    expect(shape).not.toContain('anyOf');
  });

  it('rejects a non-ISO custom date', () => {
    const result = validateViewSpec({
      type: 'agent_scorecard',
      params: { agentId: 'a', period: { kind: 'custom', from: '01/07/2026', to: '2026-07-31' } },
    });
    expect(result.ok).toBe(false);
  });

  it('rejects a metric the backend cannot compute', () => {
    // A metric with no series behind it renders an empty chart, and the model
    // has no way to know that in advance.
    const result = validateViewSpec({
      type: 'trend_chart',
      params: { metric: 'vibes', period: { kind: 'mtd' } },
    });
    expect(result.ok).toBe(false);
  });

  it('defaults a trend interval rather than requiring one', () => {
    const result = validateViewSpec({
      type: 'trend_chart',
      params: { metric: 'availability', period: { kind: 'mtd' } },
    });
    expect(result.ok).toBe(true);
    expect((result as { spec: { params: { interval: string } } }).spec.params.interval).toBe('day');
  });

  it('requires an outlet map to be scoped', () => {
    // An unscoped map is every outlet in the tenant: not a useful answer to any
    // question, and slow on a large client.
    expect(validateViewSpec({ type: 'outlet_map', params: {} }).ok).toBe(false);
    expect(validateViewSpec({ type: 'outlet_map', params: { outletIds: [] } }).ok).toBe(false);
    expect(validateViewSpec({ type: 'outlet_map', params: { territoryId: 't1' } }).ok).toBe(true);
    expect(validateViewSpec({ type: 'outlet_map', params: { outletIds: ['o1'] } }).ok).toBe(true);
  });

  it.each([[null], [undefined], ['a string'], [42], [[]]])('rejects %p as a spec', (value) => {
    expect(validateViewSpec(value).ok).toBe(false);
  });

  it('rejects a spec with no type', () => {
    expect(validateViewSpec({ params: {} }).ok).toBe(false);
  });

  it('carries the comparison basis in pillar_metrics params, never the figures', () => {
    // Params identify the view; the numbers ride in the artifact's data. If a
    // figure lived here, a filter change would be a data edit — and `refine`
    // re-runs the tool precisely so it never is.
    const spec = validateViewSpec({
      type: 'pillar_metrics',
      params: {
        pillar: 'visibility',
        period: { kind: 'mtd' },
        compareTo: { kind: 'same_period_last_year' },
      },
    });

    expect(spec).toMatchObject({ ok: true });
    expect(JSON.stringify(spec)).not.toMatch(/\d+\.\d+/);
  });

  it('rejects a pillar outside the four', () => {
    // The pillars are the practitioner's own mental model, not a free-text tag.
    expect(
      validateViewSpec({
        type: 'pillar_metrics',
        params: { pillar: 'logistics', period: { kind: 'mtd' } },
      }),
    ).toMatchObject({ ok: false });
  });

  it('covers every catalog entry with at least one valid example', () => {
    // Guards against a spec being added to the catalog and never exercised —
    // which is how an unvalidatable schema ships.
    const examples: Record<string, unknown> = {
      agent_scorecard: { agentId: 'a', period: { kind: 'today' } },
      trend_chart: { metric: 'execution_score', period: { kind: 'ytd' } },
      outlet_map: { territoryId: 't1' },
      pillar_metrics: { pillar: 'stock', period: { kind: 'mtd' } },
    };
    for (const type of VIEW_SPEC_TYPES) {
      expect(validateViewSpec({ type, params: examples[type] })).toMatchObject({ ok: true });
    }
  });
});
