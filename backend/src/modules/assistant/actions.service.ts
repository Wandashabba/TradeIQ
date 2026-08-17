import { prisma } from '../../lib/prisma';
import { tierOf, type RiskTier } from './risk';

/**
 * The write ledger.
 *
 * **Written before the action, resolved after it.** An action that throws
 * halfway, or that the process dies during, still leaves a row — stuck at
 * `requested`, which is a legible state rather than an absence. That is the
 * property the whole thing turns on: *no row means never attempted*. A ledger
 * written only on success cannot tell "nobody tried" from "it blew up", and
 * those are opposite answers in an incident.
 *
 * **Refusals are recorded too.** The rows nobody wants to read are the ones
 * that matter: a tenant repeatedly asking for something it cannot have is a
 * signal, and it is invisible in a success-only log.
 *
 * **Never throws into the turn.** Audit is a side record, not the work. A
 * ledger write that fails must not also cost the user their action — it is
 * logged loudly and the action proceeds. The alternative trades a
 * completeness problem for an availability one, and hands anyone who can break
 * the ledger a way to break every write.
 */

/** Where an action got to. */
export type ActionOutcome =
  /** Row opened; the action has not run yet. A row left here is a crash. */
  | 'requested'
  /** Tier 3, waiting on a human. Resolves to `executed` or `rejected`. */
  | 'awaiting_confirmation'
  /** It ran and succeeded. */
  | 'executed'
  /** The system said no — roster, tenant scope, validation. Never reached the service. */
  | 'refused'
  /** A human said no. Distinct from `refused`: one is policy, the other is judgement. */
  | 'rejected'
  /** It ran and threw. */
  | 'failed';

export interface ActionActor {
  userId: string;
  clientId: string;
}

export interface RecordedAction {
  id: string;
  toolName: string;
  tier: RiskTier;
  outcome: ActionOutcome;
  args: unknown;
  detail: string | null;
  undoContext: unknown;
  createdAt: Date;
  resolvedAt: Date | null;
}

/**
 * Open a ledger row for an action about to be attempted.
 *
 * The tier is captured here rather than looked up when the ledger is read.
 * Re-deriving it later would rewrite history every time the policy table
 * changes, and "what did we consider risky at the time" is exactly the question
 * an auditor asks.
 */
export async function openAction(input: {
  actor: ActionActor;
  conversationId?: string;
  toolName: string;
  args: unknown;
  outcome?: Extract<ActionOutcome, 'requested' | 'awaiting_confirmation'>;
}): Promise<string | null> {
  try {
    const row = await prisma.assistantAction.create({
      data: {
        clientId: input.actor.clientId,
        userId: input.actor.userId,
        conversationId: input.conversationId ?? null,
        toolName: input.toolName,
        tier: tierOf(input.toolName),
        args: (input.args ?? {}) as object,
        outcome: input.outcome ?? 'requested',
      },
      select: { id: true },
    });
    return row.id;
  } catch (err) {
    // Null rather than a throw: see the file header. The caller carries on.
    console.error('[assistant] could not open an action ledger row', err);
    return null;
  }
}

/**
 * Close a row out with what happened.
 *
 * Tolerates a null id so the caller does not need a branch for "the ledger was
 * down when we opened this". The action already ran; failing here would only
 * turn a missing audit row into a failed user request.
 */
export async function resolveAction(
  id: string | null,
  outcome: Exclude<ActionOutcome, 'requested'>,
  extra?: { detail?: string; undoContext?: unknown },
): Promise<void> {
  if (id === null) return;
  try {
    await prisma.assistantAction.update({
      where: { id },
      data: {
        outcome,
        detail: extra?.detail ?? null,
        // Only written when supplied. Passing `null` through would clear undo
        // context that a previous resolve had already stored — and a nullable
        // Json column needs `Prisma.DbNull` rather than `null` anyway, which is
        // a distinction worth not having to remember at every call site.
        ...(extra?.undoContext === undefined
          ? {}
          : { undoContext: extra.undoContext as object }),
        // `awaiting_confirmation` is not an ending — a tier-3 action sits there
        // until a human answers, and stamping it resolved would make an
        // unanswered prompt look settled.
        resolvedAt: outcome === 'awaiting_confirmation' ? null : new Date(),
      },
    });
  } catch (err) {
    console.error('[assistant] could not resolve action ledger row', id, err);
  }
}

/**
 * Record an action that never got as far as running.
 *
 * A refusal has no before-and-after, so it opens and closes in one write. Kept
 * separate from `openAction` so a caller cannot accidentally leave a refusal
 * sitting at `requested` and have it read as a crash.
 */
export async function recordRefusal(input: {
  actor: ActionActor;
  conversationId?: string;
  toolName: string;
  args: unknown;
  detail: string;
}): Promise<void> {
  const id = await openAction({ ...input, outcome: 'requested' });
  await resolveAction(id, 'refused', { detail: input.detail });
}

/**
 * The ledger for one tenant, newest first.
 *
 * **Tenant scoping is in the `where`, not in a check afterwards** — the same
 * shape as `loadOwned` in artifacts.service.ts, and for the same reason: there
 * is no window in which another tenant's rows are in memory.
 *
 * Deliberately NOT scoped to one user by default. The audit view exists so a
 * manager can see what the assistant did across their business; narrowing it to
 * the caller would make it a personal history and answer a different question.
 * `userId` narrows it when asked.
 */
export async function listActions(
  clientId: string,
  filter: { userId?: string; toolName?: string; tier?: RiskTier; limit?: number } = {},
): Promise<RecordedAction[]> {
  const rows = await prisma.assistantAction.findMany({
    where: {
      clientId,
      ...(filter.userId ? { userId: filter.userId } : {}),
      ...(filter.toolName ? { toolName: filter.toolName } : {}),
      ...(filter.tier ? { tier: filter.tier } : {}),
    },
    orderBy: { createdAt: 'desc' },
    // Bounded by default. An audit table grows without limit by design, so the
    // one query guaranteed to be run against the biggest version of it should
    // not be the unbounded one.
    take: Math.min(filter.limit ?? 50, 200),
  });

  return rows.map((row) => ({
    id: row.id,
    toolName: row.toolName,
    tier: row.tier as RiskTier,
    outcome: row.outcome as ActionOutcome,
    args: row.args,
    detail: row.detail,
    undoContext: row.undoContext,
    createdAt: row.createdAt,
    resolvedAt: row.resolvedAt,
  }));
}
