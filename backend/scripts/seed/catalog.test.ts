import { haversineDistanceMeters } from '../../src/lib/geofence';
import {
  AGENTS,
  DEMO_CLIENT_ID,
  DEMO_USERS,
  HOME_OUTLET_ID,
  PRICE_BREACH_CHAIN,
  TERRITORY_GEOGRAPHY,
  assignOutletsToAgents,
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

  it('produces four hundred outlets, home base included', () => {
    expect(outlets).toHaveLength(400);
  });

  it('keeps outlets clear of each other\'s geofences', () => {
    // Overlapping fences would blur the fraud engine's location signals.
    const sample = outlets.slice(0, 120);
    for (let i = 0; i < sample.length; i += 1) {
      for (let j = i + 1; j < sample.length; j += 1) {
        expect(haversineDistanceMeters(sample[i]!, sample[j]!)).toBeGreaterThan(100);
      }
    }
  });

  it('places every outlet near its territory centre', () => {
    for (const outlet of outlets.filter((o) => o.id !== HOME_OUTLET_ID)) {
      const geo = TERRITORY_GEOGRAPHY[outlet.territoryId]!;
      expect(Math.abs(outlet.lat - geo.centre.lat)).toBeLessThanOrEqual(geo.radius + 1e-6);
      expect(Math.abs(outlet.lng - geo.centre.lng)).toBeLessThanOrEqual(geo.radius + 1e-6);
    }
  });

  it('covers every channel the assistant is asked about', () => {
    const channels = new Set(outlets.map((o) => o.channelType));
    for (const channel of ['supermarket', 'spaza', 'wholesaler', 'forecourt']) {
      expect(channels.has(channel)).toBe(true);
    }
  });

  it('names a price-breaching chain across several territories', () => {
    const chain = outlets.filter((o) => o.name.startsWith(`${PRICE_BREACH_CHAIN} `));
    expect(chain.length).toBeGreaterThanOrEqual(15);
    expect(new Set(chain.map((o) => o.territoryId)).size).toBeGreaterThanOrEqual(4);
  });

  it('is a prefix of itself when cut down, so a small world is the same world', () => {
    const small = buildOutlets({ lat: -26.1076, lng: 28.0567, source: 'fallback' }, { fraction: 0.2 });
    const byId = new Map(outlets.map((o) => [o.id, o]));
    for (const outlet of small) expect(byId.get(outlet.id)).toEqual(outlet);
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
  it('has one admin, two managers and fifty agents', () => {
    expect(USERS.filter((u) => u.role === 'admin')).toHaveLength(1);
    expect(USERS.filter((u) => u.role === 'manager')).toHaveLength(2);
    expect(AGENTS).toHaveLength(50);
  });

  // People sign in with these every day. A reseed must not change a single
  // byte of who they are or where they work.
  it('keeps the nine demo logins exactly as they were', () => {
    expect(DEMO_USERS).toEqual([
      { id: 'demo-user-admin', email: 'admin@demo-fmcg.tradeiq.com', role: 'admin', name: 'Thandi Mokoena' },
      { id: 'demo-user-mgr-1', email: 'manager@demo-fmcg.tradeiq.com', role: 'manager', name: 'Pieter van Wyk' },
      { id: 'demo-user-mgr-2', email: 'manager2@demo-fmcg.tradeiq.com', role: 'manager', name: 'Nomsa Dlamini' },
      { id: 'demo-user-agent-1', email: 'agent@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Sipho Ndlovu', territoryId: 'demo-territory-gp' },
      { id: 'demo-user-agent-2', email: 'agent2@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Lerato Mahlangu', territoryId: 'demo-territory-gp' },
      { id: 'demo-user-agent-3', email: 'agent3@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Ruan Botha', territoryId: 'demo-territory-wc' },
      { id: 'demo-user-agent-4', email: 'agent4@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Aisha Patel', territoryId: 'demo-territory-wc' },
      { id: 'demo-user-agent-5', email: 'agent5@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Bongani Zulu', territoryId: 'demo-territory-kzn' },
      { id: 'demo-user-agent-6', email: 'agent6@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Chantal Adams', territoryId: 'demo-territory-kzn' },
    ]);
    expect(USERS.slice(0, 9)).toEqual(DEMO_USERS);
  });

  // The assistant resolves a spoken name with a case-insensitive contains
  // (scorecards.service resolveAgent). A name hidden inside another person's
  // would turn "how is Naledi doing" into "which one?".
  it('gives no one a name part that is inside someone else\'s name', () => {
    const names = USERS.map((u) => u.name.toLowerCase());
    for (const name of names) {
      for (const part of name.split(' ').filter((p) => p.length > 2)) {
        expect(names.filter((other) => other.includes(part))).toEqual([name]);
      }
    }
  });

  it('assigns every agent a territory and some outlets', () => {
    const owners = assignOutletsToAgents(buildOutlets({ lat: -26.1076, lng: 28.0567, source: 'fallback' }));
    const counts = new Map<string, number>();
    for (const owner of owners.values()) counts.set(owner, (counts.get(owner) ?? 0) + 1);
    for (const agent of AGENTS) {
      expect(TERRITORIES.some((t) => t.id === agent.territoryId)).toBe(true);
      expect(counts.get(agent.id) ?? 0).toBeGreaterThanOrEqual(5);
    }
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

  it('has thirteen territories across at least seven provinces, the original three first', () => {
    expect(TERRITORIES).toHaveLength(13);
    expect(TERRITORIES.slice(0, 3)).toEqual([
      { id: 'demo-territory-gp', name: 'Gauteng', code: 'GP', region: 'Inland' },
      { id: 'demo-territory-wc', name: 'Western Cape', code: 'WC', region: 'Coastal' },
      { id: 'demo-territory-kzn', name: 'KwaZulu-Natal', code: 'KZN', region: 'Coastal' },
    ]);
    const provinces = new Set(TERRITORIES.map((t) => t.code.split('-')[0]));
    expect(provinces.size).toBeGreaterThanOrEqual(7);
    expect(SKUS.length).toBeGreaterThanOrEqual(18);
  });

  it('uses a stable client id so reset can scope to it', () => {
    expect(DEMO_CLIENT_ID).toBe('demo-fmcg-client');
  });
});
