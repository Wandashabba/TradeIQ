import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { ConflictError, NotFoundError, ValidationError } from '../../middleware/errorHandler';
import { buildPage } from '../../lib/pagination';
import { personLabel } from '../../lib/personName';
import { scoreAndStoreVisitFraud } from '../fraud/fraud.service';

/**
 * An outlet's lifecycle state (#386).
 *
 * `closed` keeps a retired store out of planning without deleting it — a
 * deleted outlet would take its visit history with it. It deliberately does
 * NOT gate check-in; see the note on `Outlet.status`.
 */
export const OUTLET_STATUSES = ['active', 'closed'] as const;
export type OutletStatus = (typeof OUTLET_STATUSES)[number];

/** How many failed check-in attempts an outlet's detail screen shows as evidence. */
export const OUTLET_ATTEMPT_EVIDENCE_LIMIT = 20;

/**
 * The worst reported accuracy, in metres, a check-in fix may have and still be
 * adoptable as an outlet's pin (#386 follow-up).
 *
 * "Use their position" is not a note in a log. It moves the fence: from then
 * on, that coordinate is where the shop is, and check-ins from there pass
 * cleanly. A fix the device itself reports as good to ±500m cannot be used to
 * say where a shop's door is — it can be a block away, which is the bug this
 * whole feature exists to repair, reintroduced by the repair.
 *
 * 100m is a building and its pavement. A fix worse than that is refused, and
 * the manager is told to use the map or the coordinates instead; a fix that
 * reports NO accuracy is allowed, because an older handset that sends nothing
 * must not lock a manager out of fixing a pin — it is shown as unknown rather
 * than as fine.
 */
export const MAX_ADOPTABLE_FIX_ACCURACY_M = 100;

export interface CreateOutletInput {
  name: string;
  code: string;
  channelType: string;
  lat: number;
  lng: number;
  territoryId: string;
  teamProfile?: Prisma.InputJsonValue;
  clientId: string;
}

/**
 * Outlets for a tenant, optionally narrowed to the ones in a user's assigned
 * territories.
 *
 * The narrowing is a *filter the caller asks for*, never something imposed.
 * Territory assignment should shorten an agent's list, not decide what work is
 * possible: an agent covering a colleague's patch, or standing in a store
 * filed under the wrong territory, must still be able to check in. In
 * offline-first field software, "I am here and the app will not let me work"
 * is a worse failure than a longer list.
 *
 * An agent with no assignments gets everything rather than nothing — an empty
 * roster is far more likely to mean nobody has set assignments up yet than to
 * mean this agent is meant to visit no outlets at all.
 */
export interface ListOutletsForClientInput {
  clientId: string;
  assignedTo?: string;
  limit: number;
  cursor?: string;
}

export async function listOutletsForClient(input: ListOutletsForClientInput) {
  const { clientId, assignedTo, limit, cursor } = input;
  // `id` is the unique tiebreaker that makes the cursor deterministic when
  // two outlets share a name — same reasoning as alerts.service.ts.
  //
  // COPYING THIS PATTERN: the tiebreaker's direction MUST match the primary
  // sort's direction (both `asc` here).
  const paging = {
    orderBy: [{ name: 'asc' as const }, { id: 'asc' as const }],
    take: limit + 1,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
  };

  if (!assignedTo) {
    const rows = await prisma.outlet.findMany({ where: { clientId }, ...paging });
    return buildPage(rows, limit);
  }

  const assignments = await prisma.userTerritory.findMany({
    where: { userId: assignedTo, territory: { clientId } },
    // NOTE: `Outlet.territoryId` stores a Territory *code*, not its id (see the
    // comment on the Territory model). Matching on id here would silently
    // return nothing — the exact bug #97 shipped once, where a territory
    // filter degraded to all-zero KPIs rather than erroring.
    select: { territory: { select: { code: true } } },
  });

  const codes = assignments.map((a) => a.territory.code);
  if (codes.length === 0) {
    const rows = await prisma.outlet.findMany({ where: { clientId }, ...paging });
    return buildPage(rows, limit);
  }

  const rows = await prisma.outlet.findMany({
    where: { clientId, territoryId: { in: codes } },
    ...paging,
  });
  return buildPage(rows, limit);
}

export async function createOutlet(input: CreateOutletInput) {
  // `Outlet.territoryId` is free text mirroring `Territory.code` — there is no
  // foreign key to enforce it (see the note on the Territory model). Without a
  // check here, any string is accepted and the outlet is silently orphaned:
  // absent from coverage counts, territory filters and every territory-scoped
  // view, with no error to explain why.
  //
  // Observed in production data: an outlet was created with territoryId
  // "Hurlingham" — the territory's *name* — while its code was "2773u". It
  // looked correct to a human and matched nothing.
  const territory = await prisma.territory.findUnique({
    where: {
      clientId_code: { clientId: input.clientId, code: input.territoryId },
    },
    select: { id: true },
  });

  if (!territory) {
    // Names the distinction the caller almost certainly got wrong, rather than
    // a bare "invalid territory" that leaves them retrying the same string.
    throw new ValidationError(
      `Unknown territory "${input.territoryId}". territoryId must be a territory's code, not its name — see GET /territories.`,
    );
  }

  return prisma.outlet.create({ data: input });
}

// ── The repair path (#386) ────────────────────────────────────────────────
//
// Until this existed an outlet's coordinates were write-once, taken from
// wherever the manager's phone happened to be when they submitted the create
// form. A store pinned to the depot car park could never be visited by
// anybody, ever, and no screen in the product could correct the number.

/** The pin, the evidence against it, and who has moved it. */
export interface OutletDetail {
  outlet: {
    id: string;
    name: string;
    code: string;
    channelType: string;
    lat: number;
    lng: number;
    status: string;
    territoryId: string;
    teamProfile: Prisma.JsonValue;
    acvWeight: number;
  };
  /**
   * Rejected check-in attempts at this outlet, newest first — the evidence a
   * manager judges the pin by. Each one is an agent who stood somewhere and was
   * told they were not at the shop, with the position they were actually at.
   * Several clustered on one spot hundreds of metres from the pin is what a
   * wrong pin looks like in data.
   */
  failedAttempts: Array<{
    id: string;
    agentId: string;
    agentLabel: string;
    lat: number;
    lng: number;
    distanceM: number;
    /**
     * What the device said about this fix: reported accuracy in metres, and
     * whether the platform called it mocked. Null means the device did not
     * say. A manager pressing "use their position" is adopting this
     * coordinate as the outlet's pin, and these decide whether they may.
     */
    accuracyM: number | null;
    isMocked: boolean | null;
    createdAt: Date;
  }>;
  /** Agents' explicit "the pin is wrong" claims, newest first. */
  disputes: PinDisputeView[];
  /** Who has changed this outlet, newest first. */
  changes: Array<{
    id: string;
    userId: string;
    userLabel: string;
    before: Prisma.JsonValue;
    after: Prisma.JsonValue;
    pinSource: string | null;
    disputeId: string | null;
    /**
     * For `pinSource: 'agent_position'`, WHICH attempt the coordinates came
     * from and WHOSE. Without them the ledger said only that a pin had been
     * moved to a position some phone once claimed. Null on every earlier row
     * and on any change that did not adopt an attempt.
     */
    fromAttemptId: string | null;
    fromAgentId: string | null;
    createdAt: Date;
  }>;
}

export interface PinDisputeView {
  id: string;
  outletId: string;
  outletName: string;
  outletCode: string;
  visitId: string;
  agentId: string;
  agentLabel: string;
  lat: number;
  lng: number;
  distanceM: number;
  /** The pin as it read when the claim was made, not as it reads now. */
  outletLat: number;
  outletLng: number;
  note: string | null;
  /**
   * What the device said about the fix behind this claim: its reported
   * horizontal accuracy in metres, and whether the platform called it a mock
   * location. Null means the device did not say — which is not the same as
   * "fine", and the console says so in words.
   *
   * A manager adopting this position onto the outlet's pin is moving the
   * boundary of who may check in there, on one phone's word. These two are
   * what makes that decision readable instead of a row of decimals.
   */
  accuracyM: number | null;
  isMocked: boolean | null;
  status: string;
  resolvedById: string | null;
  resolvedByLabel: string | null;
  resolvedNote: string | null;
  resolvedAt: Date | null;
  createdAt: Date;
  /**
   * Photo metadata for the storefront evidence the agent attached — never the
   * bytes. The app uploads it against the visit under section
   * `pin_dispute`; see PIN_DISPUTE_PHOTO_SECTION.
   *
   * `timestamp` is the DEVICE clock and `gpsTag` is what the device reported;
   * both are the agent's own account of the photo. `createdAt` is when THIS
   * SERVER received it and `source` is how it was obtained, and those two are
   * the ones a reviewer can lean on. A view that showed only the first pair
   * let a picture picked from the gallery at home arrive stamped with a fresh
   * time and a matching home position, and read as a storefront photo.
   */
  photos: Array<{
    id: string;
    url: string;
    timestamp: Date;
    gpsTag: Prisma.JsonValue;
    createdAt: Date;
    source: string | null;
  }>;
  /**
   * True when the agent who filed this claim is the ONLY agent who has ever
   * visited this outlet — so there is nobody whose visits would contradict a
   * pin moved onto their position. Not a refusal, a warning: a genuinely new
   * store has exactly one visitor too.
   */
  agentIsOnlyVisitor: boolean;
}

/**
 * The photo section a storefront photo offered with a pin dispute is filed
 * under.
 *
 * It rides the ordinary photo pipeline against the created visit rather than
 * travelling inside the check-in body: an offline-first check-in POST from a
 * shop doorway should carry coordinates and a sentence, not megabytes, and the
 * photo module already does hashing, duplicate detection and GPS tagging that
 * this evidence benefits from exactly as much as any other photo does.
 */
export const PIN_DISPUTE_PHOTO_SECTION = 'pin_dispute';

function disputeView(row: {
  id: string;
  outletId: string;
  visitId: string;
  agentId: string;
  lat: number;
  lng: number;
  distanceM: number;
  outletLat: number;
  outletLng: number;
  note: string | null;
  accuracyM: number | null;
  isMocked: boolean | null;
  status: string;
  resolvedById: string | null;
  resolvedByLabel: string | null;
  resolvedNote: string | null;
  resolvedAt: Date | null;
  createdAt: Date;
  agent: { displayName: string | null; email: string };
  outlet: { name: string; code: string };
  visit: {
    photos: Array<{
      id: string;
      url: string;
      timestamp: Date;
      gpsTag: Prisma.JsonValue;
      createdAt: Date;
      source: string | null;
    }>;
  };
}, soleVisitorByOutlet: ReadonlyMap<string, string | null> = new Map()): PinDisputeView {
  return {
    id: row.id,
    outletId: row.outletId,
    outletName: row.outlet.name,
    outletCode: row.outlet.code,
    visitId: row.visitId,
    agentId: row.agentId,
    agentLabel: personLabel(row.agent.displayName, row.agent.email),
    lat: row.lat,
    lng: row.lng,
    distanceM: row.distanceM,
    outletLat: row.outletLat,
    outletLng: row.outletLng,
    note: row.note,
    accuracyM: row.accuracyM,
    isMocked: row.isMocked,
    status: row.status,
    resolvedById: row.resolvedById,
    resolvedByLabel: row.resolvedByLabel,
    resolvedNote: row.resolvedNote,
    resolvedAt: row.resolvedAt,
    createdAt: row.createdAt,
    photos: row.visit.photos,
    agentIsOnlyVisitor: soleVisitorByOutlet.get(row.outletId) === row.agentId,
  };
}

/**
 * For each of these outlets: the one agent who has ever visited it, or null
 * when nobody or more than one has.
 *
 * "Use their position" moves an outlet's pin onto a coordinate one agent's
 * phone reported. When that agent is also the only person who has ever worked
 * the outlet, nobody else's visits can contradict the new pin — the agent has
 * effectively told the system where the shop is and then been the only one
 * measured against it. That is not proof of anything (a store visited once is
 * also a store visited once), so it is surfaced as a warning on the claim and
 * never as a refusal.
 *
 * One grouped read for the whole page, tenant-scoped.
 */
async function soleVisitorByOutlet(
  clientId: string,
  outletIds: string[],
): Promise<Map<string, string | null>> {
  const sole = new Map<string, string | null>();
  if (outletIds.length === 0) {
    return sole;
  }
  const pairs = await prisma.visit.groupBy({
    by: ['outletId', 'agentId'],
    where: { clientId, outletId: { in: [...new Set(outletIds)] } },
  });
  for (const pair of pairs) {
    // First agent seen for an outlet wins the slot; a second one empties it.
    sole.set(pair.outletId, sole.has(pair.outletId) ? null : pair.agentId);
  }
  return sole;
}

const disputeInclude = {
  agent: { select: { displayName: true, email: true } },
  outlet: { select: { name: true, code: true } },
  visit: {
    select: {
      photos: {
        where: { section: PIN_DISPUTE_PHOTO_SECTION },
        // createdAt and source as well as the device's own account of the
        // photo: the manager needs the server's receipt time and whether it
        // came from the camera, not only what the phone claimed.
        select: {
          id: true,
          url: true,
          timestamp: true,
          gpsTag: true,
          createdAt: true,
          source: true,
        },
        orderBy: { timestamp: 'asc' as const },
      },
    },
  },
} as const;

/**
 * One outlet with everything a manager needs to judge its pin.
 *
 * Tenant-scoped: another client's outlet is a 404, not a 403 — a 403 confirms
 * the id exists somewhere, which is an existence oracle across tenants.
 */
export async function getOutletDetail(outletId: string, clientId: string): Promise<OutletDetail> {
  const outlet = await prisma.outlet.findFirst({
    where: { id: outletId, clientId },
  });
  if (!outlet) {
    throw new NotFoundError('Outlet not found');
  }

  const [failedAttempts, disputes, changes, soleVisitors] = await Promise.all([
    prisma.checkInAttempt.findMany({
      // clientId as well as outletId: belt and braces, so a mistyped id can
      // never reach across tenants even though the outlet above is scoped.
      where: { outletId, clientId, passed: false },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: OUTLET_ATTEMPT_EVIDENCE_LIMIT,
      include: { agent: { select: { displayName: true, email: true } } },
    }),
    prisma.pinDispute.findMany({
      where: { outletId, clientId },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: OUTLET_ATTEMPT_EVIDENCE_LIMIT,
      include: disputeInclude,
    }),
    prisma.outletChangeAudit.findMany({
      where: { outletId, clientId },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: OUTLET_ATTEMPT_EVIDENCE_LIMIT,
    }),
    soleVisitorByOutlet(clientId, [outletId]),
  ]);

  return {
    outlet: {
      id: outlet.id,
      name: outlet.name,
      code: outlet.code,
      channelType: outlet.channelType,
      lat: outlet.lat,
      lng: outlet.lng,
      status: outlet.status,
      territoryId: outlet.territoryId,
      teamProfile: outlet.teamProfile ?? null,
      acvWeight: outlet.acvWeight,
    },
    failedAttempts: failedAttempts.map((a) => ({
      id: a.id,
      agentId: a.agentId,
      agentLabel: personLabel(a.agent.displayName, a.agent.email),
      lat: a.lat,
      lng: a.lng,
      distanceM: a.distanceM,
      accuracyM: a.accuracyM,
      isMocked: a.isMocked,
      createdAt: a.createdAt,
    })),
    disputes: disputes.map((d) => disputeView(d, soleVisitors)),
    changes: changes.map((c) => ({
      id: c.id,
      userId: c.userId,
      userLabel: c.userLabel,
      before: c.before,
      after: c.after,
      pinSource: c.pinSource,
      disputeId: c.disputeId,
      fromAttemptId: c.fromAttemptId,
      fromAgentId: c.fromAgentId,
      createdAt: c.createdAt,
    })),
  };
}

export interface UpdateOutletInput {
  outletId: string;
  clientId: string;
  userId: string;
  name?: string;
  status?: OutletStatus;
  /** Manual coordinate entry. Both or neither. */
  lat?: number;
  lng?: number;
  /**
   * "Use the agent's recorded position": the id of a CheckInAttempt at this
   * outlet whose coordinates become the new pin.
   *
   * The coordinates are read from that row HERE, never taken from the body.
   * A body that carried both the attempt id and the numbers would let the
   * ledger record "moved to the agent's recorded position" beside coordinates
   * that were never any agent's position, which is a forgeable audit trail.
   */
  fromAttemptId?: string;
  /** The dispute this change answers; resolved `applied` in the same transaction. */
  disputeId?: string;
  resolutionNote?: string;
}

/**
 * PATCH /outlets/:id — the repair (#386).
 *
 * Writes the change and its ledger row in ONE transaction. An outlet whose pin
 * moved with no record of who moved it is the same problem as a pin nobody can
 * move, one step later: the coordinates decide who is allowed to check in, so
 * changing them is a change to an access boundary.
 *
 * The ledger stores only the fields that actually changed. A no-op PATCH
 * writes no row — an audit trail padded with "changed nothing to nothing" is
 * an audit trail people stop reading.
 */
export async function updateOutlet(input: UpdateOutletInput) {
  const outlet = await prisma.outlet.findFirst({
    where: { id: input.outletId, clientId: input.clientId },
  });
  if (!outlet) {
    throw new NotFoundError('Outlet not found');
  }

  let lat = input.lat;
  let lng = input.lng;
  let pinSource: string | null = lat !== undefined ? 'manual' : null;

  let fromAgentId: string | null = null;
  if (input.fromAttemptId !== undefined) {
    const attempt = await prisma.checkInAttempt.findFirst({
      where: { id: input.fromAttemptId, clientId: input.clientId, outletId: input.outletId },
      select: { lat: true, lng: true, agentId: true, accuracyM: true, isMocked: true },
    });
    if (!attempt) {
      // Scoped to the tenant AND to this outlet: an attempt id from another
      // client, or from a different store, must not be usable to move this pin.
      throw new NotFoundError('No check-in attempt with that id at this outlet');
    }
    // A position the platform itself called fake cannot become the place a
    // shop is. Refused rather than warned about: a manager cannot be asked to
    // tell a spoofed coordinate from a real one by reading decimals, and the
    // manual lat/lng path is still open for a pin they can place themselves.
    if (attempt.isMocked === true) {
      throw new ValidationError(
        'That position was reported by the device as a mock location and cannot become this ' +
          "outlet's pin. Set the coordinates yourself, or ask the agent to check in again.",
      );
    }
    if (attempt.accuracyM !== null && attempt.accuracyM > MAX_ADOPTABLE_FIX_ACCURACY_M) {
      throw new ValidationError(
        `That position was only accurate to ${Math.round(attempt.accuracyM)}m, beyond the ` +
          `${MAX_ADOPTABLE_FIX_ACCURACY_M}m limit for setting an outlet's pin. Set the ` +
          'coordinates yourself, or ask the agent to check in again with a better fix.',
      );
    }
    lat = attempt.lat;
    lng = attempt.lng;
    pinSource = 'agent_position';
    fromAgentId = attempt.agentId;
  }

  let dispute: { id: string; status: string } | null = null;
  if (input.disputeId !== undefined) {
    dispute = await prisma.pinDispute.findFirst({
      where: { id: input.disputeId, clientId: input.clientId, outletId: input.outletId },
      select: { id: true, status: true },
    });
    if (!dispute) {
      throw new NotFoundError('No pin dispute with that id at this outlet');
    }
    if (dispute.status !== 'open') {
      throw new ConflictError(`That pin dispute was already ${dispute.status}`);
    }
  }

  const before: Record<string, unknown> = {};
  const after: Record<string, unknown> = {};
  const data: Prisma.OutletUpdateInput = {};

  if (input.name !== undefined && input.name !== outlet.name) {
    before.name = outlet.name;
    after.name = input.name;
    data.name = input.name;
  }
  if (input.status !== undefined && input.status !== outlet.status) {
    before.status = outlet.status;
    after.status = input.status;
    data.status = input.status;
  }
  if (lat !== undefined && lng !== undefined && (lat !== outlet.lat || lng !== outlet.lng)) {
    before.lat = outlet.lat;
    before.lng = outlet.lng;
    after.lat = lat;
    after.lng = lng;
    data.lat = lat;
    data.lng = lng;
  }

  const movedPin = after.lat !== undefined;
  const changed = Object.keys(after).length > 0;

  if (!changed && dispute === null) {
    // Nothing to do and nothing to record. Returning the outlet unchanged is
    // the honest answer; a 400 here would make a retry of a successful PATCH
    // look like a failure, which on a flaky connection it very often is.
    return { outlet, dispute: null as PinDisputeView | null };
  }

  const resolvedAt = new Date();

  // The editor's name is read here and FROZEN onto the ledger row, for the same
  // reason `fraud_verdicts.reviewer_label` is: `userId` carries no relation, so
  // deactivating a manager must not erase what they changed, and renaming them
  // must not rewrite it.
  const actor = await prisma.user.findFirst({
    where: { id: input.userId, clientId: input.clientId },
    select: { displayName: true, email: true },
  });
  const userLabel = actor ? personLabel(actor.displayName, actor.email) : input.userId;

  const [updated, resolvedDispute] = await prisma.$transaction(async (tx) => {
    const row = changed
      ? await tx.outlet.update({ where: { id: outlet.id }, data })
      : outlet;

    if (changed) {
      await tx.outletChangeAudit.create({
        data: {
          clientId: input.clientId,
          outletId: outlet.id,
          userId: input.userId,
          userLabel,
          before: before as Prisma.InputJsonValue,
          after: after as Prisma.InputJsonValue,
          pinSource: movedPin ? pinSource : null,
          disputeId: dispute?.id ?? null,
          // Whose position, and which reading of it. `agent_position` alone
          // recorded that a pin had moved to somewhere a phone once claimed,
          // with no way afterwards to ask whose phone or to re-read the fix.
          fromAttemptId: movedPin ? (input.fromAttemptId ?? null) : null,
          fromAgentId: movedPin ? fromAgentId : null,
        },
      });
    }

    let closed = null;
    if (dispute) {
      // `updateMany` with `status: 'open'` in the WHERE is the lock: two
      // managers answering the same claim at once means exactly one write
      // lands, and the loser is told rather than silently overwriting a
      // colleague's ruling — the same reasoning as the fraud verdict's unique
      // index, expressed with the tools a mutable row has.
      const applied = await tx.pinDispute.updateMany({
        where: { id: dispute.id, clientId: input.clientId, status: 'open' },
        data: {
          // Moving the pin is agreeing with the agent. A PATCH that names a
          // dispute but does not move the pin is a manager saying "I looked,
          // and the pin stands" — which is a rejection, and is recorded as one
          // rather than as a silent nothing.
          status: movedPin ? 'applied' : 'rejected',
          resolvedById: input.userId,
          resolvedByLabel: userLabel,
          resolvedNote: input.resolutionNote ?? null,
          resolvedAt,
        },
      });
      if (applied.count === 0) {
        throw new ConflictError('That pin dispute was resolved by someone else first');
      }
      closed = await tx.pinDispute.findUnique({
        where: { id: dispute.id },
        include: disputeInclude,
      });
    }

    return [row, closed] as const;
  });

  // ── The ruling has to reach the VISIT (#386 follow-up) ──────────────────
  //
  // Rejecting a claim is a manager saying, in the one place the product asks
  // them to, that the pin stands and therefore the agent was not at the shop.
  // Until now that changed nothing outside the pin_disputes row: the visit kept
  // its score of 30, stayed out of /fraud/flagged, stayed submitted and kept
  // its points. The finding and the visit it was about lived in different
  // halves of the product.
  //
  // Re-scoring here is what joins them. geofence_override_rejected is weighted
  // above the review threshold, so the re-score is what puts the visit in the
  // flagged queue; an APPLIED claim is re-scored by the same call, and is the
  // reason this is not `if (rejected)` — a manager agreeing that the pin was
  // wrong should not leave a stale score sitting on the agent's record either.
  //
  // Best-effort and after the transaction, deliberately. The manager's ruling
  // is recorded either way: a scoring failure must not roll back a decision a
  // person already made, and the nightly rescore (fraudRescore.ts) sweeps up
  // anything missed. It is awaited so the score is current by the time the
  // response is read.
  if (resolvedDispute) {
    try {
      await scoreAndStoreVisitFraud(resolvedDispute.visitId, input.clientId);
    } catch (err) {
      console.error(
        `Re-scoring visit ${resolvedDispute.visitId} after its pin dispute was ` +
          `${resolvedDispute.status} failed:`,
        err,
      );
    }
  }

  return {
    outlet: updated,
    dispute: resolvedDispute ? disputeView(resolvedDispute) : null,
  };
}

export interface ListPinDisputesInput {
  clientId: string;
  status?: string;
  outletId?: string;
  limit: number;
  cursor?: string;
}

/**
 * The manager's queue of "the pin is wrong" claims, newest first.
 *
 * Defaults to the OPEN ones, for the reason GET /fraud/flagged defaults to its
 * open queue: a list that never shortens is a list people stop opening, and
 * these claims are each an agent currently unable to work properly.
 */
export async function listPinDisputes(input: ListPinDisputesInput) {
  const { clientId, status = 'open', outletId, limit, cursor } = input;
  const rows = await prisma.pinDispute.findMany({
    where: {
      clientId,
      ...(status === 'all' ? {} : { status }),
      ...(outletId ? { outletId } : {}),
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    include: disputeInclude,
  });
  const page = buildPage(rows, limit);
  const soleVisitors = await soleVisitorByOutlet(
    clientId,
    page.data.map((row) => row.outletId),
  );
  return {
    data: page.data.map((row) => disputeView(row, soleVisitors)),
    nextCursor: page.nextCursor,
  };
}
