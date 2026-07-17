import jwt from 'jsonwebtoken';
import { issueToken, verifyToken } from './auth.service';

describe('auth.service', () => {
  const payload = { userId: 'user-1', role: 'field_agent' as const, clientId: 'client-1' };

  it('issues a token that verifies back to the same payload', () => {
    const token = issueToken(payload);
    const decoded = verifyToken(token);
    expect(decoded.userId).toBe(payload.userId);
    expect(decoded.role).toBe(payload.role);
    expect(decoded.clientId).toBe(payload.clientId);
  });

  it('throws when verifying a malformed token', () => {
    expect(() => verifyToken('not-a-real-token')).toThrow();
  });

  // A token can be correctly SIGNED and still carry a payload we never issued.
  // Prisma drops `undefined` from a `where` clause, so a missing clientId would
  // turn every tenant-scoped query into a cross-tenant read. Verify the shape.
  it('rejects a validly-signed token whose payload is missing clientId', () => {
    const forged = jwt.sign({ userId: 'u1', role: 'field_agent' }, process.env.JWT_SECRET!);
    expect(() => verifyToken(forged)).toThrow('Malformed token payload');
  });

  it('rejects a validly-signed token whose payload is missing userId', () => {
    const forged = jwt.sign({ role: 'manager', clientId: 'c1' }, process.env.JWT_SECRET!);
    expect(() => verifyToken(forged)).toThrow('Malformed token payload');
  });

  it('rejects a validly-signed token carrying a role outside the union', () => {
    const forged = jwt.sign(
      { userId: 'u1', role: 'superadmin', clientId: 'c1' },
      process.env.JWT_SECRET!,
    );
    expect(() => verifyToken(forged)).toThrow('Malformed token payload');
  });

  it('rejects a validly-signed token whose clientId is an empty string', () => {
    const forged = jwt.sign(
      { userId: 'u1', role: 'manager', clientId: '' },
      process.env.JWT_SECRET!,
    );
    expect(() => verifyToken(forged)).toThrow('Malformed token payload');
  });

  it('rejects a validly-signed token whose payload is a bare string', () => {
    const forged = jwt.sign('just-a-string', process.env.JWT_SECRET!);
    expect(() => verifyToken(forged)).toThrow('Malformed token payload');
  });
});
