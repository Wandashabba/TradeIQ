import { prisma } from '../../lib/prisma';
import { TestUser, userIn } from '../../test-utils/tenants';
import {
  cleanupOrphanAttachmentPhotos,
  parseOrphanCleanupArgs,
} from './orphanAttachmentCleanup';

/**
 * #308 — scripts/cleanup-orphan-attachment-photos.ts. It deletes rows, so the
 * tests are mostly about what it must NOT delete.
 */
describe('cleanupOrphanAttachmentPhotos (#308)', () => {
  const HOUR = 60 * 60 * 1000;
  const now = new Date('2026-09-15T12:00:00.000Z');
  const hoursAgo = (h: number) => new Date(now.getTime() - h * HOUR);

  let tenantA: string;
  let tenantB: string;
  let agentA: TestUser;
  let agentB: TestUser;
  let visitId: string;

  const seedClient = async (name: string) =>
    (
      await prisma.client.create({
        data: { name, industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
      })
    ).id;

  const attachmentPhoto = (user: TestUser, createdAt: Date) =>
    prisma.photo.create({
      data: {
        clientId: user.clientId,
        uploadedById: user.userId,
        section: 'message_attachment',
        url: 'data:image/png;base64,AAAA',
        gpsTag: {},
        timestamp: createdAt,
        createdAt,
      },
    });

  const exists = async (id: string) => (await prisma.photo.count({ where: { id } })) === 1;

  /** One of each kind, in both tenants. Returns ids by name. */
  const seed = async () => {
    const ids = {
      oldOrphanA: (await attachmentPhoto(agentA, hoursAgo(72))).id,
      oldOrphanA2: (await attachmentPhoto(agentA, hoursAgo(49))).id,
      recentOrphanA: (await attachmentPhoto(agentA, hoursAgo(47))).id,
      attachedA: (await attachmentPhoto(agentA, hoursAgo(72))).id,
      // Visit evidence, however old and unattached, is never an orphan — even
      // one that somehow carries the attachment section.
      visitPhotoA: (
        await prisma.photo.create({
          data: {
            visitId,
            clientId: tenantA,
            uploadedById: agentA.userId,
            section: 'visibility',
            url: 'data:image/png;base64,AAAA',
            gpsTag: {},
            timestamp: hoursAgo(500),
            createdAt: hoursAgo(500),
          },
        })
      ).id,
      visitPhotoWithAttachmentSectionA: (
        await prisma.photo.create({
          data: {
            visitId,
            clientId: tenantA,
            section: 'message_attachment',
            url: 'data:image/png;base64,AAAA',
            gpsTag: {},
            timestamp: hoursAgo(500),
            createdAt: hoursAgo(500),
          },
        })
      ).id,
      oldOrphanB: (await attachmentPhoto(agentB, hoursAgo(72))).id,
    };
    await prisma.message.create({
      data: {
        clientId: tenantA,
        senderId: agentA.userId,
        body: 'kept',
        attachments: { create: [{ photoId: ids.attachedA, position: 0 }] },
      },
    });
    return ids;
  };

  const clearPhotos = async () => {
    await prisma.message.deleteMany({ where: { clientId: { in: [tenantA, tenantB] } } });
    await prisma.photo.deleteMany({ where: { clientId: { in: [tenantA, tenantB] } } });
  };

  beforeAll(async () => {
    tenantA = await seedClient('ORPHAN-A');
    tenantB = await seedClient('ORPHAN-B');
    agentA = await userIn(tenantA, 'field_agent');
    agentB = await userIn(tenantB, 'field_agent');
    const outlet = await prisma.outlet.create({
      data: {
        name: 'ORPHAN-Outlet',
        code: 'ORPHAN-001',
        channelType: 'spaza',
        lat: -26.2,
        lng: 28.0,
        territoryId: 't1',
        clientId: tenantA,
      },
    });
    visitId = (
      await prisma.visit.create({
        data: {
          outletId: outlet.id,
          agentId: agentA.userId,
          clientId: tenantA,
          checkinTs: hoursAgo(500),
          checkinLat: -26.2,
          checkinLng: 28.0,
          geofencePass: true,
          status: 'submitted',
        },
      })
    ).id;
  });

  afterEach(clearPhotos);

  afterAll(async () => {
    const tenants = [tenantA, tenantB];
    await clearPhotos();
    await prisma.visit.deleteMany({ where: { clientId: { in: tenants } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: tenants } } });
    await prisma.user.deleteMany({ where: { clientId: { in: tenants } } });
    await prisma.client.deleteMany({ where: { id: { in: tenants } } });
    await prisma.$disconnect();
  });

  it('deletes only unattached message photos older than the 48h default', async () => {
    const ids = await seed();

    const result = await cleanupOrphanAttachmentPhotos({ now, clientId: tenantA, batchSize: 1 });

    expect(result).toMatchObject({ matched: 2, deleted: 2, dryRun: false, cutoff: hoursAgo(48) });
    expect(await exists(ids.oldOrphanA)).toBe(false);
    expect(await exists(ids.oldOrphanA2)).toBe(false);
  });

  it('keeps attached photos, recent photos and visit photos', async () => {
    const ids = await seed();

    await cleanupOrphanAttachmentPhotos({ now });

    expect(await exists(ids.attachedA)).toBe(true);
    expect(await exists(ids.recentOrphanA)).toBe(true);
    expect(await exists(ids.visitPhotoA)).toBe(true);
    expect(await exists(ids.visitPhotoWithAttachmentSectionA)).toBe(true);
    expect(await prisma.messageAttachment.count({ where: { photoId: ids.attachedA } })).toBe(1);
  });

  it('honours a custom grace period', async () => {
    const ids = await seed();

    const result = await cleanupOrphanAttachmentPhotos({ now, clientId: tenantA, olderThanHours: 60 });

    expect(result.deleted).toBe(1);
    expect(await exists(ids.oldOrphanA)).toBe(false);
    expect(await exists(ids.oldOrphanA2)).toBe(true);
  });

  it('deletes nothing on a dry run, and reports what it would delete', async () => {
    const ids = await seed();
    const before = await prisma.photo.count({ where: { clientId: { in: [tenantA, tenantB] } } });

    const result = await cleanupOrphanAttachmentPhotos({ now, dryRun: true });

    expect(result).toMatchObject({ matched: 3, deleted: 0, dryRun: true });
    expect(await prisma.photo.count({ where: { clientId: { in: [tenantA, tenantB] } } })).toBe(before);
    expect(await exists(ids.oldOrphanA)).toBe(true);
  });

  it('touches only the given tenant with clientId', async () => {
    const ids = await seed();

    const result = await cleanupOrphanAttachmentPhotos({ now, clientId: tenantB });

    expect(result.deleted).toBe(1);
    expect(await exists(ids.oldOrphanB)).toBe(false);
    expect(await exists(ids.oldOrphanA)).toBe(true);
    expect(await exists(ids.oldOrphanA2)).toBe(true);
  });

  it('is safe to re-run: a second run deletes nothing and keeps everything else', async () => {
    const ids = await seed();

    const first = await cleanupOrphanAttachmentPhotos({ now, batchSize: 2 });
    const second = await cleanupOrphanAttachmentPhotos({ now, batchSize: 2 });

    expect(first.deleted).toBe(3);
    expect(second).toMatchObject({ matched: 0, deleted: 0 });
    for (const kept of [ids.attachedA, ids.recentOrphanA, ids.visitPhotoA]) {
      expect(await exists(kept)).toBe(true);
    }
  });

  it('refuses a grace period under an hour', async () => {
    await expect(cleanupOrphanAttachmentPhotos({ now, olderThanHours: 0 })).rejects.toThrow(
      /at least 1/,
    );
  });
});

describe('parseOrphanCleanupArgs (#308)', () => {
  it('reads every flag', () => {
    expect(
      parseOrphanCleanupArgs(['--older-than', '72', '--client', 'c1', '--batch', '50', '--dry-run']),
    ).toEqual({ olderThanHours: 72, clientId: 'c1', batchSize: 50, dryRun: true });
  });

  it('defaults to nothing, leaving the service defaults in charge', () => {
    expect(parseOrphanCleanupArgs([])).toEqual({});
  });

  it.each([
    [['--older-than', '0']],
    [['--older-than', 'soon']],
    [['--batch', '0']],
    [['--batch', '1.5']],
    [['--client']],
    [['--client', '--dry-run']],
    [['--olderthan', '72']],
  ])('rejects %j', (argv) => {
    expect(() => parseOrphanCleanupArgs(argv)).toThrow();
  });
});
