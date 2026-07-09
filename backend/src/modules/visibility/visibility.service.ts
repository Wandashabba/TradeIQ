import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import {
  countFacings,
  detectBranding,
  scoreCleanliness,
  scorePlanogramCompliance,
} from '../../services/vision.stub';

export interface RecordVisibilityInput {
  visitId: string;
  clientId: string;
  // highTrafficPass is a manual field in both the vision-assisted and
  // manual-entry paths.
  highTrafficPass: boolean;
  // Manual-entry fields — required when photoUrl is absent.
  brandingElements?: Prisma.InputJsonValue;
  planogramCompliancePct?: number;
  facingsCount?: Prisma.InputJsonValue;
  cleanlinessScore?: number;
  // Vision-assisted capture — when photoUrl is a non-empty string the vision
  // fields are derived from the CV stub instead of the client-supplied values.
  photoUrl?: string;
  templateId?: string;
  skuId?: string;
}

interface VisibilityFields {
  brandingElements: Prisma.InputJsonValue;
  planogramCompliancePct: number;
  facingsCount: Prisma.InputJsonValue;
  highTrafficPass: boolean;
  cleanlinessScore: number;
}

export async function recordVisibility(input: RecordVisibilityInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  let fields: VisibilityFields;
  if (input.photoUrl) {
    // S3–S4 computer-vision seam. Phase 1 uses the weighted-random stub in
    // services/vision.stub.ts; real on-device/server CV swaps in right here
    // (issue #1). When a photo is supplied we derive the vision fields from the
    // stub rather than trusting client-provided values.
    const [branding, planogram, facings, cleanliness] = await Promise.all([
      detectBranding(input.photoUrl),
      scorePlanogramCompliance(input.photoUrl, input.templateId ?? ''),
      countFacings(input.photoUrl, input.skuId ?? ''),
      scoreCleanliness(input.photoUrl),
    ]);

    // Merge the stub's branding result over any manual brandingElements object.
    const manualBranding: Record<string, unknown> =
      typeof input.brandingElements === 'object' &&
      input.brandingElements !== null &&
      !Array.isArray(input.brandingElements)
        ? (input.brandingElements as unknown as Record<string, unknown>)
        : {};
    const mergedBranding = {
      ...manualBranding,
      detected: branding.elementsDetected,
      pass: branding.pass,
    };

    fields = {
      // Cast through unknown: the merged object's values are unknown-typed, so
      // it is not directly assignable to Prisma's Json input union.
      brandingElements: mergedBranding as unknown as Prisma.InputJsonValue,
      // Stub returns 0..1; store as a 0..100 percentage.
      planogramCompliancePct: planogram * 100,
      facingsCount: { total: facings } as Prisma.InputJsonValue,
      highTrafficPass: input.highTrafficPass,
      cleanlinessScore: cleanliness,
    };
  } else {
    // Manual-entry path — trust the validated client-provided values.
    fields = {
      brandingElements: input.brandingElements as Prisma.InputJsonValue,
      planogramCompliancePct: input.planogramCompliancePct as number,
      facingsCount: input.facingsCount as Prisma.InputJsonValue,
      highTrafficPass: input.highTrafficPass,
      cleanlinessScore: input.cleanlinessScore as number,
    };
  }

  // One VisitVisibility per visit (unique visitId) — upsert so re-submitting
  // the section is idempotent.
  return prisma.visitVisibility.upsert({
    where: { visitId: input.visitId },
    create: { visitId: input.visitId, ...fields },
    update: fields,
  });
}

export async function getVisibility(input: { visitId: string; clientId: string }) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const visibility = await prisma.visitVisibility.findUnique({
    where: { visitId: input.visitId },
  });
  if (!visibility) {
    throw new NotFoundError('Visibility not found');
  }
  return visibility;
}
