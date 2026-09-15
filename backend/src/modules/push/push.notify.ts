import { NotificationCategory, UserRole } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { PushMessage, getPushSender, logPushUnconfigured } from './push.sender';

/**
 * Turns "tell these users about X" into push messages (#67).
 *
 * Recipients are filtered here, in one place, so no trigger can forget a rule:
 * only active users of the event's own tenant, only those who have not switched
 * the category off, and only tokens registered in that same tenant.
 */

export interface PushNotification {
  clientId: string;
  userIds: string[];
  category: NotificationCategory;
  title: string;
  body: string;
  /**
   * The in-app route opened on tap. A function when the right screen depends
   * on who is reading — a manager's task list is not an agent's.
   */
  route: string | ((role: UserRole) => string);
}

export interface NotifyResult {
  recipients: number;
  sent: number;
  invalidTokensRemoved: number;
}

const NOTHING: NotifyResult = { recipients: 0, sent: 0, invalidTokensRemoved: 0 };

/** Push text is a preview, not the record: one line, bounded. */
export function previewText(text: string, max = 140): string {
  const flat = text.replace(/\s+/g, ' ').trim();
  return flat.length <= max ? flat : `${flat.slice(0, max - 1).trimEnd()}…`;
}

export async function notifyUsers(notification: PushNotification): Promise<NotifyResult> {
  const sender = getPushSender();
  const userIds = [...new Set(notification.userIds)];
  if (userIds.length === 0) return NOTHING;
  if (!sender.enabled) {
    logPushUnconfigured(`a ${notification.category} push`);
    return NOTHING;
  }

  const users = await prisma.user.findMany({
    where: {
      id: { in: userIds },
      clientId: notification.clientId,
      active: true,
      notificationPrefs: { none: { category: notification.category, enabled: false } },
    },
    select: {
      role: true,
      deviceTokens: { where: { clientId: notification.clientId }, select: { token: true } },
    },
  });

  const title = previewText(notification.title, 80);
  const body = previewText(notification.body);
  const messages: PushMessage[] = users.flatMap((user) => {
    const route =
      typeof notification.route === 'function' ? notification.route(user.role) : notification.route;
    return user.deviceTokens.map(({ token }) => ({
      token,
      title,
      body,
      data: { route, category: notification.category },
    }));
  });
  if (messages.length === 0) return { ...NOTHING, recipients: users.length };

  const result = await sender.send(messages);
  let invalidTokensRemoved = 0;
  if (result.invalidTokens.length > 0) {
    ({ count: invalidTokensRemoved } = await prisma.deviceToken.deleteMany({
      where: { token: { in: result.invalidTokens } },
    }));
  }
  return { recipients: users.length, sent: result.sent, invalidTokensRemoved };
}

const inFlight = new Set<Promise<void>>();

/**
 * Fire-and-forget: the request that raised the event has already done its job,
 * and a slow or failing push must never delay or fail it. `build` runs after
 * the caller has moved on, so recipient lookups cost the request nothing, and
 * it is skipped outright while push is unconfigured.
 *
 * There is no durable queue: a push lost to a crash mid-send is not retried.
 * For a notification — a nudge to open the app, where the record already lives
 * — that is the right trade against a new table and a worker.
 */
export function firePush(label: string, build: () => Promise<PushNotification | null>): void {
  if (!getPushSender().enabled) {
    logPushUnconfigured(label);
    return;
  }
  const run = (async () => {
    const notification = await build();
    if (notification) await notifyUsers(notification);
  })()
    .catch((err) => console.error(`[push] ${label} failed:`, err))
    .finally(() => inFlight.delete(run));
  inFlight.add(run);
}

/** Waits for every push started by {@link firePush}. Tests and shutdown only. */
export async function settleInFlightPushes(): Promise<void> {
  while (inFlight.size > 0) {
    await Promise.allSettled([...inFlight]);
  }
}

/** Active managers and admins of a tenant — the people who watch the console. */
export async function supervisorIds(clientId: string): Promise<string[]> {
  const rows = await prisma.user.findMany({
    where: { clientId, active: true, role: { in: ['manager', 'admin'] } },
    select: { id: true },
  });
  return rows.map((r) => r.id);
}
