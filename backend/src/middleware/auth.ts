import { NextFunction, Request, Response } from 'express';
import { AuthTokenPayload, verifyToken } from '../modules/auth/auth.service';

export interface AuthedRequest extends Request {
  user?: AuthTokenPayload;
}

export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing bearer token' });
    return;
  }
  try {
    req.user = verifyToken(header.slice('Bearer '.length));
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}
