import { NextFunction, Request, Response } from 'express';

export class NotImplementedError extends Error {}
export class GeofenceRejectedError extends Error {}
export class NotFoundError extends Error {}
// Malformed/invalid request input caught by a service layer (as opposed to
// the shape-level checks routes do before ever calling a service) — e.g. a
// business-rule cross-item constraint like "no duplicate skuId" (#121).
export class ValidationError extends Error {}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof NotImplementedError) {
    res.status(501).json({ error: err.message });
    return;
  }
  if (err instanceof GeofenceRejectedError) {
    res.status(422).json({ error: err.message });
    return;
  }
  if (err instanceof NotFoundError) {
    res.status(404).json({ error: err.message });
    return;
  }
  if (err instanceof ValidationError) {
    res.status(400).json({ error: err.message });
    return;
  }
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
}
