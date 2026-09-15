import { prisma } from '../../lib/prisma';
import { notifyUsers, supervisorIds } from './push.notify';
import { taskRouteFor } from './push.triggers';

/**
 * SLA breaches (#67).
 *
 * Until now a breach was never *computed* anywhere on the server: a task
 * carries `slaDueAt` (from `lib/slaClock.ts`) and the app's `SlaPill` compares
 * it with the device clock when it draws the row. Nothing happens at the moment
 * a deadline passes, so there is no event to hang a push on. This sweep is
 * that event: an open or in-progress task whose `slaDueAt` has passed is
 * breached, and each breach is announced once.
 *
 * - **Once.** `slaBreachNotifiedAt` is claimed with a conditional update before
 *   anything is sent, so two instances sweeping together cannot both announce
 *   a task. The cost of that order is that a crash between claim and send
 *   loses that one push — acceptable for a nudge whose record is on screen.
 * - **Recent only.** Only breaches within {@link SLA_BREACH_LOOKBACK_MS} are
 *   announced. Switching push on must not fire a push for every task that went
 *   overdue months ago; those stay unannounced.
 * - **Who.** The task's owner, and the tenant's managers and admins.
 */

/** A day: a breach found later than this is history, not news. */
export const SLA_BREACH_LOOKBACK_MS = 24 * 60 * 60 * 1000;
export const SLA_BREACH_BATCH_SIZE = 50;

export interface SlaSweepResult {
  /** Breached tasks this run claimed (and so announced). */
  claimed: number;
}

export async function sweepSlaBreaches(
  now: Date = new Date(),
  batchSize = SLA_BREACH_BATCH_SIZE,
): Promise<SlaSweepResult> {
  const candidates = await prisma.task.findMany({
    where: {
      status: { not: 'closed' },
      slaBreachNotifiedAt: null,
      slaDueAt: { lte: now, gt: new Date(now.getTime() - SLA_BREACH_LOOKBACK_MS) },
    },
    orderBy: [{ slaDueAt: 'asc' }, { id: 'asc' }],
    take: batchSize,
    select: {
      id: true,
      ownerId: true,
      requiredFix: true,
      outlet: { select: { name: true, clientId: true } },
    },
  });

  let claimed = 0;
  for (const task of candidates) {
    const claim = await prisma.task.updateMany({
      where: { id: task.id, slaBreachNotifiedAt: null, status: { not: 'closed' } },
      data: { slaBreachNotifiedAt: now },
    });
    if (claim.count === 0) continue; // another instance, or closed meanwhile
    claimed += 1;

    const clientId = task.outlet.clientId;
    try {
      await notifyUsers({
        clientId,
        userIds: [task.ownerId, ...(await supervisorIds(clientId))],
        category: 'sla',
        title: 'Task overdue',
        body: `${task.outlet.name}: ${task.requiredFix}`,
        route: taskRouteFor,
      });
    } catch (err) {
      // One task's failed push must not stop the rest of the batch.
      console.error(`[sla-breach] push for task ${task.id} failed:`, err);
    }
  }
  return { claimed };
}
