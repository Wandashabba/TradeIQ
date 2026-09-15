import { round2 } from '../../lib/kpiMath';

export interface RoiInput {
  /** Sell-in value of orders attributed to the campaign, over its window. */
  attributedRevenue: number;
  /**
   * Sell-in value at the SAME outlets over an equal-length window immediately
   * before the campaign started.
   */
  baselineRevenue: number;
  /** `Campaign.budget`. Null when the campaign has no budget recorded. */
  spend: number | null;
}

export interface Roi {
  attributedRevenue: number;
  baselineRevenue: number;
  /** attributed − baseline. Negative when the campaign period sold less. */
  incrementalRevenue: number;
  spend: number | null;
  /**
   * `(incrementalRevenue − spend) / spend`, as a percentage.
   *
   * **Null, not zero**, when it cannot honestly be computed — see [computeRoi].
   */
  roiPct: number | null;
  /** Why `roiPct` is null, for a UI that must say something truthful. */
  unmeasurable: 'no_budget' | 'zero_budget' | null;
}

/**
 * Campaign return, measured as incremental sell-in against spend.
 *
 * The model is the one #94 specifies: revenue attributed to the campaign, minus
 * what the same outlets were already selling before it started, weighed against
 * what the campaign cost. The baseline is what stops a campaign taking credit
 * for business that would have happened anyway.
 *
 * ## Where this is deliberately silent
 *
 * `roiPct` is **null** rather than a number when the arithmetic would be a
 * fiction:
 *
 * - **no budget recorded** — a campaign with no spend has no return on it.
 *   Reporting 0% would read as "broke even"; reporting infinity would read as
 *   "infinitely profitable". Neither is a measurement.
 * - **budget of exactly zero** — same, and it is also a division by zero.
 *
 * This mirrors how the scorecard treats an unmeasurable dimension (#93): absent
 * rather than zero, because a zero is a claim about the store and a null is an
 * admission about the data. `unmeasurable` carries the reason so a screen can
 * say which, instead of rendering a dash nobody can interpret.
 *
 * ## What this is NOT
 *
 * Sell-in, not sell-through. These orders are what the outlet bought from the
 * client, not what shoppers bought from the outlet — no POS feed exists (#119).
 * A campaign that loaded a retailer's back room looks identical here to one that
 * cleared the shelf. Naming it `attributedRevenue` rather than `sales` is
 * deliberate; do not relabel it in a UI as consumer sales.
 */
export function computeRoi(input: RoiInput): Roi {
  const incrementalRevenue = round2(input.attributedRevenue - input.baselineRevenue);

  let roiPct: number | null = null;
  let unmeasurable: Roi['unmeasurable'] = null;

  if (input.spend === null) {
    unmeasurable = 'no_budget';
  } else if (input.spend === 0) {
    unmeasurable = 'zero_budget';
  } else {
    roiPct = round2((100 * (incrementalRevenue - input.spend)) / input.spend);
  }

  return {
    attributedRevenue: round2(input.attributedRevenue),
    baselineRevenue: round2(input.baselineRevenue),
    incrementalRevenue,
    spend: input.spend,
    roiPct,
    unmeasurable,
  };
}
