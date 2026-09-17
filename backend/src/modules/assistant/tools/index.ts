import { rosterFor, type ToolName } from '../roster';
import { isToolDeclared } from '../toolGates';
import type { AnyAssistantTool } from '../types';
import { buildCompetitorPriceTools } from './competitorPrices';
import { buildExecutionTools, type ToolContext } from './execution';
import { buildOperationTools } from './operations';
import { buildPillarTools } from './pillars';
import { buildTrendTools } from './trends';

export type { ToolContext } from './execution';

/**
 * Build every tool this caller may reach, in a stable order.
 *
 * **The only place identity enters the tool layer.** Tools are constructed per
 * request as closures over `ctx.user`; nothing below this function takes a
 * tenant argument, so the model has no way to ask for one.
 *
 * Two filters run, and they are not redundant:
 *
 * 1. The **roster** decides what this role may see. It is the security boundary
 *    and it is a table, not a computation over the implementations.
 * 2. The **registry** decides what exists. A tool implemented but absent from
 *    `TOOL_REGISTRY` reaches nobody, which is the direction a mistake here
 *    should fail in — adding a file must not silently widen the boundary.
 * 3. The **gates** decide what is switched on for this business. A gated tool
 *    (`toolGates.ts`) whose gate is not open in `ctx.gates` is not declared at
 *    all — the model never learns it exists.
 */
export function buildTools(ctx: ToolContext): AnyAssistantTool[] {
  const implemented = [
    ...buildExecutionTools(ctx),
    ...buildPillarTools(ctx),
    ...buildTrendTools(ctx),
    ...buildOperationTools(ctx),
    ...buildCompetitorPriceTools(ctx),
  ];
  const allowed = rosterFor(ctx.user.role);

  // Ordering is the roster's, not the implementation files'. Tool declarations
  // sit inside the cached prompt prefix, so a reordering is a cache miss with
  // no functional symptom — and file order changes whenever someone adds a
  // pillar file.
  const byName = new Map(implemented.map((tool) => [tool.name, tool]));

  return [...allowed]
    .filter((name) => isToolDeclared(name, ctx.gates))
    .map((name) => byName.get(name))
    .filter((tool): tool is AnyAssistantTool => tool !== undefined);
}

/**
 * Which roster entries have no implementation yet.
 *
 * Phase 0 lands the pillars incrementally, so a gap is expected rather than a
 * bug. It is surfaced instead of ignored because the *silent* version of this
 * gap — a tool the model is told about and cannot call — is a failed turn with
 * no explanation. `buildTools` filters those out; this is how a caller can log
 * what is still missing.
 */
export function unimplementedTools(ctx: ToolContext): ToolName[] {
  const implemented = new Set(
    [
      ...buildExecutionTools(ctx),
      ...buildPillarTools(ctx),
      ...buildTrendTools(ctx),
      ...buildOperationTools(ctx),
      ...buildCompetitorPriceTools(ctx),
    ].map(
      (tool) => tool.name,
    ),
  );
  return [...rosterFor(ctx.user.role)].filter((name) => !implemented.has(name)) as ToolName[];
}
