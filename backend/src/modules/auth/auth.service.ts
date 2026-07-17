import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { prisma } from '../../lib/prisma';

export interface AuthTokenPayload {
  userId: string;
  // Derived from ROLES so the runtime guard and the compile-time type cannot
  // drift apart in either direction: a role the array lacks is not assignable,
  // and a role the array gains is automatically accepted by the type.
  role: (typeof ROLES)[number];
  clientId: string;
}

// Every entry here is already shorter than MIN_SECRET_LENGTH, so the length
// floor below would reject it anyway. The list exists to name the mistake
// precisely ("you shipped the repo's placeholder") instead of emitting a
// generic length error — and to catch any future default that IS long enough.
const KNOWN_DEFAULT_SECRETS = new Set([
  'dev-only-change-me',
  'change-me',
  'changeme',
  'secret',
  'ci-test-secret',
]);
const MIN_SECRET_LENGTH = 32;

// Fail SAFE: only an explicit dev/test declaration relaxes the check. An unset
// NODE_ENV — the likeliest production misconfiguration — is treated as prod.
function secretChecksRelaxed(): boolean {
  const env = process.env.NODE_ENV;
  return env === 'development' || env === 'test';
}

function getSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET is not set');
  }
  if (!secretChecksRelaxed()) {
    if (KNOWN_DEFAULT_SECRETS.has(secret)) {
      throw new Error(
        'JWT_SECRET is a known default published in this repository. Set a unique, random secret (32+ chars).',
      );
    }
    if (secret.length < MIN_SECRET_LENGTH) {
      throw new Error(`JWT_SECRET must be at least ${MIN_SECRET_LENGTH} characters.`);
    }
  }
  return secret;
}

/**
 * Validates the JWT secret at startup so a misconfigured deploy dies loudly.
 *
 * `getSecret()` is otherwise only reached lazily from issueToken/verifyToken,
 * which meant a bad secret let the process boot, serve /health, and then fail
 * every login with a 500 and every authed request with a 401 — with the reason
 * swallowed by requireAuth's catch. A bad secret should stop the process, not
 * produce a healthy-looking service that cannot authenticate anyone.
 */
export function assertJwtSecretUsable(): void {
  getSecret();
}

export function issueToken(payload: AuthTokenPayload): string {
  return jwt.sign(payload, getSecret(), { expiresIn: '12h' });
}

const ROLES = ['field_agent', 'manager', 'admin'] as const;

// `jwt.verify` proves the token was signed by us. It proves NOTHING about the
// payload's shape — the old `as AuthTokenPayload` cast simply asserted it.
// That mattered because Prisma DROPS `undefined` filters from a `where`
// clause: a signed token without `clientId` turned `where: { clientId }` into
// "return every tenant's rows". So we parse, never cast.
function parseTokenPayload(decoded: unknown): AuthTokenPayload {
  if (typeof decoded !== 'object' || decoded === null) {
    throw new Error('Malformed token payload');
  }
  const { userId, role, clientId } = decoded as Record<string, unknown>;
  if (
    typeof userId !== 'string' ||
    userId.length === 0 ||
    typeof clientId !== 'string' ||
    clientId.length === 0 ||
    typeof role !== 'string' ||
    !(ROLES as readonly string[]).includes(role)
  ) {
    throw new Error('Malformed token payload');
  }
  return { userId, clientId, role: role as AuthTokenPayload['role'] };
}

export function verifyToken(token: string): AuthTokenPayload {
  return parseTokenPayload(jwt.verify(token, getSecret()));
}

export async function hashPassword(plain: string): Promise<string> {
  return bcrypt.hash(plain, 10);
}

export async function comparePassword(plain: string, hash: string): Promise<boolean> {
  return bcrypt.compare(plain, hash);
}

// A bcrypt hash of a random string, never a real password. Used so that
// login attempts for unknown emails run a bcrypt comparison of the same
// cost as attempts for known emails, keeping response timing indistinguishable
// and preventing email enumeration via timing side-channels.
const DUMMY_HASH = '$2a$10$CwTycUXWue0Thq9StjUM0uJ8gr5J8Xj3GVj0mLKfsYnZ5ZUq0/UZK';

export async function authenticateUser(email: string, password: string) {
  const user = await prisma.user.findUnique({ where: { email } });
  const passwordValid = await comparePassword(password, user?.passwordHash ?? DUMMY_HASH);
  // Deactivated accounts are rejected as if the credentials were bad — the
  // bcrypt comparison above has already run, so timing stays indistinguishable
  // and we never reveal that the account exists but is disabled.
  if (!user || !passwordValid || !user.active) {
    return null;
  }
  return user;
}
