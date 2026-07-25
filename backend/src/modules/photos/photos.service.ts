import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
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
    },
  });
}

export async function listPhotosForVisit(visitId: string, clientId: string) {
  const visit = await prisma.visit.findFirst({
    where: { id: visitId, clientId },
    select: { id: true },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  return prisma.photo.findMany({
    where: { visitId },
    orderBy: { createdAt: 'desc' },
  });
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
      orderBy: { createdAt: 'desc' },
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
