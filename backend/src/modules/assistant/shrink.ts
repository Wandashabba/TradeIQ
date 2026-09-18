/**
 * Fit one tool result into the model's context without breaking it.
 *
 * A tool that returns thousands of rows would otherwise push the turn past the
 * window, and it is billed by the token either way. This used to slice the JSON
 * at a character count, which cut mid-structure: the model received a string
 * that was not JSON, often ending inside a number, and summarised whatever half
 * it happened to get.
 *
 * Shrinking is now structural, and in order of how little it loses:
 *
 * 1. **Lists are cut to their first N items**, N stepping down until it fits.
 *    Every tool orders its lists worst- or most-first, so the head is the part
 *    worth keeping. A cut list ends with an `{ "omitted": n }` marker, so the
 *    model can say "and 40 more" rather than treat the head as the whole.
 * 2. **Long strings are shortened**, with the count of characters dropped.
 * 3. **Only then**, the result is reduced to its top-level scalars — the
 *    totals, percentages and counts the tools put at the top level — with a
 *    note saying the detail was dropped.
 *
 * Scalars and small objects (totals, deltas) are never touched by steps 1–2, so
 * the figures a headline quotes survive every step. The output is always valid
 * JSON, and anything shrunk says so inside it.
 */

/**
 * The ceiling on one result, in characters.
 *
 * Was 24,000, which is a context-window number rather than a cost one. A turn
 * re-sends every result it has collected on every subsequent round, so a single
 * 24k result that arrives in round two is paid for again in rounds three, four
 * and five — roughly 25k tokens for one lookup. Measured, real results land
 * between 1k and 3k characters, so 8,000 is still several times the largest
 * thing any tool actually returns and the ladder below stays dormant in the
 * ordinary case. It bites only on the runaway, which is what a ceiling is for.
 */
export const MAX_TOOL_RESULT_CHARS = Number(process.env.ASSISTANT_MAX_TOOL_RESULT_CHARS ?? 8_000);

/** Tried in order; the first that fits wins. */
const LIST_LIMITS = [50, 25, 10, 5, 3, 1, 0];
const STRING_LIMITS = [1_000, 200];

export const SHRUNK_NOTE =
  'This result was too large to include in full. Lists end with an {"omitted": n} marker ' +
  'giving how many items were left out; every other figure is complete. Say the list is partial.';

function cutLists(value: unknown, limit: number): unknown {
  if (Array.isArray(value)) {
    const kept = value.slice(0, limit).map((item) => cutLists(item, limit));
    return value.length > limit ? [...kept, { omitted: value.length - limit }] : kept;
  }
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([k, v]) => [k, cutLists(v, limit)]),
    );
  }
  return value;
}

function cutStrings(value: unknown, limit: number): unknown {
  if (typeof value === 'string') {
    return value.length > limit
      ? `${value.slice(0, limit)}… [${value.length - limit} characters omitted]`
      : value;
  }
  if (Array.isArray(value)) return value.map((item) => cutStrings(item, limit));
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([k, v]) => [k, cutStrings(v, limit)]),
    );
  }
  return value;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/**
 * Put the note first, so a reader meets it before the data it qualifies. Named
 * `shrunkNote` because several tool results already carry a `note` of their own.
 */
function annotate(value: unknown): unknown {
  return isPlainObject(value)
    ? { shrunkNote: SHRUNK_NOTE, ...value }
    : { shrunkNote: SHRUNK_NOTE, result: value };
}

/**
 * The model's copy of a tool result, as JSON of at most `maxChars` characters
 * (unless even the last-resort form cannot fit, which only a pathological
 * `maxChars` produces). See the module comment for the order of steps.
 */
export function shrinkToolResult(value: unknown, maxChars = MAX_TOOL_RESULT_CHARS): string {
  const whole = JSON.stringify(value) ?? 'null';
  if (whole.length <= maxChars) return whole;

  for (const listLimit of LIST_LIMITS) {
    const lists = cutLists(value, listLimit);
    const candidate = JSON.stringify(annotate(lists));
    if (candidate.length <= maxChars) return candidate;

    for (const stringLimit of STRING_LIMITS) {
      const strings = JSON.stringify(annotate(cutStrings(lists, stringLimit)));
      if (strings.length <= maxChars) return strings;
    }
  }

  // Last resort: the top-level scalars only, then just the note.
  if (isPlainObject(value)) {
    const scalars = Object.fromEntries(
      Object.entries(value).filter(([, v]) => v === null || typeof v !== 'object'),
    );
    const dropped = Object.keys(value).filter((k) => !(k in scalars));
    const candidate = JSON.stringify(
      cutStrings(
        {
          shrunkNote:
            'This result was too large to include. Only its top-level figures are shown; ' +
            'say the detail is missing and suggest narrowing the question.',
          omittedFields: dropped,
          ...scalars,
        },
        200,
      ),
    );
    if (candidate.length <= maxChars) return candidate;
  }
  return JSON.stringify({
    shrunkNote:
      'This result was too large to include. Say you could not retrieve it in full and ' +
      'suggest narrowing the question.',
    omitted: true,
  });
}
