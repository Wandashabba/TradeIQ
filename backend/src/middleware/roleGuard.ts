import { NextFunction, Response } from 'express';
import type { Role } from '../modules/auth/auth.service';
import { AuthedRequest } from './auth';

// `Role` rather than a restated literal union. That restatement used to be the
// only thing catching a role ADDED to ROLES but not to Prisma — an accident,
// not a design, and one that made this exact cleanup dangerous. The mutual
// assignability assertion in auth.service.ts now guards that direction
// deliberately, so sharing the type here loses nothing.
export function requireRole(...allowed: Role[]) {
  return (req: AuthedRequest, res: Response, next: NextFunction): void => {
    if (!req.user || !allowed.includes(req.user.role)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    next();
  };
}
