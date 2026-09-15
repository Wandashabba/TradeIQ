-- #311: turn off GIN "fast update" on the perceptual-hash band index.
--
-- With fastupdate on (the Postgres default), new index entries are appended to
-- an unsorted pending list and only merged into the GIN tree by (auto)vacuum or
-- when the list passes gin_pending_list_limit (4MB). Every probe scans that
-- whole list linearly. The duplicate_photo lookup probes once per scanned photo
-- with up to 68 keys, and the photos it most needs to find — recent uploads —
-- are exactly the ones sitting in the list. Measured on 100k photos
-- (docs/architecture/perf-duplicate-photo.md): a full pending list made each
-- probe ~50ms instead of ~0.2ms, i.e. seconds for one rescore batch.
--
-- Off, each upload writes its four band keys straight into the tree: a few
-- index pages per POST /photos, measured in the same doc.
--
-- Prisma cannot express index storage parameters, so schema.prisma does not
-- show this and `prisma migrate diff` does not compare it.
-- Both statements are metadata-light: SET (fastupdate) takes a
-- ShareUpdateExclusiveLock (reads and writes continue), and the cleanup merges
-- at most gin_pending_list_limit of pending entries.

-- AlterIndex
ALTER INDEX "photos_perceptual_hash_bands_idx" SET (fastupdate = off);

-- Merge whatever is already pending, so the next lookup does not pay for it.
SELECT gin_clean_pending_list('"photos_perceptual_hash_bands_idx"'::regclass);
