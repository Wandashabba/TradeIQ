import { deriveAgentState, listAgentActivity, VisitStop } from './agents.service';
import { prisma } from '../../lib/prisma';

const stop = (over: Partial<VisitStop> = {}): VisitStop => ({
  visitId: 'v1',
  outletId: 'o1',
  outletName: 'Sandton Spar',
  lat: -26.1,
  lng: 28.05,
  checkinTs: new Date('2026-07-22T08:00:00Z'),
  status: 'submitted',
  ...over,
});

describe('deriveAgentState', () => {
  it('reports idle when the agent has no stops', () => {
    expect(deriveAgentState([])).toEqual({ state: 'idle', currentOutlet: null });
  });

  it('reports at_store when a visit is still in progress', () => {
    const stops = [stop({ status: 'submitted' }), stop({ visitId: 'v2', outletId: 'o2', outletName: 'Rosebank PnP', status: 'in_progress' })];
    expect(deriveAgentState(stops)).toEqual({
      state: 'at_store',
      currentOutlet: { id: 'o2', name: 'Rosebank PnP' },
    });
  });

  it('reports in_transit when the latest visit is submitted', () => {
    const stops = [stop({ checkinTs: new Date('2026-07-22T08:00:00Z') })];
    expect(deriveAgentState(stops)).toEqual({ state: 'in_transit', currentOutlet: null });
  });

  it('reports in_transit when the latest of several submitted visits is submitted', () => {
    const stops = [
      stop({ visitId: 'v1', outletId: 'o1', outletName: 'First', checkinTs: new Date('2026-07-22T08:00:00Z') }),
      stop({ visitId: 'v2', outletId: 'o2', outletName: 'Second', checkinTs: new Date('2026-07-22T10:00:00Z') }),
      stop({ visitId: 'v3', outletId: 'o3', outletName: 'Third', checkinTs: new Date('2026-07-22T12:00:00Z') }),
    ];
    expect(deriveAgentState(stops)).toEqual({ state: 'in_transit', currentOutlet: null });
  });

  // The real "forgot to submit the earlier one" case: an open visit exists
  // but is not the most recent stop. An open visit always wins over
  // recency — the agent is confirmed present there until they submit.
  it('reports at_store for an in-progress visit even when a later visit was submitted', () => {
    const stops = [
      stop({ visitId: 'v1', outletId: 'o1', outletName: 'First', status: 'in_progress', checkinTs: new Date('2026-07-22T08:00:00Z') }),
      stop({ visitId: 'v2', outletId: 'o2', outletName: 'Second', status: 'submitted', checkinTs: new Date('2026-07-22T11:00:00Z') }),
    ];
    expect(deriveAgentState(stops)).toEqual({
      state: 'at_store',
      currentOutlet: { id: 'o1', name: 'First' },
    });
  });

  // Two open visits is a data anomaly (an agent who checked in twice without
  // submitting). It must not throw, and it must pick the later one — that is
  // where the agent most plausibly is now.
  it('picks the latest of two in-progress visits rather than throwing', () => {
    const stops = [
      stop({ visitId: 'v1', outletId: 'o1', outletName: 'First', status: 'in_progress', checkinTs: new Date('2026-07-22T08:00:00Z') }),
      stop({ visitId: 'v2', outletId: 'o2', outletName: 'Second', status: 'in_progress', checkinTs: new Date('2026-07-22T11:00:00Z') }),
    ];
    expect(deriveAgentState(stops)).toEqual({
      state: 'at_store',
      currentOutlet: { id: 'o2', name: 'Second' },
    });
  });
});

describe('listAgentActivity', () => {
  let clientId: string;
  let otherClientId: string;
  let agentId: string;
  let agentId2: string;
  let otherAgentId: string;
  let outletId: string;

  const FROM = new Date('2026-07-22T00:00:00Z');
  const TO = new Date('2026-07-23T00:00:00Z');

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'AGT-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const other = await prisma.client.create({
      data: { name: 'AGT-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = other.id;

    const agent = await prisma.user.create({
      data: { email: 'AGT-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;

    // A second same-tenant agent, deliberately kept without visits — it
    // exists so the pagination/limit tests always have exactly two
    // field_agent rows to page over ("two matching agents" throughout this
    // describe block always means agentId + agentId2, nothing more).
    const agent2 = await prisma.user.create({
      data: { email: 'AGT-agent2@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId2 = agent2.id;

    const otherAgent = await prisma.user.create({
      data: { email: 'AGT-other@example.com', passwordHash: 'x', role: 'field_agent', clientId: otherClientId },
    });
    otherAgentId = otherAgent.id;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Sandton Spar',
        code: 'AGT-O1',
        channelType: 'general_trade',
        lat: -26.1,
        lng: 28.05,
        clientId,
        territoryId: 'AGT-T1',
      },
    });
    outletId = outlet.id;

    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'Other Store',
        code: 'AGT-O2',
        channelType: 'general_trade',
        lat: -26.2,
        lng: 28.15,
        clientId: otherClientId,
        territoryId: 'AGT-T2',
      },
    });

    await prisma.visit.create({
      data: {
        outletId, agentId, clientId,
        checkinTs: new Date('2026-07-22T08:00:00Z'),
        checkinLat: -26.1, checkinLng: 28.05,
        geofencePass: true, status: 'submitted',
      },
    });

    // Another tenant's visit, same day. Must never appear.
    await prisma.visit.create({
      data: {
        outletId: otherOutlet.id, agentId: otherAgentId, clientId: otherClientId,
        checkinTs: new Date('2026-07-22T09:00:00Z'),
        checkinLat: -26.2, checkinLng: 28.15,
        geofencePass: true, status: 'submitted',
      },
    });
  });

  afterAll(async () => {
    // Safety net: the territory tests below clean up their own Territory /
    // UserTerritory rows in a `finally`, but if an assertion throws first
    // this still leaves the fixtures deletable.
    await prisma.userTerritory.deleteMany({
      where: { territory: { clientId: { in: [clientId, otherClientId] } } },
    });
    await prisma.territory.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
  });

  it('returns the agent with their stop and derived state', async () => {
    const result = await listAgentActivity({ clientId, from: FROM, to: TO });
    const mine = result.agents.find((a) => a.agentId === agentId);
    expect(mine).toBeDefined();
    expect(mine!.stops).toHaveLength(1);
    expect(mine!.stops[0].outletName).toBe('Sandton Spar');
    expect(mine!.state).toBe('in_transit');
    expect(mine!.lastSeenAt).toEqual(new Date('2026-07-22T08:00:00Z'));
  });

  it('never returns another tenant\'s agents', async () => {
    const result = await listAgentActivity({ clientId, from: FROM, to: TO });
    expect(result.agents.map((a) => a.agentId)).not.toContain(otherAgentId);
  });

  it('reports an agent with no visits in range as idle with a null lastSeenAt', async () => {
    const result = await listAgentActivity({
      clientId,
      from: new Date('2026-07-01T00:00:00Z'),
      to: new Date('2026-07-02T00:00:00Z'),
    });
    const mine = result.agents.find((a) => a.agentId === agentId);
    expect(mine!.state).toBe('idle');
    expect(mine!.lastSeenAt).toBeNull();
    expect(mine!.stops).toEqual([]);
  });

  // A non-positive limit must not be read as "unbounded". Clamped to 1 so a
  // bad query param (or a NaN forwarded from the route) still pages rather
  // than silently claiming there's nothing more to fetch.
  it('clamps a non-positive limit up to 1 instead of returning everything', async () => {
    const result = await listAgentActivity({ clientId, from: FROM, to: TO, limit: 0 });
    expect(result.agents).toHaveLength(1);
    expect(result.nextCursor).not.toBeNull();
  });

  it('limit: 1 returns one agent with nextCursor equal to that agent\'s id', async () => {
    const result = await listAgentActivity({ clientId, from: FROM, to: TO, limit: 1 });
    expect(result.agents).toHaveLength(1);
    expect(result.nextCursor).toBe(result.agents[0].agentId);
  });

  it('fetches the second page using the cursor from the first', async () => {
    const first = await listAgentActivity({ clientId, from: FROM, to: TO, limit: 1 });
    const second = await listAgentActivity({
      clientId,
      from: FROM,
      to: TO,
      limit: 1,
      cursor: first.nextCursor!,
    });
    expect(second.agents).toHaveLength(1);
    expect(second.agents[0].agentId).not.toBe(first.agents[0].agentId);
    expect(second.nextCursor).toBeNull();
  });

  // Guards the classic off-by-one: returning exactly `limit` rows must not
  // also emit a cursor implying there is more.
  it('nextCursor is null when limit equals the total number of matching agents', async () => {
    const result = await listAgentActivity({ clientId, from: FROM, to: TO, limit: 2 });
    expect(result.agents).toHaveLength(2);
    expect(result.agents.map((a) => a.agentId).sort()).toEqual([agentId, agentId2].sort());
    expect(result.nextCursor).toBeNull();
  });

  // The regression this guards against: the client-facing contract is a
  // Territory.id (matching every other dashboard endpoint), and
  // UserTerritory joins Territory by foreign key so the id matches directly.
  // Asserting on the assigned agent (not just "the list is non-empty") is
  // what would catch this filter silently matching on the wrong column.
  it('filters agents to those assigned to a territory, matched by id not code', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'AGT-Territory', code: 'AGT-TC1' },
    });
    await prisma.userTerritory.create({ data: { userId: agentId, territoryId: territory.id } });

    try {
      const result = await listAgentActivity({ clientId, from: FROM, to: TO, territoryId: territory.id });
      expect(result.agents.map((a) => a.agentId)).toEqual([agentId]);
    } finally {
      await prisma.userTerritory.deleteMany({ where: { territoryId: territory.id } });
      await prisma.territory.delete({ where: { id: territory.id } });
    }
  });

  // Pins the contract in the other direction: passing the territory's CODE
  // (what the dropdown used to be suspected of sending, and what this
  // endpoint used to match on) must now match nothing, not accidentally
  // succeed. This is the exact bug (#153) — an id sent, a code matched — and
  // this test would have caught it in either direction.
  it('returns no agents when a territory code is passed instead of its id', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'AGT-Territory-2', code: 'AGT-TC2' },
    });
    await prisma.userTerritory.create({ data: { userId: agentId, territoryId: territory.id } });

    try {
      const result = await listAgentActivity({ clientId, from: FROM, to: TO, territoryId: territory.code });
      expect(result).toEqual({ agents: [], nextCursor: null });
    } finally {
      await prisma.userTerritory.deleteMany({ where: { territoryId: territory.id } });
      await prisma.territory.delete({ where: { id: territory.id } });
    }
  });

  it('returns no agents when the territory id has zero assignments', async () => {
    const result = await listAgentActivity({ clientId, from: FROM, to: TO, territoryId: 'AGT-NOPE' });
    expect(result).toEqual({ agents: [], nextCursor: null });
  });

  // Two open visits with an identical checkinTs is plausible from a retried
  // offline sync. `orderBy: checkinTs asc` alone leaves Postgres free to
  // return ties in either order, which `deriveAgentState`'s stable sort
  // would then faithfully propagate into a flip-flopping currentOutlet. A
  // secondary `id` sort is what makes "pick the latest" deterministic.
  it('picks the same outlet across repeated calls when two open visits share an exact checkinTs', async () => {
    const tieClient = await prisma.client.create({
      data: { name: 'AGT-Tie-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const tieAgent = await prisma.user.create({
      data: { email: 'AGT-tie-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId: tieClient.id },
    });
    const outletA = await prisma.outlet.create({
      data: {
        name: 'Tie Outlet A',
        code: 'AGT-TIE-A',
        channelType: 'general_trade',
        lat: -26.1,
        lng: 28.05,
        clientId: tieClient.id,
        territoryId: 'AGT-TIE-T',
      },
    });
    const outletB = await prisma.outlet.create({
      data: {
        name: 'Tie Outlet B',
        code: 'AGT-TIE-B',
        channelType: 'general_trade',
        lat: -26.1,
        lng: 28.05,
        clientId: tieClient.id,
        territoryId: 'AGT-TIE-T',
      },
    });
    const tieTs = new Date('2026-07-22T10:00:00Z');
    const v1 = await prisma.visit.create({
      data: {
        outletId: outletA.id,
        agentId: tieAgent.id,
        clientId: tieClient.id,
        checkinTs: tieTs,
        checkinLat: -26.1,
        checkinLng: 28.05,
        geofencePass: true,
        status: 'in_progress',
      },
    });
    const v2 = await prisma.visit.create({
      data: {
        outletId: outletB.id,
        agentId: tieAgent.id,
        clientId: tieClient.id,
        checkinTs: tieTs,
        checkinLat: -26.1,
        checkinLng: 28.05,
        geofencePass: true,
        status: 'in_progress',
      },
    });

    try {
      // With an identical checkinTs, an ascending [checkinTs, id] order puts
      // the larger id last — that's the deterministic "latest" pick.
      const expectedOutletId = v1.id > v2.id ? outletA.id : outletB.id;

      const first = await listAgentActivity({ clientId: tieClient.id, from: FROM, to: TO });
      const second = await listAgentActivity({ clientId: tieClient.id, from: FROM, to: TO });
      expect(first.agents[0].currentOutlet?.id).toBe(expectedOutletId);
      expect(second.agents[0].currentOutlet?.id).toBe(expectedOutletId);
    } finally {
      await prisma.visit.deleteMany({ where: { clientId: tieClient.id } });
      await prisma.outlet.deleteMany({ where: { clientId: tieClient.id } });
      await prisma.user.deleteMany({ where: { clientId: tieClient.id } });
      await prisma.client.delete({ where: { id: tieClient.id } });
    }
  });
});
