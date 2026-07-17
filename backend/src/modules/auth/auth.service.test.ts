import { spawnSync } from 'child_process';
import * as path from 'path';
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

    // Pins the WIRING, not just the export. `assertJwtSecretUsable()` only
    // protects anything if server.ts actually calls it before listen(), and no
    // in-process test can see that — server.ts is imported by zero suites, so
    // deleting the call left the entire suite green. Boot the real entrypoint
    // in a child process instead. Mutation-checked: removing the call from
    // server.ts makes this fail.
    it(
      'server.ts refuses to boot on a known-default secret',
      () => {
        const res = spawnSync('npx', ['ts-node', 'src/server.ts'], {
          cwd: path.resolve(__dirname, '../../..'),
          env: {
            ...process.env,
            NODE_ENV: 'production',
            JWT_SECRET: 'dev-only-change-me',
            // PORT=0 so that if the guard regresses, the child binds an
            // ephemeral port rather than fighting a real dev server on 4000 —
            // an EADDRINUSE exit would look like a pass and hide the regression.
            PORT: '0',
          },
          encoding: 'utf8',
          // Bounded: a regressed build listens forever, so kill it rather than
          // hang the suite and leak a bound port. Kept comfortably under the
          // jest timeout below so spawnSync always reaps the child itself —
          // if jest timed out first, the server process would leak.
          timeout: 100000,
        });
        // Assert on the output, not just the exit code: a timeout-killed child
        // reports status `null`, which would satisfy `not.toBe(0)` on its own.
        expect(res.stderr).toMatch(/known default/i);
        expect(res.stdout).not.toMatch(/listening on port/);
        expect(res.status).not.toBe(0);
      },
      // ts-node compiles the whole app here; this box has hit 45s wall under
      // load, so leave generous headroom over the 20000ms file default.
      180000,
    );
  });
});
