import request from 'supertest';
import { app } from '../app';
import { issueToken } from './auth/auth.service';

const token = issueToken({ userId: 'user-1', role: 'manager', clientId: 'client-1' });

const skeletonRoutes = [
  '/visits', '/stock', '/visibility', '/pricing', '/competitive',
  '/capability', '/risks', '/tasks', '/scorecards', '/dashboard',
];

describe('module skeleton routes', () => {
  it.each(skeletonRoutes)('GET %s requires auth and returns 501 when authed', async (path) => {
    const unauthed = await request(app).get(path);
    expect(unauthed.status).toBe(401);

    const authed = await request(app).get(path).set('Authorization', `Bearer ${token}`);
    expect(authed.status).toBe(501);
  });
});
