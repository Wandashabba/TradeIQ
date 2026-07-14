import { computeFraudSignals, FraudVisitInput } from './fraud.service';

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
    computeFraudSignals(v, related).signals.map((s) => s.code);

  it('flags a genuinely fast visit using the device clock', () => {
    const result = computeFraudSignals(
      visit({ submittedAtClient: new Date('2026-07-13T09:00:20.000Z') }), // 20s
      related,
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
    // of five signals, and narrowing it must not blunt the rest.
    const result = computeFraudSignals(visit({ submittedAtClient: null }), {
      ...related,
      sectionCreatedAts: [],
    });

    expect(result.signals.map((s) => s.code)).toContain('no_capture');
  });
});
