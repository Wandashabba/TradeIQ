/**
 * A person's display name, and the label to show when they have none (#280).
 *
 * `User.displayName` is nullable — accounts that predate it were never given
 * one, and it is not guessed from the email — so every place that shows a
 * person needs the same fallback. It lives here so that "name, else email" is
 * spelled once rather than drifting per module.
 */

/** Longest display name accepted. Generous for real names, short enough to lay out. */
export const DISPLAY_NAME_MAX_LENGTH = 120;

/** The name when there is a non-blank one, otherwise the email. */
export function personLabel(displayName: string | null | undefined, email: string): string {
  const trimmed = displayName?.trim();
  return trimmed ? trimmed : email;
}

export type DisplayNameParse =
  | { ok: true; value: string | null | undefined }
  | { ok: false };

/**
 * Validate a `displayName` from a request body.
 *
 * - absent (`undefined`) stays `undefined`, meaning "leave it alone";
 * - `null` or a blank string becomes `null`, meaning "clear it";
 * - a string is trimmed and must be at most {@link DISPLAY_NAME_MAX_LENGTH};
 * - anything else is invalid.
 */
export function parseDisplayName(value: unknown): DisplayNameParse {
  if (value === undefined) return { ok: true, value: undefined };
  if (value === null) return { ok: true, value: null };
  if (typeof value !== 'string') return { ok: false };
  const trimmed = value.trim();
  if (trimmed.length === 0) return { ok: true, value: null };
  if (trimmed.length > DISPLAY_NAME_MAX_LENGTH) return { ok: false };
  return { ok: true, value: trimmed };
}
