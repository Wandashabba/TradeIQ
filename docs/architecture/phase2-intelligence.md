# Phase 2 — Intelligence (status)

Phase 2 replaces the deferred stubs with real logic. Some capabilities are
genuinely implementable in-house (heuristic/statistical) and are now shipped;
computer vision and OCR require a trained model or a paid vendor and remain
stubbed behind their interfaces until that decision is made.

## Implemented (real logic)

### Fraud / ghost-visit detection (issue #3) — `backend/src/modules/fraud`
A real heuristic engine (replaces the throwing `fraud.stub.ts`). Per visit it
computes a `riskScore` (0-100) from weighted signals:
- `geofence_distance` — checked in near the fence edge (>40m of 50m)
- `failed_attempts` — prior rejected check-ins for the same agent+outlet in the 6h before check-in
- `photo_gps_divergence` — a visit photo's EXIF GPS is >150m from the check-in
- `fast_completion` — sections captured in an implausibly short dwell time
  (device check-in → device submit, under `kpiThresholds.fastCompletionMinutes`, default 1)
- `slow_completion` — dwell implausibly long, over
  `kpiThresholds.slowCompletionMinutes` (default 48, 4x the practitioner's
  ~12-minute audit). Flat, low weight (10): an app left open also does this, so
  it corroborates other signals rather than flagging a visit alone (#247)
- `no_capture` — submitted with zero section data
- `capture_timeline_gap` — a shelf photo's device timestamp falls outside the
  visit's device window (check-in → `submittedAtClient`) by more than
  `kpiThresholds.captureTimelineToleranceMinutes` (default 15): the counts and
  the photos were not captured in one sitting (#246). Stock rows carry only a
  server `createdAt`, so they are never compared with a device photo time
  directly; the device window, which brackets every count keyed in, stands in
  for them. Silent on drafts, without `submittedAtClient`, without photo
  timestamps, and for `task_closure` photos. Flat weight 15; only 5 when the
  out-of-window photos are the same ones `photo_gps_divergence` already scored,
  so one stale photo is not counted twice
- `repeating_stock_counts` — the practitioner's *"2-1, 2-1"*: identical
  `unitsAvailable` for the same (outlet, SKU) across at least
  `kpiThresholds.repeatingStockRunLength` consecutive submitted stock visits
  (default 3; lower settings fall back to 3, higher ones clamp at 12). "Previous"
  is ordered by each visit's device `checkinTs` (ties by id), never a stock row's
  server `createdAt`. A visit that did not record the SKU ends its run. A SKU only
  counts when it is non-zero and the `velocityAvg` stored (#112) on the **first**
  row of its run, times the run's span in days, predicts at least 3 units sold.
  The first row is used because a copied count reads as zero consumption, so
  later rows' velocity is diluted by the copies themselves. Slow movers and
  out-of-stock shelves therefore stay silent (#245). Flat weight 15 when every
  comparable SKU in the basket repeats (at least 2 SKUs, at least one of them a
  mover); 5 when at least half of it does, or for a one-SKU basket; silent below
  half. Silent on drafts, visits without stock, and with too little history.
  History is loaded in one windowed query per call, `lookback` = run length − 1 +
  10 visits per outlet. `GET /fraud/flagged` uses the scanned visits themselves
  as each outlet's recent history, and loads only what precedes each outlet's
  oldest scanned visit
- `duplicate_photo` — the same shelf photo submitted again (#244). `POST /photos`
  stores two small hashes per photo, computed once with `sharp`: `contentHash`
  (SHA-256 of the decoded bytes) and `perceptualHash` (a 64-bit dHash), plus the
  dHash split into four position-tagged 16-bit bands in a GIN-indexed `int[]`.
  The base64 `url` is never compared or indexed. A visit's photo matches when a
  photo on an **earlier** visit of the **same client** (device `checkinTs`, ties
  by id) is byte-identical, or within
  `kpiThresholds.duplicatePhotoMaxDistance` bits of dHash (default 6; negative
  falls back, above 7 clamps — the band index guarantees recall only up to 7).
  The first use of a photo is never accused. Flat weights, strongest match wins:
  another outlet 35 exact / 25 near; an earlier visit to the same outlet 15
  exact / 5 near (the same shelf shot from the same spot honestly looks alike).
  Never flags alone. Excludes `task_closure` photos on either side, and photos
  without hashes. The hashes are omitted from every photo response
  (`lib/prisma.ts`). Lookups are one query per call: an exact branch on the
  btree `content_hash` index and a near branch probing the band index, keeping
  only the strongest match per photo, so `GET /fraud/flagged` does not N+1.
  Photos uploaded before #244 are hashed by `npm run backfill-photo-hashes`
  (batched, idempotent, resumable; `--batch`, `--limit`, `--client`), never by
  the migration

`GET /fraud/visits/:visitId`, `GET /fraud/attempts`, `GET /fraud/flagged`.
Fed by the new `CheckInAttempt` table (every attempt, incl. rejected ones — #44)
and the `Photo` GPS captured in Phase 1.

### Predictive dispatch (issue #4) — `backend/src/modules/dispatch`
Real nearest-agent ranking (replaces `dispatch.stub.ts`): ranks a client's
field agents for an outlet by territory membership then haversine distance from
their last-known location. `POST /dispatch`, `GET /dispatch/agents`. Fed by the
new `User.lastLat/lastLng/lastSeenAt` (updated on check-in) and Phase-3
Territories.

### ML demand forecasting — `backend/src/services/forecast.service.ts` + `backend/src/modules/forecast`
Upgrades the naive point-velocity `predictCoverageDays` with real exponential
smoothing over a SKU's historical `VisitStock` sales series
(`exponentialSmoothing`, `forecastDemand`, `forecastCoverageDays`).
`GET /forecast?skuId=&outletId=`. The original formula is retained for the
inline stock-capture path.

## Still stubbed — needs a model/vendor decision

### Computer vision (issue #1) — `backend/src/services/vision.stub.ts`
Branding/planogram/facings/cleanliness/POSM detection needs a trained CV model
(on-device or a cloud vision API). The stub (weighted-random) is wired into
S3-4 as the swap-in seam, and Phase 1 now persists the shelf photos a real
model would consume — but shipping genuine CV requires a model/vendor that this
codebase cannot fabricate. **Blocked on a vendor/model decision, not on
integration.**

### OCR price extraction (issue #2) — `backend/src/services/ocr.stub.ts`
Same story: the seam is wired into S5 pricing and photos are captured, but real
price-tag OCR needs an OCR engine/model. **Blocked on a vendor/model decision.**

Both should adopt a small provider interface (`VisionProvider` / `OcrProvider`)
so a real provider drops in via config; the current stubs are the default
provider. Photo storage also moves to an object store at that point (ADR 0007).

## Deferred infrastructure (Phase 2+, unchanged)
Kafka (event streaming — would let fraud/alert evaluation and webhooks fire on
events instead of on-demand), PostGIS (spatial territory/dispatch queries),
Redis (caching). See ADR 0002. No caller assumes them yet.
