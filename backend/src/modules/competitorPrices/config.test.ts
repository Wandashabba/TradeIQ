import { readFileSync } from 'fs';
import { resolve } from 'path';
import { collectionConfig, isCollectionGloballyEnabled, MIN_DOMAIN_INTERVAL_MS, userAgent } from './config';
import { competitorPriceWorkerEnabled, isRunDue, startCompetitorPriceWorker } from './collector.worker';

describe('competitor price collection config', () => {
  it('is off unless COMPETITOR_PRICE_COLLECTION is exactly "on"', () => {
    expect(isCollectionGloballyEnabled({})).toBe(false);
    for (const value of ['off', 'true', '1', 'yes', 'enabled', 'onn']) {
      expect(isCollectionGloballyEnabled({ COMPETITOR_PRICE_COLLECTION: value })).toBe(false);
    }
    expect(isCollectionGloballyEnabled({ COMPETITOR_PRICE_COLLECTION: ' ON ' })).toBe(true);
  });

  it('never lets per-domain spacing drop below 10 seconds', () => {
    expect(collectionConfig({ COMPETITOR_PRICE_DOMAIN_INTERVAL_MS: '500' }).domainIntervalMs).toBe(MIN_DOMAIN_INTERVAL_MS);
    expect(collectionConfig({}).domainIntervalMs).toBeGreaterThanOrEqual(MIN_DOMAIN_INTERVAL_MS);
    expect(collectionConfig({ COMPETITOR_PRICE_DOMAIN_INTERVAL_MS: 'abc' }).domainIntervalMs).toBeGreaterThanOrEqual(10_000);
  });

  it('keeps the daily cap small and the stale window sane', () => {
    expect(collectionConfig({}).dailyCapPerDomain).toBeLessThanOrEqual(50);
    expect(collectionConfig({ COMPETITOR_PRICE_DAILY_CAP: '100000' }).dailyCapPerDomain).toBe(200);
    expect(collectionConfig({}).staleAfterDays).toBe(7);
  });

  it('requires a printable contact for the User-Agent', () => {
    expect(collectionConfig({}).contact).toBeNull();
    expect(collectionConfig({ COMPETITOR_PRICE_BOT_CONTACT: 'bad\nheader' }).contact).toBeNull();
    expect(collectionConfig({ COMPETITOR_PRICE_BOT_CONTACT: 'https://tradeiq.example/bot' }).contact).toBe(
      'https://tradeiq.example/bot',
    );
    expect(userAgent('https://tradeiq.example/bot')).toBe(
      'TradeIQPriceBot/1.0 (+https://tradeiq.example/bot; competitor shelf-price research for TradeIQ; honours robots.txt)',
    );
  });

  it('documents the switch as off in .env.example', () => {
    const example = readFileSync(resolve(__dirname, '../../../.env.example'), 'utf8');
    expect(example).toMatch(/^COMPETITOR_PRICE_COLLECTION=off$/m);
  });
});

describe('competitor price worker', () => {
  it('is not started unless the kill switch is on', () => {
    expect(competitorPriceWorkerEnabled({})).toBe(false);
    expect(competitorPriceWorkerEnabled({ COMPETITOR_PRICE_COLLECTION: 'on' })).toBe(true);
  });

  it('runs once per UTC day from the run hour', () => {
    expect(isRunDue(new Date('2026-09-17T00:30:00Z'), null, 1)).toBe(false);
    expect(isRunDue(new Date('2026-09-17T01:00:00Z'), null, 1)).toBe(true);
    expect(isRunDue(new Date('2026-09-17T05:00:00Z'), '2026-09-17', 1)).toBe(false);
    expect(isRunDue(new Date('2026-09-18T01:00:00Z'), '2026-09-17', 1)).toBe(true);
  });

  it('does not retry a failed run the same day', async () => {
    const run = jest.fn().mockRejectedValue(new Error('boom'));
    const quiet = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    const worker = startCompetitorPriceWorker({ intervalMs: 5, hourUtc: 0, now: () => new Date('2026-09-17T02:00:00Z'), run });
    await new Promise((r) => setTimeout(r, 60));
    await worker.stop();
    expect(run).toHaveBeenCalledTimes(1);
    quiet.mockRestore();
  });

  it('is started from server.ts only behind the kill switch', () => {
    const server = readFileSync(resolve(__dirname, '../../server.ts'), 'utf8');
    expect(server).toMatch(/competitorPriceWorkerEnabled\(\) \? startCompetitorPriceWorker\(\) : null/);
  });
});
