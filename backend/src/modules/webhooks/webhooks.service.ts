import { createHmac } from 'node:crypto';
// undici's fetch rather than the global: the global ignores `dispatcher`, so
// the guarded agent would be silently dropped and rebinding would stay open
// while the code read as though it were closed.
import { fetch } from 'undici';
import { Prisma, Webhook, WebhookDeliveryStatus } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { ssrfSafeAgent } from '../../lib/ssrfAgent';
import { assertPublicHostname } from '../../lib/urlGuard';
import { buildPage } from '../../lib/pagination';

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

export interface ListWebhooksForClientInput {
  clientId: string;
  limit: number;
  cursor?: string;
}

export type WebhookHealth = 'healthy' | 'failing' | 'unhealthy';

/**
 * A webhook's health, as the Webhooks screen shows it.
 *
 * - `unhealthy` — at least one delivery has given up since the last success.
 *   A give-up already means ~8.5 hours of failed retries (see
 *   RETRY_DELAYS_MS), so one is enough to say the endpoint is not receiving.
 * - `failing` — nothing has given up, but the latest delivery failed and is
 *   waiting on a retry.
 * - `healthy` — otherwise, including a webhook that has never fired.
 */
export function webhookHealth(
  webhook: Pick<Webhook, 'consecutiveFailures' | 'lastDeliveryStatus'>,
): WebhookHealth {
  if (webhook.consecutiveFailures > 0) return 'unhealthy';
  if (webhook.lastDeliveryStatus === 'failed_retrying') return 'failing';
  return 'healthy';
}

export async function listWebhooksForClient(input: ListWebhooksForClientInput) {
  const rows = await prisma.webhook.findMany({
    where: { clientId: input.clientId },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two webhooks share a createdAt — same reasoning as alerts.service.ts.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  const page = buildPage(rows, input.limit);
  return {
    ...page,
    data: page.data.map((webhook) => ({ ...webhook, health: webhookHealth(webhook) })),
  };
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
  // Deliveries cascade with the webhook (onDelete: Cascade).
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

// ── Delivery (#100) ─────────────────────────────────────────────────────────

/**
 * The wait before each retry: attempt 2 comes 1m after attempt 1, attempt 3 5m
 * after attempt 2, and so on. Roughly ×5 each step, capped at 6h, so a blip
 * recovers within a minute while a subscriber that is down for a deploy or a
 * night still receives the event — about 8.5 hours of cover in total — without
 * us hammering an endpoint that is plainly down.
 */
export const RETRY_DELAYS_MS: readonly number[] = [
  60_000, // 1m
  5 * 60_000, // 5m
  25 * 60_000, // 25m
  2 * 60 * 60_000, // 2h
  6 * 60 * 60_000, // 6h
];

/** One first attempt plus one per retry delay; the last failure gives up. */
export const MAX_ATTEMPTS = RETRY_DELAYS_MS.length + 1;

/**
 * Per-attempt fetch timeout. Without one, undici waits ~300s for headers, and
 * one hung subscriber held a field agent's submit open for five minutes (audit
 * H7). Delivery no longer blocks the caller, but it still ties up a processor.
 */
export const DELIVERY_TIMEOUT_MS = 5000;

/**
 * How long a claimed row is hidden from other processors. It must comfortably
 * exceed an attempt (DNS pre-check + DELIVERY_TIMEOUT_MS + two writes). If a
 * process dies mid-attempt, the row simply becomes due again when this runs
 * out — which is what makes a crash lose nothing.
 */
export const CLAIM_LEASE_MS = 2 * 60_000;

/** Keep `lastError` a diagnostic, not a copy of someone's 5MB error page. */
const MAX_ERROR_LENGTH = 500;

/** Statuses a processor may still attempt. */
const ATTEMPTABLE: WebhookDeliveryStatus[] = ['pending', 'failed_retrying'];

/**
 * Attempts started in this process and not yet finished. Tracked so tests (and
 * a graceful shutdown) can wait for fire-and-forget work instead of racing it.
 */
const inFlight = new Set<Promise<void>>();

function track(work: Promise<void>): void {
  inFlight.add(work);
  void work.finally(() => inFlight.delete(work));
}

/** Resolves once every attempt started in this process has finished. */
export async function settleInFlightDeliveries(): Promise<void> {
  while (inFlight.size > 0) {
    await Promise.allSettled([...inFlight]);
  }
}

function truncate(message: string): string {
  return message.length > MAX_ERROR_LENGTH ? `${message.slice(0, MAX_ERROR_LENGTH - 1)}…` : message;
}

/** The delay before the retry that follows attempt number `attempt` (1-based). */
export function retryDelayAfter(attempt: number): number {
  return RETRY_DELAYS_MS[Math.min(attempt, RETRY_DELAYS_MS.length) - 1];
}

/**
 * Records a domain event for every ACTIVE webhook the client has registered
 * for `event`, then starts the first attempt of each in the background.
 *
 * What the caller awaits is only the insert of the delivery rows — durable, and
 * quick — never the HTTP call to a subscriber. A slow or failing subscriber
 * therefore cannot hold up a visit submit, and a failed attempt is retried on
 * the backoff schedule by the delivery worker rather than being lost.
 *
 * Still never throws: a database hiccup here must not fail a visit that has
 * already been persisted. The cost of that choice is that an event can be lost
 * if the insert itself fails — a transactional outbox written in the same
 * transaction as the domain row is the durable-streaming work of #62.
 */
export async function dispatchWebhookEvent(
  clientId: string,
  event: string,
  payload: unknown,
): Promise<void> {
  try {
    const webhooks = await prisma.webhook.findMany({
      where: { clientId, event, active: true },
      select: { id: true },
    });
    if (webhooks.length === 0) return;

    // The body envelope is stored once and re-sent byte-for-byte on every
    // attempt. Its `timestamp` is when the event happened; the signed
    // X-TradeIQ-Timestamp header is when each attempt was made, so a retry
    // hours later still passes a subscriber's replay window.
    const envelope = {
      event,
      payload,
      timestamp: new Date().toISOString(),
    } as Prisma.InputJsonValue;
    // Created already leased: this process attempts them right now, and the
    // worker only picks one up if that attempt never finishes.
    const leaseUntil = new Date(Date.now() + CLAIM_LEASE_MS);

    const deliveries = await prisma.webhookDelivery.createManyAndReturn({
      data: webhooks.map((webhook) => ({
        webhookId: webhook.id,
        clientId,
        event,
        payload: envelope,
        status: 'pending' as const,
        nextAttemptAt: leaseUntil,
      })),
      select: { id: true },
    });

    for (const delivery of deliveries) {
      track(attemptDelivery(delivery.id));
    }
  } catch (err) {
    console.error(`Webhook dispatch for ${event} failed:`, err);
  }
}

type AttemptOutcome =
  | { ok: true; statusCode: number }
  | { ok: false; statusCode: number | null; error: string };

/** One HTTP POST. Never throws — every failure becomes an outcome. */
async function sendOnce(
  webhook: Pick<Webhook, 'url' | 'secret'>,
  deliveryId: string,
  attempt: number,
  event: string,
  body: string,
): Promise<AttemptOutcome> {
  const timestamp = new Date().toISOString();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'X-TradeIQ-Event': event,
    'X-TradeIQ-Timestamp': timestamp,
    // The same id on every attempt, so a receiver that got an attempt whose
    // response we never saw can recognise the retry and skip it.
    'X-TradeIQ-Delivery': deliveryId,
    'X-TradeIQ-Delivery-Attempt': String(attempt),
  };

  // A webhook registered without a secret still fires — it just cannot be
  // verified. We do not silently invent one, because a subscriber holding a
  // secret we never told them about would reject every delivery. Re-signed on
  // every attempt, because the signed timestamp is the attempt's own.
  if (webhook.secret) {
    headers['X-TradeIQ-Signature'] = `sha256=${signWebhookBody(webhook.secret, timestamp, body)}`;
  }

  try {
    // Re-resolve here because DNS can change between registration and fire —
    // a host that was public when registered can point at 169.254.169.254 by
    // now.
    //
    // Rebinding is closed by `ssrfSafeAgent`, not by this call: it validates
    // the address inside the connector, so the socket cannot be handed an
    // address that was never checked. This pre-check is still worth keeping —
    // it fails a bad host before a connection is attempted, and gives a
    // clearer error than a refused socket.
    //
    // `redirect: 'manual'` matters too: Node follows redirects by default, so a
    // 302 to the metadata service would walk straight through a hostname
    // check. A 3xx is therefore a failed delivery, not a success.
    await assertPublicHostname(new URL(webhook.url).hostname);
    const response = await fetch(webhook.url, {
      method: 'POST',
      headers,
      body,
      redirect: 'manual',
      // undici's fetch, so the guarded dispatcher is actually honoured.
      dispatcher: ssrfSafeAgent,
      signal: AbortSignal.timeout(DELIVERY_TIMEOUT_MS),
    });
    // We never read the response; release the connection rather than leave
    // the body buffered.
    await response.body?.cancel().catch(() => undefined);

    if (response.status >= 200 && response.status < 300) {
      return { ok: true, statusCode: response.status };
    }
    return {
      ok: false,
      statusCode: response.status,
      error: `HTTP ${response.status}`,
    };
  } catch (err) {
    return {
      ok: false,
      statusCode: null,
      error: truncate(err instanceof Error ? err.message : String(err)),
    };
  }
}

/**
 * Makes one attempt at a delivery and records the outcome.
 *
 * The caller must hold the row's lease (a fresh dispatch, a worker claim, or a
 * redeliver). Recording is guarded on `attempts` still being what this attempt
 * read: if two processors ever did overlap on a row, only the first write
 * lands, so the attempt count and the webhook's health cannot be applied twice.
 * Never throws — a failure to record leaves the lease to run out, and the row
 * is simply attempted again.
 */
export async function attemptDelivery(deliveryId: string, now: () => Date = () => new Date()): Promise<void> {
  try {
    const delivery = await prisma.webhookDelivery.findUnique({
      where: { id: deliveryId },
      include: { webhook: true },
    });
    if (!delivery || !ATTEMPTABLE.includes(delivery.status)) return;

    if (!delivery.webhook.active) {
      // Paused since the event fired. Stop quietly: pausing is a deliberate
      // choice, not a failing endpoint, so it does not count against health.
      await prisma.webhookDelivery.updateMany({
        where: { id: delivery.id, attempts: delivery.attempts },
        data: { status: 'gave_up', nextAttemptAt: null, lastError: 'Webhook paused' },
      });
      return;
    }

    const attempt = delivery.attempts + 1;
    const outcome = await sendOnce(
      delivery.webhook,
      delivery.id,
      attempt,
      delivery.event,
      JSON.stringify(delivery.payload),
    );
    const at = now();

    await prisma.$transaction(async (tx) => {
      let status: WebhookDeliveryStatus;
      let data: Prisma.WebhookDeliveryUpdateManyMutationInput;
      if (outcome.ok) {
        status = 'succeeded';
        data = {
          status,
          attempts: attempt,
          lastStatusCode: outcome.statusCode,
          lastError: null,
          nextAttemptAt: null,
          lastAttemptAt: at,
          deliveredAt: at,
        };
      } else {
        status = attempt >= MAX_ATTEMPTS ? 'gave_up' : 'failed_retrying';
        data = {
          status,
          attempts: attempt,
          lastStatusCode: outcome.statusCode,
          lastError: outcome.error,
          nextAttemptAt:
            status === 'gave_up' ? null : new Date(at.getTime() + retryDelayAfter(attempt)),
          lastAttemptAt: at,
        };
      }

      const recorded = await tx.webhookDelivery.updateMany({
        where: { id: delivery.id, attempts: delivery.attempts },
        data,
      });
      if (recorded.count === 0) return; // another processor recorded first

      await tx.webhook.update({
        where: { id: delivery.webhookId },
        data: {
          lastDeliveryStatus: status,
          lastDeliveryAt: at,
          ...(status === 'succeeded'
            ? { consecutiveFailures: 0 }
            : status === 'gave_up'
              ? { consecutiveFailures: { increment: 1 } }
              : {}),
        },
      });
    });
  } catch (err) {
    console.error(`Webhook delivery ${deliveryId} could not be attempted:`, err);
  }
}

/**
 * Atomically claims up to `limit` due deliveries and pushes each one's
 * `nextAttemptAt` out by the lease, returning their ids.
 *
 * `FOR UPDATE SKIP LOCKED` is what makes this safe with more than one backend
 * instance: two concurrent claims lock disjoint rows instead of both reading
 * the same due row, and the lease written in the same statement hides the row
 * from every later claim until the attempt has had time to finish.
 */
export async function claimDueDeliveries(now: Date, limit: number): Promise<string[]> {
  // Timestamps are sent as ISO text and cast to `timestamp`: the columns are
  // `timestamp without time zone` holding UTC, and the cast drops the `Z`
  // rather than converting through the session time zone.
  const rows = await prisma.$queryRaw<Array<{ id: string }>>`
    UPDATE "webhook_deliveries"
    SET "next_attempt_at" = ${new Date(now.getTime() + CLAIM_LEASE_MS).toISOString()}::timestamp
    WHERE "id" IN (
      SELECT "id" FROM "webhook_deliveries"
      WHERE "status" IN ('pending', 'failed_retrying')
        AND "next_attempt_at" <= ${now.toISOString()}::timestamp
      ORDER BY "next_attempt_at"
      LIMIT ${limit}
      FOR UPDATE SKIP LOCKED
    )
    RETURNING "id"
  `;
  return rows.map((row) => row.id);
}

/** Claims a batch of due deliveries and attempts each. Returns how many. */
export async function processDueDeliveries(
  now: Date = new Date(),
  limit = 20,
): Promise<number> {
  const ids = await claimDueDeliveries(now, limit);
  await Promise.all(ids.map((id) => attemptDelivery(id)));
  return ids.length;
}

export interface ListDeliveriesInput {
  webhookId: string;
  limit: number;
  cursor?: string;
}

export async function listDeliveriesForWebhook(input: ListDeliveriesInput) {
  const rows = await prisma.webhookDelivery.findMany({
    where: { webhookId: input.webhookId },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
}

export class DeliveryNotRedeliverableError extends Error {}

/**
 * Re-queues a delivery that gave up or is waiting on a retry, and attempts it
 * now. Throws NotFoundError for another tenant's delivery, and
 * DeliveryNotRedeliverableError for one that succeeded or is already queued.
 *
 * The attempt count is kept, not reset, so it stays a truthful total. A
 * redelivered give-up that fails again therefore gives up again straight away:
 * a manual redeliver is one more try, not a fresh eight-hour schedule.
 */
export async function redeliver(id: string, clientId: string) {
  const delivery = await prisma.webhookDelivery.findFirst({ where: { id, clientId } });
  if (!delivery) {
    throw new NotFoundError('Delivery not found');
  }

  const claimed = await prisma.webhookDelivery.updateMany({
    where: { id, clientId, status: { in: ['gave_up', 'failed_retrying'] } },
    data: {
      status: 'pending',
      nextAttemptAt: new Date(Date.now() + CLAIM_LEASE_MS),
    },
  });
  if (claimed.count === 0) {
    throw new DeliveryNotRedeliverableError(
      `Only a failed delivery can be redelivered (this one is ${delivery.status})`,
    );
  }

  track(attemptDelivery(id));
  return prisma.webhookDelivery.findUniqueOrThrow({ where: { id } });
}
