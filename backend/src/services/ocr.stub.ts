// STUB — Phase 2+. Real OCR price extraction is not built. For Phase 1,
// price entry is manual (agent types the shelf price) — this passthrough
// exists so the S5 pricing module has a stable interface to call.
// See: docs/architecture/stubs-and-interfaces.md

export async function extractPriceFromPhoto(_photoUrl: string, manualEntry: number): Promise<number> {
  return manualEntry;
}
