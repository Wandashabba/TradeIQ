import { NextFunction, Response } from 'express';
import { AuthedRequest } from './auth';

export function requireRole(...allowed: Array<'field_agent' | 'manager' | 'admin'>) {
  return (req: AuthedRequest, res: Response, next: NextFunction): void => {
    if (!req.user || !allowed.includes(req.user.role)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    next();
  };
}
