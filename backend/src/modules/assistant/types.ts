import type { z } from 'zod';

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
}

/** A tool of unknown arg/return shape — what a roster or a provider handles. */
export type AnyAssistantTool = AssistantTool<ToolArgs, unknown>;
