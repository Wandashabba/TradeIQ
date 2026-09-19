import { NextFunction, Request, Response } from 'express';

export class NotImplementedError extends Error {}
export class GeofenceRejectedError extends Error {}
export class NotFoundError extends Error {}
// Malformed/invalid request input caught by a service layer (as opposed to
// the shape-level checks routes do before ever calling a service) — e.g. a
// business-rule cross-item constraint like "no duplicate skuId" (#121).
export class ValidationError extends Error {}
// The request is well-formed but collides with existing state — e.g. a photo
// that is already attached to another message (#125).
export class ConflictError extends Error {}
// The request is well-formed and permitted, but the caller has done it too
// often — e.g. an agent opening more pin disputes in one day than the policy
// allows (#386 follow-up). 429, not 403: nothing about this actor is forbidden,
// they have simply spent the allowance, and the message says what and when.
export class TooManyRequestsError extends Error {}

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
  if (err instanceof ConflictError) {
    res.status(409).json({ error: err.message });
    return;
  }
  if (err instanceof TooManyRequestsError) {
    res.status(429).json({ error: err.message });
    return;
  }
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
}
