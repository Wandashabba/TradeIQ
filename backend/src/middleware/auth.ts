import { NextFunction, Request, Response } from 'express';
import { AuthTokenPayload, verifyToken } from '../modules/auth/auth.service';
import { prisma } from '../lib/prisma';

export interface AuthedRequest extends Request {
  user?: AuthTokenPayload;
}

export async function requireAuth(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing bearer token' });
    return;
  }

  let payload: AuthTokenPayload;
  try {
    payload = verifyToken(header.slice('Bearer '.length));
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
    return;
  }

  try {
    // A valid signature proves we minted this token. It proves nothing about
    // whether the person still works here.
    //
    // Tokens last 12h and there is no refresh endpoint, so without this lookup
    // deactivating someone at 09:00 left them working until 21:00 — revocation
    // was a promise the system did not keep. The cost is one indexed primary-key
    // read per request; correctness first, and a short-TTL cache is the obvious
    // optimisation if it ever shows up in profiling.
    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: { active: true, role: true, clientId: true },
    });

    // Every mismatch is the same answer to the client: this token is no longer
    // good. Distinguishing "deactivated" from "demoted" from "deleted" would
    // tell an attacker holding a stale token which of those happened.
    const stillValid =
      user !== null &&
      user.active &&
      user.role === payload.role &&
      // Re-checked because the tenant is the blast radius of every query built
      // from this payload. A token whose clientId no longer matches the user's
      // must not be able to name the old tenant.
      user.clientId === payload.clientId;

    if (!stillValid) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    req.user = payload;
    next();
  } catch (err) {
    // A database failure must not read as a valid session. Hand it to the error
    // handler as a 500 rather than letting the request through unauthenticated.
    next(err);
  }
}
