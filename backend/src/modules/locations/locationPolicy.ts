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
//
// Product-confirmed on #153 (2026-09-15): stale = max(5 min, 3 missed
// intervals), offline = 30 min. The reasoning below is why they were proposed;
// the numbers are no longer an open question.

/**
 * A ping is stale once this many intervals have passed without a newer one.
 * One missed ping is ordinary — a slow GPS fix, a lift, a basement stockroom —
 * and flagging it would make "stale" noise a manager learns to ignore (the
 * open question T0 left on #153). Three in a row means the position on screen
 * is no longer where the agent is. Product-confirmed.
 */
export const STALE_AFTER_MISSED_PINGS = 3;

/**
 * Never call a ping stale sooner than this, whatever the interval. At the
 * one-minute floor, three missed pings is three minutes — shorter than a slow
 * outbox flush on 2G, so the map would flicker stale for agents who are fine.
 * Product-confirmed.
 */
export const MIN_STALE_AFTER_SECONDS = 5 * 60;

/**
 * No ping for this long means the app is closed, backgrounded or the phone is
 * off. Heartbeats are FOREGROUND ONLY (T1), so this is the normal end of an
 * agent's shift as well as a flat battery — there is no shift model to tell
 * them apart, and "offline" claims neither. Thirty minutes is well past any
 * plausible run of missed foreground pings (the stale band), so an agent who
 * reaches it has stopped sharing rather than lost signal for a moment.
 * Product-confirmed.
 */
export const OFFLINE_AFTER_SECONDS = 30 * 60;

export function staleAfterSeconds(intervalSeconds: number): number {
  return Math.max(MIN_STALE_AFTER_SECONDS, STALE_AFTER_MISSED_PINGS * intervalSeconds);
}

/**
 * The worst GPS accuracy (metres, the platform's horizontal estimate) at which
 * a ping inside an outlet fence is trusted to mean the agent is IN that store.
 * Product decision on #153 (2026-09-15).
 *
 * The check-in fence is only 50m. Indoors, where agents spend their day, phones
 * fall back to Wi-Fi and cell positioning with estimates of hundreds of metres,
 * and those fixes routinely land inside the fence of a store the agent is only
 * driving past or parked beside. At 100m — two fence radii — the fix puts the
 * agent in or right beside that store; past it, "at store" would be a claim the
 * reading cannot support, so the map says "near" instead. A ping with no
 * estimate at all has nothing vouching for it and is treated the same way.
 */
export const MAX_AT_STORE_ACCURACY_M = 100;

/**
 * Whether a ping is precise enough to place the agent IN the outlet whose fence
 * it falls in. One rule for the live map (`at_store` vs `near_store`) and for
 * the stops retention writes into `AgentDaySummary`, so the two never disagree
 * about what counted as being at a store.
 */
export function confirmsStore(accuracyM: number | null): boolean {
  return accuracyM !== null && accuracyM <= MAX_AT_STORE_ACCURACY_M;
}

// ── Background tracking (#153 T2) ────────────────────────────────────────────

/**
 * What produced a ping. `AgentLocationPing.source` holds one of these.
 *
 * - `foreground` — the T1 heartbeat, taken while the agent has the app open in
 *   front of them.
 * - `background` — the T2 Android foreground service, taken on a timer inside
 *   the client's working hours with nobody looking at the phone.
 */
export type PingSource = 'foreground' | 'background';

export function isPingSource(value: unknown): value is PingSource {
  return value === 'foreground' || value === 'background';
}

/**
 * Ten minutes. Product decision on #153 T2.
 *
 * Roughly 60 points per agent per working day — enough to draw the route
 * between two stores and see that an agent is moving, and cheap enough that
 * Android can serve most fixes from the fused provider's existing work rather
 * than waking the GPS radio for each one (risk 5, battery). It is deliberately
 * coarser than the foreground heartbeat's two minutes: the foreground map
 * answers "where is this agent right now", background answers "did they travel
 * between these stores", and the second question does not need the first
 * question's resolution.
 */
export const BACKGROUND_PING_INTERVAL_SECONDS = 10 * 60;

/**
 * Whether a ping may be read as the agent being IN the outlet whose fence it
 * falls in — accuracy AND provenance, in one rule shared by the live map
 * (`at_store` / `near_store`) and by the stops retention folds into
 * `AgentDaySummary`.
 *
 * **A background ping never places an agent in a store.** Product decision on
 * #153 T2, and the reasoning is worth keeping:
 *
 * - `at_store` is the strongest claim the map makes, and a background fix is
 *   the weakest evidence it has. It is taken by a service on a ten-minute
 *   timer with the phone in a pocket, so Android is free to answer from a
 *   cached or low-power network fix — and those routinely land inside the
 *   50m fence of a shop the agent is only parked beside. The accuracy gate
 *   catches many of those, not all.
 * - T2 exists to show *movement between* stores. Presence *in* a store is
 *   already established twice over, by check-in (T0) and by the foreground
 *   heartbeat an agent runs while actually working the shelf. Letting a
 *   pocketed phone assert the visit would add nothing those two do not already
 *   say, while quietly lowering the bar for what "at store" means.
 * - The same rule governs `foldStops`, so a stop in a day summary continues to
 *   mean "somebody confirmed present", not "a phone was nearby".
 *
 * So a background ping inside a fence reads `in_transit`: it is placed on the
 * map, it ages normally, and it names no outlet.
 */
export function confirmsStorePresence(source: PingSource, accuracyM: number | null): boolean {
  return source !== 'background' && confirmsStore(accuracyM);
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
 * Which notice an answer answers. Two notices, two independent answers.
 *
 * Accepting foreground sharing must NOT imply background tracking (product
 * decision, #153 T2): it is a materially bigger ask — the phone reports where
 * the agent is when they are not using the app at all — so it gets its own
 * words, its own tap, and its own row. Revoking either leaves the other
 * untouched, in both directions.
 */
export type ConsentKind = 'foreground' | 'background';

export function isConsentKind(value: unknown): value is ConsentKind {
  return value === 'foreground' || value === 'background';
}

/**
 * The wording the app shows for FOREGROUND sharing. Bump it when the notice
 * text changes in a way an agent should answer again — every agent is then
 * asked afresh, and pings stop until they do.
 */
export const LOCATION_NOTICE_VERSION = '2026-09-15';

/**
 * The wording the app shows for BACKGROUND tracking (#153 T2).
 *
 * Versioned separately from the foreground notice on purpose. Re-wording one
 * must not force every agent to re-answer the other, and the two will not
 * change at the same times: the foreground notice describes a heartbeat, this
 * one describes a service that runs inside working hours with a permanent
 * notification.
 */
export const BACKGROUND_LOCATION_NOTICE_VERSION = '2026-09-17';

/** The current wording of the notice for `kind`. */
export function noticeVersionFor(kind: ConsentKind): string {
  return kind === 'background' ? BACKGROUND_LOCATION_NOTICE_VERSION : LOCATION_NOTICE_VERSION;
}

export type ConsentDecision = 'acknowledged' | 'declined';
