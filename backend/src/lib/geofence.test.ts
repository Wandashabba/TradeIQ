import { isWithinGeofence } from './geofence';

describe('isWithinGeofence', () => {
  it('returns true when within 50m of the outlet', () => {
    // ~11m north of the outlet
    const outlet = { lat: -26.2041, lng: 28.0473 };
    const checkin = { lat: -26.20400, lng: 28.0473 };
    expect(isWithinGeofence(outlet, checkin, 50)).toBe(true);
  });

  it('returns false when more than 50m from the outlet', () => {
    const outlet = { lat: -26.2041, lng: 28.0473 };
    const checkin = { lat: -26.2100, lng: 28.0473 }; // ~650m away
    expect(isWithinGeofence(outlet, checkin, 50)).toBe(false);
  });
});
