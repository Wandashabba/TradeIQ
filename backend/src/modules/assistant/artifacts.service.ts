import { prisma } from '../../lib/prisma';
import type { ArtifactParamsChange } from './paramsNote';
import { resolveToolGates } from './toolGates';
import { buildTools, type ToolContext } from './tools';
import type { AnyAssistantTool, ToolArgs } from './types';

/**
 * Persistence and refinement for artifacts.
 *
 * **An artifact stores what to re-run, never what came back.** The row holds a
 * tool name and a bag of parameters; every read re-invokes that tool through a
 * roster built for whoever is asking *now*. That is the whole security design:
 * there is no stored copy of tenant data to leak, no cached answer to go stale,
 * and no second authorisation path to keep in step with the first. A refine by
 * a user whose role lost a tool simply cannot find it.
 *
 * **Params are validated by the tool's own Zod schema, not by a schema written
 * here.** The plan calls the params schema "the single contract both the model
 * and the UI write through" — two schemas would be two contracts, and the one
 * that drifts is always the one the attacker uses. `refineArtifact` therefore
 * runs the *same* `tool.args.safeParse` the orchestrator runs, which is what
 * makes a hand-edited `refine` payload unable to widen scope: the tool closure
 * has no parameter for tenant, and Zod rejects anything the tool did not
 * declare.
 */

/**
 * How many previous parameter sets an artifact remembers.
 *
 * The plan caps this at 20. It is a JSON column on a row that is written on
 * every filter change, so an uncapped history is an unbounded row — and nobody
 * has ever wanted the 21st undo.
 */
export const PARAMS_HISTORY_LIMIT = 20;

export class ArtifactNotFoundError extends Error {
  constructor() {
    // Deliberately indistinguishable from "belongs to someone else". Telling a
    // caller that an id exists but is not theirs is an existence oracle across
    // tenants — the same reasoning that made Outlet.code per-tenant unique.
    super('No such artifact.');
    this.name = 'ArtifactNotFoundError';
  }
}

export class ToolUnavailableError extends Error {
  constructor(toolName: string) {
    super(`This view cannot be refreshed: ${toolName} is not available to you.`);
    this.name = 'ToolUnavailableError';
  }
}

export class InvalidParamsError extends Error {
  readonly issues: unknown;
  constructor(issues: unknown) {
    super('Those parameters are not valid for this view.');
    this.name = 'InvalidParamsError';
    this.issues = issues;
  }
}

export interface ArtifactOwner {
  userId: string;
  clientId: string;
}

export interface StoredArtifact {
  id: string;
  type: string;
  toolName: string;
  params: ToolArgs;
  createdAt: Date;
  updatedAt: Date;
}

export interface ArtifactWithData extends StoredArtifact {
  data: unknown;
  /** Whether an undo is available — the UI should not offer a dead control. */
  canUndo: boolean;
}

function toStored(row: {
  id: string;
  type: string;
  toolName: string;
  params: unknown;
  createdAt: Date;
  updatedAt: Date;
}): StoredArtifact {
  return {
    id: row.id,
    type: row.type,
    toolName: row.toolName,
    params: (row.params ?? {}) as ToolArgs,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

function historyOf(row: { paramsHistory: unknown }): ToolArgs[] {
  return Array.isArray(row.paramsHistory) ? (row.paramsHistory as ToolArgs[]) : [];
}

/** Persist an artifact a turn produced. */
export async function createArtifact(input: {
  owner: ArtifactOwner;
  conversationId: string;
  type: string;
  toolName: string;
  params: ToolArgs;
}): Promise<StoredArtifact> {
  const row = await prisma.assistantArtifact.create({
    data: {
      clientId: input.owner.clientId,
      userId: input.owner.userId,
      conversationId: input.conversationId,
      type: input.type,
      toolName: input.toolName,
      params: input.params as object,
      paramsHistory: [],
    },
  });
  return toStored(row);
}

/**
 * Fetch one artifact, scoped to its owner.
 *
 * Scoping lives in the `where` clause rather than in a check after the read, so
 * there is no window in which the row is in memory before anyone has asked
 * whether the caller is entitled to it.
 */
async function loadOwned(id: string, owner: ArtifactOwner) {
  const row = await prisma.assistantArtifact.findFirst({
    where: { id, clientId: owner.clientId, userId: owner.userId },
  });
  if (!row) throw new ArtifactNotFoundError();
  return row;
}

/**
 * The tool this artifact re-runs, resolved through the caller's own roster.
 *
 * Built per call, never cached: a roster is a function of the caller's role,
 * and reusing one across callers is precisely the bug this shape prevents.
 */
function toolFor(ctx: ToolContext, toolName: string): AnyAssistantTool {
  const tool = buildTools(ctx).find((candidate) => candidate.name === toolName);
  if (!tool) throw new ToolUnavailableError(toolName);
  return tool;
}

async function runWithParams(
  ctx: ToolContext,
  toolName: string,
  params: unknown,
): Promise<{ params: ToolArgs; data: unknown }> {
  // Gates are resolved per call like the roster: a gated tool switched off since
  // the artifact was made is not found, exactly as a role that lost it is not.
  const gated = ctx.gates ? ctx : { ...ctx, gates: await resolveToolGates(ctx.user.clientId) };
  const tool = toolFor(gated, toolName);
  // The tool's schema, not one of ours. See the file header.
  const parsed = tool.args.safeParse(params);
  if (!parsed.success) throw new InvalidParamsError(parsed.error.issues);
  return { params: parsed.data, data: await tool.run(parsed.data) };
}

/** Rehydrate an artifact on reopen — fresh data, stored params. */
export async function readArtifact(
  id: string,
  ctx: ToolContext,
): Promise<ArtifactWithData> {
  const owner = { userId: ctx.user.userId, clientId: ctx.user.clientId };
  const row = await loadOwned(id, owner);
  const { data } = await runWithParams(ctx, row.toolName, row.params);
  return { ...toStored(row), data, canUndo: historyOf(row).length > 0 };
}

/**
 * Apply new parameters and return fresh data.
 *
 * **No model call.** A filter change is a re-query, not a conversation: routing
 * it through the orchestrator would cost a paid turn, add latency the control
 * cannot hide, and give the model an opportunity to decide something the user
 * already decided.
 */
export async function refineArtifact(
  id: string,
  params: unknown,
  ctx: ToolContext,
): Promise<ArtifactWithData> {
  const owner = { userId: ctx.user.userId, clientId: ctx.user.clientId };
  const row = await loadOwned(id, owner);

  // Run before writing. A rejected params bag must leave the artifact exactly
  // as it was, or a typo in a filter costs the user their undo history.
  const { params: valid, data } = await runWithParams(ctx, row.toolName, params);

  const history = [...historyOf(row), toStored(row).params].slice(-PARAMS_HISTORY_LIMIT);
  const updated = await prisma.assistantArtifact.update({
    where: { id: row.id },
    data: {
      params: valid as object,
      paramsHistory: history as object[],
      // Flagged, not narrated. The note the model eventually reads is rendered
      // at turn time from whatever the params are *then*, so three drags of the
      // same slider collapse into one honest statement of where it ended up
      // rather than three stale ones.
      paramsChangedAt: new Date(),
    },
  });

  return { ...toStored(updated), data, canUndo: history.length > 0 };
}

/** Pop the last parameter set. */
export async function undoArtifact(id: string, ctx: ToolContext): Promise<ArtifactWithData> {
  const owner = { userId: ctx.user.userId, clientId: ctx.user.clientId };
  const row = await loadOwned(id, owner);

  const history = historyOf(row);
  const previous = history[history.length - 1];
  // Nothing to undo is not an error. The control is idempotent at the bottom of
  // the stack, which is friendlier than a 400 for pressing it once too often.
  if (previous === undefined) {
    const { data } = await runWithParams(ctx, row.toolName, row.params);
    return { ...toStored(row), data, canUndo: false };
  }

  // Re-run before writing, exactly as refine does: a stored params bag can stop
  // being runnable (a deleted territory), and discovering that must not also
  // destroy the history entry that would let the user step back further.
  const { params: valid, data } = await runWithParams(ctx, row.toolName, previous);
  const remaining = history.slice(0, -1);
  const updated = await prisma.assistantArtifact.update({
    where: { id: row.id },
    data: {
      params: valid as object,
      paramsHistory: remaining as object[],
      // An undo is a UI-driven change like any other. Leaving it unflagged
      // would be the worst case of all: the model told about a change, then
      // never told it was taken back.
      paramsChangedAt: new Date(),
    },
  });

  return { ...toStored(updated), data, canUndo: remaining.length > 0 };
}

/**
 * The live artifacts of one conversation, newest first.
 *
 * Injected into context so the model can target an artifact that already exists
 * instead of emitting a near-duplicate beside it. Params travel; data does not —
 * the model is choosing what to refine, not reading the figures.
 */
export async function artifactManifest(
  conversationId: string,
  owner: ArtifactOwner,
  limit = 10,
): Promise<Array<{ id: string; type: string; params: ToolArgs }>> {
  const rows = await prisma.assistantArtifact.findMany({
    where: { conversationId, clientId: owner.clientId, userId: owner.userId },
    orderBy: { updatedAt: 'desc' },
    take: limit,
  });
  return rows.map((row) => ({
    id: row.id,
    type: row.type,
    params: (row.params ?? {}) as ToolArgs,
  }));
}

/**
 * The UI-driven changes this conversation has not told the model about — and
 * clearing them as it hands them over.
 *
 * "Take" rather than "list": reading them is what marks them delivered, so a
 * change is announced on exactly one turn. Announcing it every turn afterwards
 * would spend tokens restating what the manifest already carries, and never
 * announcing it is the stale-params bug this exists to close.
 *
 * Oldest first, because the order the user moved the controls in is the order
 * that reads correctly. Bounded for the same reason the manifest is: a note is
 * meant to cost a few tokens.
 *
 * A change made *between* the read and the clear survives — the clear is
 * bounded by the newest timestamp actually returned, not by "everything
 * currently flagged". The alternative silently swallows a filter change that
 * landed mid-turn, which is precisely the failure this function exists to
 * prevent.
 */
export async function takeParamsChanges(
  conversationId: string,
  owner: ArtifactOwner,
  limit = 10,
): Promise<ArtifactParamsChange[]> {
  const rows = await prisma.assistantArtifact.findMany({
    where: {
      conversationId,
      clientId: owner.clientId,
      userId: owner.userId,
      paramsChangedAt: { not: null },
    },
    orderBy: { paramsChangedAt: 'asc' },
    take: limit,
  });
  if (rows.length === 0) return [];

  const cutoff = rows[rows.length - 1].paramsChangedAt!;
  // Raw, deliberately: `update` would touch `updatedAt`, and marking a note
  // delivered is bookkeeping, not a change to the view. A bumped `updatedAt`
  // would reorder the manifest and tell the client the artifact moved when
  // nothing about it did.
  await prisma.$executeRaw`
    UPDATE assistant_artifacts
       SET params_changed_at = NULL
     WHERE conversation_id = ${conversationId}
       AND client_id = ${owner.clientId}
       AND user_id = ${owner.userId}
       AND params_changed_at <= ${cutoff}`;

  return rows.map((row) => ({
    id: row.id,
    type: row.type,
    params: (row.params ?? {}) as ToolArgs,
  }));
}
