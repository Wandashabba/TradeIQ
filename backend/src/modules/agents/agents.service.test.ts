import { deriveAgentState, VisitStop } from './agents.service';

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
