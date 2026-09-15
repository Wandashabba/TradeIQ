import { kpiThreshold } from '../../lib/kpiThresholds';

/**
 * The numbers that govern foreground location sharing (#153 T1) and its
 * retention (#178), in one place so the ingest route, the live map and the
 * pruning job cannot drift apart.
 */

// ── Heartbeat interval (risk 5: battery) ─────────────────────────────────────

/** The `Client.kpiThresholds` key an admin sets (PATCH /clients/me) to tune it. */
export const PING_INTERVAL_KEY = 'locationPingIntervalSeconds';

/**
 * Two minutes. The ticket's volume estimate (20 agents × 1 ping/2min × 10h ≈
 * 6,000 rows/day) was sized on this, and it is frequent enough that a manager's
 * map moves visibly between two stores without keeping the GPS radio warm.
 */
export const DEFAULT_PING_INTERVAL_SECONDS = 120;

/**
 * Below a minute the GPS radio barely rests between fixes, which is what drains
 * a field phone before the afternoon (risk 5). The clamp is the server's
 * promise that no tenant setting can make the app do that.
 */
export const MIN_PING_INTERVAL_SECONDS = 60;

/**
 * Past fifteen minutes an agent can visit a store and leave between two pings,
 * so the "live" map stops answering the question it exists for.
 */
export const MAX_PING_INTERVAL_SECONDS = 900;

/** The tenant's heartbeat interval, clamped. A non-integer is rounded. */
export function pingIntervalSeconds(kpiThresholds: unknown): number {
  const raw = kpiThreshold(kpiThresholds, PING_INTERVAL_KEY, DEFAULT_PING_INTERVAL_SECONDS);
  return Math.min(MAX_PING_INTERVAL_SECONDS, Math.max(MIN_PING_INTERVAL_SECONDS, Math.round(raw)));
}

// ── Live-map states ──────────────────────────────────────────────────────────

/**
 * A ping is stale once this many intervals have passed without a newer one.
 * One missed ping is ordinary — a slow GPS fix, a lift, a basement stockroom —
 * and flagging it would make "stale" noise a manager learns to ignore (the
 * open question T0 left on #153). Three in a row means the position on screen
 * is no longer where the agent is.
 */
export const STALE_AFTER_MISSED_PINGS = 3;

/**
 * Never call a ping stale sooner than this, whatever the interval. At the
 * one-minute floor, three missed pings is three minutes — shorter than a slow
 * outbox flush on 2G, so the map would flicker stale for agents who are fine.
 */
export const MIN_STALE_AFTER_SECONDS = 5 * 60;

/**
 * No ping for this long means the app is closed, backgrounded or the phone is
 * off. Heartbeats are FOREGROUND ONLY (T1), so this is the normal end of an
 * agent's shift as well as a flat battery — there is no shift model to tell
 * them apart, and "offline" claims neither. Thirty minutes is well past any
 * plausible run of missed foreground pings (the stale band), so an agent who
 * reaches it has stopped sharing rather than lost signal for a moment.
 */
export const OFFLINE_AFTER_SECONDS = 30 * 60;

export function staleAfterSeconds(intervalSeconds: number): number {
  return Math.max(MIN_STALE_AFTER_SECONDS, STALE_AFTER_MISSED_PINGS * intervalSeconds);
}

// ── Ingest bounds ────────────────────────────────────────────────────────────

/**
 * A day of pings at the default interval is ~300; the app flushes in batches
 * this size, so a phone that was offline all morning catches up in a few
 * requests and no single request is large.
 */
export const MAX_PINGS_PER_BATCH = 100;

/**
 * Device clocks drift. A ping stamped further ahead than this is ignored
 * rather than stored, because a far-future `recordedAt` would win every
 * "newest ping" comparison forever and freeze the agent's position on the map.
 */
export const MAX_CLOCK_SKEW_SECONDS = 10 * 60;

// ── Retention (#178) ─────────────────────────────────────────────────────────

/** Product decision on #178: raw pings are kept 90 days. */
export const RAW_PING_RETENTION_DAYS = 90;

// ── Disclosure (POPIA risk 1) ────────────────────────────────────────────────

/**
 * The wording the app shows. Bump it when the notice text changes in a way an
 * agent should answer again — every agent is then asked afresh, and pings stop
 * until they do.
 */
export const LOCATION_NOTICE_VERSION = '2026-09-15';

export type ConsentDecision = 'acknowledged' | 'declined';
