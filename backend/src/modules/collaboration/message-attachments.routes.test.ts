import request from 'supertest';
import sharp from 'sharp';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';

// superagent leaves image bodies unparsed unless told otherwise — collect the
// raw bytes so the tests can assert on the actual payload.
const binaryParser = (
  res: unknown,
  callback: (err: Error | null, body: Buffer) => void,
): void => {
  const stream = res as unknown as NodeJS.ReadableStream;
  const chunks: Buffer[] = [];
  stream.on('data', (chunk: Buffer) => chunks.push(chunk));
  stream.on('end', () => callback(null, Buffer.concat(chunks)));
};

/**
 * Image attachments on messages (#125). Images only, through the existing
 * photo pipeline: `POST /photos` with purpose `message_attachment`, then
 * `POST /messages` with `attachmentPhotoIds`.
 */
describe('message image attachments', () => {
  let clientId: string;
  let manager: TestUser;
  let agentA: TestUser;
  let agentB: TestUser;
  let agentC: TestUser;
  let foreign: Awaited<ReturnType<typeof foreignTenant>>;
  let foreignManager: TestUser;
  let pngDataUrl: string;

  const upload = async (user: TestUser, dataUrl = pngDataUrl) =>
    request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ purpose: 'message_attachment', dataUrl });

  const uploadId = async (user: TestUser): Promise<string> => {
    const res = await upload(user);
    expect(res.status).toBe(201);
    return res.body.id as string;
  };

  const send = (user: TestUser, body: Record<string, unknown>) =>
    request(app).post('/messages').set('Authorization', `Bearer ${user.token}`).send(body);

  const fetchBytes = (user: TestUser, path: string) =>
    request(app)
      .get(path)
      .set('Authorization', `Bearer ${user.token}`)
      .buffer(true)
      .parse(binaryParser);

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'MSGATT-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    manager = await userIn(clientId, 'manager');
    agentA = await userIn(clientId, 'field_agent');
    agentB = await userIn(clientId, 'field_agent');
    agentC = await userIn(clientId, 'field_agent');
    foreign = await foreignTenant('field_agent');
    foreignManager = await userIn(foreign.clientId, 'manager');

    const png = await sharp({
      create: { width: 16, height: 12, channels: 3, background: '#3a2f78' },
    })
      .png()
      .toBuffer();
    pngDataUrl = `data:image/png;base64,${png.toString('base64')}`;
  });

  afterAll(async () => {
    const tenants = [clientId, foreign.clientId];
    // Attachments cascade with their message; photos, visits and outlets must
    // go before the users and clients they reference.
    await prisma.message.deleteMany({ where: { clientId: { in: tenants } } });
    await prisma.photo.deleteMany({
      where: { OR: [{ clientId: { in: tenants } }, { visit: { clientId: { in: tenants } } }] },
    });
    await prisma.visit.deleteMany({ where: { clientId: { in: tenants } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: tenants } } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
    await prisma.$disconnect();
  });

  describe('POST /photos with purpose message_attachment', () => {
    it('lets any role upload, and answers with metadata and links — never the bytes', async () => {
      const res = await upload(manager);

      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({
        clientId,
        uploadedById: manager.userId,
        section: 'message_attachment',
        thumbnailUrl: `/photos/${res.body.id}/thumbnail`,
        imageUrl: `/photos/${res.body.id}/image`,
      });
      expect(res.body.url).toBeUndefined();
      expect(JSON.stringify(res.body)).not.toContain('base64');

      const row = await prisma.photo.findUniqueOrThrow({ where: { id: res.body.id } });
      expect(row.visitId).toBeNull();
      expect(row.url).toBe(pngDataUrl);
    });

    it.each([
      ['a non-image data URL', 'data:application/pdf;base64,JVBERi0xLjQK'],
      ['an image data URL whose bytes are not an image', 'data:image/png;base64,AAAAAAAA'],
      ['a bare string', 'not a data url'],
    ])('rejects %s with 400 (images only)', async (_label, dataUrl) => {
      const res = await upload(agentA, dataUrl);
      expect(res.status).toBe(400);
    });

    it('rejects an unknown purpose, and a message attachment that names a visit, with 400', async () => {
      const unknown = await request(app)
        .post('/photos')
        .set('Authorization', `Bearer ${agentA.token}`)
        .send({ purpose: 'document', dataUrl: pngDataUrl });
      expect(unknown.status).toBe(400);

      const withVisit = await request(app)
        .post('/photos')
        .set('Authorization', `Bearer ${agentA.token}`)
        .send({ purpose: 'message_attachment', dataUrl: pngDataUrl, visitId: 'v1' });
      expect(withVisit.status).toBe(400);
    });

    it('still forbids a manager from uploading visit evidence (403)', async () => {
      const res = await request(app)
        .post('/photos')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({
          visitId: 'any',
          section: 'visibility',
          dataUrl: pngDataUrl,
          gpsTag: {},
          timestamp: '2026-09-15T10:00:00.000Z',
        });
      expect(res.status).toBe(403);
    });
  });

  describe('POST /messages with attachmentPhotoIds', () => {
    it('creates a message carrying its images in order, as metadata and links', async () => {
      const first = await uploadId(agentA);
      const second = await uploadId(agentA);

      const res = await send(agentA, {
        body: 'Shelf after restock',
        recipientId: agentB.userId,
        attachmentPhotoIds: [first, second],
      });

      expect(res.status).toBe(201);
      expect(res.body.attachments).toEqual([
        {
          photoId: first,
          position: 0,
          thumbnailUrl: `/photos/${first}/thumbnail`,
          imageUrl: `/photos/${first}/image`,
        },
        {
          photoId: second,
          position: 1,
          thumbnailUrl: `/photos/${second}/thumbnail`,
          imageUrl: `/photos/${second}/image`,
        },
      ]);
      expect(JSON.stringify(res.body)).not.toContain('base64');
    });

    it('allows an image-only message with a blank body', async () => {
      const photoId = await uploadId(agentA);
      const res = await send(agentA, { body: '', attachmentPhotoIds: [photoId] });
      expect(res.status).toBe(201);
      expect(res.body.attachments).toHaveLength(1);
    });

    it('still rejects a blank body with no attachments (400)', async () => {
      const res = await send(agentA, { body: '  ', attachmentPhotoIds: [] });
      expect(res.status).toBe(400);
    });

    it('enforces the maximum of 4 images (400) and creates nothing', async () => {
      const ids = await Promise.all([1, 2, 3, 4, 5].map(() => uploadId(agentA)));
      const before = await prisma.message.count({ where: { clientId } });

      const res = await send(agentA, { body: 'Too many', attachmentPhotoIds: ids });

      expect(res.status).toBe(400);
      expect(await prisma.message.count({ where: { clientId } })).toBe(before);

      // Four is allowed.
      const ok = await send(agentA, { body: 'Four', attachmentPhotoIds: ids.slice(0, 4) });
      expect(ok.status).toBe(201);
      expect(ok.body.attachments).toHaveLength(4);
    });

    it.each([
      ['a non-array', 'photo-1'],
      ['an array with a non-string', [1]],
    ])('rejects attachmentPhotoIds as %s (400)', async (_label, attachmentPhotoIds) => {
      const res = await send(agentA, { body: 'hi', attachmentPhotoIds });
      expect(res.status).toBe(400);
    });

    it('rejects the same photo twice in one message (400)', async () => {
      const photoId = await uploadId(agentA);
      const res = await send(agentA, { body: 'dup', attachmentPhotoIds: [photoId, photoId] });
      expect(res.status).toBe(400);
    });

    it("rejects another tenant's photo (404) and creates no message", async () => {
      const foreignPhotoId = await uploadId(foreign);
      const before = await prisma.message.count({ where: { clientId } });

      const res = await send(agentA, { body: 'Cross-tenant', attachmentPhotoIds: [foreignPhotoId] });

      expect(res.status).toBe(404);
      expect(await prisma.message.count({ where: { clientId } })).toBe(before);
      expect(
        await prisma.messageAttachment.count({ where: { photoId: foreignPhotoId } }),
      ).toBe(0);
    });

    it("rejects a photo someone else in the tenant uploaded (404) — the uploader must be the sender", async () => {
      const agentBPhoto = await uploadId(agentB);
      const res = await send(agentA, { body: 'Not mine', attachmentPhotoIds: [agentBPhoto] });
      expect(res.status).toBe(404);

      // Not even a manager may attach an agent's upload.
      const asManager = await send(manager, { body: 'Not mine', attachmentPhotoIds: [agentBPhoto] });
      expect(asManager.status).toBe(404);
    });

    it('rejects visit evidence as an attachment (400)', async () => {
      const outlet = await prisma.outlet.create({
        data: {
          name: 'MSGATT-Outlet',
          code: 'MSGATT-001',
          channelType: 'hypermarket',
          lat: -26.2,
          lng: 28.0,
          territoryId: 't1',
          clientId,
        },
      });
      const visit = await prisma.visit.create({
        data: {
          outletId: outlet.id,
          agentId: agentA.userId,
          clientId,
          checkinTs: new Date(),
          checkinLat: -26.2,
          checkinLng: 28.0,
          geofencePass: true,
          status: 'in_progress',
        },
      });
      const evidence = await request(app)
        .post('/photos')
        .set('Authorization', `Bearer ${agentA.token}`)
        .send({
          visitId: visit.id,
          section: 'visibility',
          dataUrl: pngDataUrl,
          gpsTag: { lat: -26.2, lng: 28.0 },
          timestamp: '2026-09-15T10:00:00.000Z',
        });
      expect(evidence.status).toBe(201);
      // Visit evidence now records its uploader too.
      expect(evidence.body.uploadedById).toBe(agentA.userId);

      const res = await send(agentA, { body: 'Evidence', attachmentPhotoIds: [evidence.body.id] });
      expect(res.status).toBe(400);
    });

    it('rejects a photo that is already attached to another message (409)', async () => {
      const photoId = await uploadId(agentA);
      expect((await send(agentA, { body: 'first', attachmentPhotoIds: [photoId] })).status).toBe(201);

      const again = await send(agentA, { body: 'second', attachmentPhotoIds: [photoId] });
      expect(again.status).toBe(409);
    });
  });

  describe('GET /messages', () => {
    it('lists attachment metadata and thumbnail links, with no image bytes anywhere', async () => {
      const photoId = await uploadId(agentA);
      const sent = await send(agentA, {
        body: 'List shape',
        recipientId: agentB.userId,
        attachmentPhotoIds: [photoId],
      });
      expect(sent.status).toBe(201);

      const res = await request(app)
        .get('/messages')
        .query({ limit: 200 })
        .set('Authorization', `Bearer ${agentB.token}`);

      expect(res.status).toBe(200);
      const raw = JSON.stringify(res.body);
      expect(raw).not.toContain('base64');
      expect(raw).not.toContain('data:image');

      const listed = (res.body.data as Array<{ id: string; attachments: unknown[] }>).find(
        (m) => m.id === sent.body.id,
      );
      expect(listed?.attachments).toEqual([
        {
          photoId,
          position: 0,
          thumbnailUrl: `/photos/${photoId}/thumbnail`,
          imageUrl: `/photos/${photoId}/image`,
        },
      ]);

      // Every message carries the array, empty when it has no images.
      for (const m of res.body.data as Array<{ attachments: unknown }>) {
        expect(Array.isArray(m.attachments)).toBe(true);
      }
    });
  });

  describe('attachment access control (thumbnail and full image)', () => {
    let directPhotoId: string;
    let broadcastPhotoId: string;
    let unattachedPhotoId: string;

    beforeAll(async () => {
      directPhotoId = await uploadId(agentA);
      expect(
        (
          await send(agentA, {
            body: 'Direct with image',
            recipientId: agentB.userId,
            attachmentPhotoIds: [directPhotoId],
          })
        ).status,
      ).toBe(201);

      broadcastPhotoId = await uploadId(agentA);
      expect(
        (await send(agentA, { body: 'Broadcast with image', attachmentPhotoIds: [broadcastPhotoId] }))
          .status,
      ).toBe(201);

      unattachedPhotoId = await uploadId(agentA);
    });

    const paths = (id: string) => [`/photos/${id}/thumbnail`, `/photos/${id}/image`];

    it('serves a direct message attachment to its sender, its recipient, and a manager', async () => {
      for (const user of [agentA, agentB, manager]) {
        const thumb = await fetchBytes(user, `/photos/${directPhotoId}/thumbnail`);
        expect(thumb.status).toBe(200);
        expect(thumb.headers['content-type']).toBe('image/jpeg');
        expect(thumb.body.subarray(0, 2).equals(Buffer.from([0xff, 0xd8]))).toBe(true);

        const image = await fetchBytes(user, `/photos/${directPhotoId}/image`);
        expect(image.status).toBe(200);
        expect(image.headers['content-type']).toBe('image/png');
        expect(image.headers['cache-control']).toContain('private');
        expect((image.body as Buffer).toString('base64')).toBe(pngDataUrl.split(',')[1]);
      }
    });

    it('hides a direct message attachment from a same-tenant bystander (404)', async () => {
      for (const path of paths(directPhotoId)) {
        expect((await fetchBytes(agentC, path)).status).toBe(404);
      }
    });

    it('hides every attachment from another tenant, managers included (404)', async () => {
      for (const id of [directPhotoId, broadcastPhotoId, unattachedPhotoId]) {
        for (const path of paths(id)) {
          expect((await fetchBytes(foreignManager, path)).status).toBe(404);
          expect((await fetchBytes(foreign, path)).status).toBe(404);
        }
      }
    });

    it('serves a broadcast attachment to everyone in the tenant — they are all its recipients', async () => {
      for (const user of [agentA, agentB, agentC, manager]) {
        for (const path of paths(broadcastPhotoId)) {
          expect((await fetchBytes(user, path)).status).toBe(200);
        }
      }
    });

    it('keeps an unattached upload to its uploader and the managers', async () => {
      for (const user of [agentA, manager]) {
        expect((await fetchBytes(user, `/photos/${unattachedPhotoId}/thumbnail`)).status).toBe(200);
      }
      for (const path of paths(unattachedPhotoId)) {
        expect((await fetchBytes(agentB, path)).status).toBe(404);
      }
    });

    it('checks access before the thumbnail cache — a warm cache never leaks', async () => {
      // agentA just warmed the direct attachment's thumbnail above.
      expect((await fetchBytes(agentA, `/photos/${directPhotoId}/thumbnail`)).status).toBe(200);
      expect((await fetchBytes(agentC, `/photos/${directPhotoId}/thumbnail`)).status).toBe(404);
    });

    it('answers 404 for a photo id that does not exist', async () => {
      const missing = '00000000-0000-4000-8000-000000000000';
      for (const path of paths(missing)) {
        expect((await fetchBytes(manager, path)).status).toBe(404);
      }
    });

    it('rejects both routes without a token (401)', async () => {
      for (const path of paths(directPhotoId)) {
        expect((await request(app).get(path)).status).toBe(401);
      }
    });
  });
});
