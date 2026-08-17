import { ALL_TOOL_NAMES } from './roster';
import {
  RISK_TIERS,
  isWrite,
  requiresConfirmation,
  tierOf,
  toolsByTier,
  type RiskTier,
} from './risk';

/**
 * The policy table's tests.
 *
 * Structured like `roster.test.ts` for the same reason: this is a security
 * table, so the test's job is to make a *gap* fail rather than to re-state the
 * table's contents in a second place. A test that lists the same pairs again
 * passes whenever the table is self-consistent, including when it is
 * self-consistently wrong.
 */
describe('risk tiers', () => {
  const TIERS: RiskTier[] = ['read', 'reversible', 'irreversible'];

  it('classifies every tool in the registry', () => {
    // The compile-time half of this is `satisfies Record<ToolName, RiskTier>`
    // in risk.ts. This is the runtime half, and it is not redundant: the
    // `satisfies` clause is erased at build time, so a table edited through a
    // cast, or a registry loaded from anywhere but the literal, would still be
    // caught here.
    for (const name of ALL_TOOL_NAMES) {
      expect(TIERS).toContain(tierOf(name));
    }
    expect(Object.keys(RISK_TIERS).sort()).toEqual([...ALL_TOOL_NAMES].sort());
  });

  it('every read tool is a read, and nothing yet writes', () => {
    // Phase 3 has added no write tools. Stated as a fact rather than left
    // implicit, so the first write tool has to come here and change it —
    // which is the moment somebody has to think about the tier.
    expect(toolsByTier()).toEqual({
      read: [...ALL_TOOL_NAMES],
      reversible: [],
      irreversible: [],
    });
  });

  describe('an unknown tool', () => {
    // The case that matters most, because it is the one that happens by
    // accident: a tool added to the registry, shipped, and never tiered.
    const unknown = 'deleteEverything';

    // Every call below deliberately trips the fail-closed path, which logs. The
    // log is asserted in its own test; here it is noise that would bury a real
    // error in the suite's output.
    let quiet: jest.SpyInstance;
    beforeEach(() => {
      quiet = jest.spyOn(console, 'error').mockImplementation(() => {});
    });
    afterEach(() => quiet.mockRestore());

    it('is treated as irreversible, not as a read', () => {
      expect(tierOf(unknown)).toBe('irreversible');
    });

    it('requires confirmation', () => {
      // The whole point of failing closed. If this ever returns false, an
      // untiered write executes with no human in the loop.
      expect(requiresConfirmation(unknown)).toBe(true);
      expect(isWrite(unknown)).toBe(true);
    });

    it('is reported, so it is a bug someone can find', () => {
      // Silence here would make the fail-closed behaviour indistinguishable
      // from a correctly-tiered irreversible tool, and the missing table entry
      // would survive forever behind a prompt nobody questioned.
      tierOf(unknown);
      expect(quiet).toHaveBeenCalledWith(expect.stringContaining(unknown));
      expect(quiet).toHaveBeenCalledWith(expect.stringContaining('RISK_TIERS'));
    });
  });

  describe('what prompts', () => {
    it('reads never prompt', () => {
      // Gating reads is the named way approval UX dies: a prompt that appears
      // constantly is a prompt nobody reads.
      for (const name of ALL_TOOL_NAMES) {
        expect(requiresConfirmation(name)).toBe(false);
        expect(isWrite(name)).toBe(false);
      }
    });

    it('only irreversible actions prompt', () => {
      // Asserted against the tier rather than against a tool list, so it still
      // holds when the first `reversible` tool lands: reversible executes and
      // offers an undo, which is the trade that keeps the prompt rate low
      // enough for a prompt to still mean something.
      const cases: [RiskTier, boolean][] = [
        ['read', false],
        ['reversible', false],
        ['irreversible', true],
      ];
      for (const [tier, prompts] of cases) {
        const probe = `probe_${tier}`;
        const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
        try {
          (RISK_TIERS as Record<string, RiskTier>)[probe] = tier;
          expect(requiresConfirmation(probe)).toBe(prompts);
          expect(isWrite(probe)).toBe(tier !== 'read');
        } finally {
          delete (RISK_TIERS as Record<string, RiskTier>)[probe];
          spy.mockRestore();
        }
      }
    });
  });
});
