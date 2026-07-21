import express from 'express';
import jwt from 'jsonwebtoken';
import request from 'supertest';
import { AuthedRequest, requireAuth } from './auth';
import { errorHandler } from './errorHandler';
import { issueToken } from '../modules/auth/auth.service';
import { prisma } from '../lib/prisma';
import { foreignTenant } from '../test-utils/tenants';

// Mounts requireAuth in front of a protected route, with errorHandler behind
// it. The errorHandler is what would turn an escaping throw into a 500, so its
// presence is what gives the "401, not 500" assertions their teeth.
function appWithProtectedRoute() {
  const app = express();
  app.get('/protected', requireAuth, (req: AuthedRequest, res) => {
    res.status(200).json({ clientId: req.user?.clientId });
  });
  app.use(errorHandler);
  return app;
}

describe('requireAuth', () => {
  // Control: proves the route is genuinely reachable, so a 401 below is the
  // guard rejecting the token rather than a broken fixture.
  it('allows a well-formed token through to the route', async () => {
    // A real user in a real tenant, because requireAuth now re-reads the user
    // on every request. A fabricated id is a 401 by design — that lookup is
    // precisely what makes revocation work.
    const foreign = await foreignTenant('manager');
    const res = await request(appWithProtectedRoute())
      .get('/protected')
      .set('Authorization', `Bearer ${foreign.token}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ clientId: foreign.clientId });
    await foreign.cleanup();
  });

  // The security value of validating the payload depends entirely on the throw
  // surfacing as a 401. A 500 would mean the request errored rather than being
  // refused; a 200 would mean the cross-tenant read went through.
  it('responds 401 when a validly-signed token is missing clientId', async () => {
    const forged = jwt.sign({ userId: 'u1', role: 'field_agent' }, process.env.JWT_SECRET!);

    const res = await request(appWithProtectedRoute())
      .get('/protected')
      .set('Authorization', `Bearer ${forged}`);

    expect(res.status).toBe(401);
  });

  it('does not leak the internal reason a token was rejected', async () => {
    const forged = jwt.sign({ userId: 'u1', role: 'field_agent' }, process.env.JWT_SECRET!);

    const res = await request(appWithProtectedRoute())
      .get('/protected')
      .set('Authorization', `Bearer ${forged}`);

    expect(res.body).toEqual({ error: 'Invalid or expired token' });
    expect(JSON.stringify(res.body)).not.toContain('Malformed token payload');
  });
});

describe('requireAuth revocation', () => {
  let clientId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'REVOKE-Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    clientId = client.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
  });

  async function userWith(overrides: {
    active?: boolean;
    role?: 'field_agent' | 'manager' | 'admin';
    email: string;
  }) {
    return prisma.user.create({
      data: {
        email: overrides.email,
        passwordHash: 'x',
        role: overrides.role ?? 'manager',
        active: overrides.active ?? true,
        clientId,
      },
    });
  }

  it('rejects a token belonging to a deactivated user', async () => {
    // The gap: a 12h token outlives the decision to revoke access. Deactivating
    // someone at 09:00 left them working until 21:00, because nothing between
    // the signature check and the route ever asked the database whether this
    // person is still allowed in.
    const user = await userWith({ email: 'revoked@example.com', active: false });
    const token = issueToken({ userId: user.id, role: 'manager', clientId });

    const res = await request(appWithProtectedRoute())
      .get('/protected')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(401);
  });

  it('rejects a token whose role no longer matches the user', async () => {
    // Demotion is revocation too: a token minted while someone was an admin
    // must not keep admin powers after they are moved to field_agent.
    const user = await userWith({ email: 'demoted@example.com', role: 'field_agent' });
    const token = issueToken({ userId: user.id, role: 'admin', clientId });

    const res = await request(appWithProtectedRoute())
      .get('/protected')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(401);
  });

  it('rejects a token for a user that no longer exists', async () => {
    // Deliberately a fabricated id: this is the deleted-user case, and it is
    // the one place in the suite where a token must NOT name a real person.
    const token = issueToken({
      userId: '00000000-0000-0000-0000-000000000000',
      role: 'manager',
      clientId,
    });

    const res = await request(appWithProtectedRoute())
      .get('/protected')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(401);
  });

  it('still admits an active user whose role is unchanged', async () => {
    // The control. Without it, a guard that rejected everything would pass the
    // three tests above and lock every real user out.
    const user = await userWith({ email: 'still-here@example.com' });
    const token = issueToken({ userId: user.id, role: 'manager', clientId });

    const res = await request(appWithProtectedRoute())
      .get('/protected')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.clientId).toBe(clientId);
  });
});
