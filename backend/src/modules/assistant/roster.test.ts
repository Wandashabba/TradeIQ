import { ROLES, type Role } from '../auth/auth.service';
import { ALL_TOOL_NAMES, TOOL_REGISTRY, pillarOf, rosterFor, type ToolName } from './roster';

/**
 * The full (role × tool) matrix, written out rather than computed.
 *
 * Computing the expectation from `ROSTERS` would make this test assert that the
 * table equals itself. Spelling every pair out means a change to the roster
 * fails here and has to be re-affirmed by a human — which is the entire point
 * of a security boundary being a table instead of a rule.
 */
const EXPECTED: Readonly<Record<Role, Readonly<Record<ToolName, boolean>>>> = {
  field_agent: {
    getRateOfSale: false,
    getSkuMovement: false,
    getTerritoryRanking: false,
    getStockLevels: false,
    getShareOfShelf: false,
    getVisibilityCompliance: false,
    getCompetitorActivity: false,
    getAgentScorecard: false,
    getVisitHistory: false,
    getFraudFlags: false,
    getMetricTrend: false,
    getCampaignPerformance: false,
    getSellInForecast: false,
    getPriceCompliance: false,
    getCompetitorShelfPrices: false,
    getContestStandings: false,
    getTaskSummary: false,
    getAlerts: false,
    findTerritories: false,
  },
  manager: {
    getRateOfSale: true,
    getSkuMovement: true,
    getTerritoryRanking: true,
    getStockLevels: true,
    getShareOfShelf: true,
    getVisibilityCompliance: true,
    getCompetitorActivity: true,
    getAgentScorecard: true,
    getVisitHistory: true,
    getFraudFlags: true,
    getMetricTrend: true,
    getCampaignPerformance: true,
    getSellInForecast: true,
    getPriceCompliance: true,
    getCompetitorShelfPrices: true,
    getContestStandings: true,
    getTaskSummary: true,
    getAlerts: true,
    findTerritories: true,
  },
  admin: {
    getRateOfSale: true,
    getSkuMovement: true,
    getTerritoryRanking: true,
    getStockLevels: true,
    getShareOfShelf: true,
    getVisibilityCompliance: true,
    getCompetitorActivity: true,
    getAgentScorecard: true,
    getVisitHistory: true,
    getFraudFlags: true,
    getMetricTrend: true,
    getCampaignPerformance: true,
    getSellInForecast: true,
    getPriceCompliance: true,
    getCompetitorShelfPrices: true,
    getContestStandings: true,
    getTaskSummary: true,
    getAlerts: true,
    findTerritories: true,
  },
};

describe('assistant roster — the security boundary', () => {
  describe('every (role × tool) pair', () => {
    for (const role of ROLES) {
      for (const tool of ALL_TOOL_NAMES) {
        const allowed = EXPECTED[role][tool];
        it(`${role} ${allowed ? 'CAN' : 'CANNOT'} reach ${tool}`, () => {
          expect(rosterFor(role).has(tool)).toBe(allowed);
        });
      }
    }
  });

  describe('the negative case that matters', () => {
    it('field_agent reaches no tool at all in Phase 0', () => {
      // Manager-console only (STATUS.md → Decisions → Audience). If this ever
      // becomes non-empty it must be a deliberate Phase 5 decision, not a tool
      // author adding themselves to every roster out of habit.
      expect(rosterFor('field_agent').size).toBe(0);
    });

    it('field_agent cannot reach a single manager tool', () => {
      const agent = rosterFor('field_agent');
      for (const tool of rosterFor('manager')) {
        expect(agent.has(tool)).toBe(false);
      }
    });
  });

  describe('hierarchy is asserted, never assumed', () => {
    // The code does not derive admin from manager. These tests are what make
    // the containment true — remove them and an inherited-permissions bug
    // becomes silent.
    it('admin ⊇ manager', () => {
      const admin = rosterFor('admin');
      for (const tool of rosterFor('manager')) {
        expect(admin.has(tool)).toBe(true);
      }
    });

    it('manager ⊇ field_agent', () => {
      const manager = rosterFor('manager');
      for (const tool of rosterFor('field_agent')) {
        expect(manager.has(tool)).toBe(true);
      }
    });
  });

  describe('registry integrity', () => {
    it('every rostered tool exists in the registry', () => {
      for (const role of ROLES) {
        for (const tool of rosterFor(role)) {
          expect(ALL_TOOL_NAMES).toContain(tool);
        }
      }
    });

    it('every registered tool is reachable by at least one role', () => {
      // A tool nobody can call is either dead code or a roster omission, and
      // both are worth failing on rather than shipping.
      for (const tool of ALL_TOOL_NAMES) {
        const reachable = ROLES.some((role) => rosterFor(role).has(tool));
        expect(reachable).toBe(true);
      }
    });

    it('every registered tool has a pillar', () => {
      const pillars = new Set(['sales', 'stock', 'visibility', 'competition', 'execution']);
      for (const tool of ALL_TOOL_NAMES) {
        expect(pillars.has(pillarOf(tool))).toBe(true);
      }
    });

    it('no tool name collides after case-folding', () => {
      // The name is part of the cached prompt prefix and is what the model
      // emits back. Two tools differing only by case is an ambiguity the model
      // resolves however it likes.
      const folded = ALL_TOOL_NAMES.map((n) => n.toLowerCase());
      expect(new Set(folded).size).toBe(ALL_TOOL_NAMES.length);
    });
  });

  describe('failure modes', () => {
    it('fails closed on a role the table does not know', () => {
      // Unreachable through the type system; reachable through a JWT, which is
      // data off the wire regardless of what the type says.
      expect(rosterFor('auditor' as Role).size).toBe(0);
    });

    it('widening a returned roster cannot widen the next caller’s', () => {
      // Note this asserts isolation, not throwing. `Object.freeze` on a Set is
      // decorative — Set contents live in internal slots, so a frozen Set still
      // accepts .add(). A per-call copy is what actually holds the boundary,
      // and this is the test that would catch a change back to a shared set.
      (rosterFor('field_agent') as Set<string>).add('getFraudFlags');
      expect(rosterFor('field_agent').size).toBe(0);
      expect(rosterFor('field_agent').has('getFraudFlags')).toBe(false);
    });

    it('narrowing a returned roster cannot narrow the next caller’s', () => {
      (rosterFor('manager') as Set<string>).delete('getAgentScorecard');
      expect(rosterFor('manager').has('getAgentScorecard')).toBe(true);
    });
  });

  describe('identity is never a tool argument', () => {
    it('no tool name suggests a tenant selector', () => {
      // The structural guarantee lives in the closure: tools bind to req.user
      // and expose no identity parameter. The args-schema assertion belongs
      // with the tool implementations; until they exist, this catches the
      // cheapest version of the mistake — a tool whose very name implies the
      // caller picks the tenant.
      for (const tool of ALL_TOOL_NAMES) {
        expect(tool.toLowerCase()).not.toMatch(/clientid|tenantid|userid|forclient|fortenant/);
      }
    });
  });

  describe('accuracy control', () => {
    it('no role sees more than 30 tools', () => {
      // Tool-selection accuracy degrades past roughly 30–50 visible tools, so
      // the roster is a quality control as much as a security one. This fails
      // early enough to force a grouping decision rather than a silent
      // accuracy regression the eval suite would find much later.
      for (const role of ROLES) {
        expect(rosterFor(role).size).toBeLessThanOrEqual(30);
      }
    });
  });

  it('the registry and the expectation table describe the same tools', () => {
    // Guards the test itself: adding a tool to the registry without adding it
    // here would otherwise silently shrink the matrix above.
    for (const role of ROLES) {
      expect(Object.keys(EXPECTED[role]).sort()).toEqual([...ALL_TOOL_NAMES].sort());
    }
    expect(Object.keys(TOOL_REGISTRY).sort()).toEqual([...ALL_TOOL_NAMES].sort());
  });
});
