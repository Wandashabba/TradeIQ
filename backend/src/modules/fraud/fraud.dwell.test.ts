import { DEFAULT_CLIENT_TIME_ZONE } from '../../lib/clientTime';
import {
  computeFraudSignals,
  DEFAULT_SLOW_COMPLETION_MINUTES,
  dwellBand,
  FAST_COMPLETION_MINUTES_KEY,
  FraudVisitInput,
  SLOW_COMPLETION_MINUTES_KEY,
} from './fraud.service';

/**
 * #101 — dwell time used to be `sectionRow.createdAt (SERVER) - visit.checkinTs
 * (CLIENT)`. Two different clocks, and on an offline-first app the server one is
 * "whenever the outbox flushed". The figure was wrong in both directions:
 *
 *   * a device clock running ahead made dwell negative, which the old code
 *     clamped to 0 and reported as "completed ~0s after check-in" — 20 points of
 *     fraud risk on an agent who did nothing wrong;
 *   * a delayed sync inflated dwell, so a genuine 20-second ghost visit sailed
 *     through unflagged.
 *
 * Dwell is now measured on ONE clock: the device's own `submittedAtClient`
 * against its own `checkinTs`.
 */
describe('fast_completion dwell (#101)', () => {
  const checkinTs = new Date('2026-07-13T09:00:00.000Z');

  function visit(overrides: Partial<FraudVisitInput> = {}): FraudVisitInput {
    return {
      id: 'v1',
      status: 'submitted',
      agentId: 'a1',
      outletId: 'o1',
      checkinTs,
      checkinLat: -26.2,
      checkinLng: 28.0,
      // Well inside the fence, so no other signal fires and the score is purely
      // the dwell verdict.
      checkinDistanceM: 5,
      ...overrides,
    };
  }

  const related = {
    photos: [],
    // The server inserted every section row at once, hours after the visit —
    // exactly what an offline sync burst looks like.
    sectionCreatedAts: [new Date('2026-07-13T17:30:00.000Z')],
    failedAttempts: [],
  };

  const codes = (v: FraudVisitInput) =>
    computeFraudSignals(v, related, {}, DEFAULT_CLIENT_TIME_ZONE).signals.map((s) => s.code);

  it('flags a genuinely fast visit using the device clock', () => {
    const result = computeFraudSignals(
      visit({ submittedAtClient: new Date('2026-07-13T09:00:20.000Z') }), // 20s
      related,
      {},
      DEFAULT_CLIENT_TIME_ZONE,
    );

    expect(result.signals.map((s) => s.code)).toContain('fast_completion');
    expect(result.riskScore).toBe(20);
    // The detail says which clock it trusted, so a reviewer can weigh it.
    expect(result.signals[0].detail).toContain('device clock');
  });

  it('does NOT flag an agent who spent 40 minutes in the store but synced hours later', () => {
    // The whole false-positive class. The section rows landed on the server at
    // 17:30 — eight and a half hours after check-in — because the agent was in a
    // dead zone. That says nothing about how long they spent in the store.
    const result = computeFraudSignals(
      visit({ submittedAtClient: new Date('2026-07-13T09:40:00.000Z') }), // 40 min
      related,
      {},
      DEFAULT_CLIENT_TIME_ZONE,
    );

    expect(result.signals.map((s) => s.code)).not.toContain('fast_completion');
    expect(result.riskScore).toBe(0);
  });

  it('does NOT flag a negative dwell — that is a clock that moved, not fraud', () => {
    // Device clock ran ahead: it reports finishing BEFORE it checked in. The old
    // code clamped this to "~0s" and charged 20 points of fraud risk for it.
    const result = computeFraudSignals(
      visit({ submittedAtClient: new Date('2026-07-13T08:59:30.000Z') }),
      related,
      {},
      DEFAULT_CLIENT_TIME_ZONE,
    );

    expect(result.signals.map((s) => s.code)).not.toContain('fast_completion');
    expect(result.riskScore).toBe(0);
  });

  it('emits NOTHING when the device sent no completion time', () => {
    // Legacy visits, and any client too old to send it. Dwell is unmeasurable,
    // and a fabricated signal that gets someone investigated is worse than a
    // missing one.
    expect(codes(visit({ submittedAtClient: null }))).not.toContain('fast_completion');
    expect(codes(visit())).not.toContain('fast_completion');
  });

  it('leaves the other heuristics untouched', () => {
    // A visit with no captured data at all is still caught — dwell is only one
    // heuristic among several, and narrowing it must not blunt the rest.
    const result = computeFraudSignals(visit({ submittedAtClient: null }), {
      ...related,
      sectionCreatedAts: [],
    }, {}, DEFAULT_CLIENT_TIME_ZONE);

    expect(result.signals.map((s) => s.code)).toContain('no_capture');
  });
});

/**
 * #247 — the opposite tail. Too fast means the audit was not done; too slow
 * means something else is going on (the agent left mid-visit, the app sat open
 * in a pocket, the record was padded). Same one clock as #101, a per-client band
 * from kpiThresholds, and a capped weight because an idle app is not fraud.
 */
describe('slow_completion dwell (#247)', () => {
  const checkinTs = new Date('2026-07-13T09:00:00.000Z');
  const minutesAfter = (m: number) => new Date(checkinTs.getTime() + m * 60_000);

  function visit(overrides: Partial<FraudVisitInput> = {}): FraudVisitInput {
    return {
      id: 'v1',
      status: 'submitted',
      agentId: 'a1',
      outletId: 'o1',
      checkinTs,
      checkinLat: -26.2,
      checkinLng: 28.0,
      checkinDistanceM: 5,
      ...overrides,
    };
  }

  const related = {
    photos: [],
    sectionCreatedAts: [new Date('2026-07-13T09:10:00.000Z')],
    failedAttempts: [],
  };

  const codes = (v: FraudVisitInput, kpi?: unknown) =>
    computeFraudSignals(v, related, kpi, DEFAULT_CLIENT_TIME_ZONE).signals.map((s) => s.code);

  it('fires above the default band, on the device clock', () => {
    const result = computeFraudSignals(
      visit({ submittedAtClient: minutesAfter(DEFAULT_SLOW_COMPLETION_MINUTES + 12) }),
      related,
      {},
      DEFAULT_CLIENT_TIME_ZONE,
    );

    expect(result.signals.map((s) => s.code)).toEqual(['slow_completion']);
    expect(result.riskScore).toBe(10);
    expect(result.signals[0].detail).toBe(
      'Visit took 60 min from check-in to submit (device clock), over the 48 min ' +
        'benchmark; an app left open also does this',
    );
  });

  it('is silent within the band, including a thorough audit well past 12 minutes', () => {
    expect(codes(visit({ submittedAtClient: minutesAfter(12) }))).toEqual([]);
    expect(codes(visit({ submittedAtClient: minutesAfter(40) }))).toEqual([]);
    // The edge itself is inside the band.
    expect(codes(visit({ submittedAtClient: minutesAfter(DEFAULT_SLOW_COMPLETION_MINUTES) }))).toEqual(
      [],
    );
  });

  it('is silent without submittedAtClient, however late the server rows landed', () => {
    // Section rows synced nine hours later. That is the network, not the agent,
    // and it must not be read as a slow visit.
    const lateSync = { ...related, sectionCreatedAts: [new Date('2026-07-13T18:00:00.000Z')] };
    expect(computeFraudSignals(
      visit({ submittedAtClient: null }),
      lateSync,
      {},
      DEFAULT_CLIENT_TIME_ZONE,
    ).signals).toEqual([]);
    expect(computeFraudSignals(visit(), lateSync, {}, DEFAULT_CLIENT_TIME_ZONE).signals).toEqual([]);
  });

  it('does not fire on a draft, or on a submitted visit with nothing captured', () => {
    expect(codes(visit({ status: 'in_progress', submittedAtClient: minutesAfter(120) }))).toEqual([]);
    const none = computeFraudSignals(visit({ submittedAtClient: minutesAfter(120) }), {
      ...related,
      sectionCreatedAts: [],
    }, {}, DEFAULT_CLIENT_TIME_ZONE);
    // no_capture already says the stronger thing.
    expect(none.signals.map((s) => s.code)).toEqual(['no_capture']);
  });

  it('respects a per-client kpiThresholds override, in both directions', () => {
    const thirty = visit({ submittedAtClient: minutesAfter(30) });
    // A client whose audits are genuinely short tightens the band...
    expect(codes(thirty, { [SLOW_COMPLETION_MINUTES_KEY]: 20 })).toEqual(['slow_completion']);
    // ...and one with long-format audits loosens it.
    const seventy = visit({ submittedAtClient: minutesAfter(70) });
    expect(codes(seventy)).toEqual(['slow_completion']);
    expect(codes(seventy, { [SLOW_COMPLETION_MINUTES_KEY]: 90 })).toEqual([]);
    // The detail names the band that was actually applied.
    const [signal] = computeFraudSignals(
      thirty,
      related,
      { slowCompletionMinutes: 20 },
      DEFAULT_CLIENT_TIME_ZONE,
    ).signals;
    expect(signal.detail).toContain('over the 20 min benchmark');
  });

  it('reads the keys the engine documents, and ignores ones it does not', () => {
    // #97: a seeded key nothing reads is silently inert. Pin the literal names.
    expect(SLOW_COMPLETION_MINUTES_KEY).toBe('slowCompletionMinutes');
    expect(FAST_COMPLETION_MINUTES_KEY).toBe('fastCompletionMinutes');
    const thirty = visit({ submittedAtClient: minutesAfter(30) });
    expect(codes(thirty, { dwellMaxMinutes: 20, slowCompletionMins: 20 })).toEqual([]);
  });

  it('makes the fast edge of the band configurable too, keeping its 1-minute default', () => {
    const ninetySeconds = visit({ submittedAtClient: new Date(checkinTs.getTime() + 90_000) });
    expect(codes(ninetySeconds)).toEqual([]);
    expect(codes(ninetySeconds, { [FAST_COMPLETION_MINUTES_KEY]: 2 })).toEqual(['fast_completion']);
    // 0 switches the fast tail off rather than doing anything surprising.
    const tenSeconds = visit({ submittedAtClient: new Date(checkinTs.getTime() + 10_000) });
    expect(codes(tenSeconds)).toEqual(['fast_completion']);
    expect(codes(tenSeconds, { [FAST_COMPLETION_MINUTES_KEY]: 0 })).toEqual([]);
  });

  it('falls back to the default when the upper edge is not a positive number', () => {
    // Zero or negative would flag every visit the tenant has: a typo, not a policy.
    expect(dwellBand({ slowCompletionMinutes: 0 }).slowMs).toBe(
      DEFAULT_SLOW_COMPLETION_MINUTES * 60_000,
    );
    expect(dwellBand({ slowCompletionMinutes: -5 }).slowMs).toBe(
      DEFAULT_SLOW_COMPLETION_MINUTES * 60_000,
    );
    expect(dwellBand({ fastCompletionMinutes: -1 }).fastMs).toBe(0);
    expect(codes(visit({ submittedAtClient: minutesAfter(30) }), { slowCompletionMinutes: 0 })).toEqual(
      [],
    );
  });

  it('caps an idle app: a phone left open overnight scores no higher than a 49-minute visit', () => {
    const justOver = computeFraudSignals(
      visit({ submittedAtClient: minutesAfter(49) }),
      related,
      {},
      DEFAULT_CLIENT_TIME_ZONE,
    );
    const overnight = computeFraudSignals(
      visit({ submittedAtClient: minutesAfter(14 * 60) }),
      related,
      {},
      DEFAULT_CLIENT_TIME_ZONE,
    );

    expect(justOver.riskScore).toBe(10);
    expect(overnight.riskScore).toBe(justOver.riskScore);
    // Alone it cannot reach the default review threshold (50), so an idle app
    // never lands a visit on the flagged list by itself.
    expect(overnight.riskScore).toBeLessThan(50);
  });

  it('still corroborates other evidence when it co-occurs with it', () => {
    const result = computeFraudSignals(
      visit({ submittedAtClient: minutesAfter(90), checkinDistanceM: 45 }),
      {
        ...related,
        photos: [{ gpsTag: { lat: -26.21, lng: 28.0 } }],
      },
      {},
      DEFAULT_CLIENT_TIME_ZONE,
    );

    expect(result.signals.map((s) => s.code)).toEqual(
      expect.arrayContaining(['geofence_distance', 'photo_gps_divergence', 'slow_completion']),
    );
    // 20 + 25 + 10.
    expect(result.riskScore).toBe(55);
  });

  it('never fires alongside fast_completion — a visit sits in one tail at most', () => {
    for (const minutes of [0, 0.5, 1, 12, 48, 49, 600]) {
      const found = codes(visit({ submittedAtClient: minutesAfter(minutes) }));
      expect(found.filter((c) => c.endsWith('_completion')).length).toBeLessThanOrEqual(1);
    }
  });
});
