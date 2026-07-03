// STUB — Phase 2+. Real on-device/server computer vision for branding
// detection, planogram compliance, facings count, and cleanliness scoring
// is not built. This weighted-random implementation exists so Phase 1
// callers (S3/S4 visibility+display screens) have a working interface to
// build against. See: docs/architecture/stubs-and-interfaces.md
// Tracking issue: https://github.com/Wandashabba/TradeIQ/issues/1

export interface BrandingResult {
  pass: boolean;
  elementsDetected: number;
}

const TOTAL_BRANDING_ELEMENTS = 8;
const PASS_WEIGHT = 0.8;

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export async function detectBranding(_photoUrl: string): Promise<BrandingResult> {
  const elementsDetected = Array.from({ length: TOTAL_BRANDING_ELEMENTS }).filter(
    () => Math.random() < PASS_WEIGHT,
  ).length;
  return { pass: elementsDetected === TOTAL_BRANDING_ELEMENTS, elementsDetected };
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export async function scorePlanogramCompliance(_photoUrl: string, _templateId: string): Promise<number> {
  return Math.round((0.6 + Math.random() * 0.4) * 100) / 100;
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export async function countFacings(_photoUrl: string, _skuId: string): Promise<number> {
  return Math.floor(Math.random() * 6) + 1;
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export async function scoreCleanliness(_photoUrl: string): Promise<number> {
  return Math.ceil(Math.random() * 5);
}
