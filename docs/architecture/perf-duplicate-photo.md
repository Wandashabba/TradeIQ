# Duplicate-photo lookup: query plans at scale (#311)

`loadDuplicatePhotoMatches()` in `backend/src/modules/fraud/fraud.service.ts`
(#244, PR #298) finds, for every photo in a scoring batch, the strongest earlier
photo of the same client that is byte-identical (`content_hash`, btree) or within
`duplicatePhotoMaxDistance` dHash bits (`perceptual_hash_bands && probe keys`,
GIN). It is one statement per batch. The batch is one visit for
`GET /fraud/visits/:id` and the submit hook, and up to 100 visits for
`rescoreFraudScores` / `npm run rescore-fraud`. `GET /fraud/flagged` reads
stored scores since #236 and runs no lookup.

It had been tested for correctness and for no N+1, but its plan had never been
measured on a large table. This doc records that measurement.

## TL;DR

- **The GIN band index and the `content_hash` btree are always used.** At 50k
  and 100k photos, for batches of 1, 16 and 100 visits, every plan probed both
  indexes. None fell back to scanning photos for candidates.
- **The real problem was GIN "fast update".** New index entries sit in an
  unsorted pending list until autovacuum merges them. Every probe scans that
  whole list, and the photos a duplicate lookup most needs (recent uploads) are
  exactly the ones in it. With a full list (48k tuples, the 4MB default), each
  of the batch's probes took about 48 ms instead of about 0.15 ms. A 100-visit
  rescore batch took **24 s** instead of 0.3 s, and one visit took 180 ms
  instead of 6 ms. This depends on autovacuum timing, so it comes and goes in
  production.
  **Fix:** `ALTER INDEX photos_perceptual_hash_bands_idx SET (fastupdate = off)`.
  Single-row insert latency did not get worse (below).
- **The query re-joined `photos` by id after the index probes.** From 16 visits
  up, the planner did that as a sequential scan of the whole table, hashed
  against the client's visits. **Fix:** the candidate branches now carry the
  columns the scorer needs, so the re-join is gone. At 16 visits: 75 ms → 39 ms
  median. At 100 visits: 391 ms → 269 ms. Results are identical (below).

## Setup

- Postgres 16.14 (Docker, arm64), default `work_mem` 4MB, `shared_buffers`
  128MB, `random_page_cost` 4, JIT on. Laptop, shared with other work, so
  treat timings as ±30%.
- Seed: `backend/scripts/bench/seed-duplicate-photos.ts`. It is not run in CI
  and refuses any database not named `*bench*`. Run it on a freshly migrated
  scratch DB, then `ANALYZE`:

  | parameter | 50k run | 100k run |
  |---|---|---|
  | clients / outlets / agents per client | 3 / 2,000 / 30 | 3 / 2,000 / 30 |
  | submitted visits (over 180 days) | 10,000 | 20,000 |
  | photos total | 50,601 | 101,288 |
  | audit photos (4–6 per visit) | 49,814 | 99,719 |
  | exact re-uploads of an earlier photo | 712 | 1,459 |
  | near-duplicates (1–6 bit flips) | 766 | 1,489 |
  | per-client placeholder image (hot hash) | 154 | 301 |
  | cross-tenant copies (must not match) | 263 | 503 |
  | degenerate dHash (no bands) | 517 | 1,033 |
  | no hashes (pre-#244, not backfilled) | 998 | 1,971 |
  | `task_closure` photos (half copies of audit photos) | 787 | 1,569 |
  | seed time | 4 s | 7 s |

  `url` is a placeholder, since the lookup never reads it. Hashes are random
  hex. `perceptual_hash_bands` comes from `perceptualHashBands()`, so the keys
  match what `POST /photos` stores. Heap 40 MB, GIN 10–12 MB, btree 12 MB at
  100k.
- Measurement: `backend/scripts/bench/explain-duplicate-photo.ts` runs the real
  `scoreFraudBatch()` with `$queryRaw` wrapped. The duplicate-photo statement
  is sent as `EXPLAIN (ANALYZE, BUFFERS)` with the same text and bound
  parameters, then timed round-trip through Prisma (median of 5–7). The batch
  is the client's newest visits, the worst case, because everything earlier
  is a candidate. The default threshold is 6 bits, so there are 68 probe keys
  per photo.

## Findings

### 1. Both indexes are used; the pending list decides the cost

100k photos, `fastupdate = on` (the default), measured straight after the
seed. Autovacuum was disabled on the table to hold the list full, as it would
be between autovacuum runs:

```
pgstatginindex: pending_pages=465 pending_tuples=48110

100 visits / 490 source photos / 32,708 probe keys — median 22,155 ms
->  Nested Loop  (actual time=79.885..23581.918 rows=49847 loops=1)
      ->  HashAggregate  (rows=481)                       -- one probe array per photo
      ->  Bitmap Heap Scan on photos p_2  (actual time=48.539..48.959 rows=104 loops=481)
            ->  Bitmap Index Scan on photos_perceptual_hash_bands_idx
                  (actual time=48.517..48.517 rows=104 loops=481)
                  Buffers: shared hit=322270
...
Planning Time: 7.781 ms
Execution Time: 24021.497 ms
```

About 48 ms per probe × 481 photos. The GIN tree lookup is cheap. The time goes
into reading 465 pending-list pages for each probe.

Same data and query after `VACUUM photos` (pending list merged):

```
->  Bitmap Index Scan on photos_perceptual_hash_bands_idx
      (actual time=0.114..0.114 rows=104 loops=481)
      Buffers: shared hit=98605
Execution Time: 288.082 ms
```

The 50k run showed the same thing by accident. The first EXPLAIN, before
autovacuum had reached the new table, took 3,721 ms for 16 visits
(46.9 ms per probe). About a minute later autovacuum had run, and the same
query took 80 ms (0.19 ms per probe).

The default `gin_pending_list_limit` of 4MB holds roughly 48k band rows. That
is 48k photo uploads, a few days for a mid-sized tenant, which is exactly the
window duplicate detection cares about. How slow a lookup is then depends on
when autovacuum last ran.

`fastupdate = off` (new migration) makes each insert write its four keys into
the tree directly. Measured with 1,000 single-row `INSERT`s into the
100k-row table, one round trip each, as `POST /photos` does:

| | p50 | p95 | p99 | max | pending after |
|---|---|---|---|---|---|
| fastupdate = on | 0.80 ms | 2.23 ms | 4.68 ms | 35.8 ms | 1,000 tuples |
| fastupdate = off | 0.56 ms | 1.05 ms | 1.39 ms | 4.75 ms | 0 |

There is no measurable insert cost at this scale. Only four keys per row are
indexed, so a GIN insert is a few page touches. With `on`, the max is the
pending-list flush that some unlucky upload pays for. The on/off difference is
within noise, and the claim is only "not slower", not "faster".

### 2. The re-join to `photos` becomes a sequential scan

With the pending list empty, the shipped query (v0) is:

```
Hash Join  (rows=16969)                              -- candidates ⋈ (photos ⋈ visits)
  Hash Cond: (p_1.id = p.id)
  ->  Unique (rows=49856)                            -- UNION of both index branches
        ->  Append
              ->  Index Scan using photos_content_hash_idx on photos p_1  (loops=490)
              ->  Bitmap Index Scan on photos_perceptual_hash_bands_idx     (loops=481)
  ->  Hash  (rows=33598)
        ->  Hash Join  (p.visit_id = v.id)
              ->  Seq Scan on photos p  (rows=99719)  -- every photo, to re-read 5 columns
                    Filter: (section <> 'task_closure'::text)
              ->  Bitmap Index Scan on visits_client_id_status_idx (rows=6736)
```

The `candidate` CTE returned only `(photo_id, match_id)`. Scoring joined back to
`photos` by primary key for `visit_id`, `section` and the hashes, which the
index branches had already read. For 1 visit the planner uses `photos_pkey`
(395 index lookups). From 16 visits up, it seq-scans every photo and hashes
them against the client's visits, and that cost grows with the table, not the
batch.

The rewrite (v2) selects those columns in each `UNION` branch and drops the
join:

```
Hash Join
  ->  Unique (rows=49070)
        ->  Append
              ->  Index Scan using photos_content_hash_idx on photos p     (loops=490)
              ->  Bitmap Heap Scan on photos p_1                           (loops=481)
                    Filter: (section <> 'task_closure'::text)              -- pushed into the probe
                    ->  Bitmap Index Scan on photos_perceptual_hash_bands_idx (loops=481)
  ->  Hash
        ->  Bitmap Heap Scan on visits v  (rows=6736)   -- visits only, via visits_client_id_status_idx
```

No `Seq Scan on photos` at any batch size.

`UNION` now de-duplicates on the extra columns too. They are functions of
`match_id`, so the rows are the same.

A `LATERAL ... ORDER BY ... LIMIT 1` per source photo (v1: a `BitmapOr` of both
indexes) was also tried. It was slower at 16 and 100 visits (54 ms and 169 ms,
with EXPLAIN runs of 226 ms and 485 ms) because it sorts each photo's
candidates separately, so it was rejected.

### Timings

Median round trip through Prisma, 7 runs. EXPLAIN columns come from one
`EXPLAIN ANALYZE` run, so they are noisier and JIT adds 30–40 ms to the large
ones. "rows examined" is GIN candidates → after the tenant/earlier/closure
join → returned (one per matched photo).

**100k photos**

| batch | state | query | median | EXPLAIN exec | planning | shared buffers hit | `Seq Scan on photos` |
|---|---|---|---|---|---|---|---|
| 1 visit (4 photos) | pending list full | v0 (before) | 178 ms | 202 ms | 1.2 ms | 5,226 | no |
| 16 visits (74 photos) | pending list full | v0 (before) | 3,232 ms | 3,203 ms | 0.6 ms | 62,254 | yes |
| 100 visits (490 photos) | pending list full | v0 (before) | 22,155 ms | 24,021 ms | 7.8 ms | 379,291 | yes |
| 100 visits (490 photos) | pending list full | v2 | 24,687 ms | 24,459 ms | 1.8 ms | 374,253 | no |
| 1 visit | `fastupdate=off` | v0 | 7.5 ms | 8.0 ms | 1.5 ms | 3,366 | no |
| 1 visit | `fastupdate=off` | **v2 (after)** | **5.2 ms** | 5.1 ms | 0.5 ms | 1,783 | no |
| 16 visits | `fastupdate=off` | v0 | 74.9 ms | 168 ms | 0.7 ms | 28,310 | yes |
| 16 visits | `fastupdate=off` | **v2 (after)** | **39.4 ms** | 35.9 ms | 0.5 ms | 23,253 | no |
| 100 visits | `fastupdate=off` | v0 | 390.6 ms | 288 ms | 1.4 ms | 155,640 | yes |
| 100 visits | `fastupdate=off` | **v2 (after)** | **269.2 ms** | 376 ms | 1.4 ms | 150,583 | no |

Rows examined at 100 visits: 596 btree hits + 49,847 GIN candidates
→ 16,969 same-client → 112 qualifying (earlier, not closure, within 6 bits)
→ 19 returned. At 16 visits: about 7,500 GIN candidates → 4 returned.

The shipped service on this branch, through `explain-duplicate-photo.ts`
(100k, `fastupdate=off`): **1 visit 6.4 ms, 16 visits 40.6 ms, 100 visits
299.6 ms** median round trip.

**50k photos** (autovacuum had merged the list):

| batch | v0 median | v2 median |
|---|---|---|
| 1 visit (6 photos) | 5.7 ms | 3.8 ms |
| 16 visits (79 photos) | 40.5 ms | 24.6 ms |
| 100 visits (490 photos) | 199.6 ms | 149.2 ms |

At 50k the 16-visit v0 plan already seq-scanned photos. The cost scales with
the table, which is why the 100k gap is larger.

### Equivalence

The harness ran v0 and v2 (and v1) over every visit of every client in
consecutive batches and compared the returned
`(photo, match visit, match outlet, match checkin, exact, distance)` rows:

- 50k, batch 100: 102 batches, 0 differences, 1,612 rows from each variant.
- 100k, batch 16: 1,251 batches, 0 differences, 3,227 rows from each variant.

The existing `fraud.duplicate*.test.ts` suites pass unchanged, including the
one-query spy.

## What changed

1. `backend/prisma/migrations/20260915090000_photo_bands_gin_fastupdate_off`:
   `ALTER INDEX ... SET (fastupdate = off)` plus `gin_clean_pending_list()`
   to merge whatever is already pending. It is metadata-only and takes
   `ShareUpdateExclusiveLock`. Prisma cannot express index storage parameters,
   so `schema.prisma` carries a comment and `prisma migrate diff` stays clean,
   but it also cannot catch a hand-recreated index that loses the setting.
2. `loadDuplicatePhotoMatches()`: the candidate branches select the matched
   photo's columns, and the `JOIN photos p ON p.id = c.match_id` is removed.
   Matches, exclusions (task-closure on both sides, cross-tenant, earlier
   visits only, same visit), thresholds, ranking and the one-statement shape
   are unchanged.

Not changed, and why:

- **No composite/partial GIN** (e.g. partial on non-closure, or `client_id` via
  `btree_gin`). Closure photos are about 1.5% of rows. The tenant filter
  removes about two thirds of candidates, but they are cheap heap-block reads,
  already cached. And a partial index would have to repeat the section literal
  from the service.
- **No chunking.** After the fixes, cost is linear in batch size, about 0.6 ms
  per source photo at 100k. The rescore's 100-visit batch in 0.3 s is fine,
  and splitting it would break the one-query-per-batch contract the tests pin.
- `work_mem`: the 100-visit plan spills about 12 MB of sort to temp. Raising
  it globally is an ops decision and not needed at these timings.

## Revisit when

- Photos move to object storage (#65). Nothing here reads `url`, so this should
  not change, but re-run the bench.
- A tenant reaches millions of photos: GIN candidates per probe grow linearly
  (about 1 in 1,000 photos per 68-key probe set). Wider bands or a
  `client_id`-scoped index would then be worth measuring.

## Reproduce

```sh
cd backend
# .env pointing DATABASE_URL at a scratch database whose name contains "bench"
npx prisma migrate deploy
npx ts-node scripts/bench/seed-duplicate-photos.ts --photos 100000
npx ts-node scripts/bench/explain-duplicate-photo.ts --sizes 1,16,100 --runs 7
# to see the fastupdate=on cost: ALTER INDEX photos_perceptual_hash_bands_idx SET (fastupdate = on)
# on an empty table before seeding, with autovacuum_enabled = false on photos
```
