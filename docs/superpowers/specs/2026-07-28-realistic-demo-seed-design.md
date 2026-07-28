# Realistic demo seed — design

**Date:** 2026-07-28
**Status:** approved, not yet implemented
**Closes:** #204, #209 (and very likely makes #207 moot)

## Why

`backend/scripts/seed.ts` (824 lines) was written to make a handful of endpoints
return non-empty, not to model a business. It shows:

- **22 of 34 models seeded.** `Alert` instances, `Order`/`OrderLine`, `Message`,
  `Announcement`, `CheckInAttempt`, `VisitTemplateResponse`, `IncentiveScheme`,
  `Webhook`, `ReportDefinition`, `ReportSchedule` have never had a single row, so
  whole screens render their empty state during a walkthrough.
- **Toy volume.** 1 client, 3 users, 3 outlets, 4 SKUs, 3 visits — every row a
  hand-written literal.
- **Two open bugs that are really symptoms of the above.** #204 (trends collapse
  to one weekly bucket) and #209 (photo URLs 422 on thumbnail).

The two bugs are worth understanding precisely, because they drive design
decisions below:

**#204 is not "the visits are too close together".** `/trends` buckets on each
row's *own* `createdAt` (`trends.service.ts` — `buildSeries` keyed by
`bucketStart(getDate(row))`), and the seed never sets `createdAt` on `Scorecard`
or `VisitStock`. Those columns are `@default(now())`, so every row gets
*insert* time regardless of its visit's `checkinTs`. Backdating `checkinTs`
alone would change nothing. Both halves are required: set `createdAt`
explicitly, *and* spread the visits across weeks.

**#209** is simpler: `Photo.url` must match
`/^data:image\/[a-z0-9.+-]+;base64,(...)$/` for `getThumbnailForPhoto` to decode
it. The seed writes `https://demo.tradeiq.local/...`, which correctly 422s.

## Purpose and scope

Decided with the user:

| Question | Decision |
|---|---|
| What is the seed for? | **Live demo / sales walkthrough.** Coherence and narrative beat volume. |
| How big? | **Mid** — ~30 outlets, 6 agents, ~12 weeks, ~360 visits. |
| Dates and repeatability? | **Fixed shapes, dates relative to run day.** |
| What story? | **Improving, with a live problem tail.** |
| Fill which empty areas? | Manager ops, field-agent flow, comms. **Not** integrations/admin. |

## Architecture

A small package replaces the single script. Each module has one purpose and can
be tested without a database.

```
backend/scripts/seed/
  rng.ts         seeded PRNG (mulberry32) — fixed SEED, every value reproducible
  calendar.ts    run-day anchor + week maths; all timestamps derive from one anchor
  catalog.ts     hand-authored reference data: client, users, territories, outlets, SKUs
  photos.ts      real JPEG data URLs via sharp (raw pixels, no font dependency)
  visits.ts      12-week visit history + the improving-score curve
  ops.ts         tasks, alerts, incentive scheme + standings
  comms.ts       messages, announcements
  reset.ts       FK-safe teardown, scoped to the demo client
  index.ts       orchestration + the summary line
```

`backend/scripts/seed.ts` becomes a thin entrypoint that calls
`seed/index.ts`, so `npm run seed` is unchanged.

### Determinism

A fixed `SEED` constant drives a mulberry32 PRNG. Every generated value —
scores, unit counts, prices, names drawn from lists — is byte-identical run to
run. A bug seen in a demo can always be recreated.

Only *dates* move. A single `anchor` (UTC start of the seed-run day) is the
origin for all 12 weeks of history, so the demo always looks current: "today"
has stops, SLAs are believably due, and the trend chart ends at this week.

This deliberately replaces the current file's rule ("no `Date.now()`/`new
Date()` with no args that would drift between runs"). That rule bought
idempotency; we are trading it for a demo that does not rot. The reproducibility
it protected is preserved by the PRNG instead.

### Reset, not upsert

Relative dates make `upsert(where: {id}, update: {})` meaningless — a second run
would leave the previous run's rows fossilised at their old dates while adding
new ones. `reset.ts` deletes then rebuilds.

**`npm run seed` always resets first.** There is no additive mode. Making reset
opt-in would leave the default path producing exactly the fossilised-dates
problem described above, which is the failure this design exists to prevent.

Safety constraints, in order of importance:

1. **Scoped to the demo client id.** Deletion is always `where: { clientId:
   DEMO_CLIENT_ID }` (or a join to it), never a bare `deleteMany({})`. It can
   never touch another tenant's data.
2. **FK-safe order.** Children before parents, explicitly ordered.
3. **Refuses to run when `NODE_ENV=production`** unless `--force` is passed.

## The dataset

| | |
|---|---|
| **Org** | 1 client, 3 territories (Gauteng / Western Cape / KZN), 9 users — 1 admin, 2 managers, 6 field agents |
| **Retail** | ~30 outlets across the 3 regions (one of them the home-base outlet, below), ~20 SKUs, ZAR pricing, invented-but-plausible chain names |
| **History** | ~12 weeks, ~360 visits (6 agents × ~5/week), each with full S1–S10 section rows |
| **Live** | today's beat plan with real stops, open alerts, overdue SLA tasks, an active incentive scheme with standings |

**Names must be invented.** Plausible South African retail chains and outlet
names, ZAR pricing, SA address and phone formats — but no real company
trademarks. The existing seed's Johannesburg framing (Sandton, Rosebank) is
kept and extended.

### The home-base outlet

One extra outlet is seeded at the demonstrator's own physical location, so a
live walkthrough can include a **real geofence check-in** — walk in, open the
app, check in for real — rather than a simulated one. It is the only part of the
field-agent flow that cannot otherwise be shown honestly.

**Coordinates come from `DEMO_HOME_LAT` / `DEMO_HOME_LNG`**, read from the local
environment, falling back to a generic Johannesburg point when unset. The
demonstrator's real location therefore never enters git, and re-pointing it for a
different venue is an `.env` edit rather than a code change. The fallback keeps a
fresh clone seeding the full outlet count.

The outlet is otherwise a normal member of the dataset — it belongs to a
territory, carries visit history, and appears in lists — so it does not read as a
test artefact. It is given a plausible name and assigned to the agent account the
demonstrator signs in as, and it appears on **today's** beat plan so the check-in
is the natural next action rather than something hunted for.

**Known risk, to be stated plainly in the seed's output.** The geofence is 50 m
(`isWithinGeofence`, hardcoded default — `Outlet` has no per-store radius), and
`visits.service.ts` *throws* `GeofenceRejectedError` outside it, so check-in is
blocked rather than flagged. Indoor GPS routinely drifts 20–50 m, which means a
live check-in can legitimately fail in front of an audience through no fault of
the software. Two things follow:

1. The seed prints the configured home coordinates and the 50 m radius on
   completion, so the setup is verifiable before the demo rather than during it.
2. A rejected check-in still writes a `CheckInAttempt` row, so the failure path
   is itself demonstrable — "the system refuses check-ins from outside the
   store, and records the attempt" is a feature, not a save. Worth knowing in
   advance rather than improvising.

Widening the radius is deliberately *not* proposed here: it would weaken a real
fraud control for a presentation convenience.

### The curve

Weekly mean execution score climbs **~62 → ~78** across the 12 weeks. On top of
that:

- **Weekly noise** from the PRNG, so the line is not suspiciously smooth.
- **A fixed per-outlet offset**, so outlets rank consistently rather than
  shuffling week to week.
- **Four outlets carry a permanent negative offset.** They stay red for the
  whole 12 weeks, and they are the ones carrying the open alerts, stockouts,
  price deviations and overdue SLA tasks.

That last point is the demo's spine: the trend line proves ROI while the problem
tail guarantees the rep always has something real to click into. The two must be
generated together — the red outlets are not decoration sprinkled on afterwards.

### How the two bugs are fixed

- **#204** — every `Scorecard` and `VisitStock` row gets an explicit `createdAt`
  set to its visit's timestamp. Combined with 12 weeks of spread, `/trends`
  returns ~12 weekly buckets and the dashboard hero plots a real line.
  (`LineChart` needs `points.length >= 2`; today it gets 1.)
- **#209** — `photos.ts` generates real JPEGs from raw pixel buffers via sharp
  and encodes them as `data:image/jpeg;base64,...`. Raw pixels rather than SVG
  text, deliberately: SVG text rendering needs librsvg with working fontconfig,
  which is not guaranteed in CI. Each section gets a distinct hue so demo rows
  look different from one another.
- **#207** (broken-thumb looks like loading) is expected to become moot, since
  no seeded photo will fail to decode. It should be re-checked and closed rather
  than built, once this lands.

## Testing

The point of the package split is that the interesting logic is testable without
a database:

- `rng.ts` — same seed produces the same sequence; different seeds diverge.
- `calendar.ts` — 12 weeks back from an injected anchor yields 12 distinct
  weekly buckets; week boundaries are Monday UTC, matching `bucketStart` in
  `trends.service.ts`.
- `visits.ts` — the generated series is monotonic in trend (first-3-week mean is
  materially below last-3-week mean), the four problem outlets are always in the
  bottom band, and every generated `Scorecard`/`VisitStock` carries a
  `createdAt` matching its visit.
- `photos.ts` — every generated URL is accepted by the real
  `getThumbnailForPhoto` and returns a decodable JPEG buffer. This is the guard
  that actually pins #209, because it runs the production decoder rather than a
  reimplementation of its regex.
- `reset.ts` — deletion is scoped: rows belonging to a second, non-demo client
  survive a reset. This is the safety-critical test.
- `catalog.ts` — the home-base outlet uses `DEMO_HOME_LAT`/`DEMO_HOME_LNG` when
  both are set and valid, falls back when unset, and does not silently accept a
  malformed value (a non-numeric or out-of-range coordinate must fail loudly,
  not quietly seed a store in the Gulf of Guinea).

To test bucketing against the real production logic rather than a copy,
`bucketStart` will be exported from `trends.service.ts`.

An end-to-end check (seed a test database, hit `/trends`, assert ≥3 weekly
points) is the honest proof for #204 and should be included.

## Deliberately out of scope

- **`Webhook`, `ReportDefinition`, `ReportSchedule` stay unseeded.** The user
  excluded integrations/admin. Consequence to accept knowingly: the reports
  screen will show its empty state during a walkthrough. Easy to add later.
- **Pagination is not addressed here.** 360 visits will make #141 visible — no
  list endpoint is bounded (72 `findMany`, 1 `take`), so the visits and tasks
  screens will pull everything, and those screens may feel sluggish until #141
  lands. Today's 3-visit seed hides this entirely. Making the problem visible is
  a fair trade, but it is a real consequence of this change and should not
  surprise anyone.
- **Test fixtures are not unified with the seed.** The suites have their own
  established patterns; churning 30+ test files serves no demo goal.
