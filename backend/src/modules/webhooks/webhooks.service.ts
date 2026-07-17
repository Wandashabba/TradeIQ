import { createHmac } from 'node:crypto';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { assertPublicHostname } from '../../lib/urlGuard';

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
 * Signs a webhook body with the subscriber's shared secret (#38).
 *
 * Without this, an endpoint receiving `{"event":"alert.raised",...}` has no way
 * to tell TradeIQ apart from anyone who has guessed the URL — and these payloads
 * drive downstream ERP and ordering systems. The scheme is the industry-standard
 * one (Stripe/GitHub): HMAC-SHA256 over the exact bytes we send.
 *
 * The timestamp is signed alongside the body (`<timestamp>.<body>`), not just
 * beside it, so a captured payload cannot be replayed later with a fresh
 * timestamp. Subscribers should reject a signature whose `t` is far from now.
 */
export function signWebhookBody(secret: string, timestamp: string, body: string): string {
  return createHmac('sha256', secret).update(`${timestamp}.${body}`).digest('hex');
}

/**
 * Best-effort fan-out of a domain event to every ACTIVE webhook the client has
 * registered for that `event`. Each endpoint is POSTed a JSON body of
 * `{ event, payload, timestamp }` via the global `fetch` (Node 24). Every call
 * is wrapped in its own try/catch and awaited through `Promise.allSettled`, so
 * a slow or failing subscriber can never throw back into the caller.
 *
 * Delivery is signed but still fire-and-forget: there is **no retry and no
 * queue**, so a subscriber that is down when the event fires simply misses it.
 * A durable outbox is Phase 4 (#62).
 */
export async function dispatchWebhookEvent(
  clientId: string,
  event: string,
  payload: unknown,
): Promise<void> {
  const webhooks = await prisma.webhook.findMany({
    where: { clientId, event, active: true },
  });

  const timestamp = new Date().toISOString();
  const body = JSON.stringify({ event, payload, timestamp });

  await Promise.allSettled(
    webhooks.map(async (webhook) => {
      try {
        const headers: Record<string, string> = {
          'Content-Type': 'application/json',
          'X-TradeIQ-Event': event,
          'X-TradeIQ-Timestamp': timestamp,
        };

        // A webhook registered without a secret still fires — it just cannot be
        // verified. We do not silently invent one, because a subscriber holding
        // a secret we never told them about would reject every delivery.
        if (webhook.secret) {
          headers['X-TradeIQ-Signature'] =
            `sha256=${signWebhookBody(webhook.secret, timestamp, body)}`;
        }

        // Re-resolve here because DNS can change between registration and fire —
        // a host that was public when registered can point at 169.254.169.254 by
        // now.
        //
        // This does NOT close DNS rebinding: this lookup and fetch's own lookup
        // are two separate resolutions, so an attacker with TTL=0 DNS can flip
        // the answer between them. Closing that needs the address validated at
        // connect time (undici Agent + connect.lookup) — tracked for Plan 2.
        //
        // `redirect: 'manual'` matters too: Node follows redirects by default,
        // so a 302 to the metadata service would walk straight through a
        // hostname check.
        await assertPublicHostname(new URL(webhook.url).hostname);
        await fetch(webhook.url, {
          method: 'POST',
          headers,
          body,
          redirect: 'manual',
          // Without this, undici waits ~300s for headers. Visit submit awaits
          // this dispatch, so one hung subscriber held a field agent's submit
          // open for five minutes (audit H7).
          signal: AbortSignal.timeout(5000),
        });
      } catch {
        // Best-effort: a failing subscriber must never break the caller.
      }
    }),
  );
}
