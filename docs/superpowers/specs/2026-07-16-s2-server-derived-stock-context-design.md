# S2 — Server-Derived Stock Context — Design Spec

Date: 2026-07-16
Status: Approved

## 1. Purpose

Close [issue #112](https://github.com/Wandashabba/TradeIQ/issues/112): the S2
stock form asks the agent to type four numbers they cannot observe at a
shelf — `daysOutOfStock`, `velocityAvg`, `salesActual`, `salesTarget`. Left
blank, they're silently recorded as `0`; guessed, the guess for `velocityAvg`
propagates straight into `coverageDaysPredicted`. The original S2 spec
(`2026-07-03-s2-stock-availability-design.md` §2) explicitly deferred
"computing `velocityAvg` from historical `VisitStock` rows" — this spec picks
that up, plus `daysOutOfStock`.

## 2. Scope

In scope:
- Compute `daysOutOfStock` and `velocityAvg` server-side from existing
  `VisitStock` history. No agent input for either.
- Serve both, read-only, on `GET /skus?outletId=` so the app can show context
  before the agent opens a SKU's form.
- `POST /stock` no longer accepts `daysOutOfStock`/`velocityAvg` in the
  request body — the server computes and stamps both itself.
- Remove the `salesActual`/`salesTarget` fields from the S2 Flutter form and
  from the `POST /stock` payload entirely.
- Migration: `VisitStock.salesActual`/`salesTarget` become nullable
  (`Float?`), no longer required on write.

Explicitly out of scope (deferred to a new follow-up issue on real sell-out/
target data):
- Any real `salesActual` (consumer sell-through) or `salesTarget` (quota)
  data. Investigation confirmed no data source exists for either today —
  `Order`/`OrderLine` model sell-in (what the agent orders *from* the
  outlet), not sell-out; there is no POS feed and no quota/target model
  anywhere in the schema. Building either is a POS-integration or
  admin-target-setting project, not a form-UX fix.
- `modules/forecast/forecast.service.ts`'s demand forecasting, which today
  reads historical `salesActual` values off `VisitStock` as its input series.
  Once `salesActual` stops being captured, that series thins out. This is a
  known consequence, left for the follow-up issue to address (e.g. switch its
  input series to `Order` volume, or something else) — not fixed here.
- A precise `stockoutSince` timestamp (exact day-count independent of visit
  cadence). This pass uses a visit-cadence approximation instead (§3);
  precision is a possible future addition to the same follow-up issue if the
  approximation proves too coarse for weekly-cadence beats in practice.

## 3. Backend: derivation logic

New file `backend/src/services/stock-derived.service.ts`, alongside the
existing `services/forecast.service.ts` (`predictCoverageDays`). One
implementation, used by both the read endpoint and the write path — the same
"exactly one implementation of this math" discipline `dashboard.service.ts`
already documents for its own `#93` history of KPI-duplication bugs.

```ts
export interface StockHistoryRow {
  visitCheckinTs: Date;
  unitsAvailable: number;
}

/**
 * Days since the most recent prior visit where this outlet+SKU had stock.
 * No prior row -> 0 (no history yet, not "out of stock forever").
 * Approximate at visit-cadence granularity: accurate for daily/near-daily
 * beats, coarser for weekly ones (a week-cadence outlet reads "7 days out"
 * even if it ran out only 2 days before the visit).
 */
export function computeDaysOutOfStock(
  history: StockHistoryRow[], // prior rows for this outlet+SKU, newest-first
  asOfCheckinTs: Date,
): number { ... }

/**
 * Average daily consumption across the last few visit-pairs for this
 * outlet+SKU. For each adjacent pair (history[i] newer, history[i+1]
 * older), consumption = older.unitsAvailable - newer.unitsAvailable.
 * Restock jumps (newer.unitsAvailable > older.unitsAvailable) contribute 0
 * to that interval rather than a negative number -- a restock isn't
 * "negative sales", it's evidence the interval's true consumption is
 * unknown. Fewer than 2 prior rows -> 0.
 */
export function computeVelocityAvg(
  history: StockHistoryRow[], // prior rows for this outlet+SKU, newest-first
): number { ... }
```

Both pull from the same query: the last 5 `VisitStock` rows (or fewer, if
that's all there is) for the given `outletId`+`skuId`, joined to
`Visit.checkinTs`, ordered newest-first (`computeDaysOutOfStock` walks from
index `0` forward looking for the first row with `unitsAvailable > 0`; 5 is a
fixed window — plenty for a rolling average, small enough to keep the query
cheap; not user-configurable).

## 4. Backend: `skus` module (modified)

`skus.service.ts`'s `listSkusForClient` gains an `outletId` parameter and,
for each SKU, attaches `daysOutOfStock`/`velocityAvg` computed via §3 against
that outlet. `skus.routes.ts`'s `GET /` requires `outletId` as a query param
(400 if missing — every existing caller, the S2 screen, already has one in
hand from the active visit).

## 5. Backend: `stock` module (modified)

`stock.service.ts`'s `RecordStockInput` drops `daysOutOfStock`/`velocityAvg`
as caller-supplied fields; `recordStock()` calls §3's functions itself before
building the `VisitStock.create` payload — the app no longer sends them, so
there is no client-writable path for either column.

`RecordStockInput.salesActual`/`salesTarget` become optional
(`number | undefined`); when absent, write `null`. `stock.routes.ts`'s
required-field check drops both from its list of mandatory body fields.

## 6. Migration

`schema.prisma`: `VisitStock.salesActual Float` → `Float?`,
`VisitStock.salesTarget Float` → `Float?` (drop the columns' non-null
constraint; no default). A new Prisma migration adds this; existing rows
(all of which currently hold real or zero values from the old required
fields) are left as-is — nullability only affects future writes.

## 7. Flutter

`s2_stock_screen.dart`:
- Remove the "Sales actual"/"Sales target" `TextField`s and their
  controllers from the form dialog entirely.
- Remove the "Days out of stock"/"Avg daily velocity" input fields; replace
  with read-only context text sourced from the SKU list response (e.g.
  "selling ~4/day · 12 days cover", matching the issue's own suggested
  copy), rendered above the remaining `unitsAvailable` `CountStepper` input.
- `unitsAvailable` (the `CountStepper`) and `lastStockinDate` (the date
  picker) remain the only agent inputs — `lastStockinDate` is unaffected by
  this change (it's an observable "when was this last restocked" fact, not
  one of the four flagged fields).

`skus_repository.dart`: `Sku.fromJson` gains `daysOutOfStock`/`velocityAvg`
fields; `listSkus()` gains a required `outletId` parameter threaded through
to the `GET /skus?outletId=` call.

`stock_repository.dart`: `StockRepository.recordStock` drops the
`daysOutOfStock`/`velocityAvg`/`salesActual`/`salesTarget` parameters
entirely — only `unitsAvailable` and `lastStockinDate` remain. `StockDrafts`
Drift table (`tables.dart`) drops the four corresponding columns; schema
version bumps accordingly (no shipped installs to migrate, same as the
original S2 spec's version bump).

`HttpQueueFlusher`'s `'stock'` case payload shrinks to match.

## 8. Testing

Backend (Jest + Supertest):
- `stock-derived.service.test.ts` (new, unit tests for §3's pure functions):
  no history → both `0`; single prior visit with stock → `velocityAvg` still
  `0` (needs 2+ points), `daysOutOfStock` computed from that one visit;
  multiple visits with a restock in between → the restock interval
  contributes `0` to the velocity average, not a negative number; weekly vs.
  daily cadence → `daysOutOfStock` reflects the coarser visit-cadence gap
  correctly per §3's documented approximation.
- `skus.routes.test.ts` (modified): `GET /skus?outletId=` returns
  `daysOutOfStock`/`velocityAvg` per SKU matching fixture `VisitStock`
  history; 400 when `outletId` is missing.
- `stock.routes.test.ts` (modified): `POST /stock` ignores any
  `daysOutOfStock`/`velocityAvg` present in the request body and persists the
  server-computed values instead (fixture history set up so computed ≠ any
  value the test sends, to prove the override is ignored, not coincidentally
  equal); `salesActual`/`salesTarget` omitted from the body → persisted as
  `null`; 400 check no longer includes the four removed fields.

Flutter (`flutter_test`):
- `stock_derived_service_test.dart`: N/A — computation is backend-only, no
  client-side logic to test.
- `stock_repository_test.dart` (modified): `recordStock`'s signature and the
  `StockDrafts` row/`SyncQueueItems` payload it writes shrink to match;
  existing assertions updated, no new cases needed.
- `skus_repository_test.dart`: still not added, consistent with the original
  S2 spec's precedent (§7 of that spec) — the real Dio path stays exercised
  only via widget tests with fakes.
- `s2_stock_screen_test.dart` (modified): form dialog no longer shows/accepts
  the two removed inputs; read-only context text renders from a fake SKU
  list response including `daysOutOfStock`/`velocityAvg`; submitting the
  form only requires `unitsAvailable`+`lastStockinDate`.
- `sync_service_test.dart` (modified): `'stock'` case payload shape updated
  to match the shrunk fields.
- Full `flutter test` suite stays green; `flutter analyze` clean.

## 9. Explicitly out of scope for this spec

- Real `salesActual`/`salesTarget` data sourcing (POS integration,
  admin-set targets) — tracked in a new follow-up issue.
- `forecast.service.ts`'s demand-forecast input series thinning as
  `salesActual` capture stops — left for the same follow-up issue.
- Precise `stockoutSince`-based day counting — visit-cadence approximation
  only, this pass.
