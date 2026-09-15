import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { NotFoundError, ValidationError } from '../../middleware/errorHandler';
import type { Role } from '../auth/auth.service';
import { decodeImageDataUrl, getThumbnailForPhoto, isDecodableImageDataUrl } from './thumbnails';

/**
 * The `section` of a photo uploaded to be attached to a message (#125) rather
 * than filed as visit evidence. Such photos carry no `visitId`.
 */
export const MESSAGE_ATTACHMENT_SECTION = 'message_attachment';

/** Who is asking to read a photo — enough to apply the attachment rules. */
export interface PhotoViewer {
  userId: string;
  clientId: string;
  role: Role;
}

/** Where a client fetches a photo's bytes. Never the bytes themselves. */
export function photoLinks(photoId: string): { thumbnailUrl: string; imageUrl: string } {
  return {
    thumbnailUrl: `/photos/${photoId}/thumbnail`,
    imageUrl: `/photos/${photoId}/image`,
  };
}

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
      // Recorded going forward (#125). Visit evidence is still scoped through
      // its visit; these make the owner explicit rather than inferred.
      clientId: input.clientId,
      uploadedById: input.agentId,
      section: input.section,
      url: input.dataUrl,
      gpsTag: input.gpsTag,
      timestamp: new Date(input.timestamp),
    },
  });
}

export interface CreateMessageAttachmentPhotoInput {
  clientId: string;
  uploaderId: string;
  dataUrl: string;
  gpsTag?: Prisma.InputJsonValue;
  timestamp?: string;
}

/**
 * Stores an image destined for a message (#125) — the same base64-in-Postgres
 * pipeline as visit evidence, but with no visit: the row is owned by the
 * tenant and the uploader directly, and stays readable only by them (and the
 * tenant's managers/admins) until a message they send attaches it.
 *
 * Images only: the payload must decode as an image, not merely claim to.
 * The response is metadata plus links — the bytes the caller just sent are
 * not echoed back.
 */
export async function createMessageAttachmentPhoto(input: CreateMessageAttachmentPhotoInput) {
  if (!(await isDecodableImageDataUrl(input.dataUrl))) {
    throw new ValidationError('dataUrl must be a base64 image data URL that decodes as an image');
  }

  const photo = await prisma.photo.create({
    data: {
      visitId: null,
      clientId: input.clientId,
      uploadedById: input.uploaderId,
      section: MESSAGE_ATTACHMENT_SECTION,
      url: input.dataUrl,
      gpsTag: input.gpsTag ?? {},
      timestamp: input.timestamp ? new Date(input.timestamp) : new Date(),
    },
    select: {
      id: true,
      clientId: true,
      uploadedById: true,
      section: true,
      timestamp: true,
      createdAt: true,
    },
  });
  return { ...photo, ...photoLinks(photo.id) };
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
 * Throws NotFoundError unless `viewer` may read the photo's bytes. A denial is
 * a 404, never a 403, so a photo id is not an existence oracle.
 *
 * * **Visit evidence** (`visitId` set): unchanged — any authenticated role in
 *   the visit's tenant, the same audience `GET /photos?visitId` already serves.
 * * **Message attachment** (`visitId` null, #125): same tenant AND one of —
 *   a manager/admin of that tenant; the uploader; or the sender or recipient of
 *   the message it is attached to. A broadcast (null recipient) is addressed
 *   to the whole tenant, so everyone in the tenant is a recipient of it.
 *   An upload not yet attached to anything is visible to its uploader and the
 *   tenant's managers/admins only.
 *
 * The check selects ids and foreign keys only — never `url`.
 */
export async function assertPhotoReadable(photoId: string, viewer: PhotoViewer): Promise<void> {
  const photo = await prisma.photo.findUnique({
    where: { id: photoId },
    select: {
      visitId: true,
      clientId: true,
      uploadedById: true,
      visit: { select: { clientId: true } },
      messageAttachment: {
        select: { message: { select: { clientId: true, senderId: true, recipientId: true } } },
      },
    },
  });
  if (!photo) {
    throw new NotFoundError('Photo not found');
  }

  if (photo.visitId !== null) {
    if (photo.visit?.clientId !== viewer.clientId) {
      throw new NotFoundError('Photo not found');
    }
    return;
  }

  if (photo.clientId === null || photo.clientId !== viewer.clientId) {
    throw new NotFoundError('Photo not found');
  }
  if (viewer.role === 'manager' || viewer.role === 'admin') {
    return;
  }
  if (photo.uploadedById === viewer.userId) {
    return;
  }
  const message = photo.messageAttachment?.message;
  if (
    message &&
    message.clientId === viewer.clientId &&
    (message.senderId === viewer.userId ||
      message.recipientId === viewer.userId ||
      message.recipientId === null)
  ) {
    return;
  }
  throw new NotFoundError('Photo not found');
}

/**
 * Thumbnail bytes for a photo the viewer may read (see
 * [assertPhotoReadable]), 404 otherwise. The access check runs BEFORE the
 * cache, so a warm cache never serves a thumbnail to someone the rules deny.
 * The ~MB `url` column is only fetched on a thumbnail-cache miss.
 */
export async function getPhotoThumbnail(photoId: string, viewer: PhotoViewer): Promise<Buffer> {
  await assertPhotoReadable(photoId, viewer);

  return getThumbnailForPhoto(photoId, async () => {
    const row = await prisma.photo.findUniqueOrThrow({
      where: { id: photoId },
      select: { url: true },
    });
    return row.url;
  });
}

/**
 * The full image as raw bytes plus its stored mime type, under the same rules
 * as the thumbnail. Raw bytes rather than a JSON-wrapped data URL: the client
 * already fetches thumbnails as bytes through its authed client.
 */
export async function getPhotoImage(
  photoId: string,
  viewer: PhotoViewer,
): Promise<{ contentType: string; bytes: Buffer }> {
  await assertPhotoReadable(photoId, viewer);

  const row = await prisma.photo.findUniqueOrThrow({
    where: { id: photoId },
    select: { url: true },
  });
  return decodeImageDataUrl(row.url);
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
    // Rows arrive newest-first, so the first photo seen per visit wins. The
    // `in` filter already excludes visit-less (message attachment) photos; the
    // null check only narrows the now-nullable column's type.
    for (const photo of photos) {
      if (photo.visitId !== null && !newestByVisit.has(photo.visitId)) {
        newestByVisit.set(photo.visitId, photo.id);
      }
    }
  }

  return rows.map((row) => ({
    ...row,
    evidencePhotoId: row.visitId === null ? null : (newestByVisit.get(row.visitId) ?? null),
  }));
}
