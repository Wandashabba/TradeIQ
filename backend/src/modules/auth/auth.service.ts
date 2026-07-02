import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';

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
