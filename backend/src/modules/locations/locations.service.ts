import { prisma } from '../../lib/prisma';
import { parseIsoInstant } from '../../lib/parseIsoInstant';
import { ConflictError } from '../../middleware/errorHandler';
import { DEFAULT_CLIENT_TIME_ZONE } from '../../lib/clientTime';
import {
  WorkingHours,
  WorkingWindow,
  isWithinWorkingHours,
  workingHoursOf,
  workingWindowAt,
} from '../../lib/workingHours';
import {
  BACKGROUND_PING_INTERVAL_SECONDS,
  ConsentDecision,
  ConsentKind,
  MAX_CLOCK_SKEW_SECONDS,
  MAX_PINGS_PER_BATCH,
  PingSource,
  RAW_PING_RETENTION_DAYS,
  isPingSource,
  noticeVersionFor,
  pingIntervalSeconds,
} from './locationPolicy';

/**
 * Pings are refused until the agent has acknowledged the notice that covers
 * them. Carries WHICH notice, so the route can hand the app a code it can act
 * on — stop the heartbeat, or stop the background service — rather than one
 * blanket refusal that would make the app stop both.
 */
export class LocationConsentRequiredError extends Error {
  constructor(
    readonly kind: ConsentKind,
    message: string,
  ) {
    super(message);
  }

  get code(): 'location_consent_required' | 'background_location_consent_required' {
    return this.kind === 'background'
      ? 'background_location_consent_required'
      : 'location_consent_required';
  }
}

export interface ParsedPing {
  lat: number;
  lng: number;
  accuracyM: number | null;
  recordedAt: Date;
}

export type PingBatchParse =
  | { ok: true; pings: ParsedPing[]; source: PingSource }
  | { ok: false; error: string };

const isFiniteNumber = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);

/**
 * Validates `{ source?, pings: [...] }`. Structural problems reject the WHOLE
 * batch with a reason: a malformed ping is an app bug, and quietly storing the
 * rest would hide it. Well-formed pings that are merely out of window (too old,
 * too far in the future, outside working hours) are not errors — see
 * `ingestPings`.
 *
 * `source` is a property of the BATCH rather than of each ping. The app queues
 * foreground and background pings in separate outbox lanes and flushes them in
 * separate requests, so a batch is always one or the other; making it per-ping
 * would invite a mixed batch that no single consent check could answer for.
 * Absent means `foreground`, so an app build that predates T2 keeps working.
 */
export function parsePingBatch(body: unknown): PingBatchParse {
  const raw = (body ?? null) as { pings?: unknown; source?: unknown } | null;
  const source = raw?.source === undefined ? 'foreground' : raw.source;
  if (!isPingSource(source)) {
    return { ok: false, error: "source must be 'foreground' or 'background'" };
  }
  const pings = raw?.pings;
  if (!Array.isArray(pings) || pings.length === 0) {
    return { ok: false, error: 'pings must be a non-empty array' };
  }
  if (pings.length > MAX_PINGS_PER_BATCH) {
    return { ok: false, error: `a batch holds at most ${MAX_PINGS_PER_BATCH} pings` };
  }
  const parsed: ParsedPing[] = [];
  for (const [i, entry] of pings.entries()) {
    const p = entry as Record<string, unknown> | null;
    if (typeof p !== 'object' || p === null) {
      return { ok: false, error: `pings[${i}] must be an object` };
    }
    if (!isFiniteNumber(p.lat) || p.lat < -90 || p.lat > 90) {
      return { ok: false, error: `pings[${i}].lat must be a number between -90 and 90` };
    }
    if (!isFiniteNumber(p.lng) || p.lng < -180 || p.lng > 180) {
      return { ok: false, error: `pings[${i}].lng must be a number between -180 and 180` };
    }
    // 0,0 is in the Gulf of Guinea. It is what a broken location stack reports,
    // never where a South African field agent is standing.
    if (p.lat === 0 && p.lng === 0) {
      return { ok: false, error: `pings[${i}] is 0,0, which is not a real fix` };
    }
    if (p.accuracyM !== undefined && p.accuracyM !== null && (!isFiniteNumber(p.accuracyM) || p.accuracyM < 0)) {
      return { ok: false, error: `pings[${i}].accuracyM must be a non-negative number` };
    }
    const recordedAt = typeof p.recordedAt === 'string' ? parseIsoInstant(p.recordedAt) : undefined;
    if (recordedAt === undefined) {
      return {
        ok: false,
        error: `pings[${i}].recordedAt must be a full ISO-8601 instant with a Z or numeric offset`,
      };
    }
    parsed.push({
      lat: p.lat,
      lng: p.lng,
      accuracyM: isFiniteNumber(p.accuracyM) ? p.accuracyM : null,
      recordedAt,
    });
  }
  return { ok: true, pings: parsed, source };
}

export interface ConsentState {
  decision: ConsentDecision;
  noticeVersion: string;
  decidedAt: Date;
}

/**
 * The agent's latest answer to the CURRENT version of one notice, or null if
 * they have not answered it. An answer to an older wording does not count: the
 * notice changed because what they are agreeing to changed.
 *
 * `kind` picks the notice. The two are wholly independent — an agent may have
 * acknowledged foreground sharing and declined background tracking, or the
 * reverse, and neither lookup can see the other's rows.
 */
export async function currentConsent(
  clientId: string,
  agentId: string,
  kind: ConsentKind = 'foreground',
): Promise<ConsentState | null> {
  const row = await prisma.locationConsent.findFirst({
    where: { clientId, agentId, kind, noticeVersion: noticeVersionFor(kind) },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    select: { decision: true, noticeVersion: true, decidedAt: true },
  });
  if (!row) return null;
  return {
    decision: row.decision as ConsentDecision,
    noticeVersion: row.noticeVersion,
    decidedAt: row.decidedAt,
  };
}

/** The client's working-hours window and the zone it is read in (#153 T2). */
export interface WorkingHoursSettings extends WorkingHours {
  timezone: string;
}

export interface BackgroundLocationSettings {
  /** How often the Android service takes a fix, in seconds. */
  intervalSeconds: number;
  noticeVersion: string;
  /** The agent's latest answer to the CURRENT background notice; null if unanswered. */
  consent: ConsentState | null;
  /** True only when the agent has acknowledged the current background notice. */
  enabled: boolean;
  workingHours: WorkingHoursSettings;
  /** Whether the working window is open right now, on the server clock. */
  withinWorkingHours: boolean;
  /** When the open window closes. Null when it is shut. */
  windowClosesAt: Date | null;
  /** When the next window opens. Null when one is already open. */
  windowOpensAt: Date | null;
}

export interface LocationSettings {
  intervalSeconds: number;
  noticeVersion: string;
  consent: ConsentState | null;
  /** True only when the agent has acknowledged the current notice. */
  sharingEnabled: boolean;
  /**
   * Everything the Android background service needs (#153 T2), reported
   * INDEPENDENTLY of the foreground fields above: an agent may have said yes to
   * one and no to the other, and this object never speaks for the heartbeat.
   */
  background: BackgroundLocationSettings;
}

interface ClientLocationConfig {
  kpiThresholds: unknown;
  timezone: string;
  hours: WorkingHours;
}

/** The tenant settings both the app and ingest read, in one query. */
async function clientLocationConfig(clientId: string): Promise<ClientLocationConfig> {
  const client = await prisma.client.findUnique({
    where: { id: clientId },
    select: {
      kpiThresholds: true,
      timezone: true,
      workHoursStart: true,
      workHoursEnd: true,
      workDays: true,
    },
  });
  return {
    kpiThresholds: client?.kpiThresholds,
    timezone: client?.timezone ?? DEFAULT_CLIENT_TIME_ZONE,
    hours: workingHoursOf(client),
  };
}

/**
 * What the app needs before it may start (or must stop) the heartbeat and the
 * background service.
 *
 * The working window is resolved HERE, into instants, rather than shipping the
 * client's timezone rules to the phone. The phone then only has to compare
 * `now` against two instants — no timezone database on the device, nothing to
 * go stale, and a phone whose own clock is wrong cannot move the boundary,
 * because ingest re-checks every ping against the same window on arrival.
 */
export async function getLocationSettings(
  clientId: string,
  agentId: string,
  now: Date = new Date(),
): Promise<LocationSettings> {
  const [config, consent, backgroundConsent] = await Promise.all([
    clientLocationConfig(clientId),
    currentConsent(clientId, agentId, 'foreground'),
    currentConsent(clientId, agentId, 'background'),
  ]);
  const window: WorkingWindow = workingWindowAt(now, config.timezone, config.hours);

  return {
    intervalSeconds: pingIntervalSeconds(config.kpiThresholds),
    noticeVersion: noticeVersionFor('foreground'),
    consent,
    sharingEnabled: consent?.decision === 'acknowledged',
    background: {
      intervalSeconds: BACKGROUND_PING_INTERVAL_SECONDS,
      noticeVersion: noticeVersionFor('background'),
      consent: backgroundConsent,
      enabled: backgroundConsent?.decision === 'acknowledged',
      workingHours: { ...config.hours, timezone: config.timezone },
      withinWorkingHours: window.open,
      windowClosesAt: window.closesAt,
      windowOpensAt: window.opensAt,
    },
  };
}

export interface RecordConsentInput {
  clientId: string;
  agentId: string;
  decision: ConsentDecision;
  noticeVersion: string;
  /** Which notice is being answered. Absent means the foreground one. */
  kind?: ConsentKind;
  /** The device's tap time; the server clock when absent. */
  decidedAt?: Date;
  now?: Date;
}

/**
 * Appends the agent's answer to one notice. Append-only, so what an agent
 * agreed to and when is never rewritten.
 *
 * An answer to an older version of that notice is refused (409) rather than
 * recorded against the current one — an agent who acknowledged yesterday's
 * wording offline has not seen today's.
 *
 * A re-sent identical answer (the outbox retrying after a lost response) adds
 * no second row.
 *
 * **The two notices never touch each other.** Declining background writes a
 * background row and leaves the foreground heartbeat running; declining
 * foreground leaves a background acknowledgement standing. That is the point of
 * having two — see `ConsentKind`.
 */
export async function recordConsent(input: RecordConsentInput): Promise<ConsentState & { kind: ConsentKind }> {
  const kind = input.kind ?? 'foreground';
  const current = noticeVersionFor(kind);
  if (input.noticeVersion !== current) {
    throw new ConflictError(
      `This answer is for ${kind} location notice ${input.noticeVersion}; the current ${kind} notice is ${current}`,
    );
  }
  const now = input.now ?? new Date();
  // A device clock ahead of ours must not date an answer in the future.
  const decidedAt =
    input.decidedAt && input.decidedAt.getTime() <= now.getTime() ? input.decidedAt : now;

  const latest = await currentConsent(input.clientId, input.agentId, kind);
  if (
    latest &&
    latest.decision === input.decision &&
    latest.decidedAt.getTime() === decidedAt.getTime()
  ) {
    return { ...latest, kind };
  }

  await prisma.locationConsent.create({
    data: {
      clientId: input.clientId,
      agentId: input.agentId,
      kind,
      noticeVersion: current,
      decision: input.decision,
      decidedAt,
    },
  });
  // Declining deletes nothing: it stops FUTURE pings. What was shared while the
  // agent had agreed follows the same 90-day retention as everyone else's.
  return { decision: input.decision, noticeVersion: current, decidedAt, kind };
}

export interface IngestResult {
  /** New rows stored. */
  accepted: number;
  /** Pings already stored (a retried batch). Not an error. */
  duplicates: number;
  /** Well-formed pings deliberately not stored — see `ingestPings`. */
  ignored: number;
  /**
   * How many of `ignored` fell outside the client's working hours. Present only
   * on a background batch, where the window applies; a foreground heartbeat runs
   * whenever the agent has the app open, so the number would be meaningless.
   */
  outsideWorkingHours?: number;
}

export interface IngestPingsInput {
  clientId: string;
  agentId: string;
  pings: ParsedPing[];
  /** Which capture produced them. Absent means `foreground`. */
  source?: PingSource;
  now?: Date;
}

/**
 * Stores a batch of an agent's pings.
 *
 * **Order is `recordedAt`, never arrival (#153 risk 2).** Pings queue offline
 * and land late and shuffled. Nothing here assumes the batch is sorted, and the
 * only derived state — `User.lastLat/lastLng/lastSeenAt` — moves forward only:
 * it is written in a single conditional UPDATE that matches the row only when
 * the stored `lastSeenAt` is older than this batch's newest ping. A late batch
 * therefore cannot drag an agent back to where they were an hour ago, and two
 * batches racing each other cannot either, because the comparison happens
 * inside the database row lock rather than in a read-then-write here.
 *
 * **Consent is checked per source**, against the notice that covers it. A
 * background batch from an agent who has not accepted the background notice is
 * a 403 the app must act on, and it is refused even if they have acknowledged
 * the foreground one.
 *
 * Not stored (counted as `ignored`):
 * - pings older than the 90-day retention window — the pruning job would
 *   delete them on its next run, and a day it has already summarised must not
 *   gain raw rows behind its back;
 * - pings stamped more than MAX_CLOCK_SKEW in the future — a fast device clock
 *   would otherwise pin the agent's "latest" position forever;
 * - pings recorded before the agent acknowledged the notice. They cannot exist
 *   from a well-behaved app, and location an agent had not agreed to share is
 *   the one thing this endpoint must never keep;
 * - **background pings recorded outside the client's working hours** (#153 T2),
 *   also reported separately as `outsideWorkingHours`.
 *
 * **Why out-of-hours pings are ignored rather than refused.** The obvious
 * alternative — 4xx the whole batch — is wrong here for two reasons. A batch is
 * a queue flush, so it routinely spans the edge of the window: an agent who had
 * no signal all afternoon flushes at 18:30 a queue holding pings from 15:00
 * onwards plus the one that fired as the window closed. Refusing that batch
 * would throw away the legitimate pings with the late one, and the app's
 * existing 400 handling deletes a rejected batch outright, so they would be
 * gone for good. The window is also a property of each ping's own `recordedAt`,
 * not of the request, so it can only honestly be evaluated per ping. Refusal is
 * reserved for the one condition that really is about the request — consent —
 * because that is the one the app must change its behaviour in response to.
 */
export async function ingestPings(input: IngestPingsInput): Promise<IngestResult> {
  const source: PingSource = input.source ?? 'foreground';
  const kind: ConsentKind = source === 'background' ? 'background' : 'foreground';

  const [consent, config] = await Promise.all([
    currentConsent(input.clientId, input.agentId, kind),
    source === 'background' ? clientLocationConfig(input.clientId) : Promise.resolve(null),
  ]);
  if (consent?.decision !== 'acknowledged') {
    throw new LocationConsentRequiredError(
      kind,
      kind === 'background'
        ? 'Background location notice not acknowledged'
        : 'Location notice not acknowledged',
    );
  }

  const now = (input.now ?? new Date()).getTime();
  const oldest = now - RAW_PING_RETENTION_DAYS * 24 * 60 * 60 * 1000;
  const newestAllowed = now + MAX_CLOCK_SKEW_SECONDS * 1000;
  const consentedFrom = consent.decidedAt.getTime();

  let outsideWorkingHours = 0;
  const keep = input.pings.filter((p) => {
    const t = p.recordedAt.getTime();
    if (t < oldest || t > newestAllowed || t < consentedFrom) return false;
    if (config && !isWithinWorkingHours(p.recordedAt, config.timezone, config.hours)) {
      outsideWorkingHours += 1;
      return false;
    }
    return true;
  });
  const ignored = input.pings.length - keep.length;
  const counters = source === 'background' ? { outsideWorkingHours } : {};
  if (keep.length === 0) {
    return { accepted: 0, duplicates: 0, ignored, ...counters };
  }

  const { count } = await prisma.agentLocationPing.createMany({
    data: keep.map((p) => ({
      clientId: input.clientId,
      agentId: input.agentId,
      lat: p.lat,
      lng: p.lng,
      accuracyM: p.accuracyM,
      recordedAt: p.recordedAt,
      source,
    })),
    // The (agentId, recordedAt) unique key makes a retried batch a no-op.
    skipDuplicates: true,
  });

  const newest = keep.reduce((a, b) => (b.recordedAt.getTime() > a.recordedAt.getTime() ? b : a));
  await prisma.user.updateMany({
    where: {
      id: input.agentId,
      clientId: input.clientId,
      OR: [{ lastSeenAt: null }, { lastSeenAt: { lt: newest.recordedAt } }],
    },
    data: { lastLat: newest.lat, lastLng: newest.lng, lastSeenAt: newest.recordedAt },
  });

  return { accepted: count, duplicates: keep.length - count, ignored, ...counters };
}
