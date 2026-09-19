import { DEFAULT_CLIENT_TIME_ZONE } from '../../lib/clientTime';
import {
  computeFraudSignals,
  FraudPinDispute,
  FraudRelatedInput,
  FraudVisitInput,
  OVERRIDE_CLUSTER_RADIUS_M,
} from './fraud.service';

/**
 * #386 follow-up — the override signals that read the CLAIM, not just the visit.
 *
 * geofence_override alone was the hole. Weighted under the review threshold on
 * purpose (an honest report of a wrongly pinned shop must not read as fraud),
 * it meant that scoring each visit in isolation could never say anything about
 * an agent who filed ten claims from their sofa, nor about a manager who had
 * already looked and said the pin stands.
 *
 * These are the pure cases. The attack itself, end to end over HTTP, is
 * outlets.pinOverrideBounds.test.ts.
 */
describe('the override signals read the claim (#386 follow-up)', () => {
  const claimedAt = new Date('2026-09-15T09:00:00.000Z');
  const daysBefore = (d: number) => new Date(claimedAt.getTime() - d * 24 * 60 * 60 * 1000);

  // Where the agent says they are standing, and a point ~40m away: inside the
  // cluster radius, and nothing like far enough to be a different shop.
  const HOME = { lat: -26.1076, lng: 28.0567 };
  const NEXT_DOOR = { lat: -26.10796, lng: 28.0567 };
  // ~1.1km away: a different building entirely.
  const ACROSS_TOWN = { lat: -26.1176, lng: 28.0567 };

  const visit: FraudVisitInput = {
    id: 'v1',
    status: 'in_progress',
    agentId: 'a1',
    outletId: 'o1',
    checkinTs: claimedAt,
    checkinLat: HOME.lat,
    checkinLng: HOME.lng,
    checkinDistanceM: 3200,
    geofencePass: false,
  };

  const own: FraudPinDispute = {
    visitId: 'v1',
    agentId: 'a1',
    outletId: 'o1',
    lat: HOME.lat,
    lng: HOME.lng,
    status: 'open',
    createdAt: claimedAt,
  };

  const peer = (over: Partial<FraudPinDispute>): FraudPinDispute => ({
    ...own,
    visitId: `peer-${over.visitId ?? over.outletId ?? 'x'}`,
    ...over,
  });

  const related = (over: Partial<FraudRelatedInput> = {}): FraudRelatedInput => ({
    photos: [],
    sectionCreatedAts: [],
    failedAttempts: [],
    pinDispute: own,
    agentPinDisputes: [own],
    ...over,
  });

  const score = (over: Partial<FraudRelatedInput> = {}, v: FraudVisitInput = visit) =>
    computeFraudSignals(v, related(over), {}, DEFAULT_CLIENT_TIME_ZONE);

  it('accuses nobody for one wrong-pin report', () => {
    const { signals, riskScore } = score();
    expect(signals.map((s) => s.code)).toEqual(['geofence_override']);
    // The reason the whole feature exists. A queue that flags every honest
    // report is a queue managers stop reading.
    expect(riskScore).toBeLessThan(50);
  });

  it('carries a habitual overrider past the review threshold', () => {
    const { signals, riskScore } = score({
      agentPinDisputes: [
        own,
        peer({ visitId: 'v2', outletId: 'o2', lat: ACROSS_TOWN.lat, createdAt: daysBefore(1) }),
        peer({ visitId: 'v3', outletId: 'o3', lat: ACROSS_TOWN.lat, createdAt: daysBefore(3) }),
      ],
    });
    const rate = signals.find((s) => s.code === 'geofence_override_rate');
    expect(rate).toBeDefined();
    expect(rate!.detail).toContain('3 times');
    expect(riskScore).toBeGreaterThanOrEqual(50);
  });

  it('forgets a run that has aged out of the window', () => {
    const { signals } = score({
      agentPinDisputes: [
        own,
        peer({ visitId: 'v2', outletId: 'o2', lat: ACROSS_TOWN.lat, createdAt: daysBefore(8) }),
        peer({ visitId: 'v3', outletId: 'o3', lat: ACROSS_TOWN.lat, createdAt: daysBefore(30) }),
      ],
    });
    // An agent is not still being scored in March for a fortnight in January.
    expect(signals.map((s) => s.code)).not.toContain('geofence_override_rate');
  });

  it('scores two shops disputed from one spot', () => {
    const { signals, riskScore } = score({
      agentPinDisputes: [
        own,
        peer({ visitId: 'v2', outletId: 'o2', ...NEXT_DOOR, createdAt: daysBefore(1) }),
      ],
    });
    const cluster = signals.find((s) => s.code === 'geofence_override_cluster');
    expect(cluster).toBeDefined();
    expect(cluster!.detail).toContain(`${OVERRIDE_CLUSTER_RADIUS_M}m`);
    // The home attack's signature fires on the SECOND claim, not the tenth.
    expect(riskScore).toBeGreaterThanOrEqual(50);
  });

  it('is silent when the same outlet is disputed twice from one spot', () => {
    const { signals } = score({
      agentPinDisputes: [
        own,
        peer({ visitId: 'v2', outletId: 'o1', ...NEXT_DOOR, createdAt: daysBefore(2) }),
      ],
    });
    // One shop, still wrongly pinned, reported again. That is one fact about
    // one outlet, not a phone claiming to be in two places.
    expect(signals.map((s) => s.code)).not.toContain('geofence_override_cluster');
  });

  it('is silent when two shops were disputed from two different places', () => {
    const { signals } = score({
      agentPinDisputes: [
        own,
        peer({ visitId: 'v2', outletId: 'o2', ...ACROSS_TOWN, createdAt: daysBefore(2) }),
      ],
    });
    expect(signals.map((s) => s.code)).not.toContain('geofence_override_cluster');
  });

  it('replaces the plain override when a manager has rejected the claim', () => {
    const rejected: FraudPinDispute = { ...own, status: 'rejected' };
    const { signals, riskScore } = score({
      pinDispute: rejected,
      agentPinDisputes: [rejected],
    });
    const codes = signals.map((s) => s.code);
    expect(codes).toContain('geofence_override_rejected');
    // One fact — the check-in was outside the fence — read in its strongest
    // form, not charged twice.
    expect(codes).not.toContain('geofence_override');
    // A manager saying the agent was not at the shop reaches a reviewer alone.
    expect(riskScore).toBeGreaterThanOrEqual(50);
  });

  it('leaves an applied claim as an ordinary override', () => {
    const { signals, riskScore } = score({
      pinDispute: { ...own, status: 'applied' },
      agentPinDisputes: [{ ...own, status: 'applied' }],
    });
    // Agreeing with the agent is not an accusation of the agent.
    expect(signals.map((s) => s.code)).toContain('geofence_override');
    expect(riskScore).toBeLessThan(50);
  });

  it('still scores an override whose claim row could not be loaded', () => {
    const { signals } = score({ pinDispute: null, agentPinDisputes: [] });
    // A visit that predates the pin-repair path is still an override; it just
    // has no pattern to be read against.
    expect(signals.map((s) => s.code)).toEqual(['geofence_override']);
  });

  it('says nothing about a check-in that passed the fence', () => {
    const inside: FraudVisitInput = { ...visit, geofencePass: true, checkinDistanceM: 5 };
    const { signals } = score({}, inside);
    expect(signals.map((s) => s.code)).not.toContain('geofence_override');
    expect(signals.map((s) => s.code)).not.toContain('geofence_override_rate');
    expect(signals.map((s) => s.code)).not.toContain('geofence_override_cluster');
  });

  it('never counts another agent\'s claims against this one', () => {
    const { signals } = score({
      agentPinDisputes: [
        own,
        peer({ visitId: 'v2', agentId: 'a2', outletId: 'o2', ...NEXT_DOOR, createdAt: daysBefore(1) }),
        peer({ visitId: 'v3', agentId: 'a2', outletId: 'o3', ...NEXT_DOOR, createdAt: daysBefore(1) }),
      ],
    });
    const codes = signals.map((s) => s.code);
    expect(codes).not.toContain('geofence_override_rate');
    expect(codes).not.toContain('geofence_override_cluster');
  });
});
