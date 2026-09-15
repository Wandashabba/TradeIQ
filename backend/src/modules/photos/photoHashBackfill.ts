import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { computePhotoHashes } from './photoHash';

/**
 * Fills `contentHash` / `perceptualHash` / `perceptualHashBands` on photos
 * uploaded before #244 hashed them at upload. The CLI is
 * scripts/backfill-photo-hashes.ts; the loop lives here so it is built,
 * typechecked and tested with the code that reads the hashes.
 *
 * Why not in the migration: hashing decodes every stored base64 image, which
 * would hold the deploy — and a lock on `photos` — for as long as that takes.
 *
 * - Idempotent: only rows with `contentHash IS NULL` are read, and each write
 *   is guarded by the same condition, so a second run (or two runs at once)
 *   rewrites nothing.
 * - Batched: `batchSize` rows per read. A row carries its full data URL (up to
 *   ~8MB of base64), so a batch is bounded by rows, not bytes; keep it small.
 * - Resumable: batches walk `id` upward and every finished row drops out of the
 *   `IS NULL` filter, so a run that is killed, or stopped by `limit`, picks up
 *   where it left off on the next start with nothing to remember.
 *
 * A row whose `url` is not a base64 image data URL gets no hash. It stays null,
 * is counted as `unhashable`, and is looked at again (cheaply: such urls are
 * short) on the next run. duplicate_photo ignores photos without hashes.
 */
export interface PhotoHashBackfillOptions {
  /** Rows read per query. Default 25. */
  batchSize?: number;
  /** Stop after examining this many rows. Default: no limit. */
  limit?: number;
  /** Only this tenant's photos (photo -> visit -> clientId). */
  clientId?: string;
  /** Progress lines. Default: silent. */
  log?: (line: string) => void;
}

export interface PhotoHashBackfillResult {
  /** Unhashed rows examined. */
  scanned: number;
  /** Rows this run wrote hashes to. */
  hashed: number;
  /** Rows whose url is not a hashable image data URL; left null. */
  unhashable: number;
}

export const DEFAULT_BACKFILL_BATCH_SIZE = 25;

export async function backfillPhotoHashes(
  options: PhotoHashBackfillOptions = {},
): Promise<PhotoHashBackfillResult> {
  const batchSize = Math.max(1, Math.floor(options.batchSize ?? DEFAULT_BACKFILL_BATCH_SIZE));
  const limit = options.limit === undefined ? Infinity : Math.max(0, Math.floor(options.limit));
  const result: PhotoHashBackfillResult = { scanned: 0, hashed: 0, unhashable: 0 };
  let afterId: string | undefined;

  while (result.scanned < limit) {
    const where: Prisma.PhotoWhereInput = {
      contentHash: null,
      ...(afterId ? { id: { gt: afterId } } : {}),
      ...(options.clientId ? { visit: { clientId: options.clientId } } : {}),
    };
    const rows = await prisma.photo.findMany({
      where,
      orderBy: { id: 'asc' },
      take: Math.min(batchSize, limit - result.scanned),
      select: { id: true, url: true },
    });
    if (rows.length === 0) {
      break;
    }

    for (const row of rows) {
      result.scanned += 1;
      const hashes = await computePhotoHashes(row.url);
      if (!hashes.contentHash) {
        result.unhashable += 1;
        continue;
      }
      // Guarded on contentHash IS NULL: a concurrent run, or an upload path that
      // got there first, is never overwritten.
      const { count } = await prisma.photo.updateMany({
        where: { id: row.id, contentHash: null },
        data: hashes,
      });
      result.hashed += count;
    }
    afterId = rows[rows.length - 1].id;
    options.log?.(
      `scanned ${result.scanned}, hashed ${result.hashed}, unhashable ${result.unhashable} (through ${afterId})`,
    );
  }

  return result;
}
