import { ALL_TOOL_NAMES, type ToolName } from './roster';

/**
 * What a tool costs to get wrong, and therefore whether a human sees it first.
 *
 * **Three tiers, because two is not enough and four is confirmation fatigue.**
 *
 * - `read` — retrieves. Never prompts, never writes an approval row. Gating
 *   reads is how approval UX dies: a prompt that appears constantly is a
 *   prompt nobody reads, and the one that mattered goes through on muscle
 *   memory. This is the named failure mode in the plan, not a guess.
 * - `reversible` — writes something a person can undo from the UI within
 *   seconds: a task created, a note added, a message drafted. Executes
 *   immediately and offers an undo afterwards. Asking first would prompt on
 *   the majority of useful actions.
 * - `irreversible` — writes something that reaches other people, changes who
 *   can log in, or moves money. Never executes without an explicit human yes.
 *
 * The distinction is **not** "does it write". It is *"if the model
 * misunderstood, can the user put it back?"* — which is a question about the
 * blast radius after the fact, not about the verb.
 */
export type RiskTier = 'read' | 'reversible' | 'irreversible';

/**
 * Tool → tier. The policy table, and the whole point of this file.
 *
 * **`satisfies Record<ToolName, RiskTier>` is load-bearing.** It makes this an
 * exhaustive mapping over the roster's registry, so adding a tool there and
 * forgetting it here is a *compile* error rather than a tool that silently
 * inherits whatever the fallback happens to be. That is the same trick
 * `roster.ts` uses for the same reason: a security table computed from, or
 * defaulted around, the things it constrains is not a table.
 *
 * Every entry is `read` today because every tool is a read — Phase 3 has not
 * added a write yet. A table of one value looks redundant right up until the
 * first write tool, at which point it is the thing that forces someone to make
 * a decision instead of inheriting one.
 *
 * ⚠️ **The assignments below are ours, not a customer's.** Open question #2 —
 * *"which actions are truly irreversible in your customers' eyes?"* — is
 * unanswered, and it is a question about their business, not our code. Deleting
 * a draft message is trivial to us and might be a compliance event to them.
 * This table is deliberately the only place the answer lives, so revising it
 * when someone finally asks is one edit and a test update.
 */
export const RISK_TIERS = {
  // Sales
  getRateOfSale: 'read',
  getSkuMovement: 'read',
  getTerritoryRanking: 'read',
  getCampaignPerformance: 'read',
  getSellInForecast: 'read',
  // Stock
  getStockLevels: 'read',
  // Visibility
  getShareOfShelf: 'read',
  getVisibilityCompliance: 'read',
  // Competition
  getCompetitorActivity: 'read',
  getPriceCompliance: 'read',
  // Execution
  getAgentScorecard: 'read',
  getVisitHistory: 'read',
  getFraudFlags: 'read',
  getMetricTrend: 'read',
  getContestStandings: 'read',
  getTaskSummary: 'read',
  getAlerts: 'read',
  findTerritories: 'read',
} as const satisfies Record<ToolName, RiskTier>;

/**
 * The tier a name is classified at.
 *
 * **Fails closed, and says so.** A name absent from the table is not a read —
 * it is a tool somebody added without deciding what it costs, and the safe
 * reading of "I do not know what this does" is the most restrictive one. The
 * alternative default (`read`) would let exactly the dangerous case — a new
 * write tool, merged in a hurry — execute with no prompt and no approval row.
 *
 * The type system already makes this unreachable for any registered tool; this
 * is the runtime half, for the paths where a name arrives as a string (a
 * provider echoing a tool name back, a stored audit row, a hand-made request).
 * It is `console.error` rather than `throw` because refusing to classify would
 * take down the turn, and an unnecessarily prompted action beats an
 * unprompted one.
 */
export function tierOf(toolName: string): RiskTier {
  const known = (RISK_TIERS as Record<string, RiskTier>)[toolName];
  if (known === undefined) {
    console.error(
      `[assistant] no risk tier for tool "${toolName}" — treating it as ` +
        'irreversible. Add it to RISK_TIERS in risk.ts.',
    );
    return 'irreversible';
  }
  return known;
}

/** Reads never prompt and never write an approval row. */
export function isWrite(toolName: string): boolean {
  return tierOf(toolName) !== 'read';
}

/**
 * Whether a human has to say yes *before* this runs.
 *
 * Only `irreversible`. `reversible` executes and offers an undo, which is the
 * trade that keeps the prompt rate low enough for the prompts to mean
 * something — the plan's own tripwire is that more than roughly one turn in
 * ten prompting in a routine session means this tiering is miscalibrated.
 */
export function requiresConfirmation(toolName: string): boolean {
  return tierOf(toolName) === 'irreversible';
}

/** Every tool the registry knows, grouped by what it costs. For the tests and the audit view. */
export function toolsByTier(): Record<RiskTier, ToolName[]> {
  const grouped: Record<RiskTier, ToolName[]> = {
    read: [],
    reversible: [],
    irreversible: [],
  };
  for (const name of ALL_TOOL_NAMES) grouped[tierOf(name)].push(name);
  return grouped;
}
