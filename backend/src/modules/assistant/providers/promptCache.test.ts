import type { Tool } from '@google/genai';
import {
  forgetCachedPrefix,
  getCachedPrefix,
  resetPromptCache,
  type CachesClient,
} from './promptCache';

const TOOLS: Tool[] = [
  { functionDeclarations: [{ name: 'getStockLevels', description: 'stock', parameters: undefined }] },
];

function cachesSpy(name = 'cachedContents/abc') {
  const calls: Array<{ model: string; system?: string }> = [];
  const caches: CachesClient = {
    async create(params) {
      calls.push({ model: params.model, system: params.config.systemInstruction });
      return { name, usageMetadata: { totalTokenCount: 9000 } };
    },
  };
  return { caches, calls };
}

describe('prompt cache', () => {
  beforeEach(() => resetPromptCache());
  afterEach(() => jest.restoreAllMocks());

  it('creates one entry and reuses it for an identical prefix', async () => {
    // The whole point: the second turn must not pay to re-upload a prefix that
    // has not changed. A cache created per turn would cost more than none.
    const { caches, calls } = cachesSpy();

    const first = await getCachedPrefix(caches, 'gemini-x', 'SYSTEM', TOOLS);
    const second = await getCachedPrefix(caches, 'gemini-x', 'SYSTEM', TOOLS);

    expect(first).toBe('cachedContents/abc');
    expect(second).toBe('cachedContents/abc');
    expect(calls).toHaveLength(1);
  });

  it('does not let concurrent turns race into two entries', async () => {
    // Two requests arriving together on a cold cache would both miss and both
    // create — two server-side entries, both billed, one orphaned.
    const { caches, calls } = cachesSpy();

    await Promise.all([
      getCachedPrefix(caches, 'gemini-x', 'SYSTEM', TOOLS),
      getCachedPrefix(caches, 'gemini-x', 'SYSTEM', TOOLS),
    ]);

    expect(calls).toHaveLength(1);
  });

  it('keys on the prefix, so a different roster never shares a cache', async () => {
    // The roster is role-scoped. A manager and an admin see different tool
    // declarations, and sharing one cached prefix would hand one role the
    // other's tool catalogue.
    const { caches, calls } = cachesSpy();
    const otherTools: Tool[] = [
      { functionDeclarations: [{ name: 'getFraudFlags', description: 'fraud', parameters: undefined }] },
    ];

    await getCachedPrefix(caches, 'gemini-x', 'SYSTEM', TOOLS);
    await getCachedPrefix(caches, 'gemini-x', 'SYSTEM', otherTools);
    await getCachedPrefix(caches, 'gemini-x', 'DIFFERENT SYSTEM', TOOLS);

    expect(calls).toHaveLength(3);
  });

  it('returns null without a caches client, leaving the inline path untouched', async () => {
    // Every scripted test fake is such a client. Caching must not rewrite what
    // those assertions measure.
    expect(await getCachedPrefix(undefined, 'gemini-x', 'SYSTEM', TOOLS)).toBeNull();
  });

  it('returns null for a tool-less prefix rather than attempting a doomed create', async () => {
    // The quarantine pass carries no declarations, so its prefix sits below any
    // provider's minimum cacheable size. Asking anyway spends a request to be
    // told so, every single turn.
    const { caches, calls } = cachesSpy();

    expect(await getCachedPrefix(caches, 'gemini-x', 'SYSTEM', [])).toBeNull();
    expect(calls).toHaveLength(0);
  });

  it('falls back to null when the vendor refuses, and does not throw', async () => {
    // A cache that cannot be created is a cost regression, not an outage.
    jest.spyOn(console, 'warn').mockImplementation(() => {});
    const caches: CachesClient = {
      async create() {
        throw new Error('cached content is too small');
      },
    };

    await expect(getCachedPrefix(caches, 'gemini-x', 'SYSTEM', TOOLS)).resolves.toBeNull();
  });

  it('recreates after the name is forgotten', async () => {
    // A cache deleted server-side leaves us holding a dead name. Forgetting it
    // must actually free the slot, or every turn until the local TTL expires
    // keeps sending the same dead reference.
    const { caches, calls } = cachesSpy();

    const name = await getCachedPrefix(caches, 'gemini-x', 'SYSTEM', TOOLS);
    forgetCachedPrefix(name!);
    // forgetCachedPrefix resolves the stored promise before deleting, so let
    // that microtask settle before asserting the slot is free.
    await Promise.resolve();
    await getCachedPrefix(caches, 'gemini-x', 'SYSTEM', TOOLS);

    expect(calls).toHaveLength(2);
  });
});
