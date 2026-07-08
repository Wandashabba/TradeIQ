import { Response } from 'express';
import { requireRole } from './roleGuard';
import { AuthedRequest } from './auth';

function mockRes(): Response {
  const res = {} as Response;
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

describe('requireRole', () => {
  it('calls next() when the user has an allowed role', () => {
    const req = { user: { userId: 'u1', role: 'manager', clientId: 'c1' } } as AuthedRequest;
    const res = mockRes();
    const next = jest.fn();

    requireRole('manager', 'admin')(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    expect(res.status).not.toHaveBeenCalled();
  });

  it('responds 403 when the user role is not allowed', () => {
    const req = { user: { userId: 'u1', role: 'field_agent', clientId: 'c1' } } as AuthedRequest;
    const res = mockRes();
    const next = jest.fn();

    requireRole('manager', 'admin')(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({ error: 'Forbidden' });
  });

  it('responds 403 when there is no authenticated user', () => {
    const req = {} as AuthedRequest;
    const res = mockRes();
    const next = jest.fn();

    requireRole('field_agent')(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(403);
  });
});
