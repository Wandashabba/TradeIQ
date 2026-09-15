import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import {
  MAX_DEVICE_TOKEN_LENGTH,
  NOTIFICATION_CATEGORIES,
  NotificationPreferences,
  getNotificationPreferences,
  isPushPlatform,
  registerDeviceToken,
  unregisterDeviceToken,
  updateNotificationPreferences,
} from './push.service';

/**
 * Push notification devices and preferences (#67). Every role; the user and
 * tenant always come from the token, never the body.
 */
export const pushRouter = Router();
pushRouter.use(requireAuth);

function isToken(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    value.trim().length > 0 &&
    value.length <= MAX_DEVICE_TOKEN_LENGTH &&
    !/\s/.test(value)
  );
}

/** Registers or refreshes this device's token. Idempotent. */
pushRouter.post('/devices', async (req: AuthedRequest, res) => {
  const { token, platform } = (req.body ?? {}) as { token?: unknown; platform?: unknown };
  if (!isToken(token) || !isPushPlatform(platform)) {
    res.status(400).json({
      error: `token (1-${MAX_DEVICE_TOKEN_LENGTH} characters, no spaces) and platform (android|ios|web) are required`,
    });
    return;
  }
  const device = await registerDeviceToken({
    userId: req.user!.userId,
    clientId: req.user!.clientId,
    platform,
    token,
  });
  res.status(200).json(device);
});

/**
 * Removes this device's token (sign-out). 204 whether or not anything was
 * removed: a token that is gone, or now someone else's, is not an error.
 */
pushRouter.delete('/devices/:token', async (req: AuthedRequest, res) => {
  const { token } = req.params as { token: string };
  if (!isToken(token)) {
    res.status(400).json({ error: 'token is invalid' });
    return;
  }
  await unregisterDeviceToken({ userId: req.user!.userId, clientId: req.user!.clientId, token });
  res.status(204).end();
});

pushRouter.get('/preferences', async (req: AuthedRequest, res) => {
  res.status(200).json(await getNotificationPreferences(req.user!.userId));
});

pushRouter.patch('/preferences', async (req: AuthedRequest, res) => {
  const body = (req.body ?? {}) as Record<string, unknown>;
  const keys = Object.keys(body);
  const known = NOTIFICATION_CATEGORIES as readonly string[];
  if (
    keys.length === 0 ||
    keys.some((key) => !known.includes(key) || typeof body[key] !== 'boolean')
  ) {
    res.status(400).json({
      error: `send at least one of ${NOTIFICATION_CATEGORIES.join(', ')} as a boolean, and nothing else`,
    });
    return;
  }
  const prefs = await updateNotificationPreferences({
    userId: req.user!.userId,
    clientId: req.user!.clientId,
    changes: body as Partial<NotificationPreferences>,
  });
  res.status(200).json(prefs);
});
