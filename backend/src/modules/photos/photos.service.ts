import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

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
