/**
 * Make the model's copy of a tool result smaller, always — not only when it is
 * about to overflow.
 *
 * `shrink.ts` is a ceiling: it does nothing at all until a result passes 24k
 * characters, which almost no result ever does. That left the ordinary case
 * untouched, and the ordinary case is where the money is. A turn re-sends every
 * tool result it has collected on *every* subsequent round, so a field worth 500
 * characters in round one is paid for four more times by round five. Measured on
 * one live turn, the accumulated tool results were 18k characters of a 30k
 * suffix, and none of the individual results had come near the shrinker.
 *
 * So this runs on every result, and it is deliberately timid. Three rules, each
 * chosen because it cannot cost the model a figure it might quote:
 *
 * 1. **Render-only fields are dropped.** Coordinates exist so the client can
 *    draw a map. The model cannot draw, does not quote a latitude, and is told
 *    by rule 13 not to read chart data aloud in the first place. The *artifact*
 *    still carries the raw result, coordinates included — the map is unaffected.
 * 2. **Float noise is rounded off.** `93.95999999999999` is fourteen characters
 *    of arithmetic residue saying the same thing as `93.96`. Integers are never
 *    touched, so no unit count moves.
 * 3. **The far side of a comparison keeps its totals and loses its rows.** A
 *    comparison's `values` block is the "before" picture: its totals are the
 *    thing a delta is computed from and the thing an answer quotes, and its row
 *    lists — last year's worst ten outlets — are a second full table nobody
 *    reads. The rows are cut to an `{omitted: n}` marker, which rule 1 already
 *    teaches the model to read as a partial list.
 *
 * **What this deliberately does NOT do**, having been tried and rejected:
 * dropping `null`s and empty arrays. It is the single largest saving available
 * and it is wrong here. Rule 9 turns on a null: *"When a tool returns a null
 * target, say no target is set for that scope and month rather than reporting a
 * miss."* A dropped null is indistinguishable from a field the tool does not
 * have, and an empty `publicHolidays: []` is the answer to "was there a
 * holiday?". Absence is a figure in this domain, so absence is kept.
 *
 * Runs before `shrink.ts`, never instead of it: the ceiling still has to exist
 * for the result that really is enormous.
 */

/**
 * Fields the model is never the audience for.
 *
 * A closed list rather than a heuristic, and kept very short on purpose. The
 * test for admission is not "the model probably does not need this" but "there
 * is no answer this field could contribute a figure to" — which is true of a
 * coordinate and of almost nothing else. Matched on the key alone, at any depth,
 * because the same pair means the same thing wherever a tool puts it.
 */
const RENDER_ONLY_KEYS: ReadonlySet<string> = new Set(['lat', 'lng']);

/**
 * How many rows survive on the far side of a comparison.
 *
 * Not zero: a comparison that shows only totals cannot be sanity-checked, and
 * one row makes the shape of the "before" list visible. Not more, because the
 * whole point is that nobody reads the rest.
 */
const COMPARISON_ROW_LIMIT = 1;

/** Decimal places kept on a non-integer. Two is what every percentage here uses. */
const DECIMALS = 2;

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/**
 * Is this the `values` block of a comparison, rather than a field a tool
 * happens to have called `values`?
 *
 * Checked against the shape `compare.ts` produces — a sibling `label` and
 * `basis` on the parent — so a tool returning `{ values: [...] }` of its own is
 * left alone. Being wrong in the other direction only costs rows on the far
 * side of a comparison, but being wrong in this one would cut a list the model
 * asked for.
 */
function isComparisonBlock(value: unknown): boolean {
  return (
    isPlainObject(value) &&
    'values' in value &&
    typeof value.label === 'string' &&
    isPlainObject(value.basis)
  );
}

/** Rows beyond the limit, replaced by the same marker the shrinker uses. */
function cutRows(value: unknown): unknown {
  if (Array.isArray(value)) {
    if (value.length <= COMPARISON_ROW_LIMIT) return value.map(cutRows);
    return [
      ...value.slice(0, COMPARISON_ROW_LIMIT).map(cutRows),
      { omitted: value.length - COMPARISON_ROW_LIMIT },
    ];
  }
  if (isPlainObject(value)) {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, cutRows(v)]));
  }
  return value;
}

/**
 * The model's copy of a tool result, with the three reductions above applied.
 *
 * Pure and total: any JSON-serialisable input comes back JSON-serialisable, and
 * nothing here can throw on a shape it did not expect. A cycle is left to
 * `sanitizeToolResult`, which runs first and has already replaced one.
 */
export function compactToolResult(value: unknown, depth = 0): unknown {
  // The same ceiling `sanitizeToolResult` uses. A structure deeper than this has
  // already been truncated upstream; the guard is here so this function is safe
  // on its own, not because it expects to fire.
  if (depth > 12) return value;

  if (typeof value === 'number') {
    if (!Number.isFinite(value) || Number.isInteger(value)) return value;
    return Number(value.toFixed(DECIMALS));
  }

  if (Array.isArray(value)) return value.map((item) => compactToolResult(item, depth + 1));

  if (isPlainObject(value)) {
    const out: Record<string, unknown> = {};
    for (const [key, inner] of Object.entries(value)) {
      if (RENDER_ONLY_KEYS.has(key)) continue;
      // The comparison's own `label`, `basis` and `deltas` are untouched; only
      // the `values` it carries has its rows cut.
      out[key] =
        key === 'values' && isComparisonBlock(value)
          ? compactToolResult(cutRows(inner), depth + 1)
          : compactToolResult(inner, depth + 1);
    }
    return out;
  }

  return value;
}
