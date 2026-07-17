import jwt from 'jsonwebtoken';
import { assertJwtSecretUsable, issueToken, verifyToken } from './auth.service';

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

  describe('secret strength', () => {
    const originalSecret = process.env.JWT_SECRET;
    const originalEnv = process.env.NODE_ENV;

    // `process.env.X = undefined` stores the STRING "undefined" rather than
    // unsetting the variable. A naive restore of a var that started out unset
    // would therefore leave NODE_ENV="undefined" behind and leak into every
    // later test in this file. Delete when the captured value was undefined.
    function restoreEnv(key: 'JWT_SECRET' | 'NODE_ENV', value: string | undefined): void {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }

    afterEach(() => {
      restoreEnv('JWT_SECRET', originalSecret);
      restoreEnv('NODE_ENV', originalEnv);
    });

    it('refuses the published example default outside dev/test', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'dev-only-change-me';
      expect(() => issueToken(payload)).toThrow(/known default/i);
    });

    it('refuses a too-short secret outside dev/test', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'short';
      expect(() => issueToken(payload)).toThrow(/at least 32 characters/i);
    });

    // An unset NODE_ENV is the likeliest production misconfiguration, so the
    // check must FAIL SAFE — enforce unless dev/test is explicitly declared.
    it('enforces the check when NODE_ENV is unset', () => {
      delete process.env.NODE_ENV;
      process.env.JWT_SECRET = 'dev-only-change-me';
      expect(() => issueToken(payload)).toThrow(/known default/i);
    });

    it('accepts a strong secret outside dev/test', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'S'.repeat(32);
      expect(() => issueToken(payload)).not.toThrow();
    });

    it('still allows the weak dev secret when NODE_ENV=test', () => {
      process.env.NODE_ENV = 'test';
      process.env.JWT_SECRET = 'dev-only-change-me';
      expect(() => issueToken(payload)).not.toThrow();
    });

    it('still throws when the secret is absent entirely', () => {
      delete process.env.JWT_SECRET;
      expect(() => issueToken(payload)).toThrow('JWT_SECRET is not set');
    });

    it('assertJwtSecretUsable throws on a known default outside dev/test', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'dev-only-change-me';
      expect(() => assertJwtSecretUsable()).toThrow(/known default/i);
    });

    it('assertJwtSecretUsable passes on a strong secret outside dev/test', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'S'.repeat(32);
      expect(() => assertJwtSecretUsable()).not.toThrow();
    });
  });
});
