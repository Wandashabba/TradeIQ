import type { z } from 'zod';
import type { FigureArtifact } from './figures';

/**
 * The four pillars a manager actually thinks in, plus execution quality.
 *
 * Taken verbatim from the 2026-07-29 practitioner interview — *"Sales, stock,
 * visibility, and competition. Those are your four pillars… that's what is
 * feeding to the business."* Tools are grouped by pillar rather than by REST
 * endpoint because a manager asks "how's my visibility in Western Cape", not
 * "GET /visibility?territory=".
 */
export type Pillar = 'sales' | 'stock' | 'visibility' | 'competition' | 'execution';

/** Business arguments only. Validated by the tool's own Zod schema. */
export type ToolArgs = Record<string, unknown>;

/**
 * A tool is a **closure**, not a function that takes a tenant argument.
 *
 * `run` is already bound to the authenticated caller by the time the model can
 * reach it, so there is no parameter through which the model could widen scope.
 * Tenant isolation is therefore enforced by the type signature rather than by
 * a validation step somebody has to remember to write — the difference between
 * a boundary that holds and one that holds until the next new tool.
 *
 * **Rule:** if an `args` schema ever contains `clientId`, `tenantId` or
 * `userId`, that is a defect. `roster.test.ts` asserts it.
 */
export interface AssistantTool<A extends ToolArgs = ToolArgs, R = unknown> {
  /** Stable — it is part of the cached prompt prefix. Renaming costs a cache miss. */
  readonly name: string;
  readonly pillar: Pillar;
  /**
   * Prescriptive, not descriptive: "Call this when the user asks about stock
   * levels or availability", never "Returns stock levels". Stating the trigger
   * condition measurably improves should-call rate.
   */
  readonly description: string;
  readonly args: z.ZodType<A>;
  /** Already bound to the caller. Identity never crosses this signature. */
  readonly run: (args: A) => Promise<R>;
  /**
   * What this tool's result draws, if anything.
   *
   * **The model never emits UI.** It chooses a tool; the tool declares which
   * spec from the closed catalog its data renders as. That is what makes the
   * catalog a real constraint rather than a suggestion — there is no path by
   * which a model could name a spec type at all.
   *
   * Returning `null` is normal: a tool whose answer is a sentence has nothing
   * to draw, and a blank card would be worse than prose.
   */
  readonly view?: (args: A, result: R) => { type: string; params: unknown } | null;
  /**
   * Stat tiles and ranked bars built from this tool's result.
   *
   * **Deterministic, and never model-authored.** A tool computes these from the
   * exact result it returned, with the pure builders in `figures.ts` — so a
   * number on a tile is the number the model read, and the model has no path
   * by which to put a figure on one. Async only because a builder may need the
   * client's timezone, which the tool has already resolved and cached; it must
   * never issue a new query to fill a card.
   *
   * An empty array is normal: a result with nothing honest to show draws
   * nothing rather than a card of zeros.
   */
  readonly figures?: (args: A, result: R) => Promise<FigureArtifact[]> | FigureArtifact[];
}

/** A tool of unknown arg/return shape — what a roster or a provider handles. */
export type AnyAssistantTool = AssistantTool<ToolArgs, unknown>;

/**
 * A tool failure whose message is **safe to show the model**.
 *
 * The orchestrator deliberately replaces a thrown tool error with a generic
 * line, and it is right to: a Prisma error carries table and column names
 * straight into context, and a stack trace is worse. But that also destroys the
 * failures that are *actionable* — "there are two people matching Sipho, which
 * one?" is information the model needs in order to ask a sensible follow-up,
 * and hiding it turns a one-question clarification into a dead end.
 *
 * So a tool opts in. Throwing this says: I wrote this string, I know it reaches
 * the model, and it contains nothing but what the caller is already entitled to
 * see. Anything else stays generic.
 *
 * **It must never carry data from outside the caller's tenant** — the closure
 * makes that hard to do by accident, but this is the one path where a tool
 * chooses its own wording, so it is worth saying out loud.
 */
export class ToolFacingError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ToolFacingError';
  }
}

/**
 * Erase a tool's argument type so it can sit in a heterogeneous roster.
 *
 * `run` takes its arguments, which makes `AssistantTool` contravariant in `A` —
 * a `Tool<{agentId: string}>` is genuinely *not* assignable to a
 * `Tool<ToolArgs>`, and TypeScript is right to say so. A collection of tools
 * with different argument shapes cannot be typed any other way.
 *
 * **The cast inside is guarded by a real runtime check, not by hope.** The
 * orchestrator calls `tool.args.safeParse(...)` and only invokes `run` with the
 * parsed value, so by the time `args as A` executes, Zod has already proven the
 * shape. Doing the erasure here — in one function, next to that explanation —
 * is what keeps the assertion from being scattered across every pillar file
 * where the reasoning would be re-derived or, more likely, not.
 */
export function eraseToolTypes<A extends ToolArgs, R>(tool: AssistantTool<A, R>): AnyAssistantTool {
  return {
    name: tool.name,
    pillar: tool.pillar,
    description: tool.description,
    args: tool.args as unknown as z.ZodType<ToolArgs>,
    run: (args: ToolArgs) => tool.run(args as A),
    ...(tool.view
      ? { view: (args: ToolArgs, result: unknown) => tool.view!(args as A, result as R) }
      : {}),
    ...(tool.figures
      ? { figures: (args: ToolArgs, result: unknown) => tool.figures!(args as A, result as R) }
      : {}),
  };
}
