import {
  FCM_BATCH_SIZE,
  FcmMessaging,
  FcmPushSender,
  NoopPushSender,
  PushMessage,
  createPushSender,
  getPushSender,
  logPushUnconfigured,
  parseServiceAccount,
  setPushSender,
} from './push.sender';

// Counts loads of firebase-admin: an unconfigured backend must never load it.
const mockFirebase = { appLoads: 0, messagingLoads: 0, sendEach: jest.fn() };

jest.mock('firebase-admin/app', () => {
  mockFirebase.appLoads += 1;
  const apps: Array<{ name: string }> = [];
  return {
    getApps: () => apps,
    cert: (account: object) => ({ account }),
    initializeApp: (_options: object, name: string) => {
      const app = { name };
      apps.push(app);
      return app;
    },
  };
});
jest.mock('firebase-admin/messaging', () => {
  mockFirebase.messagingLoads += 1;
  return { getMessaging: () => ({ sendEach: mockFirebase.sendEach }) };
});

const account = {
  project_id: 'tradeiq-test',
  client_email: 'push@tradeiq-test.iam.gserviceaccount.com',
  private_key: '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n',
};
const b64 = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64');

const message = (token: string): PushMessage => ({
  token,
  title: 'Title',
  body: 'Body',
  data: { route: '/alerts', category: 'alerts' },
});

describe('push sender (#67)', () => {
  beforeEach(() => {
    jest.spyOn(console, 'debug').mockImplementation(() => undefined);
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    mockFirebase.sendEach.mockReset();
  });
  afterEach(() => {
    jest.restoreAllMocks();
    setPushSender(null);
  });

  describe('unconfigured', () => {
    it('is a no-op sender when FIREBASE_SERVICE_ACCOUNT is unset or blank, without loading firebase-admin', async () => {
      for (const env of [{}, { FIREBASE_SERVICE_ACCOUNT: '' }, { FIREBASE_SERVICE_ACCOUNT: '   ' }]) {
        const sender = createPushSender(env);
        expect(sender).toBeInstanceOf(NoopPushSender);
        expect(sender.enabled).toBe(false);
      }
      expect(mockFirebase.appLoads).toBe(0);
      expect(mockFirebase.messagingLoads).toBe(0);

      const result = await new NoopPushSender().send([message('t1')]);
      expect(result).toEqual({ sent: 0, invalidTokens: [] });
      expect(console.debug).toHaveBeenCalledWith(expect.stringContaining('not sending 1 push message'));
    });

    it('is the process default under the test environment', () => {
      setPushSender(null);
      expect(getPushSender().enabled).toBe(false);
      // Memoised: the same instance until replaced.
      expect(getPushSender()).toBe(getPushSender());
    });

    it('logs the unconfigured skip once per process, at debug level', () => {
      logPushUnconfigured('a tasks push');
      logPushUnconfigured('a messages push');
      expect(console.debug).toHaveBeenCalledTimes(1);
      setPushSender(null);
      logPushUnconfigured('an alerts push');
      expect(console.debug).toHaveBeenCalledTimes(2);
    });

    it.each([
      ['not base64 JSON', 'not-json!!'],
      ['JSON missing the private key', b64({ project_id: 'p', client_email: 'e' })],
      ['a JSON array', b64(['x'])],
    ])('stays off, loudly, for %s', (_label, value) => {
      const sender = createPushSender({ FIREBASE_SERVICE_ACCOUNT: value });
      expect(sender.enabled).toBe(false);
      expect(console.error).toHaveBeenCalledWith(expect.stringContaining('push stays off'));
    });
  });

  describe('configured', () => {
    it('parses a base64 service account', () => {
      expect(parseServiceAccount(b64(account))).toEqual(account);
      expect(parseServiceAccount(undefined)).toBeNull();
    });

    it('builds the FCM sender from a valid service account', () => {
      const sender = createPushSender({ FIREBASE_SERVICE_ACCOUNT: b64(account) });
      expect(sender).toBeInstanceOf(FcmPushSender);
      expect(sender.enabled).toBe(true);
      // A second build reuses the named firebase app rather than re-initialising.
      expect(createPushSender({ FIREBASE_SERVICE_ACCOUNT: b64(account) }).enabled).toBe(true);
    });
  });

  describe('FcmPushSender', () => {
    const fcm = (impl: FcmMessaging['sendEach']) => new FcmPushSender({ sendEach: impl });

    it('sends notification + data, and reports unregistered or invalid tokens', async () => {
      const sendEach = jest.fn().mockResolvedValue({
        successCount: 1,
        responses: [
          { success: true },
          { success: false, error: { code: 'messaging/registration-token-not-registered' } },
          { success: false, error: { code: 'messaging/invalid-registration-token' } },
          { success: false, error: { code: 'messaging/internal-error', message: 'try later' } },
        ],
      });
      const result = await fcm(sendEach).send(['ok', 'gone', 'junk', 'transient'].map(message));

      expect(result).toEqual({ sent: 1, invalidTokens: ['gone', 'junk'] });
      // A transient failure is logged, and the device is NOT reported for deletion.
      expect(console.error).toHaveBeenCalledWith(expect.stringContaining('messaging/internal-error'));
      expect(sendEach.mock.calls[0][0][0]).toEqual({
        token: 'ok',
        notification: { title: 'Title', body: 'Body' },
        data: { route: '/alerts', category: 'alerts' },
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      });
    });

    it('batches at the FCM limit', async () => {
      const sendEach = jest.fn(async (batch: unknown[]) => ({
        successCount: batch.length,
        responses: batch.map(() => ({ success: true })),
      }));
      const tokens = Array.from({ length: FCM_BATCH_SIZE + 1 }, (_, i) => `t${i}`);
      const result = await fcm(sendEach).send(tokens.map(message));
      expect(sendEach).toHaveBeenCalledTimes(2);
      expect(sendEach.mock.calls[1][0]).toHaveLength(1);
      expect(result).toEqual({ sent: FCM_BATCH_SIZE + 1, invalidTokens: [] });
    });

    it('logs a failure that carries no error code', async () => {
      const sendEach = jest.fn().mockResolvedValue({ successCount: 0, responses: [{ success: false }] });
      expect(await fcm(sendEach).send([message('x')])).toEqual({ sent: 0, invalidTokens: [] });
      expect(console.error).toHaveBeenCalledWith(expect.stringContaining('(unknown)'));
    });
  });
});
