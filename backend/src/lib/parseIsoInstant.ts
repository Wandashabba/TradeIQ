// A naive datetime (no `Z`, no numeric offset) would be resolved against the
// server process's `TZ` — exactly the timezone reasoning endpoints that use
// this helper are designed never to do. Reject anything short of a full
// instant before `Date` gets a chance to guess. This does not by itself
// catch a well-formed-but-impossible date (e.g. Feb 31) — the
// `Number.isNaN` check below still does that.
export const ISO_INSTANT_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$/;

/**
 * Parses a string as a full ISO-8601 instant (a `Z` or a numeric offset is
 * required — no bare calendar dates, no offset-less datetimes). Returns
 * `undefined` if the string is not a well-formed instant, or is well-formed
 * but not a real date (e.g. `2026-02-31T00:00:00Z`).
 */
export function parseIsoInstant(value: string): Date | undefined {
  if (!ISO_INSTANT_RE.test(value)) {
    return undefined;
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return undefined;
  }
  return date;
}
