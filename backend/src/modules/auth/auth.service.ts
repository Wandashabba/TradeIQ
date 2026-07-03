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

export function verifyToken(token: string): AuthTokenPayload {
  return jwt.verify(token, getSecret()) as AuthTokenPayload;
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
  if (!user || !passwordValid) {
    return null;
  }
  return user;
}
