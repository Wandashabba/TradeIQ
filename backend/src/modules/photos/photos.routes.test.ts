import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';
import { foreignTenant, userIn } from '../../test-utils/tenants';

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
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(2);
    const createdAts = res.body.map((p: { createdAt: string }) => new Date(p.createdAt).getTime());
    expect(createdAts).toEqual([...createdAts].sort((a: number, b: number) => b - a));
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
});
