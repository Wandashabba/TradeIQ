import { computeFraudSignals, FraudPhotoInput, FraudRelatedInput, FraudVisitInput } from './fraud.service';

/**
 * #317 — photo_gps_divergence skips task-closure photos. Closing a task attaches
 * its evidence photo to the ORIGINATING visit, often days later and from
 * wherever the task was closed, so its position says nothing about where the
 * audit happened. The rule is the one capture_timeline_gap (#246) and
 * stock_outside_outlet (#248) already use.
 */
describe('photo_gps_divergence skips task-closure photos (#317)', () => {
  const checkinTs = new Date('2026-07-13T09:00:00.000Z');
  const minutesAfter = (m: number) => new Date(checkinTs.getTime() + m * 60_000);

  const ON_SITE = { lat: -26.2, lng: 28.0 };
  // ~556m and ~1112m due south: both past the 150m divergence line, and far
  // enough apart that the detail says which photo was measured.
  const FAR = { lat: -26.205, lng: 28.0 };
  const FURTHER = { lat: -26.21, lng: 28.0 };

  // A 20-minute submitted visit with counts: no other signal fires unless a
  // test asks for one.
  const visit: FraudVisitInput = {
    id: 'v1',
    status: 'submitted',
    agentId: 'a1',
    outletId: 'o1',
    checkinTs,
    checkinLat: ON_SITE.lat,
    checkinLng: ON_SITE.lng,
    checkinDistanceM: 5,
    submittedAtClient: minutesAfter(20),
  };

  const auditPhoto = (gpsTag: FraudPhotoInput['gpsTag']): FraudPhotoInput => ({
    gpsTag,
    timestamp: minutesAfter(10),
    section: 'stock',
  });
  // Closed three days later, somewhere else.
  const closurePhoto = (gpsTag: FraudPhotoInput['gpsTag']): FraudPhotoInput => ({
    gpsTag,
    timestamp: minutesAfter(3 * 24 * 60),
    section: 'task_closure',
  });

  const related = (photos: FraudPhotoInput[]): FraudRelatedInput => ({
    photos,
    sectionCreatedAts: [minutesAfter(12)],
    failedAttempts: [],
  });

  it('is silent when the only far-away photo is a task-closure photo', () => {
    const result = computeFraudSignals(visit, related([auditPhoto(ON_SITE), closurePhoto(FURTHER)]));

    expect(result.signals).toEqual([]);
    expect(result.riskScore).toBe(0);
  });

  it('still fires for a far-away audit photo', () => {
    const result = computeFraudSignals(visit, related([auditPhoto(FAR)]));

    expect(result.signals).toEqual([
      { code: 'photo_gps_divergence', detail: "A photo's GPS tag is 556m from the check-in location", weight: 25 },
    ]);
    expect(result.riskScore).toBe(25);
  });

  it('still fires with both, measured from the audit photo rather than the further closure photo', () => {
    const result = computeFraudSignals(visit, related([closurePhoto(FURTHER), auditPhoto(FAR)]));

    expect(result.signals).toEqual([
      { code: 'photo_gps_divergence', detail: "A photo's GPS tag is 556m from the check-in location", weight: 25 },
    ]);
    expect(result.riskScore).toBe(25);
  });

  it('reads the same section value as the timeline signal: any other section is an audit photo', () => {
    const relabelled = { ...closurePhoto(FURTHER), section: 'visibility' };
    const codes = computeFraudSignals(visit, related([relabelled])).signals.map((s) => s.code);

    // Now an audit photo, it diverges AND sits outside the device window.
    expect(codes).toEqual(['photo_gps_divergence', 'capture_timeline_gap']);
  });
});
