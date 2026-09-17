import { z } from 'zod';
import type { AuthTokenPayload } from '../../auth/auth.service';
import { toFunctionDeclarations } from '../providers/gemini';
import { ALL_TOOL_NAMES, rosterFor, TOOL_REGISTRY } from '../roster';
import { buildTools, unimplementedTools, type ToolContext } from './index';

const NOW = new Date('2026-08-06T12:00:00.000Z');

function ctx(role: AuthTokenPayload['role'] = 'manager'): ToolContext {
  return {
    user: { userId: 'user-1', role, clientId: 'client-1' },
    now: NOW,
  };
}

describe('buildTools', () => {
  it('implements every tool in the manager roster', () => {
    // A tool in the roster with no implementation is a tool the model is told
    // about and cannot call — a failed turn with no explanation.
    expect(unimplementedTools(ctx('manager'))).toEqual([]);
  });

  it('gives a field agent nothing', () => {
    // The Phase 0 audience decision: manager console only. This staying empty
    // is what makes the negative cases elsewhere mean anything.
    expect(buildTools(ctx('field_agent'))).toEqual([]);
  });

  it('gives admin and manager the same set today', () => {
    const names = (role: AuthTokenPayload['role']) =>
      buildTools(ctx(role)).map((t) => t.name);
    expect(names('admin')).toEqual(names('manager'));
  });

  it('orders tools by the roster, not by import order', () => {
    // Tool declarations sit inside the cached prompt prefix, so a reordering is
    // a cache miss with no functional symptom — and file order changes whenever
    // someone adds a pillar file.
    const rosterOrder = [...rosterFor('manager')];
    expect(buildTools(ctx()).map((t) => t.name)).toEqual(rosterOrder);
  });

  it('is deterministic across calls', () => {
    expect(buildTools(ctx()).map((t) => t.name)).toEqual(buildTools(ctx()).map((t) => t.name));
  });

  it('stays under the tool-count ceiling for selection accuracy', () => {
    // Selection quality degrades past roughly 30-50 visible tools. The roster
    // is the accuracy control as much as the security one.
    expect(buildTools(ctx()).length).toBeLessThanOrEqual(30);
  });

  it('covers all five pillars', () => {
    const pillars = new Set(buildTools(ctx()).map((t) => t.pillar));
    expect([...pillars].sort()).toEqual([
      'competition',
      'execution',
      'sales',
      'stock',
      'visibility',
    ]);
  });

  it('agrees with the registry about which tools exist', () => {
    const built = buildTools(ctx()).map((t) => t.name).sort();
    expect(built).toEqual([...ALL_TOOL_NAMES].sort());
  });

  it('assigns each tool the pillar the registry declares', () => {
    for (const tool of buildTools(ctx())) {
      expect(tool.pillar).toBe(TOOL_REGISTRY[tool.name as keyof typeof TOOL_REGISTRY]);
    }
  });
});

describe('the structural tenancy guarantee', () => {
  it('has no identity field in any tool\'s args schema', () => {
    // If an args schema grows a tenant field, isolation stops being enforced by
    // the type signature and starts depending on a validation step somebody has
    // to remember for every new tool. That is the whole design.
    for (const tool of buildTools(ctx())) {
      const shape = JSON.stringify(z.toJSONSchema(tool.args, { io: 'input' }));
      expect(shape).not.toMatch(/"(clientId|tenantId|userId|organisationId)"/);
    }
  });

  it('has no identity field in any tool description either', () => {
    // A description that mentions a tenant argument teaches the model to try.
    for (const tool of buildTools(ctx())) {
      expect(tool.description).not.toMatch(/clientId|tenantId/);
    }
  });
});

describe('tool declarations reach the provider intact', () => {
  it('converts every tool schema into a valid Gemini declaration', () => {
    // The promise made in geminiSchema.ts: it throws on anything Gemini cannot
    // express rather than silently dropping the constraint. This is the test
    // that catches it before a request does — a 400 mid-turn otherwise.
    expect(() => toFunctionDeclarations(buildTools(ctx()))).not.toThrow();
  });

  it('gives every declaration a name and a description', () => {
    for (const declaration of toFunctionDeclarations(buildTools(ctx()))) {
      expect(declaration.name).toBeTruthy();
      expect(declaration.description?.length ?? 0).toBeGreaterThan(20);
    }
  });

  it('states a trigger condition in every description', () => {
    // Prescriptive, not descriptive. "Call this when the user asks about stock
    // levels" measurably beats "Returns stock levels" on should-call rate.
    for (const tool of buildTools(ctx())) {
      expect(tool.description).toMatch(/^Call this when/);
    }
  });

  it('serialises declarations identically across builds', () => {
    // Byte-identical, because the cache prefix is a byte comparison.
    const a = JSON.stringify(toFunctionDeclarations(buildTools(ctx())));
    const b = JSON.stringify(toFunctionDeclarations(buildTools(ctx())));
    expect(a).toBe(b);
  });

  it('accepts a period on every tool that takes one', () => {
    // The period vocabulary is the practitioner's, and a tool that cannot
    // express it forces the model to guess a date range.
    //
    // Three tools have no date range to express, and are named rather than
    // skipped by a rule, so a new tool without a period still fails here:
    // the territory lookup, contest standings (a contest carries its own
    // dates), and the forecast (always the last 28 complete days).
    const undated = new Set(['findTerritories', 'getContestStandings', 'getSellInForecast']);
    const periodic = buildTools(ctx()).filter((tool) => {
      const shape = z.toJSONSchema(tool.args, { io: 'input' }) as {
        properties?: Record<string, unknown>;
      };
      return shape.properties?.period !== undefined;
    });
    expect(periodic.map((t) => t.name).sort()).toEqual(
      buildTools(ctx())
        .map((t) => t.name)
        .filter((name) => !undated.has(name))
        .sort(),
    );
  });
});
