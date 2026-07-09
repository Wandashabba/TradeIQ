import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { createPhoto, listPhotosForVisit } from './photos.service';

// Phase-1 photos are stored inline as base64 data URLs (see photos.service).
// Cap the payload at ~8MB of base64 so a single upload stays bounded.
const MAX_DATA_URL_LENGTH = 8 * 1024 * 1024;

export const photosRouter = Router();
photosRouter.use(requireAuth);

photosRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { visitId, section, dataUrl, gpsTag, timestamp } = req.body as {
    visitId?: unknown;
    section?: unknown;
    dataUrl?: unknown;
    gpsTag?: unknown;
    timestamp?: unknown;
  };

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

  const photo = await createPhoto({
    visitId,
    clientId: req.user!.clientId,
    section,
    dataUrl,
    gpsTag: gpsTag as Prisma.InputJsonValue,
    timestamp,
  });
  res.status(201).json(photo);
});

photosRouter.get('/', async (req: AuthedRequest, res) => {
  const { visitId } = req.query as { visitId?: unknown };

  if (typeof visitId !== 'string') {
    res.status(400).json({ error: 'visitId is required' });
    return;
  }

  const photos = await listPhotosForVisit(visitId, req.user!.clientId);
  res.status(200).json(photos);
});
