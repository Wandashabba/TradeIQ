import express from 'express';
import jwt from 'jsonwebtoken';
import request from 'supertest';
import { AuthedRequest, requireAuth } from './auth';
import { errorHandler } from './errorHandler';
import { issueToken } from '../modules/auth/auth.service';

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
    const token = issueToken({ userId: 'u1', role: 'manager', clientId: 'c1' });

    const res = await request(appWithProtectedRoute())
      .get('/protected')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ clientId: 'c1' });
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
