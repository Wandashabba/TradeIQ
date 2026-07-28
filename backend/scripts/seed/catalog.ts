import { makeRng, intBetween, pick } from './rng';

/**
 * Hand-authored reference data for the demo. Names are invented but plausible
 * South African retail — no real company trademarks.
 */

/** Stable so `reset.ts` can scope every deletion to this one tenant. */
export const DEMO_CLIENT_ID = 'demo-fmcg-client';
export const HOME_OUTLET_ID = 'demo-outlet-home';
export const DEMO_PASSWORD = 'demo-password-123';

/** Central Johannesburg, used when DEMO_HOME_LAT/LNG are not configured. */
const FALLBACK_HOME = { lat: -26.107600, lng: 28.056700 };

export interface CoordinateSource {
  lat: number;
  lng: number;
  source: 'env' | 'fallback';
}

export interface TerritorySeed {
  id: string;
  name: string;
  code: string;
  region: string;
}

export interface UserSeed {
  id: string;
  email: string;
  role: 'admin' | 'manager' | 'field_agent';
  name: string;
  territoryId?: string;
}

export interface SkuSeed {
  id: string;
  name: string;
  category: string;
  minFacingsStandard: number;
  rrp: number;
}

export interface OutletSeed {
  id: string;
  name: string;
  code: string;
  channelType: string;
  lat: number;
  lng: number;
  territoryId: string;
  acvWeight: number;
}

export const TERRITORIES: TerritorySeed[] = [
  { id: 'demo-territory-gp', name: 'Gauteng', code: 'GP', region: 'Inland' },
  { id: 'demo-territory-wc', name: 'Western Cape', code: 'WC', region: 'Coastal' },
  { id: 'demo-territory-kzn', name: 'KwaZulu-Natal', code: 'KZN', region: 'Coastal' },
];

export const USERS: UserSeed[] = [
  { id: 'demo-user-admin', email: 'admin@demo-fmcg.tradeiq.com', role: 'admin', name: 'Thandi Mokoena' },
  { id: 'demo-user-mgr-1', email: 'manager@demo-fmcg.tradeiq.com', role: 'manager', name: 'Pieter van Wyk' },
  { id: 'demo-user-mgr-2', email: 'manager2@demo-fmcg.tradeiq.com', role: 'manager', name: 'Nomsa Dlamini' },
  { id: 'demo-user-agent-1', email: 'agent@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Sipho Ndlovu', territoryId: 'demo-territory-gp' },
  { id: 'demo-user-agent-2', email: 'agent2@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Lerato Mahlangu', territoryId: 'demo-territory-gp' },
  { id: 'demo-user-agent-3', email: 'agent3@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Ruan Botha', territoryId: 'demo-territory-wc' },
  { id: 'demo-user-agent-4', email: 'agent4@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Aisha Patel', territoryId: 'demo-territory-wc' },
  { id: 'demo-user-agent-5', email: 'agent5@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Bongani Zulu', territoryId: 'demo-territory-kzn' },
  { id: 'demo-user-agent-6', email: 'agent6@demo-fmcg.tradeiq.com', role: 'field_agent', name: 'Chantal Adams', territoryId: 'demo-territory-kzn' },
];

export const SKUS: SkuSeed[] = [
  { id: 'demo-sku-1', name: 'Kalahari Cola 1L', category: 'Carbonates', minFacingsStandard: 6, rrp: 24.99 },
  { id: 'demo-sku-2', name: 'Kalahari Cola 2L', category: 'Carbonates', minFacingsStandard: 4, rrp: 34.99 },
  { id: 'demo-sku-3', name: 'Kalahari Lemon 500ml', category: 'Carbonates', minFacingsStandard: 8, rrp: 18.50 },
  { id: 'demo-sku-4', name: 'Kalahari Zero 1L', category: 'Carbonates', minFacingsStandard: 6, rrp: 26.99 },
  { id: 'demo-sku-5', name: 'Veld Still Water 500ml', category: 'Water', minFacingsStandard: 10, rrp: 9.99 },
  { id: 'demo-sku-6', name: 'Veld Sparkling 750ml', category: 'Water', minFacingsStandard: 6, rrp: 14.99 },
  { id: 'demo-sku-7', name: 'Sunrise Orange Juice 1L', category: 'Juice', minFacingsStandard: 5, rrp: 29.99 },
  { id: 'demo-sku-8', name: 'Sunrise Apple Juice 1L', category: 'Juice', minFacingsStandard: 5, rrp: 29.99 },
  { id: 'demo-sku-9', name: 'Sunrise Tropical 330ml', category: 'Juice', minFacingsStandard: 8, rrp: 12.99 },
  { id: 'demo-sku-10', name: 'Highveld Full Cream Milk 1L', category: 'Dairy', minFacingsStandard: 8, rrp: 21.99 },
  { id: 'demo-sku-11', name: 'Highveld Low Fat Milk 1L', category: 'Dairy', minFacingsStandard: 6, rrp: 21.99 },
  { id: 'demo-sku-12', name: 'Highveld Yoghurt 500g', category: 'Dairy', minFacingsStandard: 6, rrp: 27.50 },
  { id: 'demo-sku-13', name: 'Maize Meal Super 2.5kg', category: 'Staples', minFacingsStandard: 4, rrp: 42.99 },
  { id: 'demo-sku-14', name: 'Maize Meal Super 5kg', category: 'Staples', minFacingsStandard: 3, rrp: 79.99 },
  { id: 'demo-sku-15', name: 'Rooibos Tea 80s', category: 'Hot Beverages', minFacingsStandard: 4, rrp: 44.99 },
  { id: 'demo-sku-16', name: 'Instant Coffee 200g', category: 'Hot Beverages', minFacingsStandard: 4, rrp: 89.99 },
  { id: 'demo-sku-17', name: 'Salted Chips 125g', category: 'Snacks', minFacingsStandard: 10, rrp: 16.99 },
  { id: 'demo-sku-18', name: 'Biltong Sticks 50g', category: 'Snacks', minFacingsStandard: 8, rrp: 34.99 },
  { id: 'demo-sku-19', name: 'Rusks Buttermilk 500g', category: 'Snacks', minFacingsStandard: 4, rrp: 49.99 },
  { id: 'demo-sku-20', name: 'Chocolate Bar 90g', category: 'Confectionery', minFacingsStandard: 12, rrp: 18.99 },
];

/**
 * The four outlets that stay red for the whole 12 weeks. They carry the open
 * alerts, stockouts and overdue tasks — the "live problem tail" that gives a
 * demo something real to click into while the trend line still climbs.
 *
 * The home-base outlet is deliberately not among them: the live check-in demo
 * runs there and should not open onto a wall of failures.
 */
export const PROBLEM_OUTLET_CODES = ['GP-004', 'GP-009', 'WC-005', 'KZN-003'] as const;

const CHANNELS = ['hypermarket', 'supermarket', 'convenience', 'forecourt', 'wholesale'];

const OUTLET_PREFIXES = [
  'Sandton', 'Rosebank', 'Midrand', 'Fourways', 'Randburg', 'Soweto', 'Benoni',
  'Centurion', 'Pretoria East', 'Boksburg', 'Sea Point', 'Claremont',
  'Bellville', 'Stellenbosch', 'Paarl', 'Table View', 'Umhlanga', 'Ballito',
  'Pinetown', 'Westville', 'Amanzimtoti', 'Hillcrest',
];

const OUTLET_SUFFIXES = ['Hypermarket', 'Supermarket', 'Market', 'Express', 'Trading Store'];

/** Rough town centres per territory, so outlets scatter plausibly on the map. */
const TERRITORY_CENTRES: Record<string, { lat: number; lng: number }> = {
  'demo-territory-gp': { lat: -26.1076, lng: 28.0567 },
  'demo-territory-wc': { lat: -33.9249, lng: 18.4241 },
  'demo-territory-kzn': { lat: -29.8587, lng: 31.0218 },
};

/** Outlets generated per territory (plus the home-base outlet). */
const OUTLETS_PER_TERRITORY = 10;

/**
 * Reads DEMO_HOME_LAT/DEMO_HOME_LNG. Both must be present to take effect;
 * a malformed or out-of-range value is an error rather than a silent fallback,
 * because quietly seeding a store in the wrong hemisphere is worse than a crash.
 */
export function homeCoordinates(env: NodeJS.ProcessEnv = process.env): CoordinateSource {
  const rawLat = env.DEMO_HOME_LAT;
  const rawLng = env.DEMO_HOME_LNG;

  if (rawLat === undefined || rawLng === undefined) {
    return { ...FALLBACK_HOME, source: 'fallback' };
  }

  const lat = Number(rawLat);
  if (!Number.isFinite(lat) || lat < -90 || lat > 90) {
    throw new Error(`DEMO_HOME_LAT must be a number between -90 and 90, got "${rawLat}"`);
  }
  const lng = Number(rawLng);
  if (!Number.isFinite(lng) || lng < -180 || lng > 180) {
    throw new Error(`DEMO_HOME_LNG must be a number between -180 and 180, got "${rawLng}"`);
  }

  return { lat, lng, source: 'env' };
}

export function buildOutlets(home: CoordinateSource): OutletSeed[] {
  const rng = makeRng(20260728);
  const outlets: OutletSeed[] = [];

  outlets.push({
    id: HOME_OUTLET_ID,
    name: 'Kalahari Flagship Store',
    code: 'GP-000',
    channelType: 'supermarket',
    lat: home.lat,
    lng: home.lng,
    territoryId: 'demo-territory-gp',
    acvWeight: 1.4,
  });

  for (const territory of TERRITORIES) {
    const centre = TERRITORY_CENTRES[territory.id]!;
    for (let i = 1; i <= OUTLETS_PER_TERRITORY; i += 1) {
      const code = `${territory.code}-${String(i).padStart(3, '0')}`;
      outlets.push({
        id: `demo-outlet-${code.toLowerCase()}`,
        name: `${pick(rng, OUTLET_PREFIXES)} ${pick(rng, OUTLET_SUFFIXES)}`,
        code,
        channelType: pick(rng, CHANNELS),
        // ~+/-0.15 degrees keeps outlets inside a plausible metro spread.
        lat: centre.lat + (rng() - 0.5) * 0.3,
        lng: centre.lng + (rng() - 0.5) * 0.3,
        territoryId: territory.id,
        acvWeight: intBetween(rng, 5, 20) / 10,
      });
    }
  }

  return outlets;
}
