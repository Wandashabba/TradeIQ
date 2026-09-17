import { parseIsoInstant } from '../../lib/parseIsoInstant';
import { MAX_CLOCK_SKEW_SECONDS, RAW_PING_RETENTION_DAYS } from '../locations/locationPolicy';

/**
 * Deciding when an order was actually taken (#338).
 *
 * `Order.createdAt` is when the server received the order. The app sends the
 * device's own capture time so an order taken offline on the 30th and synced on
 * the 1st is still dated the 30th. A device clock is not trustworthy, though, so
 * the value is bounded exactly the way an agent location ping's `recordedAt` is
 * (see `locations/locationPolicy.ts` and `ingestPings`) — the same two failure
 * modes, so deliberately the same two numbers rather than a second opinion:
 *
 * - **Not in the future** beyond {@link MAX_CAPTURE_SKEW_SECONDS} (10 minutes).
 *   A phone whose clock runs fast would otherwise book this month's order into
 *   next month, where no target has been set for it yet.
 * - **Not older than** {@link MAX_CAPTURE_AGE_DAYS} (90 days). A phone that has
 *   reset to its epoch would otherwise drop an order into a month a manager
 *   has already read, reported on and been measured by.
 *
 * Out of range, unparseable, or simply absent (a payload queued by a build that
 * predates the field), the received time is used instead — never a rejection.
 * The order is real and the agent cannot fix their clock from the shop floor;
 * losing the sale to protect the date would be the worse trade. Which fallback
 * happened is returned so the caller can log it, because a fleet of phones with
 * wrong clocks is worth noticing rather than silently absorbing.
 */

/** How far ahead of the server a device clock may be and still be believed. */
export const MAX_CAPTURE_SKEW_SECONDS = MAX_CLOCK_SKEW_SECONDS;

/** How far back a capture time may reach. Matches raw ping retention (#178). */
export const MAX_CAPTURE_AGE_DAYS = RAW_PING_RETENTION_DAYS;

/**
 * Why the received time was used instead of the device's.
 *
 * `absent` is the ordinary case for an older build and is not a fault;
 * the other three mean a device sent something we could not believe.
 */
export type CaptureFallbackReason = 'absent' | 'unparseable' | 'future' | 'too_old';

export interface ResolvedCaptureTime {
  /** The instant to date the order by. Never null. */
  capturedAt: Date;
  /** Null when the device's own timestamp was used as sent. */
  fallbackReason: CaptureFallbackReason | null;
}

/**
 * The instant an order should be dated by, given what the device claimed.
 *
 * `receivedAt` is the server's clock — both the fallback and the reference the
 * bounds are measured against, so one order is never judged against two "now"s.
 */
export function resolveCapturedAt(raw: unknown, receivedAt: Date): ResolvedCaptureTime {
  if (raw === undefined || raw === null) {
    return { capturedAt: receivedAt, fallbackReason: 'absent' };
  }

  // A full ISO-8601 instant only — a `Z` or a numeric offset. A naive datetime
  // would be resolved against the server process's TZ, which is the one guess
  // an offline-capture timestamp must never involve.
  const parsed = typeof raw === 'string' ? parseIsoInstant(raw) : undefined;
  if (!parsed) {
    return { capturedAt: receivedAt, fallbackReason: 'unparseable' };
  }

  const now = receivedAt.getTime();
  const at = parsed.getTime();
  if (at > now + MAX_CAPTURE_SKEW_SECONDS * 1000) {
    return { capturedAt: receivedAt, fallbackReason: 'future' };
  }
  if (at < now - MAX_CAPTURE_AGE_DAYS * 24 * 60 * 60 * 1000) {
    return { capturedAt: receivedAt, fallbackReason: 'too_old' };
  }

  return { capturedAt: parsed, fallbackReason: null };
}

/**
 * The log line for a fallback, or null when there is nothing to report.
 *
 * `absent` is silent on purpose: an older build sending no capture time is
 * expected for as long as those builds are in the field, and a line per order
 * would bury the two cases that mean a real device clock problem.
 */
export function captureFallbackLog(
  resolved: ResolvedCaptureTime,
  context: { clientId: string; agentId: string; raw: unknown },
): string | null {
  if (resolved.fallbackReason === null || resolved.fallbackReason === 'absent') {
    return null;
  }
  return (
    `Order capture time rejected (${resolved.fallbackReason}) for agent ${context.agentId} ` +
    `of client ${context.clientId}: ${JSON.stringify(context.raw)}. ` +
    `Dating the order by the received time ${resolved.capturedAt.toISOString()} instead.`
  );
}
