import { spawnSync } from 'child_process';
import * as path from 'path';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { UserRole } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { ROLES, authenticateUser, hashPassword, issueToken, verifyToken } from './auth.service';

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

  describe('role union', () => {
    // The compile-time assertion in auth.service.ts is the real guard; this is
    // its legible twin. A type-level trick that nobody can read is one somebody
    // deletes during a tidy-up — which is exactly how the previous, accidental
    // guard was going to be lost.
    it('matches Prisma UserRole exactly, in both directions', () => {
      expect([...ROLES].sort()).toEqual(Object.values(UserRole).sort());
    });

    it('has no duplicates', () => {
      expect(new Set(ROLES).size).toBe(ROLES.length);
    });
  });
});

/**
 * Login is case- and whitespace-insensitive in the email (#351).
 *
 * Exercised at the service level rather than through POST /auth/login on
 * purpose: the route is IP-rate-limited to 10 attempts per window, so a
 * table of spellings belongs here, where it costs no budget. The route keeps
 * a small end-to-end sample in auth.routes.test.ts.
 */
describe('authenticateUser — email normalisation (#351)', () => {
  const email = 'auth-normalise@example.com';
  const password = 'correct-horse-battery';
  let clientId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'Auth Normalise Client',
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

  it.each([
    ['exactly as stored', 'auth-normalise@example.com'],
    ['capitalised, as an Android keyboard leaves it', 'Auth-normalise@example.com'],
    ['in all caps', 'AUTH-NORMALISE@EXAMPLE.COM'],
    ['with a leading space', '  auth-normalise@example.com'],
    ['with a trailing space', 'auth-normalise@example.com  '],
    ['padded and capitalised at once', '  Auth-Normalise@Example.com  '],
  ])('authenticates when the email is typed %s', async (_label, typed) => {
    const user = await authenticateUser(typed, password);
    expect(user).not.toBeNull();
    // The canonical row, not a second one: the stored spelling is unchanged.
    expect(user!.email).toBe(email);
  });

  it('still rejects a genuinely wrong password, however the email is cased', async () => {
    expect(await authenticateUser('AUTH-NORMALISE@example.com', 'not-the-password')).toBeNull();
  });

  it('still rejects an unknown email', async () => {
    expect(await authenticateUser('nobody-here@example.com', password)).toBeNull();
  });

  // The timing protection must survive the fix. An unknown email has to reach
  // the same bcrypt comparison a known one does, or response time reveals which
  // addresses exist. Normalising BEFORE the lookup is what keeps this true —
  // normalising afterwards would mean an early return on the unknown path.
  it('still runs one bcrypt comparison for an unknown email (timing protection intact)', async () => {
    const compare = jest.spyOn(bcrypt, 'compare');
    try {
      expect(await authenticateUser('  NoSuchUser@Example.com  ', password)).toBeNull();
      expect(compare).toHaveBeenCalledTimes(1);
      // Against a real bcrypt hash (the dummy), so the work is the same cost.
      const hash = compare.mock.calls[0][1] as unknown as string;
      expect(hash).toMatch(/^\$2[aby]\$/);
    } finally {
      compare.mockRestore();
    }
  });

  it('runs exactly the same single comparison for a known email', async () => {
    const compare = jest.spyOn(bcrypt, 'compare');
    try {
      await authenticateUser(email, password);
      expect(compare).toHaveBeenCalledTimes(1);
    } finally {
      compare.mockRestore();
    }
  });
});
