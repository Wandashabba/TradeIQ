import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { TaskPriority } from '../../lib/slaClock';
import {
  createTask,
  findTaskForClient,
  listTasks,
  TaskStatusInput,
  updateTask,
} from './tasks.service';

const PRIORITIES: readonly string[] = ['critical', 'high', 'normal'];
const STATUSES: readonly string[] = ['open', 'in_progress', 'closed'];

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

tasksRouter.get('/', async (req: AuthedRequest, res) => {
  const { status, priority, outletId } = req.query as {
    status?: unknown;
    priority?: unknown;
    outletId?: unknown;
  };

  if (
    (status !== undefined && (typeof status !== 'string' || !STATUSES.includes(status))) ||
    (priority !== undefined && (typeof priority !== 'string' || !PRIORITIES.includes(priority))) ||
    (outletId !== undefined && typeof outletId !== 'string')
  ) {
    res.status(400).json({
      error:
        'status must be open|in_progress|closed, priority must be critical|high|normal, and outletId must be a string',
    });
    return;
  }

  const tasks = await listTasks({
    clientId: req.user!.clientId,
    status: status as TaskStatusInput | undefined,
    priority: priority as TaskPriority | undefined,
    outletId: outletId as string | undefined,
  });
  res.status(200).json(tasks);
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

  if (status === 'closed' && closurePhotoUrl === undefined && !task.closurePhotoUrl) {
    res.status(400).json({
      error: 'Closing a task requires a closurePhotoUrl (in this request or already on the task)',
    });
    return;
  }

  const updated = await updateTask(task.id, {
    status: status as TaskStatusInput | undefined,
    closurePhotoUrl: closurePhotoUrl as string | undefined,
    closureVerified: closureVerified as boolean | undefined,
  });
  res.status(200).json(updated);
});
