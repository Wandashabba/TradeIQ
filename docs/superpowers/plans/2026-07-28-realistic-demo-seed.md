# Realistic Demo Seed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 824-line demo-toy seed with a coherent ~30-outlet, 12-week dataset built for a live sales walkthrough, closing #204 and #209.

**Architecture:** `backend/scripts/seed.ts` becomes a thin entrypoint over a new `backend/scripts/seed/` package — one module per concern (PRNG, calendar, catalog, photos, visits, ops, comms, reset), each unit-testable without a database. A fixed-seed PRNG makes every generated *value* reproducible while all *dates* derive from a single run-day anchor, so the demo never rots. Every run resets first, scoped to the demo client id.

**Tech Stack:** TypeScript, Prisma 6, Postgres, `sharp` (already a backend dependency, used by the thumbnail endpoint), Jest + ts-jest.

**Spec:** `docs/superpowers/specs/2026-07-28-realistic-demo-seed-design.md`

---

## Background the engineer needs

**Why #204 is not what it looks like.** `/trends` buckets each row by its *own*
`createdAt` (`backend/src/modules/trends/trends.service.ts`, `buildSeries` keyed
by `bucketStart(getDate(row))`). `Scorecard.createdAt` and `VisitStock.createdAt`
are `@default(now())` and the current seed never sets them, so every row gets
*insert* time no matter what its visit's `checkinTs` says. Backdating
`checkinTs` alone changes nothing. Both halves are required.

**Why #209 happens.** `getThumbnailForPhoto`
(`backend/src/modules/photos/thumbnails.ts`) requires `Photo.url` to match
`/^data:image\/[a-z0-9.+-]+;base64,([A-Za-z0-9+/=]+)$/i`. The seed writes
`https://demo.tradeiq.local/...`, which correctly 422s.

**Test database.** Backend tests run against a real Postgres created by
`backend/jest.global-setup.ts` from `backend/.env.test`. Jest collects any
`*.test.ts` outside `node_modules`/`dist`, so tests inside `backend/scripts/seed/`
are picked up with no config change. Always run with `npx jest --runInBand` —
the full parallel suite is known-flaky on loaded machines (#186).

**Commands** (all from `backend/`):
- Single suite: `npx jest scripts/seed/rng.test.ts --runInBand`
- Typecheck: `npx tsc --noEmit`
- Lint: `npm run lint`
- Seed: `npm run seed`

---

## File structure

| File | Responsibility |
|---|---|
| `backend/scripts/seed/rng.ts` | Seeded PRNG + `pick`/`intBetween`/`jitter` helpers. Pure. |
| `backend/scripts/seed/calendar.ts` | Run-day anchor, UTC-Monday week maths, 12-week series. Pure. |
| `backend/scripts/seed/photos.ts` | Real JPEG data URLs from raw pixels via `sharp`. |
| `backend/scripts/seed/catalog.ts` | Reference data: client, users, territories, outlets (incl. home-base), SKUs. Pure data + env parsing. |
| `backend/scripts/seed/visits.ts` | 12-week visit history generator and the improving-score curve. Pure. |
| `backend/scripts/seed/ops.ts` | Tasks, alerts, incentive scheme. Pure. |
| `backend/scripts/seed/comms.ts` | Messages, announcements. Pure. |
| `backend/scripts/seed/reset.ts` | FK-safe teardown scoped to the demo client. Touches Prisma. |
| `backend/scripts/seed/index.ts` | Orchestration: reset → write → summary. Touches Prisma. |
| `backend/scripts/seed.ts` | Thin entrypoint (rewritten). |
| `backend/src/modules/trends/trends.service.ts` | Export `bucketStart` so tests assert against real bucketing. |

**Design rule the generators follow:** every module except `reset.ts` and
`index.ts` is *pure* — it returns plain objects and never touches Prisma. That is
what makes the curve, the calendar and the photo encoding testable without a
database.

---

### Task 1: Seeded PRNG

**Files:**
- Create: `backend/scripts/seed/rng.ts`
- Test: `backend/scripts/seed/rng.test.ts`

- [ ] **Step 1: Write the failing test**

Create `backend/scripts/seed/rng.test.ts`:

```ts
import { makeRng, intBetween, pick, jitter } from './rng';

describe('makeRng', () => {
  it('produces the same sequence for the same seed', () => {
    const a = makeRng(12345);
    const b = makeRng(12345);
    const seqA = [a(), a(), a(), a(), a()];
    const seqB = [b(), b(), b(), b(), b()];
    expect(seqA).toEqual(seqB);
  });

  it('produces a different sequence for a different seed', () => {
    const a = makeRng(1);
    const b = makeRng(2);
    expect([a(), a(), a()]).not.toEqual([b(), b(), b()]);
  });

  it('stays within [0, 1)', () => {
    const rng = makeRng(99);
    for (let i = 0; i < 1000; i += 1) {
      const value = rng();
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThan(1);
    }
  });
});

describe('intBetween', () => {
  it('is inclusive at both ends', () => {
    const rng = makeRng(7);
    const seen = new Set<number>();
    for (let i = 0; i < 500; i += 1) seen.add(intBetween(rng, 1, 3));
    expect([...seen].sort()).toEqual([1, 2, 3]);
  });
});

describe('pick', () => {
  it('always returns a member of the list', () => {
    const rng = makeRng(3);
    const items = ['a', 'b', 'c'];
    for (let i = 0; i < 100; i += 1) expect(items).toContain(pick(rng, items));
  });

  it('throws on an empty list rather than returning undefined', () => {
    expect(() => pick(makeRng(1), [])).toThrow('pick from empty list');
  });
});

describe('jitter', () => {
  it('stays within +/- magnitude', () => {
    const rng = makeRng(5);
    for (let i = 0; i < 500; i += 1) {
      const value = jitter(rng, 4);
      expect(Math.abs(value)).toBeLessThanOrEqual(4);
    }
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest scripts/seed/rng.test.ts --runInBand`
Expected: FAIL — `Cannot find module './rng'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/scripts/seed/rng.ts`:

```ts
/**
 * Deterministic PRNG for the demo seed.
 *
 * The seed is generated, not hand-written, so reproducibility has to come from
 * somewhere: a fixed seed here means every run produces byte-identical values.
 * Only dates move (see `calendar.ts`), so a bug seen in a demo can always be
 * recreated.
 *
 * mulberry32 — small, fast, and good enough for demo data. Not for anything
 * security-sensitive.
 */
export function makeRng(seed: number): () => number {
  let a = seed >>> 0;
  return function next(): number {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Inclusive of both `min` and `max`. */
export function intBetween(rng: () => number, min: number, max: number): number {
  return min + Math.floor(rng() * (max - min + 1));
}

export function pick<T>(rng: () => number, items: readonly T[]): T {
  if (items.length === 0) {
    throw new Error('pick from empty list');
  }
  return items[Math.floor(rng() * items.length)] as T;
}

/** Symmetric noise in [-magnitude, +magnitude]. */
export function jitter(rng: () => number, magnitude: number): number {
  return (rng() * 2 - 1) * magnitude;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest scripts/seed/rng.test.ts --runInBand`
Expected: PASS, 6 tests

- [ ] **Step 5: Commit**

```bash
git add backend/scripts/seed/rng.ts backend/scripts/seed/rng.test.ts
git commit -m "feat(seed): deterministic PRNG for generated demo data"
```

---

### Task 2: Calendar anchored to run day

**Files:**
- Create: `backend/scripts/seed/calendar.ts`
- Test: `backend/scripts/seed/calendar.test.ts`
- Modify: `backend/src/modules/trends/trends.service.ts` (export `bucketStart`)

The week boundary here **must** agree with `/trends`, or the seed will produce a
history that buckets differently from how the dashboard reads it. Rather than
reimplement the rule, the test asserts parity against the real function.

- [ ] **Step 1: Export `bucketStart` from the trends service**

In `backend/src/modules/trends/trends.service.ts`, change the declaration:

```ts
function bucketStart(date: Date, interval: TrendInterval): Date {
```

to:

```ts
// Exported so the demo seed's calendar can assert week-boundary parity against
// the real bucketing rule rather than reimplementing it.
export function bucketStart(date: Date, interval: TrendInterval): Date {
```

- [ ] **Step 2: Write the failing test**

Create `backend/scripts/seed/calendar.test.ts`:

```ts
import { bucketStart } from '../../src/modules/trends/trends.service';
import {
  HISTORY_WEEKS,
  startOfUtcDay,
  mondayOfWeek,
  weekStarts,
  addDays,
  addHours,
} from './calendar';

const WED = new Date('2026-07-15T13:45:12.000Z'); // a Wednesday

describe('startOfUtcDay', () => {
  it('truncates to UTC midnight', () => {
    expect(startOfUtcDay(WED).toISOString()).toBe('2026-07-15T00:00:00.000Z');
  });
});

describe('mondayOfWeek', () => {
  it('returns the Monday of the containing week', () => {
    expect(mondayOfWeek(WED).toISOString()).toBe('2026-07-13T00:00:00.000Z');
  });

  it('treats Sunday as the end of its week, not the start', () => {
    const sunday = new Date('2026-07-19T23:00:00.000Z');
    expect(mondayOfWeek(sunday).toISOString()).toBe('2026-07-13T00:00:00.000Z');
  });

  // The guard that matters: if /trends ever changes its week boundary, this
  // fails rather than the seed silently generating a history the dashboard
  // buckets differently.
  it('agrees with the trends service bucketing rule', () => {
    for (let day = 0; day < 30; day += 1) {
      const date = addDays(new Date('2026-06-01T09:30:00.000Z'), day);
      expect(mondayOfWeek(date).toISOString()).toBe(
        bucketStart(date, 'week').toISOString(),
      );
    }
  });
});

describe('weekStarts', () => {
  it('returns HISTORY_WEEKS distinct Mondays, oldest first', () => {
    const weeks = weekStarts(WED, HISTORY_WEEKS);
    expect(weeks).toHaveLength(HISTORY_WEEKS);
    expect(new Set(weeks.map((w) => w.toISOString())).size).toBe(HISTORY_WEEKS);
    for (let i = 1; i < weeks.length; i += 1) {
      expect(weeks[i]!.getTime()).toBeGreaterThan(weeks[i - 1]!.getTime());
    }
  });

  it('ends with the anchor week, so the chart runs up to today', () => {
    const weeks = weekStarts(WED, HISTORY_WEEKS);
    expect(weeks[weeks.length - 1]!.toISOString()).toBe(
      mondayOfWeek(WED).toISOString(),
    );
  });

  // #204: one bucket is exactly the bug. Three is the ticket's floor.
  it('spans well beyond the three weekly buckets #204 requires', () => {
    expect(weekStarts(WED, HISTORY_WEEKS).length).toBeGreaterThanOrEqual(3);
  });
});

describe('addDays / addHours', () => {
  it('does not mutate its input', () => {
    const original = new Date(WED);
    addDays(WED, 5);
    addHours(WED, 5);
    expect(WED.toISOString()).toBe(original.toISOString());
  });

  it('adds the requested offset', () => {
    expect(addDays(WED, 2).toISOString()).toBe('2026-07-17T13:45:12.000Z');
    expect(addHours(WED, 2).toISOString()).toBe('2026-07-15T15:45:12.000Z');
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd backend && npx jest scripts/seed/calendar.test.ts --runInBand`
Expected: FAIL — `Cannot find module './calendar'`

- [ ] **Step 4: Write minimal implementation**

Create `backend/scripts/seed/calendar.ts`:

```ts
/**
 * Every timestamp in the demo seed derives from one anchor: the UTC start of
 * the day the seed was run.
 *
 * This deliberately replaces the old seed's rule ("no `Date.now()`/`new Date()`
 * with no args that would drift between runs"). That rule bought idempotency;
 * we trade it for a demo that does not rot — "today" always has stops and SLAs
 * are always believably due. The reproducibility it protected now comes from
 * the fixed-seed PRNG in `rng.ts` instead.
 */

const DAY_MS = 24 * 60 * 60 * 1000;

/** Weeks of history generated behind the anchor, inclusive of the anchor week. */
export const HISTORY_WEEKS = 12;

export function startOfUtcDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
}

/**
 * Monday 00:00 UTC of the week containing `date`. Must agree with
 * `bucketStart(date, 'week')` in the trends service — asserted in the tests.
 */
export function mondayOfWeek(date: Date): Date {
  const dayStart = startOfUtcDay(date);
  // getUTCDay: 0=Sun..6=Sat. Days since Monday: Mon->0 .. Sun->6.
  const daysSinceMonday = (dayStart.getUTCDay() + 6) % 7;
  return new Date(dayStart.getTime() - daysSinceMonday * DAY_MS);
}

/** `weeks` Monday starts ending with the anchor's own week, oldest first. */
export function weekStarts(anchor: Date, weeks: number): Date[] {
  const latest = mondayOfWeek(anchor);
  const result: Date[] = [];
  for (let i = weeks - 1; i >= 0; i -= 1) {
    result.push(new Date(latest.getTime() - i * 7 * DAY_MS));
  }
  return result;
}

export function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * DAY_MS);
}

export function addHours(date: Date, hours: number): Date {
  return new Date(date.getTime() + hours * 60 * 60 * 1000);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && npx jest scripts/seed/calendar.test.ts --runInBand`
Expected: PASS, 8 tests

- [ ] **Step 6: Confirm nothing else broke**

Run: `cd backend && npx jest scripts/seed src/modules/trends --runInBand`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add backend/scripts/seed/calendar.ts backend/scripts/seed/calendar.test.ts backend/src/modules/trends/trends.service.ts
git commit -m "feat(seed): run-day calendar anchor with trends bucketing parity"
```

---

### Task 3: Real photo data URLs (#209)

**Files:**
- Create: `backend/scripts/seed/photos.ts`
- Test: `backend/scripts/seed/photos.test.ts`

The test runs generated URLs through the **real** `getThumbnailForPhoto`, not a
copy of its regex. That is what actually pins #209: if the production decoder
ever tightens, this fails.

- [ ] **Step 1: Write the failing test**

Create `backend/scripts/seed/photos.test.ts`:

```ts
import { getThumbnailForPhoto } from '../../src/modules/photos/thumbnails';
import { demoPhotoDataUrl, SECTION_TINTS } from './photos';

describe('demoPhotoDataUrl', () => {
  it('produces a base64 jpeg data URL', async () => {
    const url = await demoPhotoDataUrl([200, 80, 60]);
    expect(url.startsWith('data:image/jpeg;base64,')).toBe(true);
  });

  // The guard for #209: the seed's URLs must survive the REAL thumbnail
  // decoder, which is what 422s on the current https://demo.tradeiq.local/...
  // placeholders.
  it('is decodable by the production thumbnail pipeline', async () => {
    const url = await demoPhotoDataUrl([60, 120, 200]);
    const thumb = await getThumbnailForPhoto(`seed-test-${Date.now()}`, async () => url);
    expect(thumb.length).toBeGreaterThan(0);
    // JPEG magic bytes.
    expect(thumb[0]).toBe(0xff);
    expect(thumb[1]).toBe(0xd8);
  });

  it('is deterministic for the same tint', async () => {
    const a = await demoPhotoDataUrl([10, 20, 30]);
    const b = await demoPhotoDataUrl([10, 20, 30]);
    expect(a).toBe(b);
  });

  it('differs between tints, so demo rows are visibly distinct', async () => {
    const a = await demoPhotoDataUrl([10, 20, 30]);
    const b = await demoPhotoDataUrl([200, 30, 40]);
    expect(a).not.toBe(b);
  });
});

describe('SECTION_TINTS', () => {
  it('covers every section the seed attaches photos to', () => {
    expect(Object.keys(SECTION_TINTS).sort()).toEqual(
      ['closure', 'competitive', 'pricing', 'visibility'].sort(),
    );
  });

  it('every tint decodes', async () => {
    for (const tint of Object.values(SECTION_TINTS)) {
      const url = await demoPhotoDataUrl(tint);
      expect(url.startsWith('data:image/jpeg;base64,')).toBe(true);
    }
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest scripts/seed/photos.test.ts --runInBand`
Expected: FAIL — `Cannot find module './photos'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/scripts/seed/photos.ts`:

```ts
import sharp from 'sharp';

/**
 * Real, decodable evidence photos for the demo seed (#209).
 *
 * The old seed stored `https://demo.tradeiq.local/...`, which
 * `getThumbnailForPhoto` correctly 422s — so every evidence row rendered as a
 * grey box. These are genuine JPEGs.
 *
 * Built from a raw pixel buffer rather than an SVG, deliberately: SVG text
 * rendering needs librsvg with a working fontconfig, which is not guaranteed in
 * CI. Raw pixels depend on nothing.
 */

export type Tint = readonly [number, number, number];

const WIDTH = 320;
const HEIGHT = 240;
const JPEG_QUALITY = 82;

/** One tint per section, so a manager's evidence rows look different. */
export const SECTION_TINTS: Record<string, Tint> = {
  visibility: [86, 122, 178],
  pricing: [196, 138, 62],
  competitive: [110, 148, 104],
  closure: [138, 116, 170],
};

function clamp255(value: number): number {
  if (value < 0) return 0;
  if (value > 255) return 255;
  return Math.round(value);
}

/**
 * A vertical gradient with a darker horizontal band across the lower third, so
 * a 256px thumbnail reads as a shelf photo rather than a flat colour swatch.
 */
export async function demoPhotoDataUrl(tint: Tint): Promise<string> {
  const [r, g, b] = tint;
  const pixels = Buffer.alloc(WIDTH * HEIGHT * 3);

  for (let y = 0; y < HEIGHT; y += 1) {
    const gradient = 0.55 + 0.45 * (y / HEIGHT);
    const inBand = y > HEIGHT * 0.62 && y < HEIGHT * 0.78;
    const bandShift = inBand ? -38 : 0;
    for (let x = 0; x < WIDTH; x += 1) {
      const i = (y * WIDTH + x) * 3;
      pixels[i] = clamp255(r * gradient + bandShift);
      pixels[i + 1] = clamp255(g * gradient + bandShift);
      pixels[i + 2] = clamp255(b * gradient + bandShift);
    }
  }

  const jpeg = await sharp(pixels, {
    raw: { width: WIDTH, height: HEIGHT, channels: 3 },
  })
    .jpeg({ quality: JPEG_QUALITY })
    .toBuffer();

  return `data:image/jpeg;base64,${jpeg.toString('base64')}`;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest scripts/seed/photos.test.ts --runInBand`
Expected: PASS, 6 tests

- [ ] **Step 5: Commit**

```bash
git add backend/scripts/seed/photos.ts backend/scripts/seed/photos.test.ts
git commit -m "feat(seed): real decodable JPEG evidence photos (#209)"
```

---

### Task 4: Catalog — client, users, territories, outlets, SKUs

**Files:**
- Create: `backend/scripts/seed/catalog.ts`
- Test: `backend/scripts/seed/catalog.test.ts`

Includes the home-base outlet, whose coordinates come from
`DEMO_HOME_LAT`/`DEMO_HOME_LNG` so a real physical location never enters git.

- [ ] **Step 1: Write the failing test**

Create `backend/scripts/seed/catalog.test.ts`:

```ts
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest scripts/seed/catalog.test.ts --runInBand`
Expected: FAIL — `Cannot find module './catalog'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/scripts/seed/catalog.ts`:

```ts
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest scripts/seed/catalog.test.ts --runInBand`
Expected: PASS, 15 tests

- [ ] **Step 5: Commit**

```bash
git add backend/scripts/seed/catalog.ts backend/scripts/seed/catalog.test.ts
git commit -m "feat(seed): demo catalog with env-configured home-base outlet"
```

---

### Task 5: Client-scoped reset

**Files:**
- Create: `backend/scripts/seed/reset.ts`
- Test: `backend/scripts/seed/reset.test.ts`

This is the safety-critical task. The test that matters is the one proving a
second tenant's rows survive.

- [ ] **Step 1: Write the failing test**

Create `backend/scripts/seed/reset.test.ts`:

```ts
import { PrismaClient } from '@prisma/client';
import { resetDemoData } from './reset';

const prisma = new PrismaClient();

const OTHER_CLIENT_ID = 'reset-test-other-client';
const DEMO_ID = 'reset-test-demo-client';

async function makeClient(id: string): Promise<void> {
  await prisma.client.create({
    data: {
      id,
      name: `client-${id}`,
      industry: 'FMCG',
      scorecardWeights: {},
      kpiThresholds: {},
    },
  });
}

describe('resetDemoData', () => {
  beforeEach(async () => {
    await resetDemoData(prisma, DEMO_ID);
    await resetDemoData(prisma, OTHER_CLIENT_ID);
    await prisma.client.deleteMany({ where: { id: { in: [DEMO_ID, OTHER_CLIENT_ID] } } });
    await makeClient(DEMO_ID);
    await makeClient(OTHER_CLIENT_ID);
  });

  afterAll(async () => {
    await resetDemoData(prisma, DEMO_ID);
    await resetDemoData(prisma, OTHER_CLIENT_ID);
    await prisma.client.deleteMany({ where: { id: { in: [DEMO_ID, OTHER_CLIENT_ID] } } });
    await prisma.$disconnect();
  });

  it('deletes the target client\'s rows', async () => {
    await prisma.territory.create({
      data: { id: 'reset-t-1', clientId: DEMO_ID, name: 'T', code: 'T1' },
    });
    await prisma.sku.create({
      data: { id: 'reset-s-1', clientId: DEMO_ID, name: 'S', category: 'C', minFacingsStandard: 1, rrp: 1 },
    });

    await resetDemoData(prisma, DEMO_ID);

    expect(await prisma.territory.count({ where: { clientId: DEMO_ID } })).toBe(0);
    expect(await prisma.sku.count({ where: { clientId: DEMO_ID } })).toBe(0);
  });

  // THE safety test. A bare deleteMany({}) would pass every other assertion
  // in this file and fail only this one.
  it('leaves another tenant\'s rows completely untouched', async () => {
    await prisma.territory.create({
      data: { id: 'reset-t-other', clientId: OTHER_CLIENT_ID, name: 'T', code: 'T1' },
    });
    await prisma.sku.create({
      data: { id: 'reset-s-other', clientId: OTHER_CLIENT_ID, name: 'S', category: 'C', minFacingsStandard: 1, rrp: 1 },
    });
    await prisma.user.create({
      data: { id: 'reset-u-other', clientId: OTHER_CLIENT_ID, email: 'other@reset-test.local', passwordHash: 'x', role: 'admin' },
    });

    await resetDemoData(prisma, DEMO_ID);

    expect(await prisma.territory.count({ where: { clientId: OTHER_CLIENT_ID } })).toBe(1);
    expect(await prisma.sku.count({ where: { clientId: OTHER_CLIENT_ID } })).toBe(1);
    expect(await prisma.user.count({ where: { clientId: OTHER_CLIENT_ID } })).toBe(1);
  });

  it('deletes visit children before visits, so no foreign key blows up', async () => {
    await prisma.territory.create({
      data: { id: 'reset-t-2', clientId: DEMO_ID, name: 'T', code: 'T2' },
    });
    const outlet = await prisma.outlet.create({
      data: { id: 'reset-o-1', clientId: DEMO_ID, name: 'O', code: 'O1', channelType: 'x', lat: 0, lng: 0, territoryId: 'reset-t-2' },
    });
    const agent = await prisma.user.create({
      data: { id: 'reset-u-1', clientId: DEMO_ID, email: 'agent@reset-test.local', passwordHash: 'x', role: 'field_agent' },
    });
    const visit = await prisma.visit.create({
      data: { id: 'reset-v-1', clientId: DEMO_ID, outletId: outlet.id, agentId: agent.id, checkinTs: new Date(), checkinLat: 0, checkinLng: 0, geofencePass: true, status: 'submitted' },
    });
    await prisma.scorecard.create({
      data: { visitId: visit.id, dimensionScores: {}, weightedTotal: 80, ratingBand: 'green' },
    });
    await prisma.photo.create({
      data: { visitId: visit.id, section: 'visibility', url: 'data:image/jpeg;base64,AA==', gpsTag: {}, timestamp: new Date() },
    });

    await expect(resetDemoData(prisma, DEMO_ID)).resolves.not.toThrow();
    expect(await prisma.visit.count({ where: { clientId: DEMO_ID } })).toBe(0);
    expect(await prisma.scorecard.count({ where: { visit: { clientId: DEMO_ID } } })).toBe(0);
  });

  it('is safe to run against a client that has no data', async () => {
    await expect(resetDemoData(prisma, 'reset-test-nonexistent')).resolves.not.toThrow();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest scripts/seed/reset.test.ts --runInBand`
Expected: FAIL — `Cannot find module './reset'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/scripts/seed/reset.ts`:

```ts
import { PrismaClient } from '@prisma/client';

/**
 * Deletes every demo row for one client, children before parents.
 *
 * The seed resets rather than upserts because its dates are anchored to the run
 * day: a second run would otherwise leave the previous run's rows fossilised at
 * their old dates alongside the new ones.
 *
 * Every delete is scoped by `clientId` (directly, or through a relation filter).
 * There is deliberately no bare `deleteMany({})` anywhere in this file — it must
 * be impossible for a demo reseed to touch another tenant's data.
 *
 * `Client` itself is NOT deleted: `index.ts` upserts it, and keeping the row
 * avoids a needless id churn.
 */
export async function resetDemoData(prisma: PrismaClient, clientId: string): Promise<void> {
  // Visit children — all reachable only through a visit.
  await prisma.orderLine.deleteMany({ where: { order: { clientId } } });
  await prisma.visitTemplateResponse.deleteMany({ where: { visit: { clientId } } });
  await prisma.scorecard.deleteMany({ where: { visit: { clientId } } });
  await prisma.photo.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitRisk.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitCapability.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitCompetitive.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitPricing.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitVisibility.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitStock.deleteMany({ where: { visit: { clientId } } });

  // Rows that reference visits and/or outlets.
  await prisma.task.deleteMany({ where: { outlet: { clientId } } });
  await prisma.order.deleteMany({ where: { clientId } });
  await prisma.alert.deleteMany({ where: { clientId } });
  await prisma.checkInAttempt.deleteMany({ where: { clientId } });
  await prisma.visit.deleteMany({ where: { clientId } });

  // Planning and comms.
  await prisma.beatPlanStop.deleteMany({ where: { beatPlan: { clientId } } });
  await prisma.beatPlan.deleteMany({ where: { clientId } });
  await prisma.campaignOutlet.deleteMany({ where: { campaign: { clientId } } });
  await prisma.campaign.deleteMany({ where: { clientId } });
  await prisma.message.deleteMany({ where: { clientId } });
  await prisma.announcement.deleteMany({ where: { clientId } });

  // Configuration.
  await prisma.reportSchedule.deleteMany({ where: { clientId } });
  await prisma.reportDefinition.deleteMany({ where: { clientId } });
  await prisma.webhook.deleteMany({ where: { clientId } });
  await prisma.incentiveScheme.deleteMany({ where: { clientId } });
  await prisma.visitTemplateResponse.deleteMany({ where: { template: { clientId } } });
  await prisma.auditTemplate.deleteMany({ where: { clientId } });
  await prisma.alertRule.deleteMany({ where: { clientId } });
  await prisma.promoCalendar.deleteMany({ where: { clientId } });

  // Core entities last.
  await prisma.outlet.deleteMany({ where: { clientId } });
  await prisma.sku.deleteMany({ where: { clientId } });
  await prisma.userTerritory.deleteMany({ where: { user: { clientId } } });
  await prisma.territory.deleteMany({ where: { clientId } });
  await prisma.user.deleteMany({ where: { clientId } });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest scripts/seed/reset.test.ts --runInBand`
Expected: PASS, 4 tests

- [ ] **Step 5: Commit**

```bash
git add backend/scripts/seed/reset.ts backend/scripts/seed/reset.test.ts
git commit -m "feat(seed): client-scoped FK-safe reset"
```

---

### Task 6: Visit history and the improving curve (#204)

**Files:**
- Create: `backend/scripts/seed/visits.ts`
- Test: `backend/scripts/seed/visits.test.ts`

The generator is pure: it returns plain objects with explicit `createdAt` values.
`index.ts` writes them. That is what makes the curve testable without a database.

- [ ] **Step 1: Write the failing test**

Create `backend/scripts/seed/visits.test.ts`:

```ts
import { mondayOfWeek, HISTORY_WEEKS } from './calendar';
import { buildOutlets, PROBLEM_OUTLET_CODES, SKUS, USERS } from './catalog';
import { buildVisitHistory, ratingBandFor } from './visits';

const ANCHOR = new Date('2026-07-28T00:00:00.000Z');
const OUTLETS = buildOutlets({ lat: -26.1076, lng: 28.0567, source: 'fallback' });
const AGENTS = USERS.filter((u) => u.role === 'field_agent');
const HISTORY = buildVisitHistory({ anchor: ANCHOR, outlets: OUTLETS, agents: AGENTS, skus: SKUS });

function meanOf(values: number[]): number {
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

describe('ratingBandFor', () => {
  // Must match kpiThresholds: green >= 80, amber >= 60, else red.
  it('maps totals onto the client\'s configured bands', () => {
    expect(ratingBandFor(85)).toBe('green');
    expect(ratingBandFor(80)).toBe('green');
    expect(ratingBandFor(79.9)).toBe('amber');
    expect(ratingBandFor(60)).toBe('amber');
    expect(ratingBandFor(59.9)).toBe('red');
  });
});

describe('buildVisitHistory', () => {
  it('generates a few hundred visits', () => {
    expect(HISTORY.length).toBeGreaterThanOrEqual(250);
    expect(HISTORY.length).toBeLessThanOrEqual(500);
  });

  // #204, the actual root cause: /trends buckets on each row's OWN createdAt,
  // which the old seed never set, so every row landed in the insert-time bucket.
  it('sets scorecard createdAt to the visit time, not insert time', () => {
    for (const visit of HISTORY) {
      expect(visit.scorecard.createdAt.toISOString()).toBe(visit.checkinTs.toISOString());
    }
  });

  it('sets stock-row createdAt to the visit time', () => {
    for (const visit of HISTORY) {
      for (const row of visit.stock) {
        expect(row.createdAt.toISOString()).toBe(visit.checkinTs.toISOString());
      }
    }
  });

  // #204's visible symptom: one weekly bucket means "Not enough data to plot",
  // because LineChart needs points.length >= 2.
  it('spreads scorecards across every week of history', () => {
    const buckets = new Set(
      HISTORY.map((v) => mondayOfWeek(v.scorecard.createdAt).toISOString()),
    );
    expect(buckets.size).toBe(HISTORY_WEEKS);
    expect(buckets.size).toBeGreaterThanOrEqual(3);
  });

  it('never generates a visit in the future', () => {
    for (const visit of HISTORY) {
      expect(visit.checkinTs.getTime()).toBeLessThanOrEqual(
        ANCHOR.getTime() + 24 * 60 * 60 * 1000,
      );
    }
  });

  // The demo's whole point: the line must visibly climb.
  it('improves materially from the first three weeks to the last three', () => {
    const weeks = [...new Set(HISTORY.map((v) => mondayOfWeek(v.checkinTs).getTime()))].sort();
    const firstThree = new Set(weeks.slice(0, 3));
    const lastThree = new Set(weeks.slice(-3));

    const early = meanOf(
      HISTORY.filter((v) => firstThree.has(mondayOfWeek(v.checkinTs).getTime()))
        .map((v) => v.scorecard.weightedTotal),
    );
    const late = meanOf(
      HISTORY.filter((v) => lastThree.has(mondayOfWeek(v.checkinTs).getTime()))
        .map((v) => v.scorecard.weightedTotal),
    );

    expect(late).toBeGreaterThan(early + 8);
  });

  it('keeps the problem outlets in the bottom band even at the end', () => {
    const problemIds = new Set(
      OUTLETS.filter((o) => (PROBLEM_OUTLET_CODES as readonly string[]).includes(o.code))
        .map((o) => o.id),
    );
    const problemMean = meanOf(
      HISTORY.filter((v) => problemIds.has(v.outletId)).map((v) => v.scorecard.weightedTotal),
    );
    const healthyMean = meanOf(
      HISTORY.filter((v) => !problemIds.has(v.outletId)).map((v) => v.scorecard.weightedTotal),
    );
    expect(problemMean).toBeLessThan(healthyMean - 10);
  });

  it('keeps every score inside a believable range', () => {
    for (const visit of HISTORY) {
      expect(visit.scorecard.weightedTotal).toBeGreaterThanOrEqual(25);
      expect(visit.scorecard.weightedTotal).toBeLessThanOrEqual(98);
    }
  });

  it('is deterministic — same anchor in, same scores out', () => {
    const again = buildVisitHistory({ anchor: ANCHOR, outlets: OUTLETS, agents: AGENTS, skus: SKUS });
    expect(again.map((v) => v.scorecard.weightedTotal)).toEqual(
      HISTORY.map((v) => v.scorecard.weightedTotal),
    );
  });

  it('gives every visit a full set of section rows', () => {
    for (const visit of HISTORY) {
      expect(visit.stock.length).toBeGreaterThan(0);
      expect(visit.pricing.length).toBeGreaterThan(0);
      expect(visit.competitive.length).toBeGreaterThan(0);
      expect(visit.visibility).toBeDefined();
      expect(visit.capability).toBeDefined();
    }
  });

  it('only ever assigns a visit to a real agent and a real outlet', () => {
    const agentIds = new Set(AGENTS.map((a) => a.id));
    const outletIds = new Set(OUTLETS.map((o) => o.id));
    for (const visit of HISTORY) {
      expect(agentIds.has(visit.agentId)).toBe(true);
      expect(outletIds.has(visit.outletId)).toBe(true);
    }
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest scripts/seed/visits.test.ts --runInBand`
Expected: FAIL — `Cannot find module './visits'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/scripts/seed/visits.ts`:

```ts
import { addDays, addHours, HISTORY_WEEKS, weekStarts } from './calendar';
import { OutletSeed, PROBLEM_OUTLET_CODES, SkuSeed, UserSeed } from './catalog';
import { intBetween, jitter, makeRng, pick } from './rng';

/**
 * Generates the 12-week visit history and the improving execution-score curve.
 *
 * Pure by design: it returns plain objects with explicit `createdAt` values and
 * never touches Prisma, so the curve can be asserted without a database.
 *
 * Every Scorecard and VisitStock row carries an explicit `createdAt` equal to
 * its visit's `checkinTs`. That is the actual fix for #204 — `/trends` buckets
 * on each row's own `createdAt`, and leaving it to `@default(now())` put every
 * row in the insert-time bucket no matter how the visits were dated.
 */

const SCORE_START = 62;
const SCORE_END = 78;
const SCORE_FLOOR = 25;
const SCORE_CEILING = 98;
const PROBLEM_OUTLET_PENALTY = 24;
const VISITS_PER_AGENT_PER_WEEK = 5;

export interface StockRow {
  skuId: string;
  unitsAvailable: number;
  lastStockinDate: Date;
  daysOutOfStock: number;
  velocityAvg: number;
  coverageDaysPredicted: number;
  salesActual: number;
  salesTarget: number;
  createdAt: Date;
}

export interface PricingRow {
  skuId: string;
  priceActual: number;
  priceMaster: number;
  deviationPct: number;
  promoActive: boolean;
  promoMaterialsDetected: Record<string, boolean>;
  commsRating: number;
  createdAt: Date;
}

export interface CompetitiveRow {
  competitorSku: string;
  competitorPrice: number;
  competitorPosmType: string;
  competitorPromoterPresent: boolean;
  facingsCount: number;
  geotag: { lat: number; lng: number };
  createdAt: Date;
}

export interface GeneratedVisit {
  id: string;
  outletId: string;
  outletCode: string;
  agentId: string;
  checkinTs: Date;
  checkinLat: number;
  checkinLng: number;
  checkinDistanceM: number;
  geofencePass: boolean;
  isProblemOutlet: boolean;
  stock: StockRow[];
  pricing: PricingRow[];
  competitive: CompetitiveRow[];
  visibility: {
    brandingElements: Record<string, boolean>;
    planogramCompliancePct: number;
    facingsCount: { total: number; byZone: { eye: number; reach: number; stoop: number } };
    highTrafficPass: boolean;
    cleanlinessScore: number;
    createdAt: Date;
  };
  capability: {
    staffHeadcountConfirmed: number;
    repTrainingStatus: Record<string, boolean>;
    quizScore: number;
    createdAt: Date;
  };
  scorecard: {
    dimensionScores: Record<string, number>;
    weightedTotal: number;
    ratingBand: string;
    createdAt: Date;
  };
}

export interface BuildVisitHistoryInput {
  anchor: Date;
  outlets: OutletSeed[];
  agents: UserSeed[];
  skus: SkuSeed[];
}

/** Matches the client's kpiThresholds: green >= 80, amber >= 60, else red. */
export function ratingBandFor(weightedTotal: number): string {
  if (weightedTotal >= 80) return 'green';
  if (weightedTotal >= 60) return 'amber';
  return 'red';
}

function clampScore(value: number): number {
  return Math.round(Math.min(SCORE_CEILING, Math.max(SCORE_FLOOR, value)) * 10) / 10;
}

const COMPETITORS = ['RivalCola 500ml', 'RivalCola 2L', 'Storm Energy 440ml', 'Pure Springs 1L'];
const POSM_TYPES = ['shelf_strip', 'wobbler', 'poster', 'end_cap'];

export function buildVisitHistory(input: BuildVisitHistoryInput): GeneratedVisit[] {
  const { anchor, outlets, agents, skus } = input;
  const rng = makeRng(987654321);
  const weeks = weekStarts(anchor, HISTORY_WEEKS);
  const problemCodes = new Set<string>(PROBLEM_OUTLET_CODES);

  // A fixed offset per outlet so outlets rank consistently week to week rather
  // than shuffling — a demo where the worst store changes every week reads as
  // noise, not as a business.
  const outletOffset = new Map<string, number>();
  for (const outlet of outlets) {
    outletOffset.set(outlet.id, jitter(rng, 8));
  }

  const visits: GeneratedVisit[] = [];
  let counter = 0;

  weeks.forEach((weekStart, weekIndex) => {
    const trend = SCORE_START + ((SCORE_END - SCORE_START) * weekIndex) / (HISTORY_WEEKS - 1);

    for (const agent of agents) {
      const agentOutlets = outlets.filter((o) => o.territoryId === agent.territoryId);
      if (agentOutlets.length === 0) continue;

      for (let n = 0; n < VISITS_PER_AGENT_PER_WEEK; n += 1) {
        // Mon-Fri only; a visit on the anchor day itself is fine, but nothing
        // beyond it — a demo must never show a visit from the future.
        const dayOffset = n % 5;
        const checkinTs = addHours(addDays(weekStart, dayOffset), 8 + intBetween(rng, 0, 8));
        if (checkinTs.getTime() > anchor.getTime() + 24 * 60 * 60 * 1000) continue;

        const outlet = agentOutlets[(weekIndex + n) % agentOutlets.length]!;
        const isProblem = problemCodes.has(outlet.code);

        const total = clampScore(
          trend + (outletOffset.get(outlet.id) ?? 0) + jitter(rng, 4)
            - (isProblem ? PROBLEM_OUTLET_PENALTY : 0),
        );

        counter += 1;
        const id = `demo-visit-${String(counter).padStart(4, '0')}`;

        // Dimensions vary around the total so the scorecard breakdown does not
        // read as six identical numbers.
        const dimension = (): number => clampScore(total + jitter(rng, 6));
        const stockSkus = skus.slice(0, 6);

        visits.push({
          id,
          outletId: outlet.id,
          outletCode: outlet.code,
          agentId: agent.id,
          checkinTs,
          checkinLat: outlet.lat + jitter(rng, 0.0002),
          checkinLng: outlet.lng + jitter(rng, 0.0002),
          checkinDistanceM: Math.round(intBetween(rng, 3, 45)),
          geofencePass: true,
          isProblemOutlet: isProblem,
          stock: stockSkus.map((sku) => {
            // A low score means empty shelves — the two must agree or the demo
            // contradicts itself when a manager drills in.
            const stockedOut = isProblem && rng() < 0.4;
            return {
              skuId: sku.id,
              unitsAvailable: stockedOut ? 0 : intBetween(rng, 8, 90),
              lastStockinDate: addDays(checkinTs, -intBetween(rng, 1, 9)),
              daysOutOfStock: stockedOut ? intBetween(rng, 1, 5) : 0,
              velocityAvg: intBetween(rng, 30, 220) / 10,
              coverageDaysPredicted: intBetween(rng, 5, 90) / 10,
              salesActual: intBetween(rng, 600, 1400),
              salesTarget: 1200,
              createdAt: checkinTs,
            };
          }),
          pricing: skus.slice(0, 4).map((sku) => {
            const deviation = isProblem && rng() < 0.5
              ? intBetween(rng, 110, 240) / 10
              : intBetween(rng, 0, 40) / 10;
            const priceActual = Math.round(sku.rrp * (1 + deviation / 100) * 100) / 100;
            return {
              skuId: sku.id,
              priceActual,
              priceMaster: sku.rrp,
              deviationPct: Math.round(deviation * 100) / 100,
              promoActive: rng() < 0.35,
              promoMaterialsDetected: { poster: rng() < 0.6, shelfStrip: rng() < 0.5 },
              commsRating: intBetween(rng, 2, 5),
              createdAt: checkinTs,
            };
          }),
          competitive: [
            {
              competitorSku: pick(rng, COMPETITORS),
              competitorPrice: intBetween(rng, 1500, 3600) / 100,
              competitorPosmType: pick(rng, POSM_TYPES),
              competitorPromoterPresent: rng() < 0.25,
              facingsCount: intBetween(rng, 2, 9),
              geotag: { lat: outlet.lat, lng: outlet.lng },
              createdAt: checkinTs,
            },
          ],
          visibility: {
            brandingElements: {
              poster: rng() < 0.8,
              shelfStrip: rng() < 0.7,
              wobbler: rng() < 0.5,
              endCap: rng() < 0.4,
            },
            planogramCompliancePct: dimension(),
            facingsCount: {
              total: intBetween(rng, 12, 30),
              byZone: { eye: intBetween(rng, 4, 14), reach: intBetween(rng, 3, 9), stoop: intBetween(rng, 1, 6) },
            },
            highTrafficPass: !isProblem || rng() < 0.3,
            cleanlinessScore: intBetween(rng, isProblem ? 1 : 3, 5),
            createdAt: checkinTs,
          },
          capability: {
            staffHeadcountConfirmed: intBetween(rng, 2, 8),
            repTrainingStatus: {
              onboarded: true,
              planogramCertified: rng() < 0.7,
              promoBriefed: rng() < 0.6,
            },
            quizScore: Math.round(dimension()),
            createdAt: checkinTs,
          },
          scorecard: {
            dimensionScores: {
              availability: dimension(),
              visibility: dimension(),
              display: dimension(),
              pricing: dimension(),
              competitive: dimension(),
              salesCapability: dimension(),
            },
            weightedTotal: total,
            ratingBand: ratingBandFor(total),
            createdAt: checkinTs,
          },
        });
      }
    }
  });

  return visits;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest scripts/seed/visits.test.ts --runInBand`
Expected: PASS, 12 tests

- [ ] **Step 5: Verify the guard actually bites**

Temporarily change `createdAt: checkinTs` on the scorecard to `createdAt: new Date()`.
Run: `cd backend && npx jest scripts/seed/visits.test.ts --runInBand`
Expected: FAIL on "sets scorecard createdAt to the visit time" **and** on "spreads
scorecards across every week of history" — the latter collapsing to 1 bucket,
which is exactly #204. **Revert the change.**

- [ ] **Step 6: Commit**

```bash
git add backend/scripts/seed/visits.ts backend/scripts/seed/visits.test.ts
git commit -m "feat(seed): 12-week visit history with improving score curve (#204)"
```

---

### Task 7: Tasks, alerts and the incentive scheme

**Files:**
- Create: `backend/scripts/seed/ops.ts`
- Test: `backend/scripts/seed/ops.test.ts`

- [ ] **Step 1: Write the failing test**

Create `backend/scripts/seed/ops.test.ts`:

```ts
import { buildOutlets, PROBLEM_OUTLET_CODES, SKUS, USERS } from './catalog';
import { SECTION_TINTS, demoPhotoDataUrl } from './photos';
import { buildVisitHistory } from './visits';
import { buildOps, OpsBundle } from './ops';

const ANCHOR = new Date('2026-07-28T00:00:00.000Z');
const OUTLETS = buildOutlets({ lat: -26.1076, lng: 28.0567, source: 'fallback' });
const AGENTS = USERS.filter((u) => u.role === 'field_agent');
const HISTORY = buildVisitHistory({ anchor: ANCHOR, outlets: OUTLETS, agents: AGENTS, skus: SKUS });

// A real generated JPEG, not a stub — otherwise the closure-photo assertion
// below would pass against any string that merely starts with the data-URL
// prefix, which is exactly the bug #209 is about.
let closurePhotoUrl: string;
let OPS: OpsBundle;

beforeAll(async () => {
  closurePhotoUrl = await demoPhotoDataUrl(SECTION_TINTS.closure!);
  OPS = buildOps({ anchor: ANCHOR, visits: HISTORY, outlets: OUTLETS, agents: AGENTS, closurePhotoUrl });
});

describe('buildOps', () => {
  it('raises alerts, and leaves some unacknowledged for the demo to triage', () => {
    expect(OPS.alerts.length).toBeGreaterThan(0);
    expect(OPS.alerts.some((a) => !a.acknowledged)).toBe(true);
  });

  it('concentrates open alerts on the problem outlets', () => {
    const problemIds = new Set(
      OUTLETS.filter((o) => (PROBLEM_OUTLET_CODES as readonly string[]).includes(o.code))
        .map((o) => o.id),
    );
    const open = OPS.alerts.filter((a) => !a.acknowledged);
    const onProblem = open.filter((a) => a.outletId && problemIds.has(a.outletId));
    expect(onProblem.length).toBeGreaterThan(open.length / 2);
  });

  it('creates both closed and open tasks, so the demo shows a working loop', () => {
    expect(OPS.tasks.some((t) => t.status === 'closed')).toBe(true);
    expect(OPS.tasks.some((t) => t.status === 'open')).toBe(true);
  });

  it('leaves some open tasks genuinely overdue', () => {
    const overdue = OPS.tasks.filter(
      (t) => t.status === 'open' && t.slaDueAt.getTime() < ANCHOR.getTime(),
    );
    expect(overdue.length).toBeGreaterThan(0);
  });

  it('never gives a task an SLA due before the visit that raised it', () => {
    const visitById = new Map(HISTORY.map((v) => [v.id, v]));
    for (const task of OPS.tasks) {
      if (!task.visitId) continue;
      const visit = visitById.get(task.visitId)!;
      expect(task.slaDueAt.getTime()).toBeGreaterThan(visit.checkinTs.getTime());
    }
  });

  it('assigns every task to a real agent', () => {
    const agentIds = new Set(AGENTS.map((a) => a.id));
    for (const task of OPS.tasks) expect(agentIds.has(task.ownerId)).toBe(true);
  });

  it('gives closed tasks the real closure photo, not a placeholder URL', () => {
    const closed = OPS.tasks.filter((t) => t.status === 'closed');
    expect(closed.length).toBeGreaterThan(0);
    for (const task of closed) {
      expect(task.closurePhotoUrl).toBe(closurePhotoUrl);
    }
  });

  it('leaves open tasks without a closure photo', () => {
    for (const task of OPS.tasks.filter((t) => t.status === 'open')) {
      expect(task.closurePhotoUrl).toBeUndefined();
    }
  });

  it('defines an active incentive scheme', () => {
    expect(OPS.incentiveSchemes.length).toBeGreaterThan(0);
    expect(OPS.incentiveSchemes.some((s) => s.active)).toBe(true);
  });

  it('is deterministic', () => {
    const again = buildOps({ anchor: ANCHOR, visits: HISTORY, outlets: OUTLETS, agents: AGENTS, closurePhotoUrl });
    expect(again.tasks.map((t) => t.id)).toEqual(OPS.tasks.map((t) => t.id));
    expect(again.alerts.map((a) => a.id)).toEqual(OPS.alerts.map((a) => a.id));
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest scripts/seed/ops.test.ts --runInBand`
Expected: FAIL — `Cannot find module './ops'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/scripts/seed/ops.ts`:

```ts
import { addDays } from './calendar';
import { OutletSeed, UserSeed } from './catalog';
import { makeRng, pick } from './rng';
import { GeneratedVisit } from './visits';

/**
 * Tasks, alerts and incentives — the "live problem tail".
 *
 * These are generated FROM the visit history rather than sprinkled on top, so a
 * manager who drills from an alert into its outlet finds the low scores and
 * stockouts that justify it. A demo where the alerts and the data disagree is
 * worse than one with no alerts.
 *
 * Closure photos are real base64 JPEGs (#209), supplied by the caller so this
 * module stays synchronous and pure.
 */

export interface GeneratedTask {
  id: string;
  visitId: string | null;
  findingType: string;
  outletId: string;
  requiredFix: string;
  // The TaskPriority enum is exactly critical | high | normal. There is no
  // 'low' — do not add one here without a migration.
  priority: 'critical' | 'high' | 'normal';
  slaDueAt: Date;
  ownerId: string;
  status: 'open' | 'closed';
  closurePhotoUrl?: string;
  closureVerified: boolean;
  createdAt: Date;
}

export interface GeneratedAlert {
  id: string;
  ruleId: string;
  visitId: string | null;
  outletId: string | null;
  metric: string;
  message: string;
  severity: string;
  acknowledged: boolean;
  createdAt: Date;
}

export interface GeneratedIncentiveScheme {
  id: string;
  name: string;
  metric: string;
  threshold: number;
  rewardPoints: number;
  rewardDetail: string;
  active: boolean;
}

export interface OpsBundle {
  tasks: GeneratedTask[];
  alerts: GeneratedAlert[];
  incentiveSchemes: GeneratedIncentiveScheme[];
}

export interface BuildOpsInput {
  anchor: Date;
  visits: GeneratedVisit[];
  outlets: OutletSeed[];
  agents: UserSeed[];
  /**
   * Real JPEG data URL for closed tasks' closure evidence. Required, not
   * optional: a default would let a placeholder string satisfy the test that is
   * supposed to prove #209 is fixed.
   */
  closurePhotoUrl: string;
}

export const ALERT_RULE_IDS = {
  outOfStock: 'demo-alert-rule-oos',
  priceDeviation: 'demo-alert-rule-price',
  lowScorecard: 'demo-alert-rule-score',
} as const;

const RECENT_WINDOW_DAYS = 21;

export function buildOps(input: BuildOpsInput): OpsBundle {
  const { anchor, visits, agents, closurePhotoUrl } = input;
  const rng = makeRng(555000111);

  const tasks: GeneratedTask[] = [];
  const alerts: GeneratedAlert[] = [];

  const recentCutoff = addDays(anchor, -RECENT_WINDOW_DAYS);
  let taskCounter = 0;
  let alertCounter = 0;

  for (const visit of visits) {
    const isRecent = visit.checkinTs.getTime() >= recentCutoff.getTime();
    const owner = pick(rng, agents);

    const stockout = visit.stock.find((row) => row.unitsAvailable === 0);
    const badPrice = visit.pricing.find((row) => row.deviationPct > 10);

    // Historic findings are closed (the loop worked); recent ones on problem
    // outlets stay open and overdue (there is still something to do).
    if (stockout) {
      taskCounter += 1;
      const closed = !isRecent || !visit.isProblemOutlet;
      tasks.push({
        id: `demo-task-${String(taskCounter).padStart(4, '0')}`,
        visitId: visit.id,
        findingType: 'out_of_stock',
        outletId: visit.outletId,
        requiredFix: 'Replenish the out-of-stock SKU from back-stock and confirm shelf facings.',
        priority: visit.isProblemOutlet ? 'critical' : 'high',
        slaDueAt: addDays(visit.checkinTs, 3),
        ownerId: owner.id,
        status: closed ? 'closed' : 'open',
        closurePhotoUrl: closed ? closurePhotoUrl : undefined,
        closureVerified: closed,
        createdAt: visit.checkinTs,
      });
    }

    if (badPrice) {
      taskCounter += 1;
      const closed = !isRecent;
      tasks.push({
        id: `demo-task-${String(taskCounter).padStart(4, '0')}`,
        visitId: visit.id,
        findingType: 'price_deviation',
        outletId: visit.outletId,
        requiredFix: 'Reprint the shelf tag to match the master price list and photograph it.',
        priority: 'normal',
        slaDueAt: addDays(visit.checkinTs, 5),
        ownerId: owner.id,
        status: closed ? 'closed' : 'open',
        closurePhotoUrl: closed ? closurePhotoUrl : undefined,
        closureVerified: closed,
        createdAt: visit.checkinTs,
      });
    }

    // Only recent exceptions raise alerts — a manager's alert list should be
    // actionable, not an archive.
    if (!isRecent) continue;

    if (stockout) {
      alertCounter += 1;
      alerts.push({
        id: `demo-alert-${String(alertCounter).padStart(4, '0')}`,
        ruleId: ALERT_RULE_IDS.outOfStock,
        visitId: visit.id,
        outletId: visit.outletId,
        metric: 'out_of_stock',
        message: 'Out of stock detected on a core SKU.',
        severity: visit.isProblemOutlet ? 'critical' : 'high',
        acknowledged: !visit.isProblemOutlet,
        createdAt: visit.checkinTs,
      });
    }

    if (visit.scorecard.weightedTotal < 60) {
      alertCounter += 1;
      alerts.push({
        id: `demo-alert-${String(alertCounter).padStart(4, '0')}`,
        ruleId: ALERT_RULE_IDS.lowScorecard,
        visitId: visit.id,
        outletId: visit.outletId,
        metric: 'low_scorecard',
        message: `Execution score ${visit.scorecard.weightedTotal} is below the red threshold.`,
        severity: 'high',
        acknowledged: false,
        createdAt: visit.checkinTs,
      });
    }

    if (badPrice) {
      alertCounter += 1;
      alerts.push({
        id: `demo-alert-${String(alertCounter).padStart(4, '0')}`,
        ruleId: ALERT_RULE_IDS.priceDeviation,
        visitId: visit.id,
        outletId: visit.outletId,
        metric: 'price_deviation',
        message: `Shelf price is ${badPrice.deviationPct}% above master.`,
        severity: 'normal',
        acknowledged: rng() < 0.5,
        createdAt: visit.checkinTs,
      });
    }
  }

  const incentiveSchemes: GeneratedIncentiveScheme[] = [
    {
      id: 'demo-incentive-1',
      name: 'Q3 Perfect Store Push',
      metric: 'scorecard',
      threshold: 80,
      rewardPoints: 500,
      rewardDetail: 'R500 airtime voucher for every store scored 80+.',
      active: true,
    },
    {
      id: 'demo-incentive-2',
      name: 'Close the Loop',
      metric: 'tasks_closed',
      threshold: 20,
      rewardPoints: 250,
      rewardDetail: 'R250 for 20 verified task closures in a month.',
      active: true,
    },
  ];

  return { tasks, alerts, incentiveSchemes };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest scripts/seed/ops.test.ts --runInBand`
Expected: PASS, 10 tests

- [ ] **Step 5: Commit**

```bash
git add backend/scripts/seed/ops.ts backend/scripts/seed/ops.test.ts
git commit -m "feat(seed): tasks, alerts and incentives derived from visit history"
```

---

### Task 8: Messages and announcements

**Files:**
- Create: `backend/scripts/seed/comms.ts`
- Test: `backend/scripts/seed/comms.test.ts`

- [ ] **Step 1: Write the failing test**

Create `backend/scripts/seed/comms.test.ts`:

```ts
import { USERS } from './catalog';
import { buildComms } from './comms';

const ANCHOR = new Date('2026-07-28T00:00:00.000Z');
const COMMS = buildComms({ anchor: ANCHOR, users: USERS });

describe('buildComms', () => {
  it('produces message threads and announcements', () => {
    expect(COMMS.messages.length).toBeGreaterThan(0);
    expect(COMMS.announcements.length).toBeGreaterThan(0);
  });

  it('has both read and unread messages, so the badge is not always zero', () => {
    expect(COMMS.messages.some((m) => m.readAt === null)).toBe(true);
    expect(COMMS.messages.some((m) => m.readAt !== null)).toBe(true);
  });

  it('only ever references real users', () => {
    const ids = new Set(USERS.map((u) => u.id));
    for (const message of COMMS.messages) {
      expect(ids.has(message.senderId)).toBe(true);
      if (message.recipientId !== null) expect(ids.has(message.recipientId)).toBe(true);
    }
    for (const announcement of COMMS.announcements) {
      expect(ids.has(announcement.authorId)).toBe(true);
    }
  });

  it('never dates a message in the future', () => {
    for (const message of COMMS.messages) {
      expect(message.createdAt.getTime()).toBeLessThanOrEqual(ANCHOR.getTime());
    }
  });

  it('is authored by managers, addressed to agents', () => {
    const managerIds = new Set(USERS.filter((u) => u.role === 'manager').map((u) => u.id));
    expect(COMMS.announcements.every((a) => managerIds.has(a.authorId))).toBe(true);
  });

  it('is deterministic', () => {
    const again = buildComms({ anchor: ANCHOR, users: USERS });
    expect(again.messages.map((m) => m.body)).toEqual(COMMS.messages.map((m) => m.body));
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest scripts/seed/comms.test.ts --runInBand`
Expected: FAIL — `Cannot find module './comms'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/scripts/seed/comms.ts`:

```ts
import { addDays, addHours } from './calendar';
import { UserSeed } from './catalog';
import { makeRng, pick } from './rng';

/** Manager-to-agent messages and company announcements (Phase 3 #37). */

export interface GeneratedMessage {
  id: string;
  senderId: string;
  recipientId: string | null;
  body: string;
  readAt: Date | null;
  createdAt: Date;
}

export interface GeneratedAnnouncement {
  id: string;
  authorId: string;
  title: string;
  body: string;
  createdAt: Date;
}

export interface CommsBundle {
  messages: GeneratedMessage[];
  announcements: GeneratedAnnouncement[];
}

const MESSAGE_BODIES = [
  'Morning — please prioritise the end-cap rebuild at your first two stops today.',
  'Thanks for closing the price tags at Sandton, the photo came through clearly.',
  'Heads up: the promo POSM shipment lands Thursday, hold the wobblers until then.',
  'Your scorecard average is up 6 points this month. Nicely done.',
  'Can you re-check the back-stock at the Fourways store? Numbers look off.',
  'Please confirm you have the updated planogram before your Wednesday run.',
];

const ANNOUNCEMENTS = [
  {
    title: 'Q3 Perfect Store push is live',
    body: 'Every store scored 80 or above this quarter earns the team an R500 airtime voucher. Photograph every end-cap rebuild — verified closures are what count.',
  },
  {
    title: 'New planogram effective Monday',
    body: 'The revised carbonates planogram moves the 2L range to eye level. Download it in the app before your first call and flag any store that cannot comply.',
  },
];

export function buildComms(input: { anchor: Date; users: UserSeed[] }): CommsBundle {
  const { anchor, users } = input;
  const rng = makeRng(31415926);

  const managers = users.filter((u) => u.role === 'manager');
  const agents = users.filter((u) => u.role === 'field_agent');

  const messages: GeneratedMessage[] = MESSAGE_BODIES.map((body, index) => ({
    id: `demo-message-${index + 1}`,
    senderId: pick(rng, managers).id,
    recipientId: pick(rng, agents).id,
    body,
    // The two most recent stay unread so the badge is non-zero in a demo.
    readAt: index < MESSAGE_BODIES.length - 2 ? addHours(anchor, -index * 6) : null,
    createdAt: addHours(addDays(anchor, -index), -index * 3),
  }));

  const announcements: GeneratedAnnouncement[] = ANNOUNCEMENTS.map((entry, index) => ({
    id: `demo-announcement-${index + 1}`,
    authorId: pick(rng, managers).id,
    title: entry.title,
    body: entry.body,
    createdAt: addDays(anchor, -(index * 5 + 2)),
  }));

  return { messages, announcements };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest scripts/seed/comms.test.ts --runInBand`
Expected: PASS, 6 tests

- [ ] **Step 5: Commit**

```bash
git add backend/scripts/seed/comms.ts backend/scripts/seed/comms.test.ts
git commit -m "feat(seed): manager-agent messages and announcements"
```

---

### Task 9: Orchestration and the entrypoint

**Files:**
- Create: `backend/scripts/seed/index.ts`
- Modify: `backend/scripts/seed.ts` (replace entirely)

This task has no new unit test — it is wiring, and Task 10 proves it end-to-end
against a real database.

- [ ] **Step 1: Write the orchestrator**

Create `backend/scripts/seed/index.ts`:

```ts
import { PrismaClient, Prisma, TaskPriority, TaskStatus } from '@prisma/client';
import { hashPassword } from '../../src/modules/auth/auth.service';
import { addDays, HISTORY_WEEKS, startOfUtcDay } from './calendar';
import {
  DEMO_CLIENT_ID,
  DEMO_PASSWORD,
  HOME_OUTLET_ID,
  SKUS,
  TERRITORIES,
  USERS,
  buildOutlets,
  homeCoordinates,
} from './catalog';
import { buildComms } from './comms';
import { ALERT_RULE_IDS, buildOps } from './ops';
import { SECTION_TINTS, demoPhotoDataUrl } from './photos';
import { resetDemoData } from './reset';
import { buildVisitHistory } from './visits';

const GEOFENCE_RADIUS_M = 50;

export async function seedDemoData(prisma: PrismaClient): Promise<void> {
  if (process.env.NODE_ENV === 'production' && !process.argv.includes('--force')) {
    throw new Error(
      'Refusing to seed with NODE_ENV=production. This deletes and rebuilds the demo ' +
        'client\'s data. Pass --force if that is genuinely what you want.',
    );
  }

  const anchor = startOfUtcDay(new Date());
  const home = homeCoordinates();
  const outlets = buildOutlets(home);
  const agents = USERS.filter((u) => u.role === 'field_agent');

  // Hash once: bcrypt at cost 10 is deliberately slow, and all demo accounts
  // share a password.
  const passwordHash = await hashPassword(DEMO_PASSWORD);

  const [visibilityPhoto, pricingPhoto, competitivePhoto, closurePhoto] = await Promise.all([
    demoPhotoDataUrl(SECTION_TINTS.visibility!),
    demoPhotoDataUrl(SECTION_TINTS.pricing!),
    demoPhotoDataUrl(SECTION_TINTS.competitive!),
    demoPhotoDataUrl(SECTION_TINTS.closure!),
  ]);
  const sectionPhotos = [visibilityPhoto, pricingPhoto, competitivePhoto];

  const visits = buildVisitHistory({ anchor, outlets, agents, skus: SKUS });
  const ops = buildOps({ anchor, visits, outlets, agents, closurePhotoUrl: closurePhoto });
  const comms = buildComms({ anchor, users: USERS });

  await resetDemoData(prisma, DEMO_CLIENT_ID);

  await prisma.client.upsert({
    where: { id: DEMO_CLIENT_ID },
    update: {},
    create: {
      id: DEMO_CLIENT_ID,
      name: 'Kalahari Beverages',
      industry: 'FMCG',
      scorecardWeights: {
        availability: 0.3,
        visibility: 0.25,
        display: 0.15,
        pricing: 0.1,
        salesCapability: 0.1,
        competitive: 0.1,
      },
      // The four keys the engine actually reads (#46).
      kpiThresholds: { green: 80, amber: 60, stockoutUnits: 0, priceDeviationPct: 10 },
    },
  });

  await prisma.user.createMany({
    data: USERS.map((user) => ({
      id: user.id,
      email: user.email,
      passwordHash,
      role: user.role,
      clientId: DEMO_CLIENT_ID,
    })),
  });

  await prisma.territory.createMany({
    data: TERRITORIES.map((t) => ({
      id: t.id,
      clientId: DEMO_CLIENT_ID,
      name: t.name,
      code: t.code,
      region: t.region,
    })),
  });

  await prisma.userTerritory.createMany({
    data: agents.map((agent) => ({
      userId: agent.id,
      territoryId: agent.territoryId!,
    })),
  });

  await prisma.sku.createMany({
    data: SKUS.map((sku) => ({ ...sku, clientId: DEMO_CLIENT_ID })),
  });

  await prisma.outlet.createMany({
    data: outlets.map((outlet) => ({ ...outlet, clientId: DEMO_CLIENT_ID })),
  });

  await prisma.promoCalendar.create({
    data: {
      id: 'demo-promo-1',
      clientId: DEMO_CLIENT_ID,
      promoName: 'Winter Warmer Multibuy',
      activeFrom: addDays(anchor, -30),
      activeTo: addDays(anchor, 30),
      requiredPosm: { poster: true, shelfStrip: true, wobbler: true },
      outletScope: { all: true },
      discountType: 'percent',
      discountValue: 15,
      skuScope: { skuIds: SKUS.slice(0, 4).map((s) => s.id) },
    },
  });

  await prisma.alertRule.createMany({
    data: [
      { id: ALERT_RULE_IDS.outOfStock, clientId: DEMO_CLIENT_ID, name: 'Out of stock', metric: 'out_of_stock', threshold: 0, severity: 'high', active: true },
      { id: ALERT_RULE_IDS.priceDeviation, clientId: DEMO_CLIENT_ID, name: 'Price deviation', metric: 'price_deviation', threshold: 10, severity: 'normal', active: true },
      { id: ALERT_RULE_IDS.lowScorecard, clientId: DEMO_CLIENT_ID, name: 'Low execution score', metric: 'low_scorecard', threshold: 60, severity: 'high', active: true },
    ],
  });

  // Visits and their children. createMany per table rather than a nested create
  // per visit: ~350 visits x 12 child rows is 4000+ rows, and one round trip per
  // row makes the seed take minutes instead of seconds.
  await prisma.visit.createMany({
    data: visits.map((v) => ({
      id: v.id,
      outletId: v.outletId,
      agentId: v.agentId,
      clientId: DEMO_CLIENT_ID,
      checkinTs: v.checkinTs,
      checkinLat: v.checkinLat,
      checkinLng: v.checkinLng,
      checkinDistanceM: v.checkinDistanceM,
      geofencePass: v.geofencePass,
      status: 'submitted' as const,
      submittedAtClient: v.checkinTs,
    })),
  });

  await prisma.visitStock.createMany({
    data: visits.flatMap((v) => v.stock.map((row) => ({ ...row, visitId: v.id }))),
  });

  await prisma.visitPricing.createMany({
    data: visits.flatMap((v) => v.pricing.map((row) => ({ ...row, visitId: v.id }))),
  });

  await prisma.visitCompetitive.createMany({
    data: visits.flatMap((v) =>
      v.competitive.map((row) => ({
        ...row,
        visitId: v.id,
        geotag: row.geotag as Prisma.InputJsonValue,
      })),
    ),
  });

  await prisma.visitVisibility.createMany({
    data: visits.map((v) => ({
      visitId: v.id,
      brandingElements: v.visibility.brandingElements as Prisma.InputJsonValue,
      planogramCompliancePct: v.visibility.planogramCompliancePct,
      facingsCount: v.visibility.facingsCount as Prisma.InputJsonValue,
      highTrafficPass: v.visibility.highTrafficPass,
      cleanlinessScore: v.visibility.cleanlinessScore,
      createdAt: v.visibility.createdAt,
    })),
  });

  await prisma.visitCapability.createMany({
    data: visits.map((v) => ({
      visitId: v.id,
      staffHeadcountConfirmed: v.capability.staffHeadcountConfirmed,
      repTrainingStatus: v.capability.repTrainingStatus as Prisma.InputJsonValue,
      quizScore: v.capability.quizScore,
      createdAt: v.capability.createdAt,
    })),
  });

  await prisma.scorecard.createMany({
    data: visits.map((v) => ({
      visitId: v.id,
      dimensionScores: v.scorecard.dimensionScores as Prisma.InputJsonValue,
      weightedTotal: v.scorecard.weightedTotal,
      ratingBand: v.scorecard.ratingBand,
      // The #204 fix: explicit, equal to the visit time. /trends buckets on this.
      createdAt: v.scorecard.createdAt,
    })),
  });

  await prisma.photo.createMany({
    data: visits.map((v, index) => ({
      visitId: v.id,
      section: ['visibility', 'pricing', 'competitive'][index % 3]!,
      // Real decodable JPEGs (#209) — the old seed's demo.tradeiq.local URLs 422'd.
      url: sectionPhotos[index % 3]!,
      gpsTag: { lat: v.checkinLat, lng: v.checkinLng } as Prisma.InputJsonValue,
      timestamp: v.checkinTs,
      createdAt: v.checkinTs,
    })),
  });

  await prisma.checkInAttempt.createMany({
    data: visits.map((v) => ({
      clientId: DEMO_CLIENT_ID,
      outletId: v.outletId,
      agentId: v.agentId,
      lat: v.checkinLat,
      lng: v.checkinLng,
      distanceM: v.checkinDistanceM,
      passed: true,
      createdAt: v.checkinTs,
    })),
  });

  // A handful of rejected attempts — the negative signal the fraud engine exists
  // for, and a screen that is otherwise entirely empty.
  await prisma.checkInAttempt.createMany({
    data: visits.slice(0, 6).map((v) => ({
      clientId: DEMO_CLIENT_ID,
      outletId: v.outletId,
      agentId: v.agentId,
      lat: v.checkinLat + 0.004,
      lng: v.checkinLng + 0.004,
      distanceM: 610,
      passed: false,
      createdAt: addDays(v.checkinTs, -1),
    })),
  });

  await prisma.task.createMany({
    data: ops.tasks.map((task) => ({
      id: task.id,
      visitId: task.visitId,
      findingType: task.findingType,
      outletId: task.outletId,
      requiredFix: task.requiredFix,
      priority: task.priority as TaskPriority,
      slaDueAt: task.slaDueAt,
      ownerId: task.ownerId,
      status: task.status as TaskStatus,
      closurePhotoUrl: task.closurePhotoUrl ?? null,
      closureVerified: task.closureVerified,
      createdAt: task.createdAt,
    })),
  });

  await prisma.alert.createMany({
    data: ops.alerts.map((alert) => ({
      id: alert.id,
      clientId: DEMO_CLIENT_ID,
      ruleId: alert.ruleId,
      visitId: alert.visitId,
      outletId: alert.outletId,
      metric: alert.metric,
      message: alert.message,
      severity: alert.severity,
      acknowledged: alert.acknowledged,
      createdAt: alert.createdAt,
    })),
  });

  await prisma.incentiveScheme.createMany({
    data: ops.incentiveSchemes.map((scheme) => ({ ...scheme, clientId: DEMO_CLIENT_ID })),
  });

  await prisma.message.createMany({
    data: comms.messages.map((m) => ({ ...m, clientId: DEMO_CLIENT_ID })),
  });

  await prisma.announcement.createMany({
    data: comms.announcements.map((a) => ({ ...a, clientId: DEMO_CLIENT_ID })),
  });

  // Today's beat plan for the demo agent, opening with the home-base outlet so
  // the live geofence check-in is the natural next action.
  const demoAgent = agents[0]!;
  const gautengOutlets = outlets.filter((o) => o.territoryId === 'demo-territory-gp');
  const stopOutlets = [
    outlets.find((o) => o.id === HOME_OUTLET_ID)!,
    ...gautengOutlets.filter((o) => o.id !== HOME_OUTLET_ID).slice(0, 4),
  ];

  await prisma.beatPlan.create({
    data: {
      id: 'demo-beatplan-today',
      clientId: DEMO_CLIENT_ID,
      agentId: demoAgent.id,
      territoryId: 'demo-territory-gp',
      name: "Today's route",
      scheduledDate: anchor,
      status: 'in_progress',
      stops: {
        create: stopOutlets.map((outlet, index) => ({
          outletId: outlet.id,
          sequence: index + 1,
          visited: false,
        })),
      },
    },
  });

  await prisma.campaign.create({
    data: {
      id: 'demo-campaign-1',
      clientId: DEMO_CLIENT_ID,
      name: 'Winter Warmer Activation',
      objective: 'Drive multibuy visibility across the top 20 outlets by ACV.',
      startDate: addDays(anchor, -30),
      endDate: addDays(anchor, 30),
      budget: 250000,
      status: 'active',
      outlets: {
        create: outlets.slice(0, 20).map((outlet) => ({ outletId: outlet.id })),
      },
    },
  });

  const template = await prisma.auditTemplate.create({
    data: {
      id: 'demo-audit-template-1',
      clientId: DEMO_CLIENT_ID,
      name: 'FMCG Standard Store Audit',
      industry: 'FMCG',
      version: 1,
      active: true,
      schema: {
        sections: [
          { key: 's2_stock', label: 'Stock & Availability', fields: ['unitsAvailable', 'daysOutOfStock'] },
          { key: 's3_visibility', label: 'Visibility & Display', fields: ['planogramCompliancePct', 'cleanlinessScore'] },
          { key: 's5_pricing', label: 'Pricing & Promotions', fields: ['priceActual', 'promoActive'] },
        ],
        scoring: { availability: 0.3, visibility: 0.25, display: 0.15, pricing: 0.1, competitive: 0.1, salesCapability: 0.1 },
      } as Prisma.InputJsonValue,
    },
  });

  await prisma.visitTemplateResponse.createMany({
    data: visits.slice(0, 25).map((v) => ({
      visitId: v.id,
      templateId: template.id,
      templateVersion: 1,
      answers: {
        s2_stock: { unitsAvailable: v.stock[0]?.unitsAvailable ?? 0, daysOutOfStock: v.stock[0]?.daysOutOfStock ?? 0 },
        s3_visibility: { planogramCompliancePct: v.visibility.planogramCompliancePct, cleanlinessScore: v.visibility.cleanlinessScore },
        s5_pricing: { priceActual: v.pricing[0]?.priceActual ?? 0, promoActive: v.pricing[0]?.promoActive ?? false },
      } as Prisma.InputJsonValue,
      createdAt: v.checkinTs,
    })),
  });

  // In-store orders on the most recent visits.
  for (const visit of visits.slice(-15)) {
    const lines = SKUS.slice(0, 3).map((sku) => ({
      skuId: sku.id,
      quantity: 12,
      unitPrice: sku.rrp,
    }));
    await prisma.order.create({
      data: {
        clientId: DEMO_CLIENT_ID,
        outletId: visit.outletId,
        agentId: visit.agentId,
        visitId: visit.id,
        status: 'submitted',
        total: lines.reduce((sum, l) => sum + l.quantity * l.unitPrice, 0),
        createdAt: visit.checkinTs,
        lines: { create: lines },
      },
    });
  }

  const openTasks = ops.tasks.filter((t) => t.status === 'open').length;
  const openAlerts = ops.alerts.filter((a) => !a.acknowledged).length;

  console.log(
    [
      `Seeded ${'Kalahari Beverages'} — ${HISTORY_WEEKS} weeks of history ending today`,
      `sign in with any of: ${USERS.map((u) => u.email).join(', ')}`,
      `password: ${DEMO_PASSWORD}`,
      `${outlets.length} outlets, ${SKUS.length} SKUs, ${visits.length} visits`,
      `${ops.tasks.length} tasks (${openTasks} open), ${ops.alerts.length} alerts (${openAlerts} unacknowledged)`,
      `${comms.messages.length} messages, ${comms.announcements.length} announcements`,
    ].join('\n'),
  );

  console.log(
    [
      '',
      'Home-base outlet (live geofence check-in):',
      `  coordinates: ${home.lat}, ${home.lng} (${home.source === 'env' ? 'from DEMO_HOME_LAT/DEMO_HOME_LNG' : 'FALLBACK — set DEMO_HOME_LAT/DEMO_HOME_LNG to use your own'})`,
      `  geofence radius: ${GEOFENCE_RADIUS_M}m — check-in is REJECTED outside it, not merely flagged.`,
      '  Indoor GPS drifts 20-50m, so verify a check-in before demoing rather than during.',
    ].join('\n'),
  );
}
```

- [ ] **Step 2: Replace the entrypoint**

Replace the entire contents of `backend/scripts/seed.ts` with:

```ts
// backend/scripts/seed.ts
import { PrismaClient } from '@prisma/client';
import { seedDemoData } from './seed';

const prisma = new PrismaClient();

seedDemoData(prisma)
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

**Note:** `./seed` resolves to `backend/scripts/seed/index.ts`. If Node resolves
it to the script itself and recurses, change the import to `./seed/index`.

- [ ] **Step 3: Typecheck and lint**

Run: `cd backend && npx tsc --noEmit && npm run lint`
Expected: no errors

- [ ] **Step 4: Run the whole seed unit suite**

Run: `cd backend && npx jest scripts/seed --runInBand`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/scripts/seed/index.ts backend/scripts/seed.ts
git commit -m "feat(seed): orchestrate the realistic demo dataset"
```

---

### Task 10: End-to-end proof against a real database (#204, #209)

**Files:**
- Create: `backend/scripts/seed/seed.e2e.test.ts`

The unit tests prove the generators. This proves the thing the tickets actually
claim: that after seeding, `/trends` returns multiple weekly points and every
stored photo thumbnails.

- [ ] **Step 1: Write the failing test**

Create `backend/scripts/seed/seed.e2e.test.ts`:

```ts
import { PrismaClient } from '@prisma/client';
import { getThumbnailForPhoto } from '../../src/modules/photos/thumbnails';
import {
  getAvailabilityTrend,
  getScorecardsTrend,
} from '../../src/modules/trends/trends.service';
import { DEMO_CLIENT_ID } from './catalog';
import { seedDemoData } from './index';
import { resetDemoData } from './reset';

const prisma = new PrismaClient();

// Seeding writes several thousand rows; the default 20s timeout is not enough.
jest.setTimeout(180_000);

describe('seedDemoData (end to end)', () => {
  beforeAll(async () => {
    await seedDemoData(prisma);
  });

  afterAll(async () => {
    await resetDemoData(prisma, DEMO_CLIENT_ID);
    await prisma.client.deleteMany({ where: { id: DEMO_CLIENT_ID } });
    await prisma.$disconnect();
  });

  it('writes the expected shape of dataset', async () => {
    expect(await prisma.outlet.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(25);
    expect(await prisma.visit.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(250);
    expect(await prisma.scorecard.count({ where: { visit: { clientId: DEMO_CLIENT_ID } } })).toBeGreaterThan(250);
  });

  // #204: the dashboard hero showed "Not enough data to plot" because every
  // scorecard landed in one weekly bucket. LineChart needs >= 2 points.
  it('produces many weekly trend buckets, not one', async () => {
    const filters = { clientId: DEMO_CLIENT_ID, interval: 'week' as const };
    const scorecards = await getScorecardsTrend(filters);
    const availability = await getAvailabilityTrend(filters);
    expect(scorecards.points.length).toBeGreaterThanOrEqual(3);
    expect(availability.points.length).toBeGreaterThanOrEqual(3);
  });

  it('trends climb from the first bucket to the last', async () => {
    const scorecards = await getScorecardsTrend({
      clientId: DEMO_CLIENT_ID,
      interval: 'week',
    });
    const points = scorecards.points;
    const first = points[0]!.value;
    const last = points[points.length - 1]!.value;
    expect(last).toBeGreaterThan(first);
  });

  // #209: seeded photos rendered as grey boxes because the stored URLs 422'd.
  it('stores photos the thumbnail endpoint can actually decode', async () => {
    const photos = await prisma.photo.findMany({
      where: { visit: { clientId: DEMO_CLIENT_ID } },
      take: 5,
      select: { id: true, url: true },
    });
    expect(photos.length).toBe(5);

    for (const photo of photos) {
      const thumb = await getThumbnailForPhoto(photo.id, async () => photo.url);
      expect(thumb.length).toBeGreaterThan(0);
      expect(thumb[0]).toBe(0xff);
      expect(thumb[1]).toBe(0xd8);
    }
  });

  it('leaves open alerts and overdue tasks for the demo to act on', async () => {
    expect(await prisma.alert.count({ where: { clientId: DEMO_CLIENT_ID, acknowledged: false } })).toBeGreaterThan(0);
    expect(await prisma.task.count({
      where: { outlet: { clientId: DEMO_CLIENT_ID }, status: 'open', slaDueAt: { lt: new Date() } },
    })).toBeGreaterThan(0);
  });

  it('gives today a beat plan with stops', async () => {
    const plan = await prisma.beatPlan.findFirst({
      where: { clientId: DEMO_CLIENT_ID },
      include: { stops: true },
    });
    expect(plan).not.toBeNull();
    expect(plan!.stops.length).toBeGreaterThan(0);
  });

  it('fills every screen the walkthrough visits', async () => {
    expect(await prisma.message.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(0);
    expect(await prisma.announcement.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(0);
    expect(await prisma.order.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(0);
    expect(await prisma.incentiveScheme.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(0);
    expect(await prisma.checkInAttempt.count({ where: { clientId: DEMO_CLIENT_ID, passed: false } })).toBeGreaterThan(0);
    expect(await prisma.visitTemplateResponse.count({ where: { visit: { clientId: DEMO_CLIENT_ID } } })).toBeGreaterThan(0);
  });

  it('is safe to run twice — the second run replaces rather than duplicates', async () => {
    const before = await prisma.visit.count({ where: { clientId: DEMO_CLIENT_ID } });
    await seedDemoData(prisma);
    const after = await prisma.visit.count({ where: { clientId: DEMO_CLIENT_ID } });
    expect(after).toBe(before);
  });
});
```

- [ ] **Step 2: Run test to verify it fails, then passes**

Run: `cd backend && npx jest scripts/seed/seed.e2e.test.ts --runInBand`
Expected: PASS, 8 tests.

There is no aggregate `getTrends` — the service exports one function per series
(`getScorecardsTrend`, `getAvailabilityTrend`, `getPerfectStoreTrend`,
`getShareOfShelfTrend`), each taking a `TrendFilters` of
`{ clientId, interval, from?, to? }`. The test above already uses that shape.

- [ ] **Step 3: Run the full backend suite**

Run: `cd backend && npx jest --runInBand`
Expected: PASS. If a suite fails, re-run it in isolation before believing it —
the full run is known-flaky under load (#186).

- [ ] **Step 4: Seed a real dev database and eyeball it**

Run: `cd backend && npm run seed`
Expected: the summary block, ending with the home-base coordinates and the 50m
geofence warning.

- [ ] **Step 5: Commit**

```bash
git add backend/scripts/seed/seed.e2e.test.ts
git commit -m "test(seed): end-to-end proof of trend buckets and photo decoding (#204, #209)"
```

---

### Task 11: Documentation and issue closure

**Files:**
- Modify: `backend/.env.example` (or create if absent)
- Modify: `docs/ROADMAP.md`

- [ ] **Step 1: Document the home-base env vars**

Run: `cd backend && ls -la .env.example 2>/dev/null || echo "absent"`

If present, append; if absent, create `backend/.env.example` containing at least:

```bash
# Optional: seeds the demo "home base" outlet at your own location so a live
# geofence check-in can be demonstrated. Both must be set to take effect.
# The geofence is 50m and check-in is REJECTED outside it, so use precise
# coordinates. Unset, the seed falls back to a generic Johannesburg point.
DEMO_HOME_LAT=
DEMO_HOME_LNG=
```

- [ ] **Step 2: Update the roadmap**

In `docs/ROADMAP.md`, find the line listing the seed under Phase 1:

```
| Seed: client/users/outlets/SKUs/planograms/promos/demo visits+scorecards+tasks+**admin** | ✅ |
```

Replace it with:

```
| Seed: realistic demo dataset — 3 territories, ~31 outlets, 9 users, 20 SKUs, 12 weeks of visit history (~350 visits), tasks/alerts/incentives, comms, orders, and a home-base outlet for live geofence check-in | ✅ |
```

- [ ] **Step 3: Verify the whole thing once more**

Run: `cd backend && npx tsc --noEmit && npm run lint && npx jest scripts/seed --runInBand`
Expected: all clean

- [ ] **Step 4: Commit**

```bash
git add backend/.env.example docs/ROADMAP.md
git commit -m "docs: document DEMO_HOME_LAT/LNG and the new seed dataset"
```

- [ ] **Step 5: Open the PR**

```bash
git push -u origin feat/realistic-demo-seed
gh pr create --title "feat(seed): realistic demo dataset for live walkthroughs" --body "Closes #204. Closes #209.

Replaces the 824-line demo-toy seed (22/34 models, 3 outlets, 3 visits, all literals) with a coherent ~31-outlet, 12-week dataset built for a sales walkthrough.

See docs/superpowers/specs/2026-07-28-realistic-demo-seed-design.md."
```

- [ ] **Step 6: Re-check #207**

#207 (broken thumbnail looks identical to loading) was filed because demo-seed
placeholder URLs rendered grey boxes. No seeded photo can now fail to decode.
Re-read the ticket and either close it as resolved, or leave it open with a
comment explaining what still reproduces. **Do not close it without checking.**

---

## Verification checklist

- [ ] `npx tsc --noEmit` clean
- [ ] `npm run lint` clean
- [ ] `npx jest scripts/seed --runInBand` — all seed suites pass
- [ ] `npx jest --runInBand` — full backend suite passes (re-run failures in isolation, #186)
- [ ] `npm run seed` against a dev database completes and prints the home-base block
- [ ] The Flutter dashboard shows a plotted trend line, not "Not enough data to plot"
- [ ] Evidence thumbnails render as images, not grey boxes
- [ ] #204 and #209 closed; #207 re-checked and dispositioned
