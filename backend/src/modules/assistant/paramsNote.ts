/**
 * The `[artifact:<id> params → …]` note.
 *
 * **The problem it solves.** A user drags a filter, the artifact re-runs
 * through `/artifacts/:id/refine`, and the model is never told. The next
 * question — *"now break that down by territory"* — is then answered against
 * the params the model last saw, confidently and wrongly. The manifest covers
 * what is open at the start of a turn; this covers a change the user made in
 * between, and says who made it.
 *
 * **It rides with the user message, never the system prompt.** The cached
 * prefix is `[tools][system]` and caching is a prefix match. Since #267 caching
 * is *explicit*, so volatile text in the prefix does not merely miss the cache —
 * it bills for a new cache entry every turn. Anything that changes belongs
 * after the prefix. `assistant.routes.ts` is where that placement is made, and
 * a route test asserts the prefix stays clean.
 *
 * Pure — no Prisma, no network — so every rendering path is exhaustively
 * testable, which is why the formatting lives here rather than in the route.
 */

/**
 * How much of one params bag may reach the model.
 *
 * `outlet_map` accepts up to 500 outlet ids, and a note is supposed to cost a
 * few tokens rather than re-render the dataset the artifact already carries.
 * Truncation is visible in the output, so a model reading it can tell that the
 * list continues rather than assuming it has the whole scope.
 */
const MAX_PARAMS_CHARS = 240;

/** How many entries of an array param are spelled out before it is summarised. */
const MAX_ARRAY_ITEMS = 3;

/**
 * One params bag as compact `key=value` pairs — `period=ytd, compareTo=previous_period`.
 *
 * Keys are sorted, so the same params always render the same way and a
 * diff-watching reader (or a test) is not at the mercy of object key order.
 * Nested objects are flattened to the one field that identifies them: every
 * nested shape in the catalog is a tagged object (`period`, `compareTo`), and
 * its tag is the part a manager would say out loud.
 */
export function describeParams(params: unknown): string {
  if (typeof params !== 'object' || params === null || Array.isArray(params)) {
    return '(none)';
  }

  const parts: string[] = [];
  for (const key of Object.keys(params as Record<string, unknown>).sort()) {
    const value = (params as Record<string, unknown>)[key];
    const rendered = describeValue(value);
    // Undefined and null are absences, not settings. Printing `territoryId=null`
    // would read as a deliberate scope rather than as an unset filter.
    if (rendered === null) continue;
    parts.push(`${key}=${rendered}`);
  }

  if (parts.length === 0) return '(none)';
  const joined = parts.join(', ');
  return joined.length <= MAX_PARAMS_CHARS ? joined : `${joined.slice(0, MAX_PARAMS_CHARS)}…`;
}

function describeValue(value: unknown): string | null {
  if (value === null || value === undefined) return null;

  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    return String(value);
  }

  if (Array.isArray(value)) {
    if (value.length === 0) return null;
    const head = value
      .slice(0, MAX_ARRAY_ITEMS)
      .map((item) => describeValue(item) ?? '?')
      .join(', ');
    return value.length > MAX_ARRAY_ITEMS
      ? `[${head}, +${value.length - MAX_ARRAY_ITEMS} more]`
      : `[${head}]`;
  }

  if (typeof value === 'object') {
    const record = value as Record<string, unknown>;
    const kind = record.kind;
    if (typeof kind === 'string') {
      // A custom period is the one tag that does not carry its own meaning —
      // "custom" alone tells the model nothing, and the dates are the whole
      // point of the user having picked it.
      if (kind === 'custom' && typeof record.from === 'string' && typeof record.to === 'string') {
        return `custom(${record.from}..${record.to})`;
      }
      // `compareTo: {kind: 'territory', id: 't-1'}` — the id is what identifies
      // which comparison, so it travels with the tag.
      if (typeof record.id === 'string') return `${kind}(${record.id})`;
      return kind;
    }
    return JSON.stringify(value);
  }

  return null;
}

export interface ArtifactParamsChange {
  id: string;
  type: string;
  params: unknown;
}

/**
 * The note appended to the user's turn after one or more UI-driven changes.
 *
 * Deliberately says **who** changed it. Without that the model reads the line
 * as its own earlier work and may "helpfully" put the view back; with it, the
 * change is the user's decision and the model's job is to answer against it.
 *
 * Returns `''` for an empty list so the caller can concatenate unconditionally —
 * a note that is sometimes an empty string is easier to get right at the call
 * site than one that is sometimes null.
 */
export function paramsChangeNote(changes: readonly ArtifactParamsChange[]): string {
  if (changes.length === 0) return '';
  return (
    'The user changed these views themselves since your last answer. ' +
    'These are the current parameters — answer against them, not against the earlier ones:\n' +
    changes
      .map((change) => `[artifact:${change.id} params → ${describeParams(change.params)}]`)
      .join('\n') +
    '\n\n'
  );
}
