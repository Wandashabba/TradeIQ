-- #244: content + perceptual hashes for duplicate-photo detection.
--
-- Schema only. Existing rows are NOT hashed here: hashing means decoding every
-- stored base64 image, which inside a migration would hold the deploy (and a
-- lock on photos) for as long as that takes. New uploads are hashed by
-- POST /photos; older rows are filled by the batched, resumable
-- `npm run backfill-photo-hashes`. Until then they have no hash and the
-- duplicate_photo signal ignores them. Both added columns are cheap on a large
-- table: nullable, and a constant default (metadata-only on Postgres 11+).

-- AlterTable
ALTER TABLE "photos" ADD COLUMN     "content_hash" TEXT,
ADD COLUMN     "perceptual_hash" TEXT,
ADD COLUMN     "perceptual_hash_bands" INTEGER[] DEFAULT ARRAY[]::INTEGER[];

-- CreateIndex
CREATE INDEX "photos_content_hash_idx" ON "photos"("content_hash");

-- CreateIndex
CREATE INDEX "photos_perceptual_hash_bands_idx" ON "photos" USING GIN ("perceptual_hash_bands");
