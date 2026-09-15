import { readFileSync } from 'fs';
import { resolve } from 'path';
import {
  isPruneDue,
  locationPruneEnabled,
  startLocationPruneWorker,
} from './locationPrune.worker';
import { PruneResult, pruneLocationPings } from './locationRetention';

jest.mock('./locationRetention', () => ({
  ...jest.requireActual('./locationRetention'),
  pruneLocationPings: jest.fn(),
}));

const pruneMock = pruneLocationPings as unknown as jest.Mock;

const result: PruneResult = {
  retentionDays: 90,
  dryRun: false,
  expiredPings: 0,
  deactivatedAgentPings: 0,
  agentDaysSummarised: 2,
  pingsDeleted: 10,
  deactivatedAgentsPurged: 1,
  stoppedEarly: false,
};

/** Resolves once `mock` has been called `times` times, or fails after 2s. */
async function calledTimes(mock: jest.Mock, times: number): Promise<void> {
  const deadline = Date.now() + 2000;
  while (mock.mock.calls.length < times) {
    if (Date.now() > deadline) throw new Error(`expected ${times} call(s), saw ${mock.mock.calls.length}`);
    await new Promise((r) => setTimeout(r, 5));
  }
}

describe('location prune worker (#178)', () => {
  beforeEach(() => {
    pruneMock.mockReset();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
  });
  afterEach(() => jest.restoreAllMocks());

  it('is registered in server.ts, behind LOCATION_PRUNE_ENABLED, and stopped on shutdown', () => {
    const server = readFileSync(resolve(__dirname, '../../server.ts'), 'utf8');
    expect(server).toMatch(/locationPruneEnabled\(\)\s*\?\s*startLocationPruneWorker\(\)/);
    expect(server).toMatch(/locationPruneWorker\?\.stop\(\)/);
  });

  it('runs the real pruner by default, once per UTC day from the quiet hour', async () => {
    pruneMock.mockResolvedValue(result);
    let now = new Date('2026-09-15T00:30:00.000Z');
    const worker = startLocationPruneWorker({ intervalMs: 5, now: () => now });
    try {
      await calledTimes(pruneMock, 1);
      expect(pruneMock).toHaveBeenCalledWith({ now: new Date('2026-09-15T00:30:00.000Z') });

      // Many more checks the same day: no second run.
      await new Promise((r) => setTimeout(r, 60));
      expect(pruneMock).toHaveBeenCalledTimes(1);

      now = new Date('2026-09-16T00:05:00.000Z');
      await calledTimes(pruneMock, 2);
    } finally {
      await worker.stop();
    }
  });

  it('waits for the quiet hour', async () => {
    pruneMock.mockResolvedValue(result);
    const worker = startLocationPruneWorker({
      intervalMs: 5,
      hourUtc: 1,
      now: () => new Date('2026-09-15T00:59:00.000Z'),
    });
    await new Promise((r) => setTimeout(r, 50));
    await worker.stop();
    expect(pruneMock).not.toHaveBeenCalled();
  });

  it('retries a failed run on the next check', async () => {
    pruneMock.mockRejectedValueOnce(new Error('db down')).mockResolvedValue(result);
    const worker = startLocationPruneWorker({ intervalMs: 5, now: () => new Date('2026-09-15T03:00:00.000Z') });
    try {
      await calledTimes(pruneMock, 2);
      await new Promise((r) => setTimeout(r, 40));
      expect(pruneMock).toHaveBeenCalledTimes(2);
    } finally {
      await worker.stop();
    }
  });

  it('isPruneDue', () => {
    const at = new Date('2026-09-15T02:00:00.000Z');
    expect(isPruneDue(at, null, 0)).toBe(true);
    expect(isPruneDue(at, '2026-09-15', 0)).toBe(false);
    expect(isPruneDue(at, '2026-09-14', 0)).toBe(true);
    expect(isPruneDue(at, null, 3)).toBe(false);
  });

  it('LOCATION_PRUNE_ENABLED is on unless set to false', () => {
    expect(locationPruneEnabled({})).toBe(true);
    expect(locationPruneEnabled({ LOCATION_PRUNE_ENABLED: 'true' })).toBe(true);
    expect(locationPruneEnabled({ LOCATION_PRUNE_ENABLED: 'false' })).toBe(false);
    expect(locationPruneEnabled({ LOCATION_PRUNE_ENABLED: ' FALSE ' })).toBe(false);
  });
});
