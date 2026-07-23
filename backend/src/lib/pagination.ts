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
    const parsed = Number(rawLimit);
    if (!Number.isInteger(parsed) || parsed < 1) {
      throw new ValidationError('limit must be a positive integer');
    }
    limit = Math.min(parsed, MAX_LIMIT);
  }

  const cursor = typeof rawCursor === 'string' ? rawCursor : undefined;
  return { limit, cursor };
}

/**
 * Turns a keyset query's rows into a page envelope.
 *
 * The caller fetches `limit + 1` rows: if that probe row came back, there is
 * another page, so drop it and hand back the last KEPT row's id as the cursor.
 * The id must be a stable, unique sort tiebreaker — see the service query.
 */
export function buildPage<T extends { id: string }>(
  rows: T[],
  limit: number,
): { data: T[]; nextCursor: string | null } {
  const hasMore = rows.length > limit;
  const data = hasMore ? rows.slice(0, limit) : rows;
  const nextCursor = hasMore ? data[data.length - 1].id : null;
  return { data, nextCursor };
}
