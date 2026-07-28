import {
  DEMO_CLIENT_ID,
  HOME_OUTLET_ID,
  PROBLEM_OUTLET_CODES,
  homeCoordinates,
  buildOutlets,
  TERRITORIES,
  USERS,
  SKUS,
} from './catalog';

describe('homeCoordinates', () => {
  it('uses the env pair when both are set', () => {
    expect(homeCoordinates({ DEMO_HOME_LAT: '-33.918861', DEMO_HOME_LNG: '18.423300' }))
      .toEqual({ lat: -33.918861, lng: 18.4233, source: 'env' });
  });

  it('falls back when unset, so a fresh clone still seeds a full outlet list', () => {
    const result = homeCoordinates({});
    expect(result.source).toBe('fallback');
    expect(Number.isFinite(result.lat)).toBe(true);
    expect(Number.isFinite(result.lng)).toBe(true);
  });

  it('falls back when only one of the pair is set', () => {
    expect(homeCoordinates({ DEMO_HOME_LAT: '-33.9' }).source).toBe('fallback');
    expect(homeCoordinates({ DEMO_HOME_LNG: '18.4' }).source).toBe('fallback');
  });

  // A malformed coordinate must not quietly seed a store in the Gulf of Guinea.
  it('throws on a non-numeric value rather than silently falling back', () => {
    expect(() => homeCoordinates({ DEMO_HOME_LAT: 'here', DEMO_HOME_LNG: '18.4' }))
      .toThrow('DEMO_HOME_LAT');
  });

  it('throws on an out-of-range value', () => {
    expect(() => homeCoordinates({ DEMO_HOME_LAT: '91', DEMO_HOME_LNG: '18.4' }))
      .toThrow('DEMO_HOME_LAT');
    expect(() => homeCoordinates({ DEMO_HOME_LAT: '-33.9', DEMO_HOME_LNG: '181' }))
      .toThrow('DEMO_HOME_LNG');
  });
});

describe('buildOutlets', () => {
  const outlets = buildOutlets({ lat: -26.1076, lng: 28.0567, source: 'fallback' });

  it('produces about thirty outlets', () => {
    expect(outlets.length).toBeGreaterThanOrEqual(28);
    expect(outlets.length).toBeLessThanOrEqual(32);
  });

  it('gives every outlet a unique code, which the schema requires per client', () => {
    const codes = outlets.map((o) => o.code);
    expect(new Set(codes).size).toBe(codes.length);
  });

  it('assigns every outlet to a real territory', () => {
    const territoryIds = new Set(TERRITORIES.map((t) => t.id));
    for (const outlet of outlets) expect(territoryIds.has(outlet.territoryId)).toBe(true);
  });

  it('includes the home-base outlet at the supplied coordinates', () => {
    const home = outlets.find((o) => o.id === HOME_OUTLET_ID);
    expect(home).toBeDefined();
    expect(home!.lat).toBe(-26.1076);
    expect(home!.lng).toBe(28.0567);
  });

  it('marks exactly the four problem outlets, and they exist', () => {
    expect(PROBLEM_OUTLET_CODES).toHaveLength(4);
    const codes = new Set(outlets.map((o) => o.code));
    for (const code of PROBLEM_OUTLET_CODES) expect(codes.has(code)).toBe(true);
  });

  it('never makes the home outlet a problem outlet — the live check-in demo runs there', () => {
    const home = outlets.find((o) => o.id === HOME_OUTLET_ID)!;
    expect(PROBLEM_OUTLET_CODES).not.toContain(home.code);
  });
});

describe('reference data', () => {
  it('has one admin, two managers and six agents', () => {
    expect(USERS.filter((u) => u.role === 'admin')).toHaveLength(1);
    expect(USERS.filter((u) => u.role === 'manager')).toHaveLength(2);
    expect(USERS.filter((u) => u.role === 'field_agent')).toHaveLength(6);
  });

  it('gives every user a unique email, which the schema requires globally', () => {
    const emails = USERS.map((u) => u.email);
    expect(new Set(emails).size).toBe(emails.length);
  });

  it('has three territories and about twenty SKUs', () => {
    expect(TERRITORIES).toHaveLength(3);
    expect(SKUS.length).toBeGreaterThanOrEqual(18);
  });

  it('uses a stable client id so reset can scope to it', () => {
    expect(DEMO_CLIENT_ID).toBe('demo-fmcg-client');
  });
});
