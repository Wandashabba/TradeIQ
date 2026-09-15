import { createHash } from 'crypto';
import { prisma } from '../../lib/prisma';
import { shelfJpeg, toDataUrl } from '../../test-utils/shelfImage';
import { computePhotoHashes } from './photoHash';
import { backfillPhotoHashes } from './photoHashBackfill';

/**
 * #244 — photos uploaded before hashing existed are filled by
 * scripts/backfill-photo-hashes.ts. It must be safe to re-run, to kill, and to
 * run in pieces, because it walks a table of multi-MB rows in production.
 */
describe('backfillPhotoHashes (#244)', () => {
  let clientId: string;
  let otherClientId: string;
  let visitId: string;
  let otherVisitId: string;
  const ids: Record<string, string> = {};
  let imageUrl: string;

  const seedTenant = async (name: string) => {
    const client = await prisma.client.create({
      data: { name, industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const agent = await prisma.user.create({
      data: { email: `${name}-agent@example.test`, passwordHash: 'x', role: 'field_agent', clientId: client.id },
    });
    const outlet = await prisma.outlet.create({
      data: {
        name,
        code: name,
        channelType: 'spaza',
        lat: -26.2,
        lng: 28.0,
        territoryId: 't1',
        clientId: client.id,
      },
    });
    const visit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agent.id,
        clientId: client.id,
        checkinTs: new Date(),
        checkinLat: -26.2,
        checkinLng: 28.0,
        geofencePass: true,
        status: 'submitted',
      },
    });
    return { clientId: client.id, visitId: visit.id };
  };

  const photo = (vid: string, url: string, extra: Record<string, unknown> = {}) =>
    prisma.photo.create({
      data: { visitId: vid, section: 'stock', url, gpsTag: {}, timestamp: new Date(), ...extra },
    });

  const read = (id: string) =>
    prisma.photo.findUniqueOrThrow({
      where: { id },
      select: { contentHash: true, perceptualHash: true, perceptualHashBands: true },
    });

  beforeAll(async () => {
    ({ clientId, visitId } = await seedTenant('BACKFILL-A'));
    ({ clientId: otherClientId, visitId: otherVisitId } = await seedTenant('BACKFILL-B'));
    imageUrl = toDataUrl(await shelfJpeg(21));

    // Written the way every pre-#244 row was: no hashes.
    ids.image = (await photo(visitId, imageUrl)).id;
    ids.secondImage = (await photo(visitId, toDataUrl(await shelfJpeg(22)))).id;
    ids.remote = (await photo(visitId, 'https://example.test/remote.jpg')).id;
    ids.notAnImage = (await photo(visitId, 'data:image/jpeg;base64,aGVsbG8=')).id;
    // Already hashed (an upload since #244): never rewritten.
    ids.alreadyHashed = (
      await photo(visitId, imageUrl, { contentHash: 'already-set', perceptualHash: null })
    ).id;
    // Another tenant's unhashed photo, outside a --client run.
    ids.otherTenant = (await photo(otherVisitId, imageUrl)).id;
  });

  afterAll(async () => {
    for (const cid of [clientId, otherClientId]) {
      await prisma.photo.deleteMany({ where: { visit: { clientId: cid } } });
      await prisma.visit.deleteMany({ where: { clientId: cid } });
      await prisma.outlet.deleteMany({ where: { clientId: cid } });
      await prisma.user.deleteMany({ where: { clientId: cid } });
      await prisma.client.delete({ where: { id: cid } });
    }
    await prisma.$disconnect();
  });

  it('runs in pieces: a limited run stops, and the next one resumes without being told where', async () => {
    const first = await backfillPhotoHashes({ clientId, batchSize: 1, limit: 2 });
    expect(first.scanned).toBe(2);

    const lines: string[] = [];
    const rest = await backfillPhotoHashes({ clientId, batchSize: 1, log: (l) => lines.push(l) });
    // Five unhashed photos in the tenant. Three hash (two images, and the
    // non-image data URL, which still has bytes to SHA); the remote url never
    // does, so it is left null and seen again by every run.
    expect(first.hashed + rest.hashed).toBe(3);
    expect(rest.unhashable).toBe(1);
    expect(lines.length).toBeGreaterThan(0);
  });

  it('writes exactly what upload would have written', async () => {
    expect(await read(ids.image)).toEqual(await computePhotoHashes(imageUrl));
    expect((await read(ids.secondImage)).perceptualHash).toMatch(/^[0-9a-f]{16}$/);
    // Decodes as base64 but not as an image: content hash only.
    expect(await read(ids.notAnImage)).toEqual({
      contentHash: createHash('sha256').update(Buffer.from('hello')).digest('hex'),
      perceptualHash: null,
      perceptualHashBands: [],
    });
  });

  it('leaves unhashable, already-hashed and out-of-scope rows alone', async () => {
    expect(await read(ids.remote)).toEqual({ contentHash: null, perceptualHash: null, perceptualHashBands: [] });
    expect((await read(ids.alreadyHashed)).contentHash).toBe('already-set');
    expect((await read(ids.otherTenant)).contentHash).toBeNull();
  });

  it('is idempotent: a second run over the same rows writes nothing', async () => {
    const before = await read(ids.image);
    const again = await backfillPhotoHashes({ clientId, batchSize: 2 });
    expect(again).toEqual({ scanned: 1, hashed: 0, unhashable: 1 });
    expect(await read(ids.image)).toEqual(before);
  });

  it('never overwrites a row that was hashed between the read and the write', async () => {
    // The write is guarded on contentHash IS NULL, so a racing upload or a
    // second backfill process wins, not this one.
    const racing = (await photo(visitId, imageUrl)).id;
    const batchRead = jest.spyOn(prisma.photo, 'findMany').mockImplementationOnce((async () => {
      await prisma.photo.update({ where: { id: racing }, data: { contentHash: 'set-by-racer' } });
      return [{ id: racing, url: imageUrl }];
    }) as never);
    try {
      const result = await backfillPhotoHashes({ clientId, batchSize: 1, limit: 1 });
      expect(result).toEqual({ scanned: 1, hashed: 0, unhashable: 0 });
      expect((await read(racing)).contentHash).toBe('set-by-racer');
    } finally {
      batchRead.mockRestore();
    }
  });

  it('covers every tenant when no client is named', async () => {
    const all = await backfillPhotoHashes({ batchSize: 10 });
    expect(all.hashed).toBeGreaterThanOrEqual(1);
    expect(await read(ids.otherTenant)).toEqual(await computePhotoHashes(imageUrl));
  });
});
