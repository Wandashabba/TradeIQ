import request from 'supertest';
import { app } from '../app';
import { issueToken } from './auth/auth.service';

const token = issueToken({ userId: 'user-1', role: 'manager', clientId: 'client-1' });

// Capture modules whose POST is implemented but whose GET listing is still a
// 501 placeholder. /tasks and /dashboard have real GETs and are covered by
// their own route tests.
const skeletonRoutes = [
  '/pricing', '/competitive', '/capability', '/risks', '/scorecards',
];

describe('module skeleton routes', () => {
  it.each(skeletonRoutes)('GET %s requires auth and returns 501 when authed', async (path) => {
    const unauthed = await request(app).get(path);
    expect(unauthed.status).toBe(401);

    const authed = await request(app).get(path).set('Authorization', `Bearer ${token}`);
    expect(authed.status).toBe(501);
  });
});
