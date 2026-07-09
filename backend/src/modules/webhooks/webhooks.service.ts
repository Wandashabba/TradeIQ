import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

export interface CreateWebhookInput {
  clientId: string;
  url: string;
  event: string;
  secret?: string;
}

export async function createWebhook(input: CreateWebhookInput) {
  return prisma.webhook.create({
    data: {
      clientId: input.clientId,
      url: input.url,
      event: input.event,
      secret: input.secret,
    },
  });
}

export async function listWebhooksForClient(clientId: string) {
  return prisma.webhook.findMany({
    where: { clientId },
    orderBy: { createdAt: 'desc' },
  });
}

export async function findWebhookForClient(id: string, clientId: string) {
  const webhook = await prisma.webhook.findFirst({ where: { id, clientId } });
  if (!webhook) {
    throw new NotFoundError('Webhook not found');
  }
  return webhook;
}

export interface UpdateWebhookInput {
  active?: boolean;
  url?: string;
  event?: string;
}

export async function updateWebhook(id: string, input: UpdateWebhookInput) {
  // Prisma treats undefined fields as "leave unchanged".
  return prisma.webhook.update({
    where: { id },
    data: {
      active: input.active,
      url: input.url,
      event: input.event,
    },
  });
}

export async function deleteWebhook(id: string): Promise<void> {
  await prisma.webhook.delete({ where: { id } });
}

/**
 * Best-effort fan-out of a domain event to every ACTIVE webhook the client has
 * registered for that `event`. Each endpoint is POSTed a JSON body of
 * `{ event, payload, timestamp }` via the global `fetch` (Node 24). Every call
 * is wrapped in its own try/catch and awaited through `Promise.allSettled`, so
 * a slow or failing subscriber can never throw back into the caller — this is
 * fire-and-forget delivery with no retry/queue (a hardened version is a
 * follow-up).
 *
 * @remarks A hardened implementation would use each webhook's `secret` to sign
 * the body (e.g. an HMAC-SHA256 `X-Signature` header) so subscribers can verify
 * authenticity. That signing is intentionally omitted here.
 *
 * Wiring this into the visit.submitted / order.created / alert.raised events is
 * a follow-up: those modules are not touched by this change.
 */
export async function dispatchWebhookEvent(
  clientId: string,
  event: string,
  payload: unknown,
): Promise<void> {
  const webhooks = await prisma.webhook.findMany({
    where: { clientId, event, active: true },
  });

  const body = JSON.stringify({ event, payload, timestamp: new Date().toISOString() });

  await Promise.allSettled(
    webhooks.map(async (webhook) => {
      try {
        await fetch(webhook.url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body,
        });
      } catch {
        // Best-effort: a failing subscriber must never break the caller.
      }
    }),
  );
}
