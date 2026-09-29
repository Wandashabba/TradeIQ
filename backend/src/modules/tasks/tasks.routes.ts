import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { TaskPriority } from '../../lib/slaClock';
import { parsePagination } from '../../lib/pagination';
import {
  createTask,
  findTaskForClient,
  listTasks,
  photoExistsForClient,
  TASK_STATES,
  TaskStateInput,
  TaskStatusInput,
  updateTask,
} from './tasks.service';

const PRIORITIES: readonly string[] = ['critical', 'high', 'normal'];
const STATUSES: readonly string[] = ['open', 'in_progress', 'closed'];
const STATES: readonly string[] = TASK_STATES;

export const tasksRouter = Router();
tasksRouter.use(requireAuth);

tasksRouter.post('/', requireRole('field_agent', 'manager'), async (req: AuthedRequest, res) => {
  const { outletId, findingType, requiredFix, priority, visitId, ownerId } = req.body as {
    outletId?: unknown;
    findingType?: unknown;
    requiredFix?: unknown;
    priority?: unknown;
    visitId?: unknown;
    ownerId?: unknown;
  };

  if (
    typeof outletId !== 'string' ||
    typeof findingType !== 'string' ||
    typeof requiredFix !== 'string' ||
    typeof priority !== 'string' ||
    !PRIORITIES.includes(priority) ||
    (visitId !== undefined && typeof visitId !== 'string') ||
    (ownerId !== undefined && typeof ownerId !== 'string')
  ) {
    res.status(400).json({
      error:
        'outletId, findingType, requiredFix, and priority (critical|high|normal) are required; visitId and ownerId must be strings when given',
    });
    return;
  }

  const task = await createTask({
    clientId: req.user!.clientId,
    callerUserId: req.user!.userId,
    outletId,
    findingType,
    requiredFix,
    priority: priority as TaskPriority,
    visitId,
    ownerId,
  });
  res.status(201).json(task);
});

// THE WORKLIST'S ONE REQUEST, and why the breakdown rides on it.
//
// The answer carries a `counts` object beside the page: the whole-set
// breakdown of every state, scoped exactly as the list is. It rides here
// rather than on a `GET /tasks/summary` of its own for three reasons:
//
//  1. **One snapshot.** The chips sit directly above the rows. A second
//     request is a second instant against a table that changes, and two
//     numbers that disagree on screen are worse than one number that is late.
//  2. **One `where`.** A separate endpoint means the tenant scoping is
//     written twice, and a count that drifts from the list's scope is the one
//     defect here that leaks — it would answer how much work exists in an
//     account the caller cannot see. `taskScope` is the single literal both
//     halves of this answer are built from.
//  3. **It is cheaper than what it replaces.** Measured on the seeded
//     database at 32,368 tasks: 8.1–8.5 ms for the breakdown and 7.4–10.3 ms
//     for the overdue count, and the breakdown supplies the `total` that
//     previously needed a `count()` of its own.
//
// It is not gated behind a query flag. A count that half the callers ask for
// is a count the other half quietly render as an unknown.
tasksRouter.get('/', async (req: AuthedRequest, res) => {
  const { status, state, priority, outletId } = req.query as {
    status?: unknown;
    state?: unknown;
    priority?: unknown;
    outletId?: unknown;
  };

  if (
    (status !== undefined && (typeof status !== 'string' || !STATUSES.includes(status))) ||
    (state !== undefined && (typeof state !== 'string' || !STATES.includes(state))) ||
    (priority !== undefined && (typeof priority !== 'string' || !PRIORITIES.includes(priority))) ||
    (outletId !== undefined && typeof outletId !== 'string')
  ) {
    res.status(400).json({
      error:
        'status must be open|in_progress|closed, state must be all|open|overdue|done, priority must be critical|high|normal, and outletId must be a string',
    });
    return;
  }

  // Two spellings of the same axis. `state=open` means "not closed" and
  // `status=open` means the literal enum value; a request carrying both is
  // asking for two different lists and is a bug in the caller, not a
  // precedence puzzle for this route to settle silently.
  if (status !== undefined && state !== undefined) {
    res.status(400).json({
      error:
        'status and state are two spellings of the same filter — send one. state=open means every task that is not closed; status=open means the open status alone',
    });
    return;
  }

  const { limit, cursor } = parsePagination(req);
  const page = await listTasks({
    clientId: req.user!.clientId,
    status: status as TaskStatusInput | undefined,
    state: state as TaskStateInput | undefined,
    priority: priority as TaskPriority | undefined,
    outletId: outletId as string | undefined,
    limit,
    cursor,
  });
  res.status(200).json(page);
});

tasksRouter.patch('/:id', requireRole('field_agent', 'manager'), async (req: AuthedRequest, res) => {
  const { status, closurePhotoUrl, closureVerified } = req.body as {
    status?: unknown;
    closurePhotoUrl?: unknown;
    closureVerified?: unknown;
  };

  if (
    (status !== undefined && (typeof status !== 'string' || !STATUSES.includes(status))) ||
    (closurePhotoUrl !== undefined && typeof closurePhotoUrl !== 'string') ||
    (closureVerified !== undefined && typeof closureVerified !== 'boolean')
  ) {
    res.status(400).json({
      error:
        'status must be open|in_progress|closed, closurePhotoUrl must be a string, and closureVerified must be a boolean',
    });
    return;
  }
  if (status === undefined && closurePhotoUrl === undefined && closureVerified === undefined) {
    res.status(400).json({
      error: 'At least one of status, closurePhotoUrl, or closureVerified is required',
    });
    return;
  }

  // Only managers may verify a closure — rejected before the tenant lookup.
  if (closureVerified !== undefined && req.user!.role !== 'manager') {
    res.status(403).json({ error: 'Only a manager may set closureVerified' });
    return;
  }

  const { id: taskId } = req.params as { id: string };
  const task = await findTaskForClient(taskId, req.user!.clientId);

  if (status === 'closed') {
    const effectiveClosurePhotoUrl = closurePhotoUrl ?? task.closurePhotoUrl;
    if (!effectiveClosurePhotoUrl) {
      res.status(400).json({
        error: 'Closing a task requires a closurePhotoUrl (in this request or already on the task)',
      });
      return;
    }
    // Require an uploaded, tenant-owned Photo backing the closure url — a bare
    // string is not enough.
    if (!(await photoExistsForClient(effectiveClosurePhotoUrl, req.user!.clientId))) {
      res.status(400).json({
        error: 'Closing a task requires a verified closure photo (upload via POST /photos first)',
      });
      return;
    }
  }

  const updated = await updateTask(task.id, {
    status: status as TaskStatusInput | undefined,
    closurePhotoUrl: closurePhotoUrl as string | undefined,
    closureVerified: closureVerified as boolean | undefined,
  });
  res.status(200).json(updated);
});
