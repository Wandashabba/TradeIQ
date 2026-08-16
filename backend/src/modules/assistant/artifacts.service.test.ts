import { prisma } from '../../lib/prisma';
import type { AuthTokenPayload } from '../auth/auth.service';
import {
  ArtifactNotFoundError,
  InvalidParamsError,
  PARAMS_HISTORY_LIMIT,
  ToolUnavailableError,
  artifactManifest,
  createArtifact,
  readArtifact,
  refineArtifact,
  takeParamsChanges,
  undoArtifact,
} from './artifacts.service';

const NOW = new Date('2026-08-16T12:00:00Z');
const MTD = { period: { kind: 'mtd' as const } };
const YTD = { period: { kind: 'ytd' as const } };

function ctxFor(user: AuthTokenPayload) {
  return { user, now: NOW };
}

describe('assistant artifacts', () => {
  let clientId: string;
  let otherClientId: string;
  let manager: AuthTokenPayload;
  let colleague: AuthTokenPayload;
  let agent: AuthTokenPayload;
  let outsider: AuthTokenPayload;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'ART-Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
        assistantEnabled: true,
      },
    });
    clientId = client.id;

    const other = await prisma.client.create({
      data: {
        name: 'ART-Other',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
        assistantEnabled: true,
      },
    });
    otherClientId = other.id;

    const make = async (email: string, role: 'manager' | 'field_agent', tenant: string) => {
      const user = await prisma.user.create({
        data: { email, passwordHash: 'x', role, clientId: tenant },
      });
      return { userId: user.id, role, clientId: tenant } as AuthTokenPayload;
    };

    manager = await make('art-manager@test.local', 'manager', clientId);
    colleague = await make('art-colleague@test.local', 'manager', clientId);
    agent = await make('art-agent@test.local', 'field_agent', clientId);
    outsider = await make('art-outsider@test.local', 'manager', otherClientId);
  });

  async function seedArtifact(owner: AuthTokenPayload, conversationId = 'conv-1') {
    return createArtifact({
      owner: { userId: owner.userId, clientId: owner.clientId },
      conversationId,
      type: 'outlet_map',
      toolName: 'getStockLevels',
      params: MTD,
    });
  }

  it('rehydrates with stored params and freshly fetched data', async () => {
    // Data is never persisted — reopening re-runs the tool. A stored copy would
    // be a second source of tenant data with its own staleness.
    const created = await seedArtifact(manager);

    const read = await readArtifact(created.id, ctxFor(manager));

    expect(read.id).toBe(created.id);
    expect(read.toolName).toBe('getStockLevels');
    expect(read.params).toEqual(MTD);
    expect(read.data).toBeDefined();
    expect(read.canUndo).toBe(false);
  });

  it('refines to new params and remembers the old ones', async () => {
    const created = await seedArtifact(manager);

    const refined = await refineArtifact(created.id, YTD, ctxFor(manager));

    expect(refined.params).toEqual(YTD);
    expect(refined.canUndo).toBe(true);
    // Persisted, not just returned — a reopen must show the refined view.
    const reread = await readArtifact(created.id, ctxFor(manager));
    expect(reread.params).toEqual(YTD);
  });

  it('undo steps back, and is idempotent at the bottom of the stack', async () => {
    const created = await seedArtifact(manager);
    await refineArtifact(created.id, YTD, ctxFor(manager));

    const undone = await undoArtifact(created.id, ctxFor(manager));
    expect(undone.params).toEqual(MTD);
    expect(undone.canUndo).toBe(false);

    // Pressing undo once too often is not an error — a 400 for that would be
    // hostile, and the control is at rest either way.
    const again = await undoArtifact(created.id, ctxFor(manager));
    expect(again.params).toEqual(MTD);
    expect(again.canUndo).toBe(false);
  });

  it('rejects params the tool did not declare, and leaves the artifact untouched', async () => {
    // The params-tampering gate. Validation is the tool's own Zod schema, so a
    // hand-edited payload cannot introduce a parameter the tool never had.
    const created = await seedArtifact(manager);

    await expect(
      refineArtifact(created.id, { period: { kind: 'not-a-period' } }, ctxFor(manager)),
    ).rejects.toBeInstanceOf(InvalidParamsError);

    const after = await readArtifact(created.id, ctxFor(manager));
    expect(after.params).toEqual(MTD);
    expect(after.canUndo).toBe(false);
  });

  it('cannot be widened to another tenant by adding a clientId param', async () => {
    // The closure binds tenant; `clientId` is not a parameter of any tool, so
    // Zod strips or rejects it and the run stays inside the caller's tenant
    // either way. Asserting it explicitly because this is the attack the
    // endpoint most obviously invites.
    const created = await seedArtifact(manager);

    const refined = await refineArtifact(
      created.id,
      { ...YTD, clientId: otherClientId },
      ctxFor(manager),
    );

    expect(refined.params).not.toHaveProperty('clientId');
  });

  it('hides another user\'s artifact behind the same 404 as a missing one', async () => {
    // Same tenant, different person. Not a data leak — the roster would still
    // re-authorise every run — but it is someone else's workspace.
    const created = await seedArtifact(manager);

    await expect(readArtifact(created.id, ctxFor(colleague))).rejects.toBeInstanceOf(
      ArtifactNotFoundError,
    );
  });

  it('hides an artifact from another tenant entirely', async () => {
    const created = await seedArtifact(manager);

    await expect(readArtifact(created.id, ctxFor(outsider))).rejects.toBeInstanceOf(
      ArtifactNotFoundError,
    );
    await expect(refineArtifact(created.id, YTD, ctxFor(outsider))).rejects.toBeInstanceOf(
      ArtifactNotFoundError,
    );
  });

  it('refuses to re-run a tool the caller\'s role does not carry', async () => {
    // A field agent's roster is empty in Phase 0. Owning the row is not the
    // same as being allowed to run what it points at, and the roster is what
    // decides — re-derived per request, never stored on the artifact.
    const created = await seedArtifact(agent);

    await expect(readArtifact(created.id, ctxFor(agent))).rejects.toBeInstanceOf(
      ToolUnavailableError,
    );
  });

  it(`caps params history at ${PARAMS_HISTORY_LIMIT} entries`, async () => {
    // The history is a JSON column written on every filter change. Uncapped, a
    // busy artifact grows a row without bound.
    const created = await seedArtifact(manager);

    for (let i = 0; i < PARAMS_HISTORY_LIMIT + 5; i += 1) {
      // Alternating so consecutive entries differ, and the cap is what trims
      // the list rather than deduplication.
      await refineArtifact(created.id, i % 2 === 0 ? YTD : MTD, ctxFor(manager));
    }

    const row = await prisma.assistantArtifact.findUniqueOrThrow({ where: { id: created.id } });
    expect(Array.isArray(row.paramsHistory)).toBe(true);
    expect(row.paramsHistory as unknown[]).toHaveLength(PARAMS_HISTORY_LIMIT);
  });

  it('lists a conversation\'s artifacts without their data', async () => {
    // The manifest tells the model what already exists so it targets an
    // artifact instead of emitting a duplicate. Params travel; figures do not.
    const conversationId = `conv-${Date.now()}`;
    const created = await seedArtifact(manager, conversationId);

    const manifest = await artifactManifest(conversationId, {
      userId: manager.userId,
      clientId: manager.clientId,
    });

    expect(manifest).toHaveLength(1);
    expect(manifest[0]).toEqual({ id: created.id, type: 'outlet_map', params: MTD });
    expect(manifest[0]).not.toHaveProperty('data');
  });

  it('flags a refine so the next turn can tell the model, then forgets it', async () => {
    // The stale-params bug: the user filters, and the model answers the next
    // question against what it last saw. The flag is how the turn finds out.
    const conversationId = `conv-change-${Date.now()}`;
    const created = await seedArtifact(manager, conversationId);
    const owner = { userId: manager.userId, clientId: manager.clientId };

    // Nothing to say before anything moved.
    expect(await takeParamsChanges(conversationId, owner)).toEqual([]);

    await refineArtifact(created.id, YTD, ctxFor(manager));

    const changes = await takeParamsChanges(conversationId, owner);
    expect(changes).toEqual([{ id: created.id, type: 'outlet_map', params: YTD }]);

    // Taken means delivered: announcing it again next turn would spend tokens
    // restating what the manifest already carries.
    expect(await takeParamsChanges(conversationId, owner)).toEqual([]);
  });

  it('collapses repeated changes into where the user actually landed', async () => {
    // Three drags of one slider are one fact — the params it ended on. Three
    // notes would be two stale ones and a true one.
    const conversationId = `conv-collapse-${Date.now()}`;
    const created = await seedArtifact(manager, conversationId);

    await refineArtifact(created.id, YTD, ctxFor(manager));
    await refineArtifact(created.id, MTD, ctxFor(manager));
    await refineArtifact(created.id, YTD, ctxFor(manager));

    const changes = await takeParamsChanges(conversationId, {
      userId: manager.userId,
      clientId: manager.clientId,
    });

    expect(changes).toEqual([{ id: created.id, type: 'outlet_map', params: YTD }]);
  });

  it('flags an undo too', async () => {
    // The worst case would be telling the model about a change and then never
    // telling it the change was taken back.
    const conversationId = `conv-undo-note-${Date.now()}`;
    const created = await seedArtifact(manager, conversationId);
    const owner = { userId: manager.userId, clientId: manager.clientId };

    await refineArtifact(created.id, YTD, ctxFor(manager));
    await takeParamsChanges(conversationId, owner);

    await undoArtifact(created.id, ctxFor(manager));

    expect(await takeParamsChanges(conversationId, owner)).toEqual([
      { id: created.id, type: 'outlet_map', params: MTD },
    ]);
  });

  it('does not leak another user\'s changes into this conversation', async () => {
    const conversationId = `conv-change-scope-${Date.now()}`;
    const created = await seedArtifact(manager, conversationId);
    await refineArtifact(created.id, YTD, ctxFor(manager));

    expect(
      await takeParamsChanges(conversationId, {
        userId: colleague.userId,
        clientId: colleague.clientId,
      }),
    ).toEqual([]);
  });

  it('leaves the artifact\'s own updatedAt alone when a note is delivered', async () => {
    // Marking a note delivered is bookkeeping, not a change to the view. A
    // bumped updatedAt would reorder the manifest and tell the client the
    // artifact moved when nothing about it did.
    const conversationId = `conv-touch-${Date.now()}`;
    const created = await seedArtifact(manager, conversationId);
    const refined = await refineArtifact(created.id, YTD, ctxFor(manager));

    await takeParamsChanges(conversationId, {
      userId: manager.userId,
      clientId: manager.clientId,
    });

    const row = await prisma.assistantArtifact.findUniqueOrThrow({ where: { id: created.id } });
    expect(row.updatedAt).toEqual(refined.updatedAt);
    expect(row.paramsChangedAt).toBeNull();
  });

  it('scopes the manifest to the asking user', async () => {
    const conversationId = `conv-scope-${Date.now()}`;
    await seedArtifact(manager, conversationId);

    const seenByColleague = await artifactManifest(conversationId, {
      userId: colleague.userId,
      clientId: colleague.clientId,
    });

    expect(seenByColleague).toEqual([]);
  });
});
