import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { parsePagination } from '../../lib/pagination';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import {
  PhotoViewer,
  createMessageAttachmentPhoto,
  createPhoto,
  getPhotoImage,
  getPhotoThumbnail,
  listPhotosForVisit,
  MESSAGE_ATTACHMENT_SECTION,
  PHOTO_SOURCES,
  type PhotoSource,
} from './photos.service';
import { ThumbnailSourceError } from './thumbnails';

// Phase-1 photos are stored inline as base64 data URLs (see photos.service).
// Cap the payload at ~8MB of base64 so a single upload stays bounded.
const MAX_DATA_URL_LENGTH = 8 * 1024 * 1024;

// A cheap shape check before the service decodes the header for real.
const IMAGE_DATA_URL_PREFIX_RE = /^data:image\/[a-z0-9.+-]+;base64,/i;

export const photosRouter = Router();
photosRouter.use(requireAuth);

function viewerOf(req: AuthedRequest): PhotoViewer {
  const { userId, clientId, role } = req.user!;
  return { userId, clientId, role };
}

photosRouter.post('/', async (req: AuthedRequest, res) => {
  const { visitId, section, dataUrl, gpsTag, timestamp, purpose, source } = req.body as {
    visitId?: unknown;
    section?: unknown;
    dataUrl?: unknown;
    gpsTag?: unknown;
    timestamp?: unknown;
    purpose?: unknown;
    source?: unknown;
  };

  if (purpose !== undefined && purpose !== MESSAGE_ATTACHMENT_SECTION) {
    res.status(400).json({ error: `purpose must be "${MESSAGE_ATTACHMENT_SECTION}" when given` });
    return;
  }

  // A message attachment (#125): the same pipeline, no visit. Any role may send
  // a message, so any role may upload an image for one.
  if (purpose === MESSAGE_ATTACHMENT_SECTION) {
    if (
      typeof dataUrl !== 'string' ||
      !IMAGE_DATA_URL_PREFIX_RE.test(dataUrl) ||
      visitId !== undefined ||
      (timestamp !== undefined &&
        (typeof timestamp !== 'string' || Number.isNaN(new Date(timestamp).getTime()))) ||
      (gpsTag !== undefined && (typeof gpsTag !== 'object' || gpsTag === null || Array.isArray(gpsTag)))
    ) {
      res.status(400).json({
        error:
          'a message attachment needs dataUrl (a base64 image data URL) and no visitId; ' +
          'timestamp (ISO string) and gpsTag (object) are optional',
      });
      return;
    }
    if (dataUrl.length > MAX_DATA_URL_LENGTH) {
      res.status(400).json({ error: 'dataUrl exceeds the maximum allowed size' });
      return;
    }

    const photo = await createMessageAttachmentPhoto({
      clientId: req.user!.clientId,
      uploaderId: req.user!.userId,
      dataUrl,
      gpsTag: gpsTag as Prisma.InputJsonValue | undefined,
      timestamp: timestamp as string | undefined,
    });
    res.status(201).json(photo);
    return;
  }

  // Visit evidence: unchanged — field agents only, onto their own visit.
  if (req.user!.role !== 'field_agent') {
    res.status(403).json({ error: 'Forbidden' });
    return;
  }

  if (
    typeof visitId !== 'string' ||
    typeof section !== 'string' ||
    typeof dataUrl !== 'string' ||
    typeof timestamp !== 'string' ||
    Number.isNaN(new Date(timestamp).getTime()) ||
    typeof gpsTag !== 'object' ||
    gpsTag === null ||
    Array.isArray(gpsTag)
  ) {
    res.status(400).json({
      error:
        'visitId, section, dataUrl, timestamp (ISO string), and gpsTag (object) are required',
    });
    return;
  }

  if (dataUrl.length > MAX_DATA_URL_LENGTH) {
    res.status(400).json({ error: 'dataUrl exceeds the maximum allowed size' });
    return;
  }

  // How the image was obtained (#386 follow-up). Optional for the audit
  // sections, so an older build is unaffected; required to be `camera` for a
  // pin dispute's storefront photo, which createPhoto enforces — the rule
  // belongs beside the row it protects, not only at the door.
  if (source !== undefined && !PHOTO_SOURCES.includes(source as PhotoSource)) {
    res.status(400).json({ error: `source must be one of ${PHOTO_SOURCES.join(', ')} when given` });
    return;
  }

  const photo = await createPhoto({
    visitId,
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
    section,
    dataUrl,
    gpsTag: gpsTag as Prisma.InputJsonValue,
    timestamp,
    source: source as PhotoSource | undefined,
  });
  res.status(201).json(photo);
});

photosRouter.get('/', async (req: AuthedRequest, res) => {
  const { visitId } = req.query as { visitId?: unknown };

  if (typeof visitId !== 'string') {
    res.status(400).json({ error: 'visitId is required' });
    return;
  }

  const photos = await listPhotosForVisit(visitId, req.user!.clientId, parsePagination(req));
  res.status(200).json(photos);
});

// Access rules live in assertPhotoReadable (photos.service): visit evidence is
// readable by any role in its tenant, as before; a message attachment only by
// its sender, its recipient(s), and the tenant's managers/admins. Denials 404.
photosRouter.get('/:id/thumbnail', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };

  let thumbnail: Buffer;
  try {
    thumbnail = await getPhotoThumbnail(id, viewerOf(req));
  } catch (err) {
    if (err instanceof ThumbnailSourceError) {
      // The stored row is broken, not the request — 422, with the reason.
      res.status(422).json({ error: err.message });
      return;
    }
    throw err; // NotFoundError et al. fall through to the errorHandler.
  }

  res
    .status(200)
    .set('Content-Type', 'image/jpeg')
    // private: tenant-scoped bytes must not land in shared caches.
    // immutable: photos are never edited in place, so a day of reuse is safe.
    .set('Cache-Control', 'private, max-age=86400, immutable')
    .send(thumbnail);
});

// The full-size image as raw bytes, under exactly the thumbnail's rules.
photosRouter.get('/:id/image', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };

  let image: { contentType: string; bytes: Buffer };
  try {
    image = await getPhotoImage(id, viewerOf(req));
  } catch (err) {
    if (err instanceof ThumbnailSourceError) {
      res.status(422).json({ error: err.message });
      return;
    }
    throw err;
  }

  res
    .status(200)
    .set('Content-Type', image.contentType)
    .set('Cache-Control', 'private, max-age=86400, immutable')
    .send(image.bytes);
});
