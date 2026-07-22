/// One confirmed store presence: an agent stood inside this outlet's geofence
/// at this moment. The whole T0 feature is a list of these per agent.
export interface VisitStop {
  visitId: string;
  outletId: string;
  outletName: string;
  lat: number;
  lng: number;
  checkinTs: Date;
  status: 'in_progress' | 'submitted';
}

export type AgentState = 'at_store' | 'in_transit' | 'idle';

export interface AgentStateResult {
  state: AgentState;
  currentOutlet: { id: string; name: string } | null;
}

/**
 * Derives where an agent is from their stops, which MUST be ordered by
 * `checkinTs` ascending.
 *
 * Three states, not four. #153's sketch proposed an `offline` state, but T0
 * has no heartbeat — it cannot tell "phone is off" from "driving between
 * stores". Reporting `offline` would assert something we do not observe.
 */
export function deriveAgentState(stops: VisitStop[]): AgentStateResult {
  if (stops.length === 0) {
    return { state: 'idle', currentOutlet: null };
  }

  // Two open visits means the agent checked in somewhere without submitting
  // the previous one. Real data, not hypothetical. Take the latest: that is
  // where they most plausibly are now.
  const open = stops.filter((s) => s.status === 'in_progress');
  if (open.length > 0) {
    const latest = open[open.length - 1];
    return {
      state: 'at_store',
      currentOutlet: { id: latest.outletId, name: latest.outletName },
    };
  }

  return { state: 'in_transit', currentOutlet: null };
}
