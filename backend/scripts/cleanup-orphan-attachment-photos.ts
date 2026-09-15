import { prisma } from '../src/lib/prisma';
import {
  cleanupOrphanAttachmentPhotos,
  parseOrphanCleanupArgs,
} from '../src/modules/photos/orphanAttachmentCleanup';

/**
 * Deletes message-attachment photos that were uploaded but never attached to a
 * message (#308) — a draft abandoned after its photos uploaded, or a send that
 * failed and was never retried.
 *
 *   npm run cleanup-orphan-attachment-photos -- --dry-run
 *   npm run cleanup-orphan-attachment-photos
 *   npm run cleanup-orphan-attachment-photos -- --older-than 72 --batch 200
 *   npm run cleanup-orphan-attachment-photos -- --client <clientId>
 *
 *   --older-than  grace period in hours (default 48, minimum 1); only photos
 *                 created before now minus this are deleted
 *   --client      one tenant only
 *   --batch       ids per read/delete (default 500)
 *   --dry-run     print how many would be deleted; delete nothing
 *
 * Only `section = 'message_attachment'` photos with no visit and no
 * MessageAttachment are eligible; visit evidence is never touched. Safe to run
 * as often as you like and to kill: a re-run deletes nothing new and a stopped
 * run picks up the remaining rows on the next start.
 *
 * Nothing schedules this yet; see src/modules/photos/orphanAttachmentCleanup.ts
 * (the scheduler in #66 should call that function).
 */
async function main(): Promise<void> {
  const options = parseOrphanCleanupArgs(process.argv.slice(2));
  const started = Date.now();
  const result = await cleanupOrphanAttachmentPhotos({
    ...options,
    log: (line) => console.log(line),
  });
  const seconds = Math.round((Date.now() - started) / 1000);
  const scope = options.clientId ? ` for client ${options.clientId}` : '';
  if (result.dryRun) {
    console.log(
      `Dry run${scope}: ${result.matched} orphaned attachment photo(s) created before ` +
        `${result.cutoff.toISOString()} would be deleted. Nothing was deleted.`,
    );
    return;
  }
  console.log(
    `Done in ${seconds}s${scope}: deleted ${result.deleted} of ${result.matched} orphaned ` +
      `attachment photo(s) created before ${result.cutoff.toISOString()}.`,
  );
}

main()
  .catch((err) => {
    console.error(err instanceof Error ? err.message : err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
