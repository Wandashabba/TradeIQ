// STUB — Phase 2+. Predictive field dispatch is not built in Phase 1. No
// Phase 1 caller exists yet; this throws so any accidental call fails
// loudly instead of silently returning fake data.
// See: docs/architecture/stubs-and-interfaces.md
import { NotImplementedError } from '../middleware/errorHandler';

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export async function dispatchNearestAgent(_outletId: string): Promise<never> {
  throw new NotImplementedError('Predictive dispatch is not implemented in Phase 1');
}
