import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { computeSlaDueAt, TaskPriority } from '../../lib/slaClock';
import { buildPage } from '../../lib/pagination';
import { attachEvidencePhotoIds } from '../photos/photos.service';

export type TaskStatusInput = 'open' | 'in_progress' | 'closed';

export interface CreateTaskInput {
  clientId: string;
  callerUserId: string;
  outletId: string;
  findingType: string;
  requiredFix: string;
  priority: TaskPriority;
  visitId?: string;
  ownerId?: string;
}

export async function createTask(input: CreateTaskInput) {
  const outlet = await prisma.outlet.findFirst({
    where: { id: input.outletId, clientId: input.clientId },
    select: { id: true },
  });
  if (!outlet) {
    throw new NotFoundError('Outlet not found');
  }

  if (input.visitId) {
    const visit = await prisma.visit.findFirst({
      where: { id: input.visitId, clientId: input.clientId },
      select: { id: true },
    });
    if (!visit) {
      throw new NotFoundError('Visit not found');
    }
  }

  // The caller owns the task by default; an explicit ownerId must belong to
  // the caller's client.
  let ownerId = input.callerUserId;
  if (input.ownerId) {
    const owner = await prisma.user.findFirst({
      where: { id: input.ownerId, clientId: input.clientId },
      select: { id: true },
    });
    if (!owner) {
      throw new NotFoundError('Owner not found');
    }
    ownerId = input.ownerId;
  }

  return prisma.task.create({
    data: {
      visitId: input.visitId,
      findingType: input.findingType,
      outletId: input.outletId,
      requiredFix: input.requiredFix,
      priority: input.priority,
      slaDueAt: computeSlaDueAt(input.priority, new Date()),
      ownerId,
    },
  });
}

export interface ListTasksInput {
  clientId: string;
  status?: TaskStatusInput;
  priority?: TaskPriority;
  outletId?: string;
  limit: number;
  cursor?: string;
}

export async function listTasks(input: ListTasksInput) {
  const rows = await prisma.task.findMany({
    where: {
      // Tasks carry no clientId of their own — tenant scope goes through the
      // outlet relation.
      outlet: { clientId: input.clientId },
      ...(input.status ? { status: input.status } : {}),
      ...(input.priority ? { priority: input.priority } : {}),
      ...(input.outletId ? { outletId: input.outletId } : {}),
    },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two tasks share a slaDueAt — same reasoning as alerts.service.ts.
    //
    // COPYING THIS PATTERN: the tiebreaker's direction MUST match the primary
    // sort's direction (both `asc` here).
    orderBy: [{ slaDueAt: 'asc' }, { id: 'asc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  const page = buildPage(rows, input.limit);
  // evidencePhotoId (newest photo of the linked visit) — one batched query,
  // AFTER buildPage so the dropped probe row costs nothing and the cursor
  // (last kept row's id) is untouched.
  return { data: await attachEvidencePhotoIds(page.data), nextCursor: page.nextCursor };
}

export async function findTaskForClient(taskId: string, clientId: string) {
  const task = await prisma.task.findFirst({
    where: { id: taskId, outlet: { clientId } },
  });
  if (!task) {
    throw new NotFoundError('Task not found');
  }
  return task;
}

// A closure photo counts as verified only when a Photo row exists whose url
// matches and whose visit belongs to the caller's client (Photo -> visit ->
// clientId). This blocks closing a task with an arbitrary, unowned url.
export async function photoExistsForClient(url: string, clientId: string): Promise<boolean> {
  const photo = await prisma.photo.findFirst({
    where: { url, visit: { clientId } },
    select: { id: true },
  });
  return photo !== null;
}

export interface UpdateTaskInput {
  status?: TaskStatusInput;
  closurePhotoUrl?: string;
  closureVerified?: boolean;
}

export async function updateTask(taskId: string, input: UpdateTaskInput) {
  // Prisma treats undefined fields as "leave unchanged".
  return prisma.task.update({
    where: { id: taskId },
    data: {
      status: input.status,
      closurePhotoUrl: input.closurePhotoUrl,
      closureVerified: input.closureVerified,
    },
  });
}
