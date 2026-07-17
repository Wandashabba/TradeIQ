import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { prisma } from '../../lib/prisma';

export interface AuthTokenPayload {
  userId: string;
  role: 'field_agent' | 'manager' | 'admin';
  clientId: string;
}

function getSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET is not set');
  }
  return secret;
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
