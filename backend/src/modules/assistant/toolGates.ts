import { competitorPriceGate } from '../competitorPrices/gate';
import type { ToolName } from './roster';

/**
 * Tools that exist in the roster but are declared to the model only when a
 * per-client gate is open.
 *
 * The roster says who MAY see a tool; a gate says whether it is switched on for
 * this business at all. A gated tool is left out of the declarations entirely
 * when its gate is closed — not declared-and-refusing — so a disabled feature
 * costs no tokens, cannot be selected, and cannot be talked into running.
 *
 * Gates default CLOSED: a `ToolContext` built without `gates` (a test, a
 * script, a caller that forgot) sees no gated tool.
 */

export type ToolGate = 'competitorShelfPrices';

export type ToolGates = Readonly<Partial<Record<ToolGate, boolean>>>;

export const GATED_TOOLS: Readonly<Partial<Record<ToolName, ToolGate>>> = {
  getCompetitorShelfPrices: 'competitorShelfPrices',
};

export const ALL_TOOL_GATES: readonly ToolGate[] = ['competitorShelfPrices'];

/** Every gate open. For tests — never for a real caller. */
export const ALL_GATES_OPEN: ToolGates = Object.fromEntries(ALL_TOOL_GATES.map((g) => [g, true]));

/**
 * The gates the live eval sweep (`evals/run.ts`) declares: all of them. Golden
 * questions for a gated tool would otherwise be permanent misses, and the
 * sweep never executes a tool, so opening a gate there reads no data.
 * `evals.test.ts` asserts this covers every gate a golden question names.
 */
export const EVAL_TOOL_GATES: ToolGates = ALL_GATES_OPEN;

export function isToolDeclared(name: string, gates: ToolGates | undefined): boolean {
  const gate = (GATED_TOOLS as Record<string, ToolGate | undefined>)[name];
  return gate === undefined || gates?.[gate] === true;
}

/**
 * Resolve this client's gates for one request. Fails closed: an error reading a
 * gate leaves that gate shut rather than failing the turn.
 */
export async function resolveToolGates(
  clientId: string,
  env: NodeJS.ProcessEnv = process.env,
): Promise<ToolGates> {
  try {
    return { competitorShelfPrices: (await competitorPriceGate(clientId, env)).active };
  } catch (err) {
    console.error('[assistant] could not resolve tool gates; leaving them closed', err);
    return {};
  }
}
