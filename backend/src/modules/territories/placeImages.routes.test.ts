import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';

/**
 * THE PICTURE OF A PLACE, ON THE WIRE.
 *
 * What these hold down, in order:
 *
 * 1. the bytes come back, and they come back **marked** — `X-Image-Source` is
 *    what lets the app say "illustration" over a generated picture and
 *    "photograph" over one the owner supplied, instead of assuming either;
 * 2. the whole-footprint scope has a picture of its own, not one province's;
 * 3. another tenant's territory id misses, rather than handing back a picture
 *    of somewhere it names;
 * 4. no picture is a 404 and nothing is substituted for one;
 * 5. a broken stored row is a 422, not a 404 — the request was fine.
 */

// A one-pixel JPEG, as a data URL. Small on purpose: what is under test is the
// route's decoding and its headers, not an encoder.
const JPEG = Buffer.from(
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a' +
    'HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAA' +
    'AAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
  'base64',
);
const DATA_URL = `data:image/jpeg;base64,${JPEG.toString('base64')}`;

describe('place image routes', () => {
  let clientId: string;
  let otherClientId: string;
  let territoryId: string;
  let suppliedTerritoryId: string;
  let picturelessTerritoryId: string;
  let otherTerritoryId: string;
  let managerToken: string;
  let agentToken: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'PLACE-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'PLACE-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const agent = await prisma.user.create({
      data: { email: 'PLACE-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const territory = await prisma.territory.create({
      data: { clientId, name: 'Gauteng North', code: 'PLACE-GP-TSH' },
    });
    territoryId = territory.id;

    // A territory whose picture is a photograph the owner supplied rather than
    // one a model made. Same table, same route, different mark — and the mark
    // is the whole reason both can live here.
    const suppliedTerritory = await prisma.territory.create({
      data: { clientId, name: 'Free State', code: 'PLACE-FS' },
    });
    suppliedTerritoryId = suppliedTerritory.id;

    const pictureless = await prisma.territory.create({
      data: { clientId, name: 'Never Photographed', code: 'PLACE-NONE' },
    });
    picturelessTerritoryId = pictureless.id;

    const otherClient = await prisma.client.create({
      data: { name: 'PLACE-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherTerritory = await prisma.territory.create({
      data: { clientId: otherClientId, name: 'Somewhere Else', code: 'PLACE-OTHER' },
    });
    otherTerritoryId = otherTerritory.id;

    await prisma.placeImage.createMany({
      data: [
        {
          clientId,
          territoryId,
          source: 'generated',
          generator: 'gemini-3.1-flash-image',
          prompt: 'a street',
          mimeType: 'image/jpeg',
          url: DATA_URL,
        },
        {
          clientId,
          // The whole footprint. Null, not a sentinel territory — a territory
          // called ALL would turn up in the filter sheet and in coverage.
          territoryId: null,
          source: 'generated',
          generator: 'gemini-3.1-flash-image',
          prompt: 'a trade route',
          mimeType: 'image/jpeg',
          url: DATA_URL,
        },
        {
          clientId,
          territoryId: suppliedTerritoryId,
          // A photograph the owner handed over: no model, no prompt.
          source: 'supplied',
          mimeType: 'image/jpeg',
          url: DATA_URL,
        },
        {
          clientId: otherClientId,
          territoryId: otherTerritoryId,
          source: 'generated',
          mimeType: 'image/jpeg',
          url: DATA_URL,
        },
      ],
    });
  });

  it('serves the territory picture, and says it was generated', async () => {
    const res = await request(app)
      .get(`/territories/${territoryId}/place-image`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('image/jpeg');
    expect(Buffer.from(res.body).equals(JPEG)).toBe(true);
    // THE MARK. Without it the app has bytes and no idea what they are, and
    // "what they are" is the whole boundary this feature is built inside.
    expect(res.headers['x-image-source']).toBe('generated');
    // And a browser can read it: a cross-origin fetch sees only the exposed
    // headers, so an unexposed mark is a mark that goes missing on web.
    expect(res.headers['access-control-expose-headers']).toContain('X-Image-Source');
  });

  it('says supplied over a supplied photograph, and does not flatten it to generated', async () => {
    const res = await request(app)
      .get(`/territories/${suppliedTerritoryId}/place-image`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    // THE OTHER HALF OF THE MARK. The plate's spoken label is built from this
    // header: `generated` gets "an illustration of the area", `supplied` gets
    // "a photograph of the area". Echoing one value for both would put a
    // sentence on a manager's screen that contradicts the picture above it.
    expect(res.headers['x-image-source']).toBe('supplied');
    expect(res.headers['access-control-expose-headers']).toContain('X-Image-Source');
  });

  it('serves the whole footprint its own picture', async () => {
    const res = await request(app)
      .get('/territories/place-image')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.headers['x-image-source']).toBe('generated');
  });

  it('404s a territory with no picture, and substitutes nothing', async () => {
    const res = await request(app)
      .get(`/territories/${picturelessTerritoryId}/place-image`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(404);
    // The client draws its designed no-picture state off this. An invented
    // picture in place of a missing one is the one thing this feature may not
    // do.
    expect(res.body).not.toHaveProperty('url');
  });

  it('misses on another tenant’s territory rather than serving it', async () => {
    const res = await request(app)
      .get(`/territories/${otherTerritoryId}/place-image`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(404);
  });

  it('422s a stored row that is not a decodable data URL', async () => {
    const broken = await prisma.territory.create({
      data: { clientId, name: 'Broken', code: 'PLACE-BROKEN' },
    });
    await prisma.placeImage.create({
      data: {
        clientId,
        territoryId: broken.id,
        source: 'generated',
        mimeType: 'image/jpeg',
        url: 'https://example.invalid/not-a-data-url.jpg',
      },
    });

    const res = await request(app)
      .get(`/territories/${broken.id}/place-image`)
      .set('Authorization', `Bearer ${managerToken}`);

    // Not a 404: the row is there and it is broken, and "not found" would send
    // whoever is debugging it looking for a missing record.
    expect(res.status).toBe(422);
  });

  it('is manager/admin, like every other territory route', async () => {
    const res = await request(app)
      .get(`/territories/${territoryId}/place-image`)
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(403);
  });

  it('needs a token at all', async () => {
    const res = await request(app).get('/territories/place-image');
    expect(res.status).toBe(401);
  });
});
