import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { NotFoundError } from '../../middleware/errorHandler';
import { computePhotoHashes } from './photoHash';
import { getThumbnailForPhoto } from './thumbnails';

export interface CreatePhotoInput {
  visitId: string;
  clientId: string;
  agentId: string;
  section: string;
  dataUrl: string;
  gpsTag: Prisma.InputJsonValue;
  timestamp: string;
}

export async function createPhoto(input: CreatePhotoInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId, agentId: input.agentId },
    select: { id: true },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  // Hashed once, here, so duplicate_photo (#244) never re-reads stored bytes.
  // Never throws: a payload that is not a decodable image is stored unhashed,
  // exactly as before, and the signal ignores it.
  const hashes = await computePhotoHashes(input.dataUrl);

  // Phase-1 lean-infra choice: we store the base64 data URL string directly in
  // Photo.url — there is no object store yet. Real object storage (e.g. S3 with
  // signed URLs) is a later phase; url will then hold the object URL instead.
  return prisma.photo.create({
    data: {
      visitId: input.visitId,
      section: input.section,
      url: input.dataUrl,
      gpsTag: input.gpsTag,
      timestamp: new Date(input.timestamp),
      ...hashes,
    },
  });
}

  // Bounded by one visit's children rather than a whole tenant, so this is
  // consistency work, not an OOM fix — but a caller should not have to know
  // which lists carry an envelope and which do not.
export async function listPhotosForVisit(
  visitId: string,
  clientId: string,
  page: { limit: number; cursor?: string },
) {
  const visit = await prisma.visit.findFirst({
    where: { id: visitId, clientId },
    select: { id: true },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const rows = await prisma.photo.findMany({
    where: { visitId },
    // Tiebreaker direction matches the primary sort — see alerts.service.ts.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: page.limit + 1,
    ...(page.cursor ? { cursor: { id: page.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, page.limit);
}

/**
 * Thumbnail bytes for a photo the caller's tenant owns (photo -> visit ->
 * clientId), 404 otherwise. The existence check is a cheap id-only lookup so
 * the ~MB `url` column is only fetched on a thumbnail-cache miss.
 */
export async function getPhotoThumbnail(photoId: string, clientId: string): Promise<Buffer> {
  const photo = await prisma.photo.findFirst({
    where: { id: photoId, visit: { clientId } },
    select: { id: true },
  });
  if (!photo) {
    throw new NotFoundError('Photo not found');
  }

  return getThumbnailForPhoto(photoId, async () => {
    const row = await prisma.photo.findUniqueOrThrow({
      where: { id: photoId },
      select: { url: true },
    });
    return row.url;
  });
}

/**
 * Decorates list rows (tasks, alerts — anything carrying a nullable visitId)
 * with `evidencePhotoId`: the NEWEST photo of the row's visit, or null when
 * the row has no visit or the visit has no photos. One batched query for the
 * whole page — never per-row.
 */
export async function attachEvidencePhotoIds<T extends { visitId: string | null }>(
  rows: T[],
): Promise<(T & { evidencePhotoId: string | null })[]> {
  const visitIds = [...new Set(rows.map((r) => r.visitId).filter((v): v is string => v !== null))];

  const newestByVisit = new Map<string, string>();
  if (visitIds.length > 0) {
    const photos = await prisma.photo.findMany({
      where: { visitId: { in: visitIds } },
      // id desc as the tiebreaker so a createdAt tie picks the same photo on
      // every request instead of whatever the database felt like.
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      select: { id: true, visitId: true },
    });
    // Rows arrive newest-first, so the first photo seen per visit wins.
    for (const photo of photos) {
      if (!newestByVisit.has(photo.visitId)) {
        newestByVisit.set(photo.visitId, photo.id);
      }
    }
  }

  return rows.map((row) => ({
    ...row,
    evidencePhotoId: row.visitId === null ? null : (newestByVisit.get(row.visitId) ?? null),
  }));
}
