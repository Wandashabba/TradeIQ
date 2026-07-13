/**
 * Runtime feature flags.
 *
 * `VISION_ENABLED` gates the computer-vision seam in
 * `modules/visibility/visibility.service.ts`.
 *
 * It defaults to **off**, and that default is load-bearing. While the CV
 * implementation is `services/vision.stub.ts` — which is literally
 * `Math.random()` — taking the vision path means a real, measured planogram
 * percentage, facings count and cleanliness score captured by an agent in a
 * store get *replaced* by generated numbers. Those fields feed the scorecard,
 * the dashboard's visibility-compliance and share-of-shelf KPIs, and the
 * perfect-store trend, so the damage is invisible and downstream.
 *
 * Turning this on is therefore a deliberate act, taken when a real model is
 * wired in behind the same interface (#1). Until then, a photo supplied to
 * `POST /visibility` is stored as evidence and the agent's own values are kept.
 *
 * See #92.
 */
export function isVisionEnabled(): boolean {
  return process.env.VISION_ENABLED === 'true';
}
