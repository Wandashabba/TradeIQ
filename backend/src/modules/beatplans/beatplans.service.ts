import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { randomUUID } from 'crypto';
import { round2 } from '../../lib/kpiMath';
import { expandOccurrences, type Recurrence } from './recurrence';
import { NotFoundError } from '../../middleware/errorHandler';
import { buildPage } from '../../lib/pagination';
import type { AuthTokenPayload } from '../auth/auth.service';

export type BeatPlanStatus = 'planned' | 'in_progress' | 'completed';

// Adherence over a plan's stops: how many of the planned stops were visited.
// Zero-safe so an (unexpected) stopless plan reports 0 rather than NaN.
function computeAdherence(stops: ReadonlyArray<{ visited: boolean }>) {
  const stopsTotal = stops.length;
  const stopsVisited = stops.filter((stop) => stop.visited).length;
  const adherenceRate = stopsTotal === 0 ? 0 : round2((100 * stopsVisited) / stopsTotal);
  return { stopsTotal, stopsVisited, adherenceRate };
}

export interface CreateBeatPlanInput {
  clientId: string;
  agentId: string;
  name: string;
  scheduledDate: string; // ISO
  territoryId?: string;
  outletIds: string[];
  /**
   * Absent for a one-off plan. Present turns this into a permanent journey
   * plan (#98): the same stops, on every date the rule lands on.
   */
  recurrence?: Recurrence;
}

export async function createBeatPlan(input: CreateBeatPlanInput) {
  // The agent must be a user of the caller's client.
  const agent = await prisma.user.findFirst({
    where: { id: input.agentId, clientId: input.clientId },
    select: { id: true },
  });
  if (!agent) {
    throw new NotFoundError('Agent not found');
  }

  // An optional territory must also belong to the client.
  if (input.territoryId) {
    const territory = await prisma.territory.findFirst({
      where: { id: input.territoryId, clientId: input.clientId },
      select: { id: true },
    });
    if (!territory) {
      throw new NotFoundError('Territory not found');
    }
  }

  // Every referenced outlet must belong to the client. The message names the
  // offending id so the caller can correct the specific stop.
  for (const outletId of input.outletIds) {
    const outlet = await prisma.outlet.findFirst({
      where: { id: outletId, clientId: input.clientId },
      select: { id: true },
    });
    if (!outlet) {
      throw new NotFoundError(`Outlet not found: ${outletId}`);
    }
  }

  // Every date this plan lands on. A one-off is the degenerate series of one,
  // so there is a single code path rather than two that can drift.
  const start = new Date(input.scheduledDate);
  const dates = input.recurrence ? expandOccurrences(start, input.recurrence) : [start];

  // A series is created ALL-OR-NOTHING. Half a journey plan is worse than none:
  // an agent would work a route that stops mid-month with nothing saying why.
  // Stops are written with the plan for the same reason — a plan has never
  // existed without the stops it was created from. Sequence is the 1-based index.
  const seriesId = input.recurrence ? randomUUID() : null;

  return prisma.$transaction(async (tx) => {
    const created = [];
    for (const scheduledDate of dates) {
      const plan = await tx.beatPlan.create({
        data: {
          clientId: input.clientId,
          agentId: input.agentId,
          territoryId: input.territoryId,
          name: input.name,
          scheduledDate,
          seriesId,
          recurrence: input.recurrence
            ? {
                frequency: input.recurrence.frequency,
                interval: input.recurrence.interval,
                daysOfWeek: input.recurrence.daysOfWeek ?? [],
                until: input.recurrence.until.toISOString(),
              }
            : undefined,
        },
      });
      await tx.beatPlanStop.createMany({
        data: input.outletIds.map((outletId, index) => ({
          beatPlanId: plan.id,
          outletId,
          sequence: index + 1,
        })),
      });
      const stops = await tx.beatPlanStop.findMany({
        where: { beatPlanId: plan.id },
        orderBy: { sequence: 'asc' },
      });
      created.push({ ...plan, stops });
    }

    // The first occurrence is returned as the created resource, so a one-off
    // create is byte-identical to what it always was. `occurrences` tells a
    // recurring caller how many plans it actually made — silence there is how
    // a manager assumes a year was scheduled when the cap allowed three months.
    return { ...created[0], seriesId, occurrences: created.length };
  });
}

export interface ListBeatPlansInput {
  clientId: string;
  role: AuthTokenPayload['role'];
  // The caller's own user id — used to scope a field_agent to their own plans.
  callerUserId: string;
  // Optional agentId filter (managers/admins); ignored for a field_agent, who
  // is always scoped to their own plans.
  agentId?: string;
  status?: BeatPlanStatus;
  limit: number;
  cursor?: string;
}

export async function listBeatPlans(input: ListBeatPlansInput) {
  const where: Prisma.BeatPlanWhereInput = { clientId: input.clientId };
  if (input.agentId) {
    where.agentId = input.agentId;
  }
  // A field_agent only ever sees their own plans — this overrides any filter.
  if (input.role === 'field_agent') {
    where.agentId = input.callerUserId;
  }
  if (input.status) {
    where.status = input.status;
  }

  const rows = await prisma.beatPlan.findMany({
    where,
    include: { stops: { orderBy: { sequence: 'asc' } } },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two plans share a scheduledDate — same reasoning as alerts.service.ts.
    orderBy: [{ scheduledDate: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
}

export interface GetBeatPlanInput {
  id: string;
  clientId: string;
  role: AuthTokenPayload['role'];
  callerUserId: string;
}

export async function getBeatPlan(input: GetBeatPlanInput) {
  const where: Prisma.BeatPlanWhereInput = { id: input.id, clientId: input.clientId };
  // A field_agent may only read their own plan; anything else is a 404.
  if (input.role === 'field_agent') {
    where.agentId = input.callerUserId;
  }

  const plan = await prisma.beatPlan.findFirst({
    where,
    include: { stops: { orderBy: { sequence: 'asc' } } },
  });
  if (!plan) {
    throw new NotFoundError('Beat plan not found');
  }

  return { ...plan, adherence: computeAdherence(plan.stops) };
}

export interface UpdateStopInput {
  planId: string;
  stopId: string;
  clientId: string;
  role: AuthTokenPayload['role'];
  callerUserId: string;
  visited: boolean;
}

export async function updateStop(input: UpdateStopInput) {
  // The stop is reachable only through a plan of the caller's client (and, for
  // a field_agent, only their own plan). A miss on either is a 404.
  const planWhere: Prisma.BeatPlanWhereInput = { id: input.planId, clientId: input.clientId };
  if (input.role === 'field_agent') {
    planWhere.agentId = input.callerUserId;
  }

  const stop = await prisma.beatPlanStop.findFirst({
    where: { id: input.stopId, beatPlan: planWhere },
  });
  if (!stop) {
    throw new NotFoundError('Beat plan stop not found');
  }

  return prisma.beatPlanStop.update({
    where: { id: stop.id },
    data: { visited: input.visited },
  });
}

export interface UpdateBeatPlanStatusInput {
  id: string;
  clientId: string;
  status: BeatPlanStatus;
}

export async function updateBeatPlanStatus(input: UpdateBeatPlanStatusInput) {
  const plan = await prisma.beatPlan.findFirst({
    where: { id: input.id, clientId: input.clientId },
    select: { id: true },
  });
  if (!plan) {
    throw new NotFoundError('Beat plan not found');
  }

  return prisma.beatPlan.update({
    where: { id: plan.id },
    data: { status: input.status },
    include: { stops: { orderBy: { sequence: 'asc' } } },
  });
}
