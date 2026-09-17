import type { NextFunction, Response } from 'express';
import { prisma } from '../../lib/prisma';
import type { AuthedRequest } from '../../middleware/auth';

/**
 * Is the conversational assistant switched on for this tenant?
 *
 * Defaults to `false` at the column level, so a client that has never been
 * considered for rollout is off rather than accidentally on.
 */
export async function isAssistantEnabled(clientId: string): Promise<boolean> {
  const client = await prisma.client.findUnique({
    where: { id: clientId },
    select: { assistantEnabled: true },
  });
  return client?.assistantEnabled ?? false;
}

/**
 * May the assistant run live web search for this tenant?
 *
 * Read per turn rather than cached, so an operator switching it off takes
 * effect on the next question. **Fails closed**: a tenant that cannot be read,
 * or a read that throws, gets no search — the assistant still answers from
 * internal data, which is the product; outside context is the extra.
 */
export async function isAssistantWebSearchEnabled(clientId: string): Promise<boolean> {
  try {
    const client = await prisma.client.findUnique({
      where: { id: clientId },
      select: { assistantWebSearchEnabled: true },
    });
    return client?.assistantWebSearchEnabled ?? false;
  } catch (err) {
    console.error('[assistant] could not read the web search switch; search is off for this turn', err);
    return false;
  }
}

/**
 * May the assistant use the outside-context tools (calendar, weather, economy)
 * for this tenant?
 *
 * Same shape as the web search switch: read per turn, and **fails closed** — a
 * read that fails leaves those tools out of the roster for the turn, and the
 * assistant still answers from internal data.
 */
export async function isAssistantExternalContextEnabled(clientId: string): Promise<boolean> {
  try {
    const client = await prisma.client.findUnique({
      where: { id: clientId },
      select: { assistantExternalContextEnabled: true },
    });
    return client?.assistantExternalContextEnabled ?? false;
  } catch (err) {
    console.error('[assistant] could not read the outside-context switch; those tools are off for this turn', err);
    return false;
  }
}

/**
 * Gate every assistant route on the tenant's rollout flag.
 *
 * **Responds 404, not 403.** A 403 concedes that the feature exists and that
 * this tenant is merely not entitled to it, which is an invitation to keep
 * probing. For a flag whose whole job is "this client is not in the rollout",
 * "no such route" is both the honest answer and the quiet one. It also means
 * the kill switch behaves identically to the feature never having shipped.
 *
 * Ordering matters: mount this **after** `requireAuth`, because it reads
 * `req.user.clientId`. An unauthenticated request must fail as unauthenticated
 * rather than leaking whether a flag exists.
 */
export async function requireAssistantEnabled(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    // Defensive: this middleware is meaningless without requireAuth in front of
    // it, and silently allowing the request through would turn a mounting
    // mistake into an open endpoint.
    res.status(401).json({ error: 'Missing bearer token' });
    return;
  }

  try {
    if (!(await isAssistantEnabled(req.user.clientId))) {
      res.status(404).json({ error: 'Not found' });
      return;
    }
    next();
  } catch (err) {
    // A database failure must not read as "enabled". Hand it to the error
    // handler as a 500 rather than defaulting a paid feature open.
    next(err);
  }
}
