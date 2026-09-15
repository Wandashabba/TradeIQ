import { UserRole } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { firePush, previewText, supervisorIds } from './push.notify';

/**
 * The events that raise a push (#67), one function each, called from the
 * module that owns the event. Each one returns immediately: recipients are
 * looked up and the push is sent after the triggering request has moved on
 * (see {@link firePush}).
 *
 * Payloads carry only what the recipient can already see in the app — an
 * outlet name, a task's required fix, a message they were sent. Never an email
 * address, a location, or another user's name.
 */

/** Where a task push lands: the console's task list, or the agent's day. */
export function taskRouteFor(role: UserRole): string {
  return role === 'field_agent' ? '/today' : '/tasks';
}

/** `alert.raised` — to the tenant's managers and admins, who own the Alerts screen. */
export function pushAlertRaised(input: {
  clientId: string;
  visitId: string;
  alerts: Array<{ message: string }>;
}): void {
  firePush('alert.raised push', async () => {
    if (input.alerts.length === 0) return null;
    const [recipients, visit] = await Promise.all([
      supervisorIds(input.clientId),
      prisma.visit.findFirst({
        where: { id: input.visitId, clientId: input.clientId },
        select: { outlet: { select: { name: true } } },
      }),
    ]);
    const outlet = visit?.outlet.name ?? 'an outlet';
    const count = input.alerts.length;
    return {
      clientId: input.clientId,
      userIds: recipients,
      category: 'alerts',
      title: count === 1 ? `Alert at ${outlet}` : `${count} alerts at ${outlet}`,
      body: count === 1 ? input.alerts[0].message : previewText(input.alerts.map((a) => a.message).join(' · ')),
      route: '/alerts',
    };
  });
}

/**
 * A task assigned to someone other than its creator. A task an agent raises on
 * their own visit (a risk, a stockout) is already in front of them, so it
 * raises nothing.
 */
export function pushTaskAssigned(input: {
  clientId: string;
  assignedById: string;
  task: { ownerId: string; outletId: string; requiredFix: string; priority: string };
}): void {
  if (input.task.ownerId === input.assignedById) return;
  firePush('task assigned push', async () => {
    const outlet = await prisma.outlet.findFirst({
      where: { id: input.task.outletId, clientId: input.clientId },
      select: { name: true },
    });
    return {
      clientId: input.clientId,
      userIds: [input.task.ownerId],
      category: 'tasks',
      title: input.task.priority === 'critical' ? 'Critical task assigned to you' : 'New task assigned to you',
      body: `${outlet?.name ?? 'Outlet'}: ${input.task.requiredFix}`,
      route: taskRouteFor,
    };
  });
}

/** A message: to its recipient, or — for a broadcast — to everyone else in the tenant. */
export function pushMessageSent(input: {
  clientId: string;
  senderId: string;
  recipientId: string | null;
  body: string;
  attachmentCount: number;
}): void {
  firePush('message push', async () => {
    const userIds = input.recipientId
      ? [input.recipientId]
      : (
          await prisma.user.findMany({
            where: { clientId: input.clientId, active: true, id: { not: input.senderId } },
            select: { id: true },
          })
        ).map((u) => u.id);
    const text = input.body.trim();
    const photos = input.attachmentCount === 1 ? 'Sent a photo' : `Sent ${input.attachmentCount} photos`;
    return {
      clientId: input.clientId,
      userIds: userIds.filter((id) => id !== input.senderId),
      category: 'messages',
      title: input.recipientId ? 'New message' : 'New team message',
      body: text.length > 0 ? text : photos,
      route: '/messages',
    };
  });
}

/** An announcement: to everyone in the tenant but its author. */
export function pushAnnouncement(input: {
  clientId: string;
  authorId: string;
  title: string;
  body: string;
}): void {
  firePush('announcement push', async () => {
    const users = await prisma.user.findMany({
      where: { clientId: input.clientId, active: true, id: { not: input.authorId } },
      select: { id: true },
    });
    return {
      clientId: input.clientId,
      userIds: users.map((u) => u.id),
      category: 'messages',
      title: `Announcement: ${input.title}`,
      body: input.body,
      route: '/messages',
    };
  });
}
