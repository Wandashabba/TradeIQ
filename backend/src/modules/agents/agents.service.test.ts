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
});
