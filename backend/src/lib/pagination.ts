import { Request } from 'express';
import { ValidationError } from '../middleware/errorHandler';

/** Default page size when the caller does not ask for one. */
export const DEFAULT_LIMIT = 50;
/** Hard ceiling — a caller cannot ask for more than this in one page. */
export const MAX_LIMIT = 200;

export interface Pagination {
  limit: number;
  cursor: string | undefined;
}

/**
 * Reads `?limit=&cursor=` off a request.
 *
 * `limit` defaults to DEFAULT_LIMIT, is clamped up to MAX_LIMIT, and a
 * malformed value (non-integer, zero, negative, non-numeric) is a
 * ValidationError — the route layer turns that into a 400. Clamping the top
 * end but rejecting the bottom is deliberate: "give me 9999" is a reasonable
 * ask we can satisfy with 200, but "give me 0" or "give me abc" is a bug in
 * the caller we should surface, not paper over.
 */
export function parsePagination(req: Request): Pagination {
  const rawLimit = req.query.limit;
  const rawCursor = req.query.cursor;

  let limit = DEFAULT_LIMIT;
  if (rawLimit !== undefined) {
    if (typeof rawLimit !== 'string') {
      throw new ValidationError('limit must be a single positive integer');
    }
    // Strict digit-only match, rejecting hex ("0x10"), scientific notation
    // ("1e3"), and surrounding whitespace (" 5 ") that `Number()` alone would
    // silently accept — the docstring says "a positive integer" and the
    // parser should hold to that literally.
    if (!/^[1-9]\d*$/.test(rawLimit)) {
      throw new ValidationError('limit must be a positive integer');
    }
    const parsed = Number(rawLimit);
    limit = Math.min(parsed, MAX_LIMIT);
  }

  if (rawCursor !== undefined && typeof rawCursor !== 'string') {
    // A duplicated `?cursor=a&cursor=b` query param arrives as an array.
    // Silently coercing that to `undefined` (page 1) would hide a client bug
    // behind a "successful" first page — treat it the same as a malformed
    // `limit`: a 400, not a silent fallback.
    throw new ValidationError('cursor must be a single string');
  }
  const cursor = rawCursor as string | undefined;
  return { limit, cursor };
}

/**
 * Turns a keyset query's rows into a page envelope.
 *
 * The caller fetches `limit + 1` rows: if that probe row came back, there is
 * another page, so drop it and hand back the last KEPT row's id as the cursor.
 * The id must be a stable, unique sort tiebreaker — see the service query.
 *
 * Always returns a fresh array (never the caller's `rows` reference) so
 * callers can mutate `.data` freely without touching the input.
 */
export function buildPage<T extends { id: string }>(
  rows: T[],
  limit: number,
): { data: T[]; nextCursor: string | null } {
  if (limit < 1) {
    // `parsePagination` already guarantees limit >= 1, but `buildPage` is
    // exported standalone — a future direct caller passing 0 would otherwise
    // hit `data[-1].id` below and get an unhandled TypeError instead of a
    // clear contract violation.
    throw new RangeError('buildPage: limit must be >= 1');
  }
  const hasMore = rows.length > limit;
  const data = hasMore ? rows.slice(0, limit) : rows.slice();
  const nextCursor = hasMore ? data[data.length - 1].id : null;
  return { data, nextCursor };
}
