import express from 'express';
import request from 'supertest';
import { errorHandler, GeofenceRejectedError, NotFoundError, NotImplementedError } from './errorHandler';

describe('errorHandler', () => {
  it('maps NotImplementedError to 501', async () => {
    const app = express();
    app.get('/boom', () => {
      throw new NotImplementedError('not built yet');
    });
    app.use(errorHandler);

    const res = await request(app).get('/boom');
    expect(res.status).toBe(501);
    expect(res.body).toEqual({ error: 'not built yet' });
  });

  it('maps unknown errors to 500 without leaking stack traces', async () => {
    const app = express();
    app.get('/boom', () => {
      throw new Error('unexpected');
    });
    app.use(errorHandler);

    const res = await request(app).get('/boom');
    expect(res.status).toBe(500);
    expect(res.body).toEqual({ error: 'Internal server error' });
  });

  it('maps NotFoundError to 404', async () => {
    const app = express();
    app.get('/boom', () => {
      throw new NotFoundError('missing thing');
    });
    app.use(errorHandler);

    const res = await request(app).get('/boom');
    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: 'missing thing' });
  });
});
