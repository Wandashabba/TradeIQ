import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { addCalendarDays } from '../../lib/clientTime';
import { ConflictError, NotFoundError, ValidationError } from '../../middleware/errorHandler';
import type { Role } from '../auth/auth.service';
import { campaignWindow } from '../campaigns/campaignWindow';
import { getClientTimeZone } from '../clients/clients.service';
import {
  ContestEventType,
  ContestStatus,
  RECENTLY_ENDED_DAYS,
  contestDaysLeft,
  contestStatus,
  formatCalendarDate,
  localToday,
} from './contestRules';
import { ContestStanding, computeContestStandings } from './contestStandings';

/** How many standings rows each contest carries on the agent's view. */
export const STANDINGS_PREVIEW_LIMIT = 10;

const CONTEST_INCLUDE = {
  territory: { select: { id: true, name: true, code: true } },
} satisfies Prisma.ContestInclude;

type ContestRow = Prisma.ContestGetPayload<{ include: typeof CONTEST_INCLUDE }>;

export interface ContestView {
  id: string;
  name: string;
  description: string | null;
  prizeDescription: string | null;
  /** Calendar date, `YYYY-MM-DD`, inclusive. */
  startDate: string;
  /** Calendar date, `YYYY-MM-DD`, inclusive. */
  endDate: string;
  territoryId: string | null;
  territory: { id: string; name: string; code: string } | null;
  /** Ledger reasons that count. Empty means every reason. */
  eventTypes: string[];
  status: ContestStatus;
  /** Local days left counting today, while active. Null otherwise. */
  daysLeft: number | null;
  /** The window as instants, half-open `[from, to)`. */
  window: { from: string; to: string };
  cancelledAt: string | null;
  createdById: string;
  createdAt: string;
  updatedAt: string;
}

export interface ContestInput {
  name: string;
  description: string | null;
  prizeDescription: string | null;
  startDate: Date;
  endDate: Date;
  territoryId: string | null;
  eventTypes: ContestEventType[];
}

export type ContestPatch = Partial<ContestInput>;

function toView(row: ContestRow, timeZone: string, now: Date): ContestView {
  const today = localToday(timeZone, now);
  const window = campaignWindow(row.startDate, row.endDate, timeZone);
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    prizeDescription: row.prizeDescription,
    startDate: formatCalendarDate(row.startDate),
    endDate: formatCalendarDate(row.endDate),
    territoryId: row.territoryId,
    territory: row.territory,
    eventTypes: row.eventTypes,
    status: contestStatus(row, today),
    daysLeft: contestDaysLeft(row, today),
    window: { from: window.from.toISOString(), to: window.to.toISOString() },
    cancelledAt: row.cancelledAt ? row.cancelledAt.toISOString() : null,
    createdById: row.createdById,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

async function findContestRow(id: string, clientId: string): Promise<ContestRow> {
  const row = await prisma.contest.findFirst({ where: { id, clientId }, include: CONTEST_INCLUDE });
  if (!row) {
    throw new NotFoundError('Contest not found');
  }
  return row;
}

/** A territory id from a request body must be one of the caller's own. */
async function assertTerritoryInTenant(territoryId: string | null | undefined, clientId: string) {
  if (!territoryId) {
    return;
  }
  const territory = await prisma.territory.findFirst({
    where: { id: territoryId, clientId },
    select: { id: true },
  });
  if (!territory) {
    throw new NotFoundError('Territory not found');
  }
}

function assertDatesInOrder(startDate: Date, endDate: Date) {
  if (endDate.getTime() < startDate.getTime()) {
    throw new ValidationError('endDate must be on or after startDate');
  }
}

// ── Manager / admin ────────────────────────────────────────────────────────

export async function listContests(input: {
  clientId: string;
  limit: number;
  cursor?: string;
  now?: Date;
}): Promise<{ data: ContestView[]; nextCursor: string | null }> {
  const [rows, timeZone] = await Promise.all([
    prisma.contest.findMany({
      where: { clientId: input.clientId },
      include: CONTEST_INCLUDE,
      // `id` breaks ties between contests starting the same day, so the
      // keyset cursor is deterministic (see campaigns.service.ts).
      orderBy: [{ startDate: 'desc' }, { id: 'desc' }],
      take: input.limit + 1,
      ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
    }),
    getClientTimeZone(input.clientId),
  ]);
  const page = buildPage(rows, input.limit);
  const now = input.now ?? new Date();
  return { data: page.data.map((row) => toView(row, timeZone, now)), nextCursor: page.nextCursor };
}

export async function getContest(id: string, clientId: string): Promise<ContestView> {
  const [row, timeZone] = await Promise.all([findContestRow(id, clientId), getClientTimeZone(clientId)]);
  return toView(row, timeZone, new Date());
}

export async function createContest(
  clientId: string,
  createdById: string,
  input: ContestInput,
): Promise<ContestView> {
  assertDatesInOrder(input.startDate, input.endDate);
  await assertTerritoryInTenant(input.territoryId, clientId);
  const [row, timeZone] = await Promise.all([
    prisma.contest.create({
      data: {
        clientId,
        createdById,
        name: input.name,
        description: input.description,
        prizeDescription: input.prizeDescription,
        startDate: input.startDate,
        endDate: input.endDate,
        territoryId: input.territoryId,
        eventTypes: input.eventTypes,
      },
      include: CONTEST_INCLUDE,
    }),
    getClientTimeZone(clientId),
  ]);
  return toView(row, timeZone, new Date());
}

/**
 * Edits any field, dates included — checked against each other after the
 * merge, so moving only the start past the stored end is refused. A cancelled
 * contest is closed: 409.
 */
export async function updateContest(
  id: string,
  clientId: string,
  patch: ContestPatch,
): Promise<ContestView> {
  const existing = await findContestRow(id, clientId);
  if (existing.cancelledAt) {
    throw new ConflictError('A cancelled contest cannot be edited');
  }
  assertDatesInOrder(patch.startDate ?? existing.startDate, patch.endDate ?? existing.endDate);
  await assertTerritoryInTenant(patch.territoryId, clientId);

  const data: Prisma.ContestUncheckedUpdateInput = {
    ...(patch.name !== undefined ? { name: patch.name } : {}),
    ...(patch.description !== undefined ? { description: patch.description } : {}),
    ...(patch.prizeDescription !== undefined ? { prizeDescription: patch.prizeDescription } : {}),
    ...(patch.startDate !== undefined ? { startDate: patch.startDate } : {}),
    ...(patch.endDate !== undefined ? { endDate: patch.endDate } : {}),
    ...(patch.territoryId !== undefined ? { territoryId: patch.territoryId } : {}),
    ...(patch.eventTypes !== undefined ? { eventTypes: patch.eventTypes } : {}),
  };
  const [row, timeZone] = await Promise.all([
    prisma.contest.update({ where: { id }, data, include: CONTEST_INCLUDE }),
    getClientTimeZone(clientId),
  ]);
  return toView(row, timeZone, new Date());
}

/**
 * Cancels an upcoming or active contest. Cancelling twice, or cancelling one
 * that has already ended (its result stands), is a 409.
 */
export async function cancelContest(id: string, clientId: string): Promise<ContestView> {
  const [existing, timeZone] = await Promise.all([
    findContestRow(id, clientId),
    getClientTimeZone(clientId),
  ]);
  const now = new Date();
  const status = contestStatus(existing, localToday(timeZone, now));
  if (status === 'cancelled') {
    throw new ConflictError('Contest is already cancelled');
  }
  if (status === 'ended') {
    throw new ConflictError('An ended contest cannot be cancelled');
  }
  const row = await prisma.contest.update({
    where: { id },
    data: { cancelledAt: now },
    include: CONTEST_INCLUDE,
  });
  return toView(row, timeZone, now);
}

/**
 * Deletes a contest that never ran (upcoming) or was cancelled. An active or
 * ended contest is a record agents have seen: cancel it instead (409).
 */
export async function deleteContest(id: string, clientId: string): Promise<void> {
  const [existing, timeZone] = await Promise.all([
    findContestRow(id, clientId),
    getClientTimeZone(clientId),
  ]);
  const status = contestStatus(existing, localToday(timeZone));
  if (status === 'active' || status === 'ended') {
    throw new ConflictError(`An ${status} contest cannot be deleted; cancel it instead`);
  }
  await prisma.contest.delete({ where: { id } });
}

export interface ContestStandingsView {
  contest: ContestView;
  participantCount: number;
  standings: ContestStanding[];
}

/** Full standings for any of the tenant's contests, cancelled ones included. */
export async function getContestStandings(id: string, clientId: string): Promise<ContestStandingsView> {
  const [row, timeZone] = await Promise.all([findContestRow(id, clientId), getClientTimeZone(clientId)]);
  const standings = await computeContestStandings(row, timeZone);
  return {
    contest: toView(row, timeZone, new Date()),
    participantCount: standings.length,
    standings,
  };
}

// ── Agent view ─────────────────────────────────────────────────────────────

export interface CurrentContest extends ContestView {
  participantCount: number;
  /** The top of the standings, at most STANDINGS_PREVIEW_LIMIT rows. */
  standings: ContestStanding[];
  /** The caller's own row. Null for callers who are not on the board. */
  me: ContestStanding | null;
}

/**
 * Active contests, then contests that ended in the last RECENTLY_ENDED_DAYS
 * local days. Never upcoming or cancelled ones.
 *
 * A field agent sees tenant-wide contests plus those scoped to a territory
 * they are assigned to — a contest they cannot be ranked in is not theirs to
 * see. Managers and admins see every current contest, with `me: null`.
 *
 * Order: active first, soonest-ending first; then ended, most recent first.
 */
export async function listCurrentContests(input: {
  clientId: string;
  userId: string;
  role: Role;
  now?: Date;
}): Promise<{ data: CurrentContest[] }> {
  const now = input.now ?? new Date();
  const timeZone = await getClientTimeZone(input.clientId);
  const today = localToday(timeZone, now);

  const rows = await prisma.contest.findMany({
    where: {
      clientId: input.clientId,
      cancelledAt: null,
      startDate: { lte: today },
      endDate: { gte: addCalendarDays(today, -RECENTLY_ENDED_DAYS) },
      ...(input.role === 'field_agent'
        ? {
            OR: [
              { territoryId: null },
              { territory: { assignments: { some: { userId: input.userId } } } },
            ],
          }
        : {}),
    },
    include: CONTEST_INCLUDE,
    orderBy: [{ endDate: 'asc' }, { id: 'asc' }],
  });

  const data = await Promise.all(
    rows.map(async (row) => {
      const standings = await computeContestStandings(row, timeZone);
      return {
        ...toView(row, timeZone, now),
        participantCount: standings.length,
        standings: standings.slice(0, STANDINGS_PREVIEW_LIMIT),
        me: standings.find((s) => s.agentId === input.userId) ?? null,
      };
    }),
  );

  const active = data.filter((c) => c.status === 'active');
  const ended = data.filter((c) => c.status === 'ended').reverse();
  return { data: [...active, ...ended] };
}
