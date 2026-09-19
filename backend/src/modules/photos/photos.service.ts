import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { ConflictError, NotFoundError, ValidationError } from '../../middleware/errorHandler';
import type { Role } from '../auth/auth.service';
import { computePhotoHashes } from './photoHash';
import { decodeImageDataUrl, getThumbnailForPhoto, isDecodableImageDataUrl } from './thumbnails';

/**
 * The `section` of a photo uploaded to be attached to a message (#125) rather
 * than filed as visit evidence. Such photos carry no `visitId`.
 */
export const MESSAGE_ATTACHMENT_SECTION = 'message_attachment';

/**
 * How an image was obtained. `camera` means the shutter was pressed inside the
 * app; `gallery` means it was chosen from the device's library.
 *
 * The distinction matters because a photo's `timestamp` and `gpsTag` are
 * stamped when the picker hands the file back, NOT from the image's own
 * capture metadata. For a camera capture those are the same moment. For a
 * gallery pick they are not: a screenshot chosen at home gets a fresh
 * timestamp and a home gpsTag, which agree with each other perfectly and say
 * nothing about where or when the scene was photographed.
 */
export const PHOTO_SOURCES = ['camera', 'gallery'] as const;
export type PhotoSource = (typeof PHOTO_SOURCES)[number];

/**
 * The section a storefront photo offered with a pin dispute is filed under.
 * Duplicated from outlets.service rather than imported: photos must not depend
 * on outlets to enforce its own upload rule.
 */
export const PIN_DISPUTE_SECTION = 'pin_dispute';

/**
 * How long after a wrong-pin claim was RECEIVED BY THIS SERVER its storefront
 * evidence may still arrive.
 *
 * Generous, because the outbox is: a check-in captured in a dead aisle and its
 * photo can both sit for hours and flush together, and refusing the evidence
 * of an agent who was genuinely offline would punish exactly the field
 * conditions this product is built for. It is still a bound, and the bound is
 * the point — a photo uploaded against a week-old override is not evidence of
 * what the agent saw at the door, and until now there was no limit at all.
 */
export const PIN_DISPUTE_PHOTO_WINDOW_MS = 24 * 60 * 60 * 1000;

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
  /**
   * Where the image came from. Optional, so an older build that does not say
   * keeps working for ordinary audit sections — but a pin dispute's storefront
   * photo REQUIRES `camera`, and an older build therefore cannot file one.
   * That is the intended trade: unsourced evidence for the one claim that
   * overrides the geofence is evidence nobody can check.
   */
  source?: PhotoSource;
}

export async function createPhoto(input: CreatePhotoInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId, agentId: input.agentId },
    select: { id: true },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  // ── Storefront evidence for a wrong-pin claim (#386 follow-up) ───────────
  //
  // This one photo is the difference between "the pin is wrong, look at the
  // shop I am standing outside" and an assertion. It was the weakest thing in
  // the override: any image, from anywhere, at any time, stamped with the
  // moment it was PICKED and the position at that moment. A Street View
  // screenshot chosen from the gallery at home arrives with a fresh timestamp
  // and a home gpsTag that agrees exactly with the claimed position — so
  // photo_gps_divergence cannot fire, and the manager is shown a picture of a
  // shop with nothing to contradict it.
  //
  // Three rules, all server-side, none of which an app build can opt out of:
  if (input.section === PIN_DISPUTE_SECTION) {
    if (input.source !== 'camera') {
      throw new ValidationError(
        'A storefront photo for a wrong-pin report must be taken with the camera. ' +
          'A picture chosen from the gallery is stamped with the time it was picked, ' +
          'not the time the shop was photographed.',
      );
    }
    const dispute = await prisma.pinDispute.findUnique({
      where: { visitId: visit.id },
      select: { status: true, createdAt: true },
    });
    if (!dispute) {
      throw new ValidationError('This visit has no wrong-pin report to attach a storefront photo to');
    }
    if (dispute.status !== 'open') {
      // Adding evidence to a ruling already made is not evidence; it is a
      // record that cannot be trusted to be the one the manager read.
      throw new ConflictError(`That wrong-pin report was already ${dispute.status}`);
    }
    // The dispute's createdAt IS the visit's server receipt time: the two rows
    // are written in one transaction (visits.service), and Visit itself carries
    // no server clock — only the device's checkinTs, which is the thing under
    // suspicion here and so cannot be the window's anchor.
    if (Date.now() - dispute.createdAt.getTime() > PIN_DISPUTE_PHOTO_WINDOW_MS) {
      throw new ConflictError(
        'That wrong-pin report is more than a day old; its storefront photo can no longer be added.',
      );
    }
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
      // Recorded going forward (#125). Visit evidence is still scoped through
      // its visit; these make the owner explicit rather than inferred.
      clientId: input.clientId,
      uploadedById: input.agentId,
      section: input.section,
      url: input.dataUrl,
      gpsTag: input.gpsTag,
      timestamp: new Date(input.timestamp),
      source: input.source,
      ...hashes,
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
