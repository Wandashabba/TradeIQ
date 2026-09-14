import { prisma } from '../../lib/prisma';
import { AgentNotFoundError, AmbiguousAgentError, resolveAgent } from './scorecards.service';

/**
 * #280 — a manager asking "How has Sipho Ndlovu been performing?" resolved
 * nobody on any tenant, because matching was email-only and a full name with a
 * space is never a substring of `sipho.ndlovu@acme.com`.
 */
describe('resolveAgent by display name (#280)', () => {
  let clientId: string;
  let otherClientId: string;
  const ids: Record<string, string> = {};

  async function person(key: string, email: string, displayName: string | null, client = clientId) {
    const user = await prisma.user.create({
      data: { email, displayName, passwordHash: 'x', role: 'field_agent', clientId: client },
    });
    ids[key] = user.id;
  }

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'RESOLVE-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const other = await prisma.client.create({
      data: { name: 'RESOLVE-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = other.id;

    // The address says nothing about the name, which is the realistic case:
    // "agent@", "a.nd@", employee numbers.
    await person('sipho', 'resolve-agent1@example.com', 'Sipho Ndlovu');
    // An exact name that is also a prefix of someone else's.
    await person('sam', 'resolve-agent2@example.com', 'Sam Taylor');
    await person('samSmith', 'resolve-agent3@example.com', 'Sam Taylor-Smith');
    // Two different people who genuinely share a full name.
    await person('lerato1', 'resolve-agent4@example.com', 'Lerato Mahlangu');
    await person('lerato2', 'resolve-agent5@example.com', 'Lerato Mahlangu');
    // No display name — an account that predates the column.
    await person('legacy', 'tumo.mogame@example.com', null);
    // Another tenant's person with a unique name.
    await person('foreign', 'resolve-foreign@example.com', 'Ruan Botha', otherClientId);
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
    await prisma.$disconnect();
  });

  it('resolves a full name with a space', async () => {
    const agent = await resolveAgent({ clientId, query: 'Sipho Ndlovu' });
    expect(agent).toEqual({
      id: ids.sipho,
      email: 'resolve-agent1@example.com',
      displayName: 'Sipho Ndlovu',
    });
  });

  it('matches a name case-insensitively and ignores surrounding whitespace', async () => {
    const agent = await resolveAgent({ clientId, query: '  sipho ndlovu ' });
    expect(agent.id).toBe(ids.sipho);
  });

  it('resolves part of a name — a first name or a surname', async () => {
    expect((await resolveAgent({ clientId, query: 'Sipho' })).id).toBe(ids.sipho);
    expect((await resolveAgent({ clientId, query: 'ndlovu' })).id).toBe(ids.sipho);
  });

  it('prefers an exact name over a partial one that would also match', async () => {
    // "Sam Taylor" is contained in "Sam Taylor-Smith" too; the exact match wins
    // rather than being reported as ambiguous.
    const agent = await resolveAgent({ clientId, query: 'sam taylor' });
    expect(agent.id).toBe(ids.sam);
  });

  it('still asks which one when a partial name matches several people', async () => {
    await expect(resolveAgent({ clientId, query: 'Sam' })).rejects.toBeInstanceOf(
      AmbiguousAgentError,
    );
  });

  it('asks which one when two people share the exact same name, naming both by name and email', async () => {
    const error = await resolveAgent({ clientId, query: 'Lerato Mahlangu' }).catch((e) => e);
    expect(error).toBeInstanceOf(AmbiguousAgentError);
    const ambiguous = error as AmbiguousAgentError;
    expect(ambiguous.candidates.map((c) => c.id).sort()).toEqual([ids.lerato1, ids.lerato2].sort());
    expect(ambiguous.message).toMatch(/matches 2 people/);
    expect(ambiguous.message).toContain('Lerato Mahlangu <resolve-agent4@example.com>');
    expect(ambiguous.message).toContain('Lerato Mahlangu <resolve-agent5@example.com>');
  });

  it('still falls back to the email for someone with no display name', async () => {
    const agent = await resolveAgent({ clientId, query: 'tumo' });
    expect(agent).toEqual({ id: ids.legacy, email: 'tumo.mogame@example.com', displayName: null });
  });

  it('describes a nameless candidate by email alone when the email fallback is ambiguous', async () => {
    const second = await prisma.user.create({
      data: {
        email: 'tumo.second@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId,
      },
    });
    try {
      const error = await resolveAgent({ clientId, query: 'tumo' }).catch((e) => e);
      expect(error).toBeInstanceOf(AmbiguousAgentError);
      const message = (error as AmbiguousAgentError).message;
      expect(message).toMatch(/matches 2 people/);
      expect(message).toContain('tumo.mogame@example.com');
      expect(message).toContain('tumo.second@example.com');
      expect(message).not.toContain('<');
    } finally {
      await prisma.user.delete({ where: { id: second.id } });
    }
  });

  it("never resolves another tenant's person by name", async () => {
    await expect(resolveAgent({ clientId, query: 'Ruan Botha' })).rejects.toBeInstanceOf(
      AgentNotFoundError,
    );
    await expect(resolveAgent({ clientId, query: 'Ruan' })).rejects.toBeInstanceOf(
      AgentNotFoundError,
    );
    // The same name DOES resolve from inside its own tenant, so the miss above
    // is the scoping, not the matching.
    expect((await resolveAgent({ clientId: otherClientId, query: 'Ruan Botha' })).id).toBe(
      ids.foreign,
    );
  });

  it('does not let a same-named person in another tenant make a name ambiguous', async () => {
    const twin = await prisma.user.create({
      data: {
        email: 'resolve-foreign-twin@example.com',
        displayName: 'Sipho Ndlovu',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    try {
      expect((await resolveAgent({ clientId, query: 'Sipho Ndlovu' })).id).toBe(ids.sipho);
    } finally {
      await prisma.user.delete({ where: { id: twin.id } });
    }
  });
});
