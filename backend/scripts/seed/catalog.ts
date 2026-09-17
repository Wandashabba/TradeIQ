import { haversineDistanceMeters } from '../../src/lib/geofence';
import { makeRng, pick } from './rng';

/**
 * Hand-authored reference data for the demo. Names are invented but plausible
 * South African retail — no real company trademarks.
 *
 * Scale (#Ask TradeIQ mock data): 13 territories across seven provinces, 50
 * field agents and 400 outlets. The nine demo logins, their territories and
 * the twenty SKUs are unchanged — people sign in with them every day.
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

/** Exactly the columns an Outlet row takes — spread straight into createMany. */
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

/**
 * The first three are the original demo territories and must stay exactly as
 * they are: the demo agents are assigned to them by id. `region` keeps the
 * original Inland/Coastal convention; the province is in the name.
 */
export const TERRITORIES: TerritorySeed[] = [
  { id: 'demo-territory-gp', name: 'Gauteng', code: 'GP', region: 'Inland' },
  { id: 'demo-territory-wc', name: 'Western Cape', code: 'WC', region: 'Coastal' },
  { id: 'demo-territory-kzn', name: 'KwaZulu-Natal', code: 'KZN', region: 'Coastal' },
  { id: 'demo-territory-gp-tsh', name: 'Gauteng North (Tshwane)', code: 'GP-TSH', region: 'Inland' },
  { id: 'demo-territory-gp-eku', name: 'Gauteng East (Ekurhuleni)', code: 'GP-EKU', region: 'Inland' },
  { id: 'demo-territory-wc-win', name: 'Western Cape Winelands', code: 'WC-WIN', region: 'Inland' },
  { id: 'demo-territory-kzn-pmb', name: 'KwaZulu-Natal Midlands', code: 'KZN-PMB', region: 'Inland' },
  { id: 'demo-territory-ec-nmb', name: 'Eastern Cape – Nelson Mandela Bay', code: 'EC-NMB', region: 'Coastal' },
  { id: 'demo-territory-ec-bcm', name: 'Eastern Cape – Buffalo City', code: 'EC-BCM', region: 'Coastal' },
  { id: 'demo-territory-fs', name: 'Free State', code: 'FS', region: 'Inland' },
  { id: 'demo-territory-lp', name: 'Limpopo', code: 'LP', region: 'Inland' },
  { id: 'demo-territory-mp', name: 'Mpumalanga', code: 'MP', region: 'Inland' },
  { id: 'demo-territory-nw', name: 'North West', code: 'NW', region: 'Inland' },
];

/**
 * Territory id → code.
 *
 * Needed because two fields named `territoryId` in this schema hold different
 * kinds of value: `UserTerritory.territoryId` and `BeatPlan.territoryId` are
 * real foreign keys to `Territory.id`, while `Outlet.territoryId` is free text
 * mirroring `Territory.code`. Anything comparing an agent's territory to an
 * outlet's has to cross that gap deliberately, rather than assume two fields of
 * the same name are comparable — which is the assumption that put territory ids
 * on the outlets in the first place.
 */
export const TERRITORY_CODE_BY_ID: Readonly<Record<string, string>> = Object.freeze(
  Object.fromEntries(TERRITORIES.map((t) => [t.id, t.code])),
);

export const TERRITORY_ID_BY_CODE: Readonly<Record<string, string>> = Object.freeze(
  Object.fromEntries(TERRITORIES.map((t) => [t.code, t.id])),
);

/** The nine accounts people sign in with. Byte-identical across reseeds. */
export const DEMO_USERS: UserSeed[] = [
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

/**
 * The rest of the field team, by territory code. Every first name and surname
 * is unique and none is a substring of another person's: the assistant resolves
 * "how is Naledi doing" with a case-insensitive `contains`, and a name hidden
 * inside another (Anele / Zanele) would make that answer "which one?".
 */
const EXTRA_AGENT_NAMES: ReadonlyArray<readonly [string, readonly string[]]> = [
  ['GP', ['Tshepo Mahlaba', 'Megan Fourie']],
  ['GP-TSH', ['Naledi Sithole', 'Karabo Mokwena', 'Hendrik Venter', 'Precious Mabuza', 'Dineo Ramokgopa']],
  ['GP-EKU', ['Lwazi Mthembu', 'Zanele Khoza', 'Andile Shabalala', 'Riana Swanepoel', 'Mpho Letsoalo']],
  ['WC', ['Yusuf Isaacs', 'Liezl Jacobs']],
  ['WC-WIN', ['Francois Malan', 'Carmen Februarie', 'Luthando Qwabe']],
  ['KZN', ['Thabo Ngcobo', 'Kavitha Naidoo']],
  ['KZN-PMB', ['Nokuthula Mkhize', 'Priya Govender', 'Sanele Dube']],
  ['EC-NMB', ['Ayanda Mqhayi', 'Jacques Olivier', 'Nomvula Gqirana', 'Craig Pillay']],
  ['EC-BCM', ['Siyabonga Ntshona', 'Unathi Mafu', 'Willem Coetzee']],
  ['FS', ['Refilwe Motaung', 'Gert Steyn', 'Palesa Seleka', 'Tebogo Molapo']],
  ['LP', ['Khensani Baloyi', 'Rudzani Netshiongolwe', 'Tshilidzi Mudau', 'Mapula Ledwaba']],
  ['MP', ['Kagiso Molefe', 'Busisiwe Nkosi', 'Johan Pretorius', 'Sifiso Mahlalela']],
  ['NW', ['Boitumelo Seabi', 'Wikus Kruger', 'Onalenna Moagi']],
];

function emailFor(name: string): string {
  return `${name.toLowerCase().replace(/[^a-z ]/g, '').trim().replace(/\s+/g, '.')}@demo-fmcg.tradeiq.com`;
}

function buildExtraAgents(): UserSeed[] {
  const agents: UserSeed[] = [];
  let n = 7;
  for (const [code, names] of EXTRA_AGENT_NAMES) {
    for (const name of names) {
      agents.push({
        id: `demo-user-agent-${n}`,
        email: emailFor(name),
        role: 'field_agent',
        name,
        territoryId: TERRITORY_ID_BY_CODE[code],
      });
      n += 1;
    }
  }
  return agents;
}

export const USERS: UserSeed[] = [...DEMO_USERS, ...buildExtraAgents()];

export const AGENTS: UserSeed[] = USERS.filter((u) => u.role === 'field_agent');

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
 * Typical units per order line for an average-sized outlet. Cola 2L is the
 * best seller by a clear margin — the chronic out-of-stock story needs a SKU
 * whose absence visibly costs something.
 */
export const SKU_BASE_UNITS: Readonly<Record<string, number>> = {
  'demo-sku-1': 30, 'demo-sku-2': 38, 'demo-sku-3': 24, 'demo-sku-4': 18, 'demo-sku-5': 28,
  'demo-sku-6': 12, 'demo-sku-7': 14, 'demo-sku-8': 10, 'demo-sku-9': 16, 'demo-sku-10': 22,
  'demo-sku-11': 14, 'demo-sku-12': 10, 'demo-sku-13': 20, 'demo-sku-14': 14, 'demo-sku-15': 8,
  'demo-sku-16': 6, 'demo-sku-17': 26, 'demo-sku-18': 9, 'demo-sku-19': 7, 'demo-sku-20': 20,
};

/** Chance an order includes the SKU at all. */
export const SKU_LINE_PROBABILITY: Readonly<Record<string, number>> = {
  'demo-sku-1': 0.8, 'demo-sku-2': 0.85, 'demo-sku-3': 0.55, 'demo-sku-4': 0.45, 'demo-sku-5': 0.6,
  'demo-sku-6': 0.3, 'demo-sku-7': 0.35, 'demo-sku-8': 0.3, 'demo-sku-9': 0.35, 'demo-sku-10': 0.45,
  'demo-sku-11': 0.3, 'demo-sku-12': 0.25, 'demo-sku-13': 0.4, 'demo-sku-14': 0.3, 'demo-sku-15': 0.25,
  'demo-sku-16': 0.2, 'demo-sku-17': 0.5, 'demo-sku-18': 0.25, 'demo-sku-19': 0.2, 'demo-sku-20': 0.45,
};

/** Trade (sell-in) price as a share of RRP. */
export const TRADE_PRICE_FACTOR = 0.76;

/**
 * The four outlets that stay red for the whole history. They carry a steady
 * share of the open alerts, stockouts and overdue tasks — the "live problem
 * tail" that gives a demo something real to click into.
 *
 * The home-base outlet is deliberately not among them: the live check-in demo
 * runs there and should not open onto a wall of failures.
 */
export const PROBLEM_OUTLET_CODES = ['GP-004', 'GP-009', 'WC-005', 'KZN-003'] as const;

export type Channel = 'hypermarket' | 'supermarket' | 'wholesaler' | 'forecourt' | 'convenience' | 'spaza';

/** Relative outlet size: drives order volume, stock on hand and ACV weight. */
export const CHANNEL_SIZE: Readonly<Record<Channel, number>> = {
  hypermarket: 3.0,
  wholesaler: 3.6,
  supermarket: 1.6,
  convenience: 0.75,
  forecourt: 0.6,
  spaza: 0.45,
};

/** Share of each channel in an average territory's outlet list, in draw order. */
const CHANNEL_MIX: ReadonlyArray<readonly [Channel, number]> = [
  ['spaza', 0.3],
  ['supermarket', 0.3],
  ['forecourt', 0.14],
  ['convenience', 0.08],
  ['wholesaler', 0.1],
  ['hypermarket', 0.08],
];

/** The retail chain that prices above RRP (see scenario.ts). Invented. */
export const PRICE_BREACH_CHAIN = 'QuickSave';

/** How many of each territory's supermarkets carry the QuickSave banner. */
const QUICKSAVE_PER_TERRITORY: Readonly<Record<string, number>> = {
  GP: 4, 'GP-TSH': 4, 'GP-EKU': 4, FS: 2, NW: 2, MP: 2,
};

const BANNERS: Readonly<Record<Exclude<Channel, 'spaza'>, readonly string[]>> = {
  supermarket: ['Ubuntu Foods', 'FreshCo', 'Village Grocer', 'SaveMor', 'Kasi Market'],
  hypermarket: ['MegaSave Hyper', 'Big Basket Hyper'],
  wholesaler: ['Mzansi Cash & Carry', 'BulkBuy Wholesale', 'Afro Traders Wholesale'],
  forecourt: ['FuelStop Express', 'Route 66 Quickshop', 'Highway Stop'],
  convenience: ['Corner Express', 'NightOwl Convenience', '24Seven'],
};

const SPAZA_OWNERS = [
  "Mama Thandeka's", "Bra Sello's", "Gogo Mavis's", "Uncle Musa's", "Sis Lindi's",
  "Mr Osman's", "Tata Vuyo's", "Ma Zodwa's", "Bab' Themba's", "Auntie Rose's",
];

interface TerritoryGeography {
  centre: { lat: number; lng: number };
  /** Scatter radius around the centre, in degrees. */
  radius: number;
  outlets: number;
  suburbs: readonly string[];
}

/** Outlet counts sum to 400 including the home-base outlet in GP. */
export const TERRITORY_GEOGRAPHY: Readonly<Record<string, TerritoryGeography>> = {
  GP: {
    centre: { lat: -26.1076, lng: 28.0567 }, radius: 0.14, outlets: 39,
    suburbs: ['Sandton', 'Rosebank', 'Randburg', 'Fourways', 'Soweto', 'Alexandra', 'Melville', 'Roodepoort', 'Midrand', 'Bryanston', 'Diepkloof', 'Northcliff', 'Braamfontein', 'Parkhurst'],
  },
  'GP-TSH': {
    centre: { lat: -25.7479, lng: 28.2293 }, radius: 0.14, outlets: 35,
    suburbs: ['Hatfield', 'Centurion', 'Mamelodi', 'Soshanguve', 'Menlyn', 'Arcadia', 'Pretoria North', 'Atteridgeville', 'Montana', 'Brooklyn', 'Silverton', 'Wonderboom'],
  },
  'GP-EKU': {
    centre: { lat: -26.1900, lng: 28.3100 }, radius: 0.13, outlets: 35,
    suburbs: ['Benoni', 'Boksburg', 'Germiston', 'Kempton Park', 'Tembisa', 'Springs', 'Brakpan', 'Alberton', 'Daveyton', 'Edenvale', 'Katlehong', 'Vosloorus'],
  },
  WC: {
    centre: { lat: -33.9500, lng: 18.5600 }, radius: 0.11, outlets: 40,
    suburbs: ['Sea Point', 'Claremont', 'Bellville', 'Table View', 'Khayelitsha', 'Mitchells Plain', 'Durbanville', 'Observatory', 'Wynberg', 'Gugulethu', 'Parow', 'Milnerton', 'Athlone'],
  },
  'WC-WIN': {
    centre: { lat: -33.8400, lng: 18.9000 }, radius: 0.12, outlets: 25,
    suburbs: ['Stellenbosch', 'Paarl', 'Franschhoek', 'Wellington', 'Kayamandi', 'Mbekweni', 'Somerset West', 'Klapmuts'],
  },
  KZN: {
    centre: { lat: -29.8400, lng: 30.9300 }, radius: 0.1, outlets: 40,
    suburbs: ['Umhlanga', 'Westville', 'Pinetown', 'Umlazi', 'Chatsworth', 'Phoenix', 'Berea', 'Morningside', 'KwaMashu', 'Amanzimtoti', 'Glenwood', 'Durban North'],
  },
  'KZN-PMB': {
    centre: { lat: -29.6006, lng: 30.3794 }, radius: 0.1, outlets: 25,
    suburbs: ['Pietermaritzburg CBD', 'Scottsville', 'Hilton', 'Howick', 'Edendale', 'Imbali', 'Northdale', 'Mooi River'],
  },
  'EC-NMB': {
    centre: { lat: -33.8800, lng: 25.5200 }, radius: 0.09, outlets: 30,
    suburbs: ['Summerstrand', 'Walmer', 'Newton Park', 'Kwazakhele', 'Motherwell', 'Uitenhage', 'Despatch', 'Humewood', 'New Brighton', 'Gelvandale'],
  },
  'EC-BCM': {
    centre: { lat: -32.9500, lng: 27.8500 }, radius: 0.07, outlets: 20,
    suburbs: ['East London CBD', 'Vincent', 'Beacon Bay', 'Mdantsane', 'Nahoon', 'Gonubie', 'King William\'s Town'],
  },
  FS: {
    centre: { lat: -29.1052, lng: 26.1996 }, radius: 0.1, outlets: 30,
    suburbs: ['Bloemfontein CBD', 'Westdene', 'Mangaung', 'Botshabelo', 'Langenhovenpark', 'Heidedal', 'Brandwag', 'Thaba Nchu'],
  },
  LP: {
    centre: { lat: -23.9045, lng: 29.4689 }, radius: 0.1, outlets: 30,
    suburbs: ['Polokwane CBD', 'Seshego', 'Bendor', 'Mankweng', 'Flora Park', 'Westenburg', 'Ladanna', 'Moletjie'],
  },
  MP: {
    centre: { lat: -25.4658, lng: 30.9853 }, radius: 0.1, outlets: 25,
    suburbs: ['Mbombela CBD', 'White River', 'KaNyamazane', 'Riverside Park', 'Hazyview', 'Sonheuwel', 'Matsulu'],
  },
  NW: {
    centre: { lat: -25.6676, lng: 27.2421 }, radius: 0.1, outlets: 25,
    suburbs: ['Rustenburg CBD', 'Tlhabane', 'Phokeng', 'Boitekong', 'Safari Gardens', 'Protea Park', 'Geelhout Park'],
  },
};

/** Outlets closer than this would share a geofence and blur the fraud signals. */
const MIN_OUTLET_SEPARATION_M = 150;

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

/** Channel counts for `n` outlets, largest-remainder so they sum exactly to n. */
function channelPlan(n: number): Channel[] {
  const raw = CHANNEL_MIX.map(([channel, share]) => ({ channel, exact: share * n }));
  const counts = raw.map((r) => Math.floor(r.exact));
  let remaining = n - counts.reduce((a, b) => a + b, 0);
  const order = raw
    .map((r, i) => ({ i, frac: r.exact - Math.floor(r.exact) }))
    .sort((a, b) => b.frac - a.frac || a.i - b.i);
  for (const { i } of order) {
    if (remaining === 0) break;
    counts[i] += 1;
    remaining -= 1;
  }
  // Interleave rather than block, so outlet numbers do not group by channel.
  const plan: Channel[] = [];
  const left = [...counts];
  while (plan.length < n) {
    for (let i = 0; i < CHANNEL_MIX.length; i += 1) {
      if (left[i] > 0) {
        plan.push(CHANNEL_MIX[i][0]);
        left[i] -= 1;
      }
    }
  }
  return plan;
}

export interface BuildOutletsOptions {
  /**
   * Keep only this share of each territory's outlets (at least one per agent
   * there). 1 is the full dataset; the end-to-end test seeds a fraction.
   */
  fraction?: number;
}

/** Channel of an outlet, recovered from the fields every outlet row carries. */
export function channelOf(outlet: Pick<OutletSeed, 'channelType'>): Channel {
  return outlet.channelType as Channel;
}

export function buildOutlets(home: CoordinateSource, options: BuildOutletsOptions = {}): OutletSeed[] {
  const rng = makeRng(20260728);
  const fraction = options.fraction ?? 1;
  const outlets: OutletSeed[] = [];
  // Every position drawn, kept or not, so a fractional build places the outlets
  // it keeps exactly where the full build does.
  const placed: Array<{ lat: number; lng: number }> = [];

  placed.push({ lat: home.lat, lng: home.lng });
  outlets.push({
    id: HOME_OUTLET_ID,
    // Named for what it is rather than for the fiction: this is the store you
    // seed at your own coordinates to demo a live geofenced check-in, and it
    // needs to be findable at a glance in a long list.
    name: 'Home',
    code: 'GP-000',
    channelType: 'supermarket',
    lat: home.lat,
    lng: home.lng,
    // The territory CODE, not its id — see the note on the loop below.
    territoryId: 'GP',
    acvWeight: 1.4,
  });

  for (const territory of TERRITORIES) {
    const geo = TERRITORY_GEOGRAPHY[territory.code]!;
    const agentsHere = AGENTS.filter((a) => a.territoryId === territory.id).length;
    // Drawn for the full count every time, then truncated, so a fractional
    // build is a prefix of the full one rather than a different world.
    const count = geo.outlets;
    const keep = Math.max(agentsHere, Math.round(count * fraction));
    const channels = channelPlan(count);
    let quickSaveLeft = QUICKSAVE_PER_TERRITORY[territory.code] ?? 0;

    for (let i = 1; i <= count; i += 1) {
      const channel = channels[i - 1]!;
      const suburb = pick(rng, geo.suburbs);

      // Rejection-sample a position clear of every outlet placed so far.
      let lat = geo.centre.lat;
      let lng = geo.centre.lng;
      for (let attempt = 0; attempt < 50; attempt += 1) {
        const angle = rng() * 2 * Math.PI;
        const r = geo.radius * Math.sqrt(rng());
        lat = Math.round((geo.centre.lat + r * Math.sin(angle)) * 1e6) / 1e6;
        lng = Math.round((geo.centre.lng + r * Math.cos(angle)) * 1e6) / 1e6;
        const clear = placed.every(
          (o) => haversineDistanceMeters(o, { lat, lng }) >= MIN_OUTLET_SEPARATION_M,
        );
        if (clear) break;
      }

      placed.push({ lat, lng });

      let name: string;
      if (channel === 'spaza') {
        name = `${pick(rng, SPAZA_OWNERS)} Spaza (${suburb})`;
      } else if (channel === 'supermarket' && quickSaveLeft > 0) {
        name = `${PRICE_BREACH_CHAIN} ${suburb}`;
        quickSaveLeft -= 1;
      } else {
        name = `${pick(rng, BANNERS[channel])} ${suburb}`;
      }

      const size = CHANNEL_SIZE[channel] * (0.75 + rng() * 0.5);
      const code = `${territory.code}-${String(i).padStart(3, '0')}`;
      const outlet: OutletSeed = {
        id: `demo-outlet-${code.toLowerCase()}`,
        name,
        code,
        channelType: channel,
        lat,
        lng,
        // `Outlet.territoryId` is free text mirroring `Territory.code`, NOT a
        // foreign key to `Territory.id` — see the note on the Territory model.
        // Seeding the id here made every territory-scoped query silently return
        // nothing: `GET /outlets?mine=true` matches on codes, so the agent's
        // "My territories" picker came back empty. Same class of bug as #97;
        // the test asserts against codes.
        territoryId: territory.code,
        acvWeight: Math.round(Math.min(4, Math.max(0.2, size)) * 10) / 10,
      };
      if (i <= keep) outlets.push(outlet);
    }
  }

  return outlets;
}

/**
 * Each outlet's owning agent: round-robin over the territory's agents in
 * outlet-code order. The home-base outlet belongs to the primary demo agent,
 * whose "today" route opens there.
 */
export function assignOutletsToAgents(outlets: OutletSeed[], agents: UserSeed[] = AGENTS): Map<string, string> {
  const owner = new Map<string, string>();
  for (const territory of TERRITORIES) {
    const here = agents.filter((a) => a.territoryId === territory.id);
    if (here.length === 0) continue;
    const territoryOutlets = outlets
      .filter((o) => o.territoryId === territory.code && o.id !== HOME_OUTLET_ID)
      .sort((a, b) => a.code.localeCompare(b.code));
    territoryOutlets.forEach((outlet, index) => {
      owner.set(outlet.id, here[index % here.length]!.id);
    });
  }
  const home = outlets.find((o) => o.id === HOME_OUTLET_ID);
  if (home) owner.set(home.id, 'demo-user-agent-1');
  return owner;
}
