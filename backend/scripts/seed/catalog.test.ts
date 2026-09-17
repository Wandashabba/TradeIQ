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
import { normalizeEmail } from '../../src/lib/email';

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

  it('assigns every outlet to a real territory, by CODE not id', () => {
    // `Outlet.territoryId` mirrors `Territory.code`. Asserting against ids —
    // which this test used to do — passes while every territory-scoped query
    // returns nothing, because both sides of the comparison are then wrong in
    // the same way. The codes are what `GET /outlets?mine=true` matches on.
    const territoryCodes = new Set(TERRITORIES.map((t) => t.code));
    for (const outlet of outlets) expect(territoryCodes.has(outlet.territoryId)).toBe(true);
  });

  it('never assigns an outlet a territory id by mistake', () => {
    // The specific regression: an id looks like a plausible territoryId and
    // fails silently. Nothing downstream errors — the lists just come back
    // empty, which reads as "no data" rather than "wrong join".
    const territoryIds = new Set(TERRITORIES.map((t) => t.id));
    for (const outlet of outlets) expect(territoryIds.has(outlet.territoryId)).toBe(false);
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

  // Login normalises what it is given before looking the row up (#351), so a
  // demo email spelled with a capital here would be seeded as one string and
  // searched for as another — and rotate-demo-passwords, which matches on these
  // exact strings, would quietly report the account "not present". Keeping the
  // catalog canonical is what makes those three agree.
  it('spells every demo email in the canonical form login looks up (#351)', () => {
    for (const user of USERS) {
      expect(user.email).toBe(normalizeEmail(user.email));
    }
  });

  it('has three territories and about twenty SKUs', () => {
    expect(TERRITORIES).toHaveLength(3);
    expect(SKUS.length).toBeGreaterThanOrEqual(18);
  });

  it('uses a stable client id so reset can scope to it', () => {
    expect(DEMO_CLIENT_ID).toBe('demo-fmcg-client');
  });
});
