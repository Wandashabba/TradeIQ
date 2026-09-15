/**
 * Push transport (#67).
 *
 * Callers never talk to Firebase directly. They hand {@link PushMessage}s to a
 * {@link PushSender}, and which sender that is gets decided once, from the
 * environment:
 *
 * - `FIREBASE_SERVICE_ACCOUNT` set (base64 of the service-account JSON) → the
 *   FCM sender, which reaches Android, iOS (through FCM's APNs bridge) and web.
 * - unset → the no-op sender, which only logs at debug level.
 *
 * The no-op path is the shipped default, not a test seam: the product decision
 * is to build push now and switch it on later, so a backend with no Firebase
 * project must boot, serve and pass every test exactly as before.
 * `firebase-admin` is therefore required lazily, inside the FCM sender, and is
 * never loaded while push is unconfigured.
 */

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  /**
   * Delivered as FCM `data`: string values only. Always carries `route` (the
   * in-app path to open on tap) and `category`.
   */
  data: Record<string, string>;
}

export interface PushSendResult {
  /** Messages FCM accepted. */
  sent: number;
  /** Tokens FCM reported as unregistered or invalid; the caller deletes them. */
  invalidTokens: string[];
}

export interface PushSender {
  /** False for the no-op sender: callers may skip recipient lookups entirely. */
  readonly enabled: boolean;
  send(messages: PushMessage[]): Promise<PushSendResult>;
}

export class NoopPushSender implements PushSender {
  readonly enabled = false;

  async send(messages: PushMessage[]): Promise<PushSendResult> {
    console.debug(
      `[push] FIREBASE_SERVICE_ACCOUNT is not set; not sending ${messages.length} push message(s)`,
    );
    return { sent: 0, invalidTokens: [] };
  }
}

/**
 * FCM error codes that mean "this token will never work again". Anything else
 * (quota, unavailable, internal, a bad payload) is our problem or a transient
 * one, and deleting the device for it would silently unsubscribe a real phone.
 */
export const INVALID_TOKEN_CODES: ReadonlySet<string> = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/** FCM's `sendEach` accepts at most 500 messages per call. */
export const FCM_BATCH_SIZE = 500;

/** The slice of firebase-admin's Messaging this sender uses. */
export interface FcmMessaging {
  sendEach(messages: FcmMessage[]): Promise<{
    successCount: number;
    responses: Array<{ success: boolean; error?: { code?: string; message?: string } }>;
  }>;
}

export interface FcmMessage {
  token: string;
  notification: { title: string; body: string };
  data: Record<string, string>;
  android: { priority: 'high' };
  apns: { payload: { aps: { sound: string } } };
}

export class FcmPushSender implements PushSender {
  readonly enabled = true;

  constructor(private readonly messaging: FcmMessaging) {}

  async send(messages: PushMessage[]): Promise<PushSendResult> {
    let sent = 0;
    const invalidTokens: string[] = [];
    for (let i = 0; i < messages.length; i += FCM_BATCH_SIZE) {
      const batch = messages.slice(i, i + FCM_BATCH_SIZE);
      const result = await this.messaging.sendEach(
        batch.map((m) => ({
          token: m.token,
          notification: { title: m.title, body: m.body },
          data: m.data,
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default' } } },
        })),
      );
      sent += result.successCount;
      result.responses.forEach((response, index) => {
        const code = response.error?.code;
        if (!response.success && code && INVALID_TOKEN_CODES.has(code)) {
          invalidTokens.push(batch[index].token);
        } else if (!response.success) {
          console.error(`[push] FCM rejected a message (${code ?? 'unknown'}): ${response.error?.message ?? ''}`);
        }
      });
    }
    return { sent, invalidTokens };
  }
}

/**
 * Decodes `FIREBASE_SERVICE_ACCOUNT`. Base64 because a multi-line private key
 * inside JSON does not survive `fly secrets set` quoting reliably.
 *
 * Returns null — never throws — for an unset, blank, undecodable or incomplete
 * value: a typo in a secret must degrade to "no push", not a crashed API.
 */
export function parseServiceAccount(raw: string | undefined): Record<string, string> | null {
  const trimmed = raw?.trim();
  if (!trimmed) return null;
  try {
    const parsed: unknown = JSON.parse(Buffer.from(trimmed, 'base64').toString('utf8'));
    if (
      typeof parsed === 'object' &&
      parsed !== null &&
      typeof (parsed as Record<string, unknown>).project_id === 'string' &&
      typeof (parsed as Record<string, unknown>).client_email === 'string' &&
      typeof (parsed as Record<string, unknown>).private_key === 'string'
    ) {
      return parsed as Record<string, string>;
    }
  } catch {
    // fall through
  }
  return null;
}

/** Builds the sender the environment asks for. */
export function createPushSender(env: NodeJS.ProcessEnv = process.env): PushSender {
  if (!env.FIREBASE_SERVICE_ACCOUNT?.trim()) {
    return new NoopPushSender();
  }
  const account = parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT);
  if (!account) {
    console.error(
      '[push] FIREBASE_SERVICE_ACCOUNT is set but is not base64 of a service-account JSON ' +
        '(project_id, client_email, private_key); push stays off',
    );
    return new NoopPushSender();
  }
  try {
    // Required here, not imported at the top, so an unconfigured backend never
    // loads firebase-admin at all.
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const adminApp = require('firebase-admin/app') as typeof import('firebase-admin/app');
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const adminMessaging = require('firebase-admin/messaging') as typeof import('firebase-admin/messaging');
    const name = 'tradeiq-push';
    const app =
      adminApp.getApps().find((a) => a.name === name) ??
      adminApp.initializeApp({ credential: adminApp.cert(account) }, name);
    console.log(`[push] FCM enabled for Firebase project ${account.project_id}`);
    return new FcmPushSender(adminMessaging.getMessaging(app));
  } catch (err) {
    console.error('[push] could not initialise firebase-admin; push stays off:', err);
    return new NoopPushSender();
  }
}

let current: PushSender | null = null;
let announcedUnconfigured = false;

/** The process-wide sender, created from the environment on first use. */
export function getPushSender(): PushSender {
  current ??= createPushSender();
  return current;
}

/** Replaces the process-wide sender. Tests only; pass null to re-read the env. */
export function setPushSender(sender: PushSender | null): void {
  current = sender;
  announcedUnconfigured = false;
}

/**
 * Says — once per process, at debug level — that events are raising no push
 * because push is unconfigured. Once, because every message and task would
 * otherwise log a line that says nothing new.
 */
export function logPushUnconfigured(what: string): void {
  if (announcedUnconfigured) return;
  announcedUnconfigured = true;
  console.debug(
    `[push] FIREBASE_SERVICE_ACCOUNT is not set; skipping ${what} (and every push after it, silently)`,
  );
}
