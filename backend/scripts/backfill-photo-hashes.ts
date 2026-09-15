import { prisma } from '../src/lib/prisma';
import { backfillPhotoHashes } from '../src/modules/photos/photoHashBackfill';

/**
 * Hashes photos uploaded before #244, so the duplicate_photo fraud signal can
 * see them. New uploads are hashed by POST /photos; until a row is backfilled it
 * has no hash and the signal ignores it (no false match, just no match).
 *
 *   npm run backfill-photo-hashes
 *   npm run backfill-photo-hashes -- --batch 10 --limit 5000
 *   npm run backfill-photo-hashes -- --client <clientId>
 *
 *   --batch   rows read per query (default 25; each row holds its full base64
 *             image, so memory is roughly batch x photo size)
 *   --limit   stop after examining this many rows (default: all)
 *   --client  one tenant only
 *
 * Safe to run at any time, as often as you like, and to kill: it only reads
 * rows whose content_hash is still null and only writes where it still is, so
 * re-running rewrites nothing and a stopped run resumes on the next start.
 * It runs outside the migration on purpose — decoding every stored image inside
 * `prisma migrate deploy` would hold the deploy for as long as that takes.
 * See src/modules/photos/photoHashBackfill.ts.
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const flag = (name: string): string | undefined => {
    const i = args.indexOf(`--${name}`);
    return i >= 0 ? args[i + 1] : undefined;
  };
  const positiveInt = (name: string): number | undefined => {
    const raw = flag(name);
    if (raw === undefined) {
      return undefined;
    }
    const value = Number(raw);
    if (!Number.isInteger(value) || value <= 0) {
      throw new Error(`--${name} must be a positive integer, got "${raw}"`);
    }
    return value;
  };

  const started = Date.now();
  const result = await backfillPhotoHashes({
    batchSize: positiveInt('batch'),
    limit: positiveInt('limit'),
    clientId: flag('client'),
    log: (line) => console.log(line),
  });
  const seconds = Math.round((Date.now() - started) / 1000);
  console.log(
    `Done in ${seconds}s: ${result.hashed} hashed, ${result.unhashable} not hashable ` +
      `(not a base64 image data URL), ${result.scanned} examined.`,
  );
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
