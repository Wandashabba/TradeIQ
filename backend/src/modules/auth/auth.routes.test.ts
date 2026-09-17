import request from 'supertest';
import { httpServer as app } from '../../testHttpServer';
import { prisma } from '../../lib/prisma';
import { hashPassword } from './auth.service';

describe('POST /auth/login', () => {
  const email = 'auth-route-test@example.com';
  const password = 'correct-password';
  let clientId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'Auth Route Test Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    clientId = client.id;

    await prisma.user.create({
      data: {
        email,
        passwordHash: await hashPassword(password),
        role: 'field_agent',
        clientId,
      },
    });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('returns 200 with a token for valid credentials', async () => {
    const res = await request(app).post('/auth/login').send({ email, password });
    expect(res.status).toBe(200);
    expect(typeof res.body.token).toBe('string');
    expect(res.body.role).toBe('field_agent');
  });

  // The reported bug, end to end (#351): these are the spellings a phone
  // keyboard and a paste actually produce.
  //
  // BUDGET: POST /auth/login is IP-rate-limited to 10 attempts per window and
  // this file now spends 8 of them. Put further normalisation cases in
  // auth.service.test.ts, which exercises authenticateUser directly and costs
  // nothing here.
  it.each([
    ['capitalised by an Android keyboard', 'Auth-route-test@example.com'],
    ['in all caps', 'AUTH-ROUTE-TEST@EXAMPLE.COM'],
    ['padded with whitespace', '  auth-route-test@example.com  '],
  ])('returns 200 when the email is %s', async (_label, typed) => {
    const res = await request(app).post('/auth/login').send({ email: typed, password });
    expect(res.status).toBe(200);
    expect(typeof res.body.token).toBe('string');
    expect(res.body.role).toBe('field_agent');
  });

  it('returns 401 for a wrong password', async () => {
    const res = await request(app).post('/auth/login').send({ email, password: 'wrong-password' });
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: 'Invalid credentials' });
  });

  it('returns 401 for an unknown email', async () => {
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'does-not-exist@example.com', password });
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: 'Invalid credentials' });
  });

  it('returns 400 when email or password is missing', async () => {
    const res = await request(app).post('/auth/login').send({ email });
    expect(res.status).toBe(400);
    expect(res.body).toEqual({ error: 'email and password are required' });
  });

  it('returns 401 for a deactivated user even with correct credentials', async () => {
    const deactivatedEmail = 'auth-route-deactivated@example.com';
    await prisma.user.create({
      data: {
        email: deactivatedEmail,
        passwordHash: await hashPassword(password),
        role: 'field_agent',
        clientId,
        active: false,
      },
    });

    const res = await request(app)
      .post('/auth/login')
      .send({ email: deactivatedEmail, password });
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: 'Invalid credentials' });
  });
});
