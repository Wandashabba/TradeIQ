import type { Role } from '../auth/auth.service';
import type { Pillar } from './types';

/**
 * The canonical tool registry: every tool name the assistant may ever expose,
 * and the pillar it belongs to.
 *
 * It lives here rather than being derived from the tool implementations on
 * purpose. The roster is the security boundary, and a boundary that is computed
 * from the things it is supposed to constrain is not a boundary — adding a tool
 * would silently widen it. This way a new tool does not reach any role until
 * someone edits the table below and the matrix test is updated to match.
 *
 * Grouped by the four pillars plus execution, which is the manager's own mental
 * model rather than our REST layout.
 */
export const TOOL_REGISTRY = {
  // Sales
  getRateOfSale: 'sales',
  getSkuMovement: 'sales',
  // Stock
  getStockLevels: 'stock',
  // Visibility
  getShareOfShelf: 'visibility',
  getVisibilityCompliance: 'visibility',
  // Competition
  getCompetitorActivity: 'competition',
  // Execution
  getAgentScorecard: 'execution',
  getVisitHistory: 'execution',
  getFraudFlags: 'execution',
} as const satisfies Record<string, Pillar>;

export type ToolName = keyof typeof TOOL_REGISTRY;

export const ALL_TOOL_NAMES = Object.keys(TOOL_REGISTRY) as ToolName[];

/**
 * Role → tools, written out in full for every role.
 *
 * **Not derived from a hierarchy, deliberately.** `admin ⊇ manager ⊇
 * field_agent` happens to hold, and `roster.test.ts` asserts that it holds —
 * but no code here computes one role's set from another's. An
 * inherited-permissions bug is silent and reads as correct; an explicit table
 * is auditable by someone who does not know the codebase.
 *
 * Rosters are also the accuracy control, not only the security one:
 * tool-selection quality degrades past roughly 30–50 visible tools, so no role
 * ever sees the union of everything the system can do.
 */
const ROSTERS: Readonly<Record<Role, readonly ToolName[]>> = {
  /**
   * Empty, and that is the Phase 0 decision rather than an oversight.
   *
   * The assistant is manager-console only for Phase 0 (STATUS.md → Decisions →
   * Audience). The agent app is offline-first: captures queue locally and sync
   * when signal returns, but a chat turn has nothing sensible to queue, so an
   * agent with no signal would get a spinner from an app built specifically to
   * keep working without one.
   *
   * Field agents also author the free text that is the injection vector —
   * outlet names, visit notes — and they outnumber managers, so granting them a
   * roster widens the red-team and rate-limit surface for demand nobody has
   * demonstrated.
   *
   * Revisit at Phase 5, and as a narrow non-chat surface rather than the full
   * spine. Until then this staying empty is what makes the negative case in the
   * matrix test meaningful.
   */
  field_agent: [],

  manager: [
    'getRateOfSale',
    'getSkuMovement',
    'getStockLevels',
    'getShareOfShelf',
    'getVisibilityCompliance',
    'getCompetitorActivity',
    'getAgentScorecard',
    'getVisitHistory',
    'getFraudFlags',
  ],

  // Written out rather than spread from `manager`. Identical today; the point
  // is that it stays visible when it stops being identical.
  admin: [
    'getRateOfSale',
    'getSkuMovement',
    'getStockLevels',
    'getShareOfShelf',
    'getVisibilityCompliance',
    'getCompetitorActivity',
    'getAgentScorecard',
    'getVisitHistory',
    'getFraudFlags',
  ],
};

/**
 * The tools a role may see this turn. Pure, and exhaustively tested.
 *
 * Returns a **fresh set per call**, deliberately. `Object.freeze` does not make
 * a `Set` immutable — its contents live in internal slots rather than in
 * properties, so a frozen `Set` still accepts `.add()` without complaint. A
 * shared "frozen" roster would therefore be quietly mutable by any caller, and
 * the mutation would persist for every later request in the process. Copying is
 * the only cheap way to actually hold the boundary, and at nine entries beside
 * an LLM call the cost does not register.
 *
 * Fails **closed** on a role the table does not know. `Role` is a compile-time
 * union so this should be unreachable, but the one caller that matters reads a
 * role out of a JWT — and a value that arrives over the wire is worth treating
 * as data even when the type says otherwise. Returning "no tools" for an
 * unrecognised role is the only safe direction to be wrong in.
 */
export function rosterFor(role: Role): ReadonlySet<string> {
  return new Set<string>(ROSTERS[role] ?? []);
}

/** The pillar a tool belongs to, for the `tool_start` affordance. */
export function pillarOf(name: ToolName): Pillar {
  return TOOL_REGISTRY[name];
}
