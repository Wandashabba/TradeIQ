import { prisma } from '../../lib/prisma';
import { parseIsoInstant } from '../../lib/parseIsoInstant';
import { ConflictError } from '../../middleware/errorHandler';
import {
  ConsentDecision,
  LOCATION_NOTICE_VERSION,
  MAX_CLOCK_SKEW_SECONDS,
  MAX_PINGS_PER_BATCH,
  RAW_PING_RETENTION_DAYS,
  pingIntervalSeconds,
} from './locationPolicy';

/** Pings are refused until the agent has acknowledged the location notice. */
export class LocationConsentRequiredError extends Error {}

export interface ParsedPing {
  lat: number;
  lng: number;
  accuracyM: number | null;
  recordedAt: Date;
}

export type PingBatchParse = { ok: true; pings: ParsedPing[] } | { ok: false; error: string };

const isFiniteNumber = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);

/**
 * Validates `{ pings: [...] }`. Structural problems reject the WHOLE batch with
 * a reason: a malformed ping is an app bug, and quietly storing the rest would
 * hide it. Well-formed pings that are merely out of window (too old, too far in
 * the future) are not errors — see `ingestPings`.
 */
export function parsePingBatch(body: unknown): PingBatchParse {
  const pings = (body as { pings?: unknown } | null)?.pings;
  if (!Array.isArray(pings) || pings.length === 0) {
    return { ok: false, error: 'pings must be a non-empty array' };
  }
  if (pings.length > MAX_PINGS_PER_BATCH) {
    return { ok: false, error: `a batch holds at most ${MAX_PINGS_PER_BATCH} pings` };
  }
  const parsed: ParsedPing[] = [];
  for (const [i, raw] of pings.entries()) {
    const p = raw as Record<string, unknown> | null;
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
  return { ok: true, pings: parsed };
}

export interface ConsentState {
  decision: ConsentDecision;
  noticeVersion: string;
  decidedAt: Date;
}

/**
 * The agent's latest answer to the CURRENT notice, or null if they have not
 * answered it. An answer to an older wording does not count: the notice changed
 * because what they are agreeing to changed.
 */
export async function currentConsent(clientId: string, agentId: string): Promise<ConsentState | null> {
  const row = await prisma.locationConsent.findFirst({
    where: { clientId, agentId, noticeVersion: LOCATION_NOTICE_VERSION },
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

export interface LocationSettings {
  intervalSeconds: number;
  noticeVersion: string;
  consent: ConsentState | null;
  /** True only when the agent has acknowledged the current notice. */
  sharingEnabled: boolean;
}

/** What the app needs before it may start (or must stop) the heartbeat. */
export async function getLocationSettings(clientId: string, agentId: string): Promise<LocationSettings> {
  const [client, consent] = await Promise.all([
    prisma.client.findUnique({ where: { id: clientId }, select: { kpiThresholds: true } }),
    currentConsent(clientId, agentId),
  ]);
  return {
    intervalSeconds: pingIntervalSeconds(client?.kpiThresholds),
    noticeVersion: LOCATION_NOTICE_VERSION,
    consent,
    sharingEnabled: consent?.decision === 'acknowledged',
  };
}

export interface RecordConsentInput {
  clientId: string;
  agentId: string;
  decision: ConsentDecision;
  noticeVersion: string;
  /** The device's tap time; the server clock when absent. */
  decidedAt?: Date;
  now?: Date;
}

/**
 * Appends the agent's answer. Append-only, so what an agent agreed to and when
 * is never rewritten.
 *
 * An answer to an older notice is refused (409) rather than recorded against
 * the current one — an agent who acknowledged yesterday's wording offline has
 * not seen today's.
 *
 * A re-sent identical answer (the outbox retrying after a lost response) adds
 * no second row.
 */
export async function recordConsent(input: RecordConsentInput): Promise<ConsentState> {
  if (input.noticeVersion !== LOCATION_NOTICE_VERSION) {
    throw new ConflictError(
      `This answer is for location notice ${input.noticeVersion}; the current notice is ${LOCATION_NOTICE_VERSION}`,
    );
  }
  const now = input.now ?? new Date();
  // A device clock ahead of ours must not date an answer in the future.
  const decidedAt =
    input.decidedAt && input.decidedAt.getTime() <= now.getTime() ? input.decidedAt : now;

  const latest = await currentConsent(input.clientId, input.agentId);
  if (
    latest &&
    latest.decision === input.decision &&
    latest.decidedAt.getTime() === decidedAt.getTime()
  ) {
    return latest;
  }

  await prisma.locationConsent.create({
    data: {
      clientId: input.clientId,
      agentId: input.agentId,
      noticeVersion: LOCATION_NOTICE_VERSION,
      decision: input.decision,
      decidedAt,
    },
  });
  // Declining deletes nothing: it stops FUTURE pings. What was shared while the
  // agent had agreed follows the same 90-day retention as everyone else's.
  return { decision: input.decision, noticeVersion: LOCATION_NOTICE_VERSION, decidedAt };
}

export interface IngestResult {
  /** New rows stored. */
  accepted: number;
  /** Pings already stored (a retried batch). Not an error. */
  duplicates: number;
  /** Well-formed pings deliberately not stored — see `ingestPings`. */
  ignored: number;
}

export interface IngestPingsInput {
  clientId: string;
  agentId: string;
  pings: ParsedPing[];
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
 * Not stored (counted as `ignored`):
 * - pings older than the 90-day retention window — the pruning job would
 *   delete them on its next run, and a day it has already summarised must not
 *   gain raw rows behind its back;
 * - pings stamped more than MAX_CLOCK_SKEW in the future — a fast device clock
 *   would otherwise pin the agent's "latest" position forever;
 * - pings recorded before the agent acknowledged the notice. They cannot exist
 *   from a well-behaved app, and location an agent had not agreed to share is
 *   the one thing this endpoint must never keep.
 */
export async function ingestPings(input: IngestPingsInput): Promise<IngestResult> {
  const consent = await currentConsent(input.clientId, input.agentId);
  if (consent?.decision !== 'acknowledged') {
    throw new LocationConsentRequiredError('Location notice not acknowledged');
  }

  const now = (input.now ?? new Date()).getTime();
  const oldest = now - RAW_PING_RETENTION_DAYS * 24 * 60 * 60 * 1000;
  const newestAllowed = now + MAX_CLOCK_SKEW_SECONDS * 1000;
  const consentedFrom = consent.decidedAt.getTime();

  const keep = input.pings.filter((p) => {
    const t = p.recordedAt.getTime();
    return t >= oldest && t <= newestAllowed && t >= consentedFrom;
  });
  const ignored = input.pings.length - keep.length;
  if (keep.length === 0) {
    return { accepted: 0, duplicates: 0, ignored };
  }

  const { count } = await prisma.agentLocationPing.createMany({
    data: keep.map((p) => ({
      clientId: input.clientId,
      agentId: input.agentId,
      lat: p.lat,
      lng: p.lng,
      accuracyM: p.accuracyM,
      recordedAt: p.recordedAt,
      source: 'foreground',
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

  return { accepted: count, duplicates: keep.length - count, ignored };
}
