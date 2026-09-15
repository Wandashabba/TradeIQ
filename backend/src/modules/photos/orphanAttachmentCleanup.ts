import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { MESSAGE_ATTACHMENT_SECTION } from './photos.service';

/**
 * Deletes message-attachment photos that never made it onto a message (#308).
 *
 * The app uploads a draft's photos at Send time and then posts the message
 * (#125). A photo whose send was abandoned — the app closed after the upload,
 * or the message send failed and the draft was discarded — has no
 * MessageAttachment and stays in `photos` forever, base64 bytes and all
 * (ADR 0007). This removes those rows once they are older than a grace period.
 *
 * NOTHING SCHEDULES THIS YET. The CLI is
 * scripts/cleanup-orphan-attachment-photos.ts, run by hand. When the scheduler
 * (#66) exists it should call cleanupOrphanAttachmentPhotos() directly — the
 * loop lives here, not in the script, for exactly that reason.
 *
 * What is an orphan — ALL of:
 * * `section = 'message_attachment'`;
 * * `visitId IS NULL` — visit evidence is never touched, whatever its section;
 * * no MessageAttachment row;
 * * `createdAt` older than the grace period (default 48h, at least 1h).
 *
 * The grace period is what keeps an in-flight send safe: a draft's photos are
 * uploaded seconds before the message that attaches them. The floor stops a
 * careless `--older-than 0` from racing a sender mid-send.
 *
 * - Idempotent: a deleted row is gone and a kept row still fails the filter,
 *   so a second run deletes nothing new.
 * - Batched: ids only are read (never `url`), `batchSize` at a time, and each
 *   batch is one DELETE.
 * - Resumable: batches walk `id` upward and nothing is remembered between runs,
 *   so a killed run simply starts over on the rows that are left.
 * - Race-safe: the DELETE repeats the whole filter, so a photo attached between
 *   the read and the delete is kept. The FK from message_attachments is
 *   RESTRICT, so even a lost race fails loudly rather than orphaning a row.
 */
export interface OrphanAttachmentCleanupOptions {
  /** Grace period in hours. Default 48; values below MIN_GRACE_HOURS are refused. */
  olderThanHours?: number;
  /** Only this tenant's photos. */
  clientId?: string;
  /** Ids read (and deleted) per batch. Default 500. */
  batchSize?: number;
  /** Count what would be deleted, delete nothing. */
  dryRun?: boolean;
  /** The clock, for tests. Default: now. */
  now?: Date;
  /** Progress lines. Default: silent. */
  log?: (line: string) => void;
}

export interface OrphanAttachmentCleanupResult {
  /** Photos created before this are eligible. */
  cutoff: Date;
  /** Orphans found (in a dry run: the rows that WOULD be deleted). */
  matched: number;
  /** Rows deleted. Always 0 in a dry run. */
  deleted: number;
  dryRun: boolean;
}

export const DEFAULT_ORPHAN_GRACE_HOURS = 48;
export const MIN_ORPHAN_GRACE_HOURS = 1;
export const DEFAULT_ORPHAN_CLEANUP_BATCH_SIZE = 500;

function orphanFilter(cutoff: Date, clientId: string | undefined): Prisma.PhotoWhereInput {
  return {
    section: MESSAGE_ATTACHMENT_SECTION,
    visitId: null,
    messageAttachment: { is: null },
    createdAt: { lt: cutoff },
    ...(clientId ? { clientId } : {}),
  };
}

export async function cleanupOrphanAttachmentPhotos(
  options: OrphanAttachmentCleanupOptions = {},
): Promise<OrphanAttachmentCleanupResult> {
  const olderThanHours = options.olderThanHours ?? DEFAULT_ORPHAN_GRACE_HOURS;
  if (!Number.isFinite(olderThanHours) || olderThanHours < MIN_ORPHAN_GRACE_HOURS) {
    throw new Error(
      `olderThanHours must be at least ${MIN_ORPHAN_GRACE_HOURS}, got ${olderThanHours}: ` +
        'a shorter grace period could delete a photo whose message is being sent right now',
    );
  }
  const batchSize = Math.max(
    1,
    Math.floor(options.batchSize ?? DEFAULT_ORPHAN_CLEANUP_BATCH_SIZE),
  );
  const dryRun = options.dryRun ?? false;
  const now = options.now ?? new Date();
  const cutoff = new Date(now.getTime() - olderThanHours * 60 * 60 * 1000);
  const where = orphanFilter(cutoff, options.clientId);

  if (dryRun) {
    const matched = await prisma.photo.count({ where });
    options.log?.(`dry run: ${matched} orphaned attachment photo(s) older than ${cutoff.toISOString()}`);
    return { cutoff, matched, deleted: 0, dryRun };
  }

  const result: OrphanAttachmentCleanupResult = { cutoff, matched: 0, deleted: 0, dryRun };
  let afterId: string | undefined;
  for (;;) {
    const rows = await prisma.photo.findMany({
      where: { ...where, ...(afterId ? { id: { gt: afterId } } : {}) },
      orderBy: { id: 'asc' },
      take: batchSize,
      select: { id: true },
    });
    if (rows.length === 0) {
      break;
    }
    result.matched += rows.length;

    // The filter again, not just the ids: anything attached since the read stays.
    const { count } = await prisma.photo.deleteMany({
      where: { ...where, id: { in: rows.map((r) => r.id) } },
    });
    result.deleted += count;
    afterId = rows[rows.length - 1].id;
    options.log?.(`matched ${result.matched}, deleted ${result.deleted} (through ${afterId})`);
  }
  return result;
}

/**
 * Parses the CLI flags of scripts/cleanup-orphan-attachment-photos.ts. Here
 * rather than in the script so it is tested; throws on a malformed value
 * rather than guessing, because this command deletes rows.
 */
export function parseOrphanCleanupArgs(argv: string[]): OrphanAttachmentCleanupOptions {
  const known = new Set(['--older-than', '--client', '--batch', '--dry-run']);
  const options: OrphanAttachmentCleanupOptions = {};

  const valueOf = (i: number, name: string): string => {
    const value = argv[i + 1];
    if (value === undefined || value.startsWith('--')) {
      throw new Error(`${name} needs a value`);
    }
    return value;
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!known.has(arg)) {
      throw new Error(`Unknown argument "${arg}"`);
    }
    if (arg === '--dry-run') {
      options.dryRun = true;
      continue;
    }
    const raw = valueOf(i, arg);
    i += 1;
    if (arg === '--client') {
      options.clientId = raw;
    } else if (arg === '--older-than') {
      const hours = Number(raw);
      if (!Number.isFinite(hours) || hours < MIN_ORPHAN_GRACE_HOURS) {
        throw new Error(`--older-than must be a number of hours >= ${MIN_ORPHAN_GRACE_HOURS}, got "${raw}"`);
      }
      options.olderThanHours = hours;
    } else {
      const batch = Number(raw);
      if (!Number.isInteger(batch) || batch <= 0) {
        throw new Error(`--batch must be a positive integer, got "${raw}"`);
      }
      options.batchSize = batch;
    }
  }
  return options;
}
