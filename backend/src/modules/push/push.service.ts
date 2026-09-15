import { NotificationCategory, Prisma, PushPlatform } from '@prisma/client';
import { prisma } from '../../lib/prisma';

/**
 * Device tokens and notification preferences (#67).
 *
 * Every function takes the user and tenant from the caller's token (the routes
 * never read them from the body), so a user can only ever register a device to
 * themselves and read or change their own preferences.
 */

export const PUSH_PLATFORMS: readonly PushPlatform[] = ['android', 'ios', 'web'];
export const NOTIFICATION_CATEGORIES: readonly NotificationCategory[] = [
  'alerts',
  'tasks',
  'messages',
  'sla',
];

/** FCM tokens are ~160 characters today; this leaves room without inviting abuse. */
export const MAX_DEVICE_TOKEN_LENGTH = 4096;

export function isPushPlatform(value: unknown): value is PushPlatform {
  return typeof value === 'string' && (PUSH_PLATFORMS as readonly string[]).includes(value);
}

export type NotificationPreferences = Record<NotificationCategory, boolean>;

export interface RegisterDeviceInput {
  userId: string;
  clientId: string;
  platform: PushPlatform;
  token: string;
  now?: Date;
}

const deviceSelect = { platform: true, lastSeenAt: true } satisfies Prisma.DeviceTokenSelect;

/**
 * Registers or refreshes a device token. Idempotent: the same token again only
 * moves `lastSeenAt`. A token already held by someone else — the phone changed
 * hands — is re-pointed to this user and tenant rather than duplicated, so the
 * previous owner stops receiving pushes on it.
 */
export async function registerDeviceToken(input: RegisterDeviceInput) {
  const now = input.now ?? new Date();
  const upsert = () =>
    prisma.deviceToken.upsert({
      where: { token: input.token },
      create: {
        token: input.token,
        userId: input.userId,
        clientId: input.clientId,
        platform: input.platform,
        lastSeenAt: now,
      },
      update: {
        userId: input.userId,
        clientId: input.clientId,
        platform: input.platform,
        lastSeenAt: now,
      },
      select: deviceSelect,
    });
  try {
    return await upsert();
  } catch (err) {
    // Two registrations of one new token at once can both take the create
    // branch; the unique index lets one win, and the loser is now an update.
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      return upsert();
    }
    throw err;
  }
}

/**
 * Removes a device token — but only the caller's own. Deleting a token that is
 * absent, or that now belongs to someone else (the phone was re-registered), is
 * a no-op: sign-out must never unsubscribe the next person's device.
 */
export async function unregisterDeviceToken(input: {
  userId: string;
  clientId: string;
  token: string;
}): Promise<number> {
  const { count } = await prisma.deviceToken.deleteMany({
    where: { token: input.token, userId: input.userId, clientId: input.clientId },
  });
  return count;
}

export async function getNotificationPreferences(userId: string): Promise<NotificationPreferences> {
  const rows = await prisma.notificationPreference.findMany({
    where: { userId },
    select: { category: true, enabled: true },
  });
  const prefs = Object.fromEntries(
    NOTIFICATION_CATEGORIES.map((category) => [category, true]),
  ) as NotificationPreferences;
  for (const row of rows) prefs[row.category] = row.enabled;
  return prefs;
}

export async function updateNotificationPreferences(input: {
  userId: string;
  clientId: string;
  changes: Partial<NotificationPreferences>;
}): Promise<NotificationPreferences> {
  const entries = NOTIFICATION_CATEGORIES.filter((c) => input.changes[c] !== undefined).map(
    (category) => [category, input.changes[category] as boolean] as const,
  );
  await prisma.$transaction(
    entries.map(([category, enabled]) =>
      prisma.notificationPreference.upsert({
        where: { userId_category: { userId: input.userId, category } },
        create: { userId: input.userId, clientId: input.clientId, category, enabled },
        update: { enabled },
      }),
    ),
  );
  return getNotificationPreferences(input.userId);
}
