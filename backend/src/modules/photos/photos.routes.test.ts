import request from 'supertest';
import sharp from 'sharp';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';
import { foreignTenant, userIn } from '../../test-utils/tenants';
import { thumbnailCacheProbe } from './thumbnails';

// superagent leaves image bodies unparsed unless told otherwise — collect the
// raw bytes so the tests can assert on the actual jpeg payload.
const binaryParser = (
  res: unknown,
  callback: (err: Error | null, body: Buffer) => void,
): void => {
  const stream = res as unknown as NodeJS.ReadableStream;
  const chunks: Buffer[] = [];
  stream.on('data', (chunk: Buffer) => chunks.push(chunk));
  stream.on('end', () => callback(null, Buffer.concat(chunks)));
};

describe('photos routes', () => {
  let clientId: string;
  let agentToken: string;
  let agentBToken: string;
  let managerToken: string;
  let visitId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'PHOTO-Test Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'PHOTO-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = (await userIn(clientId, 'manager')).token;

    const agentB = await prisma.user.create({
      data: { email: 'PHOTO-agent-b@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentBToken = issueToken({ userId: agentB.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'PHOTO-Outlet',
        code: 'PHOTO-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    const visit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date(),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'in_progress',
      },
    });
    visitId = visit.id;
  });

  afterAll(async () => {
    // Children before parents: photos reference visits.
    await prisma.photo.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  const validBody = () => ({
    visitId,
    section: 'visibility',
    dataUrl: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD',
    gpsTag: { lat: -26.2041, lng: 28.0473 },
    timestamp: '2026-07-09T10:00:00.000Z',
  });

  it('stores a photo for a visit (201)', async () => {
    const res = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(validBody());

    expect(res.status).toBe(201);
    expect(res.body.url).toBe('data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD');
    expect(res.body.section).toBe('visibility');
    expect(res.body.createdAt).toBeDefined();
  });

  it("forbids an agent from uploading a photo onto another agent's visit (404)", async () => {
    const res = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${agentBToken}`)
      .send(validBody());
    expect(res.status).toBe(404);
  });

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${otherToken}`)
      .send(validBody());
    expect(res.status).toBe(404);
  });

  it('rejects a missing required field with 400', async () => {
    const { section, ...rest } = validBody();
    void section;
    const res = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(rest);
    expect(res.status).toBe(400);
  });

  it('rejects an invalid gpsTag with 400', async () => {
    const res = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ ...validBody(), gpsTag: null });
    expect(res.status).toBe(400);
  });

  it('rejects an oversized dataUrl with 400', async () => {
    const huge = `data:image/jpeg;base64,${'A'.repeat(8 * 1024 * 1024 + 1)}`;
    const res = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ ...validBody(), dataUrl: huge });
    expect(res.status).toBe(400);
  });

  it('forbids a manager from uploading a photo with 403', async () => {
    const res = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${managerToken}`)
      .send(validBody());
    expect(res.status).toBe(403);
  });

  it('rejects a POST without a bearer token', async () => {
    const res = await request(app).post('/photos').send(validBody());
    expect(res.status).toBe(401);
  });

  it("lists a visit's photos ordered createdAt desc (200)", async () => {
    await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ ...validBody(), section: 'stock' });
    await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ ...validBody(), section: 'pricing' });

    const res = await request(app)
      .get('/photos')
      .query({ visitId })
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThanOrEqual(2);
    const createdAts = res.body.data.map((p: { createdAt: string }) => new Date(p.createdAt).getTime());
    expect(createdAts).toEqual([...createdAts].sort((a: number, b: number) => b - a));
  });

  it('answers GET /photos with an envelope, capped and cursored', async () => {
    const first = await request(app)
      .get(`/photos?visitId=${visitId}&limit=1`)
      .set('Authorization', `Bearer ${agentToken}`);

    expect(first.status).toBe(200);
    expect(first.body.data).toHaveLength(1);
    expect(first.body).toHaveProperty('nextCursor');

    const bad = await request(app)
      .get(`/photos?visitId=${visitId}&limit=0`)
      .set('Authorization', `Bearer ${agentToken}`);
    expect(bad.status).toBe(400);
  });

  it('rejects a GET without a visitId with 400', async () => {
    const res = await request(app).get('/photos').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(400);
  });

  it('returns 404 on GET for a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .get('/photos')
      .query({ visitId })
      .set('Authorization', `Bearer ${otherToken}`);
    expect(res.status).toBe(404);
  });

  it('rejects a GET without a bearer token', async () => {
    const res = await request(app).get('/photos').query({ visitId });
    expect(res.status).toBe(401);
  });

  describe('GET /photos/:id/thumbnail', () => {
    let fixturePhotoId: string;
    let malformedPhotoId: string;

    beforeAll(async () => {
      // A real ~1MB jpeg: gaussian noise defeats jpeg compression, so a
      // 2000px frame lands well above 500KB without shipping a binary fixture.
      const jpeg = await sharp({
        create: {
          width: 2000,
          height: 2000,
          channels: 3,
          background: { r: 128, g: 128, b: 128 },
          noise: { type: 'gaussian', mean: 128, sigma: 50 },
        },
      })
        .jpeg({ quality: 95 })
        .toBuffer();
      expect(jpeg.byteLength).toBeGreaterThan(500 * 1024);

      const photo = await prisma.photo.create({
        data: {
          visitId,
          section: 'visibility',
          url: `data:image/jpeg;base64,${jpeg.toString('base64')}`,
          gpsTag: { lat: -26.2041, lng: 28.0473 },
          timestamp: new Date(),
        },
      });
      fixturePhotoId = photo.id;

      const malformed = await prisma.photo.create({
        data: {
          visitId,
          section: 'visibility',
          url: 'not-a-data-url',
          gpsTag: { lat: -26.2041, lng: 28.0473 },
          timestamp: new Date(),
        },
      });
      malformedPhotoId = malformed.id;
    });

    const seedPhoto = async (url: string) => {
      const photo = await prisma.photo.create({
        data: {
          visitId,
          section: 'visibility',
          url,
          gpsTag: { lat: -26.2041, lng: 28.0473 },
          timestamp: new Date(),
        },
      });
      return photo.id;
    };

    it('serves a manager a small jpeg with cache headers (200)', async () => {
      const res = await request(app)
        .get(`/photos/${fixturePhotoId}/thumbnail`)
        .set('Authorization', `Bearer ${managerToken}`)
        .buffer(true)
        .parse(binaryParser);

      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toBe('image/jpeg');
      expect(res.headers['cache-control']).toBe('private, max-age=86400, immutable');
      const body = res.body as Buffer;
      expect(Buffer.isBuffer(body)).toBe(true);
      expect(body.byteLength).toBeGreaterThan(0);
      expect(body.byteLength).toBeLessThan(60 * 1024);
    });

    it('serves a field agent the repeat request from the in-memory cache', async () => {
      const before = thumbnailCacheProbe();
      const res = await request(app)
        .get(`/photos/${fixturePhotoId}/thumbnail`)
        .set('Authorization', `Bearer ${agentToken}`)
        .buffer(true)
        .parse(binaryParser);

      expect(res.status).toBe(200);
      const after = thumbnailCacheProbe();
      expect(after.hits).toBe(before.hits + 1);
      expect(after.size).toBe(before.size);
    });

    it('returns 404 for an unknown photo id', async () => {
      // visitId is a real uuid that is not a photo id.
      const res = await request(app)
        .get(`/photos/${visitId}/thumbnail`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(404);
    });

    it("returns 404 for another tenant's photo", async () => {
      const otherToken = (await foreignTenant('manager')).token;
      const res = await request(app)
        .get(`/photos/${fixturePhotoId}/thumbnail`)
        .set('Authorization', `Bearer ${otherToken}`);
      expect(res.status).toBe(404);
    });

    it('rejects a request without a bearer token (401)', async () => {
      const res = await request(app).get(`/photos/${fixturePhotoId}/thumbnail`);
      expect(res.status).toBe(401);
    });

    it('returns 422 for a photo whose stored url is not a data URL', async () => {
      const res = await request(app)
        .get(`/photos/${malformedPhotoId}/thumbnail`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(422);
      expect(typeof res.body.error).toBe('string');
    });

    it('returns 422 for a data URL whose base64 payload is not an image', async () => {
      // 'aGVsbG8=' is valid base64 ("hello") — passes the regex, fails decode.
      const photoId = await seedPhoto('data:image/jpeg;base64,aGVsbG8=');
      const res = await request(app)
        .get(`/photos/${photoId}/thumbnail`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(422);
      expect(typeof res.body.error).toBe('string');
    });

    it('returns 422 for a decompression bomb (tiny bytes, huge dimensions)', async () => {
      // 9000x9000 = 81MP — a solid-color PNG of it compresses to a few KB,
      // but decoding would allocate ~324MB. Must be refused, not decoded.
      const bomb = await sharp({
        create: {
          width: 9000,
          height: 9000,
          channels: 3,
          background: { r: 0, g: 0, b: 0 },
        },
      })
        .png()
        .toBuffer();
      expect(bomb.byteLength).toBeLessThan(1024 * 1024); // small on the wire

      const photoId = await seedPhoto(`data:image/png;base64,${bomb.toString('base64')}`);
      const res = await request(app)
        .get(`/photos/${photoId}/thumbnail`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(422);
      expect(typeof res.body.error).toBe('string');
    });

    it('bakes the EXIF orientation into the thumbnail (portrait stays portrait)', async () => {
      // A 400x200 landscape frame tagged orientation 6 (rotate 90° CW) is
      // really a portrait shot — the served thumbnail must come out taller
      // than wide, proving .rotate() honours EXIF before resizing.
      const oriented = await sharp({
        create: { width: 400, height: 200, channels: 3, background: { r: 50, g: 100, b: 150 } },
      })
        .jpeg()
        .withMetadata({ orientation: 6 })
        .toBuffer();

      const photoId = await seedPhoto(`data:image/jpeg;base64,${oriented.toString('base64')}`);
      const res = await request(app)
        .get(`/photos/${photoId}/thumbnail`)
        .set('Authorization', `Bearer ${managerToken}`)
        .buffer(true)
        .parse(binaryParser);
      expect(res.status).toBe(200);

      const meta = await sharp(res.body as Buffer).metadata();
      expect(meta.width).toBe(256);
      expect(meta.height).toBe(512); // 200x400 after rotation, upscaled to width 256
    });
  });
});
