import { prisma } from '../../../lib/prisma';
import * as gate from '../../competitorPrices/gate';
import { resolveToolGates } from '../toolGates';
import { ToolFacingError } from '../types';
import { buildTools } from './index';

/**
 * `getCompetitorShelfPrices` at the tool layer: the gate at declaration, the
 * gate again at run time, and a description that routes the neighbours away.
 * The service is exercised against a database in competitorPrices.service.test.ts.
 */

const NOW = new Date('2026-09-17T10:00:00.000Z');
const ON = { COMPETITOR_PRICE_COLLECTION: 'on' };

async function client(enabled: boolean, approved: boolean) {
  const row = await prisma.client.create({
    data: {
      name: `CPTOOL-${Date.now()}-${Math.random()}`,
      industry: 'FMCG',
      scorecardWeights: {},
      kpiThresholds: {},
      competitorPriceCollectionEnabled: enabled,
      competitorPriceCollectionApprovedBy: approved ? 'Legal' : null,
      competitorPriceCollectionApprovedAt: approved ? new Date('2026-09-01') : null,
    },
  });
  return row.id;
}

function tool(clientId: string) {
  const found = buildTools({
    user: { userId: 'u1', role: 'manager', clientId },
    now: NOW,
    gates: { competitorShelfPrices: true },
  }).find((t) => t.name === 'getCompetitorShelfPrices');
  if (!found) throw new Error('not declared');
  return found;
}

describe('resolveToolGates', () => {
  it('keeps the gate closed with the kill switch off, without querying the database', async () => {
    const id = await client(true, true);
    const findUnique = jest.spyOn(prisma.client, 'findUnique');
    expect(await resolveToolGates(id, {})).toEqual({ competitorShelfPrices: false });
    expect(findUnique).not.toHaveBeenCalled();
    findUnique.mockRestore();
  });

  it('keeps it closed for a client that is not enabled, or not approved', async () => {
    expect(await resolveToolGates(await client(false, true), ON)).toEqual({ competitorShelfPrices: false });
    expect(await resolveToolGates(await client(true, false), ON)).toEqual({ competitorShelfPrices: false });
  });

  it('opens it only for an enabled, approved client with the kill switch on', async () => {
    expect(await resolveToolGates(await client(true, true), ON)).toEqual({ competitorShelfPrices: true });
  });

  it('fails closed when the gate cannot be read', async () => {
    const spy = jest.spyOn(gate, 'competitorPriceGate').mockRejectedValueOnce(new Error('db down'));
    const quiet = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    expect(await resolveToolGates('any', ON)).toEqual({});
    spy.mockRestore();
    quiet.mockRestore();
  });
});

describe('getCompetitorShelfPrices tool', () => {
  const previous = process.env.COMPETITOR_PRICE_COLLECTION;
  afterEach(() => {
    if (previous === undefined) delete process.env.COMPETITOR_PRICE_COLLECTION;
    else process.env.COMPETITOR_PRICE_COLLECTION = previous;
  });

  it('refuses at run time if the gate has closed since it was declared', async () => {
    delete process.env.COMPETITOR_PRICE_COLLECTION;
    const t = tool(await client(true, true));
    await expect(t.run(t.args.parse({}))).rejects.toBeInstanceOf(ToolFacingError);
  });

  it('runs for an enabled client and returns outside-labelled data', async () => {
    process.env.COMPETITOR_PRICE_COLLECTION = 'on';
    const t = tool(await client(true, true));
    const result = (await t.run(t.args.parse({}))) as { dataOrigin: string; competitorSkus: unknown[] };
    expect(result.dataOrigin).toBe('outside_public_retailer_website');
    expect(result.competitorSkus).toEqual([]);
  });

  it('says when NOT to use it, naming both neighbours', () => {
    const { description } = tool('c1');
    expect(description).toMatch(/^Call this when/);
    expect(description).toMatch(/OUTSIDE, PUBLIC data/);
    expect(description).toMatch(/Do NOT use it .*getCompetitorActivity.*getPriceCompliance/s);
    expect(description).toMatch(/stale/);
  });

  it('does not accept the fixture-only retailer as an argument', () => {
    const t = tool('c1');
    expect(t.args.safeParse({ retailer: 'example' }).success).toBe(false);
    expect(t.args.safeParse({ retailer: 'checkers' }).success).toBe(true);
  });
});
