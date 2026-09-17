import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { dispatchWebhookEvent } from '../webhooks/webhooks.service';
import { buildPage } from '../../lib/pagination';
import { getClientTimeZone } from '../clients/clients.service';
import { campaignRunningAt } from '../campaigns/campaignWindow';
import { captureFallbackLog, resolveCapturedAt } from './captureTime';

export type OrderStatus = 'submitted' | 'confirmed' | 'cancelled';

export const ORDER_STATUSES: readonly OrderStatus[] = ['submitted', 'confirmed', 'cancelled'];

export interface OrderLineInput {
  skuId: string;
  quantity: number;
  unitPrice: number;
}

export interface CreateOrderInput {
  clientId: string;
  agentId: string;
  outletId: string;
  visitId?: string;
  lines: OrderLineInput[];
  /**
   * The DEVICE's capture time (ISO 8601 instant) — when the agent actually
   * took the order, which offline is not when the server hears about it (#338).
   *
   * Deliberately `unknown`: it arrives straight off the request body, and a
   * payload queued by an older build has no such field at all. Everything the
   * value has to survive is `resolveCapturedAt`'s job, and its answer is always
   * a usable instant, so nothing downstream branches on this again.
   */
  capturedAt?: unknown;
}

// Sum of quantity*unitPrice, rounded to 2dp so the stored Float mirrors a
// currency total without binary-fraction drift.
function computeTotal(lines: OrderLineInput[]): number {
  const raw = lines.reduce((sum, line) => sum + line.quantity * line.unitPrice, 0);
  return Math.round(raw * 100) / 100;
}

/**
 * The campaign an order placed now at this outlet belongs to, or null.
 *
 * Attribution happens at creation and is never back-filled: an order placed
 * outside any campaign genuinely belongs to none, and re-attributing later would
 * silently rewrite a campaign's measured return after someone had read it.
 *
 * Only `active` campaigns count. A `draft` campaign has not started spending and
 * a `completed` one is closed for measurement, so neither should acquire new
 * orders — a draft that quietly accumulated revenue would show a return before
 * anyone launched it.
 *
 * ## When more than one campaign matches
 *
 * Overlapping campaigns on one outlet are legitimate (a national promo and a
 * regional push), but `Order.campaignId` is a single column, so the order can
 * only be credited to one. The tie-break is the most recently STARTED campaign,
 * then the highest id — deterministic, so the same order never lands differently
 * on a retry, and biased toward the more specific/newer initiative, which is
 * usually the one being measured.
 *
 * This is a real limitation, not a solved problem: true multi-touch attribution
 * needs an allocation model (split by weight, or an order↔campaign join), and
 * that is a product decision nobody has made. Documented here so a surprising
 * ROI figure is traceable rather than mysterious.
 *
 * ## Which days count
 *
 * A campaign covers `at` when the local calendar date `at` falls on, in the
 * client's `timeZone`, is within `[startDate, endDate]` inclusive (#324) — so an
 * order at 15:00 on the end date counts, and one at 00:30 the next day does not.
 * See `campaignWindow.ts` for how stored dates are read.
 *
 * `at` is the order's CAPTURE time, not the moment the server received it
 * (#338): an order taken in-store on the campaign's last day belongs to that
 * campaign even if the phone only finds signal the following morning.
 */
export async function attributeToCampaign(
  tx: Prisma.TransactionClient,
  clientId: string,
  outletId: string,
  at: Date,
  timeZone: string,
): Promise<string | null> {
  const campaign = await tx.campaign.findFirst({
    where: {
      clientId,
      status: 'active',
      ...campaignRunningAt(at, timeZone),
      outlets: { some: { outletId } },
    },
    orderBy: [{ startDate: 'desc' }, { id: 'desc' }],
    select: { id: true },
  });
  return campaign?.id ?? null;
}

export async function createOrder(input: CreateOrderInput) {
  const outlet = await prisma.outlet.findFirst({
    where: { id: input.outletId, clientId: input.clientId },
    select: { id: true },
  });
  if (!outlet) {
    throw new NotFoundError('Outlet not found');
  }

  if (input.visitId) {
    const visit = await prisma.visit.findFirst({
      where: { id: input.visitId, clientId: input.clientId },
      select: { id: true },
    });
    if (!visit) {
      throw new NotFoundError('Visit not found');
    }
  }

  const skuIds = input.lines.map((line) => line.skuId);
  const skus = await prisma.sku.findMany({
    where: { id: { in: skuIds }, clientId: input.clientId },
    select: { id: true },
  });
  const validSkuIds = new Set(skus.map((s) => s.id));
  const unknown = skuIds.find((id) => !validSkuIds.has(id));
  if (unknown) {
    throw new NotFoundError(`SKU not found: ${unknown}`);
  }

  // When the agent took this order, not when we heard about it (#338). Read
  // once, so the attribution, the stored column and the clamp's reference
  // "now" are all the same instant.
  const receivedAt = new Date();
  const capture = resolveCapturedAt(input.capturedAt, receivedAt);
  const fallbackLog = captureFallbackLog(capture, {
    clientId: input.clientId,
    agentId: input.agentId,
    raw: input.capturedAt,
  });
  // A device clock we could not believe. Logged rather than rejected — see
  // `captureTime.ts` — so a fleet drifting out of time is visible.
  if (fallbackLog) console.warn(fallbackLog);

  // Campaign attribution and the write share one transaction, so an order can
  // never exist with an attribution decided against a campaign that changed
  // underneath it. The zone is read first: which local day the order falls on
  // does not depend on the campaign rows the transaction guards.
  //
  // Attribution runs against the CAPTURE time, so an order taken on a
  // campaign's last day still belongs to that campaign when it syncs the
  // morning after it ended (#324).
  const timeZone = await getClientTimeZone(input.clientId);
  const campaignId = await prisma.$transaction((tx) =>
    attributeToCampaign(tx, input.clientId, input.outletId, capture.capturedAt, timeZone),
  );

  // Nested create runs the order + its lines in a single implicit transaction.
  const order = await prisma.order.create({
    data: {
      clientId: input.clientId,
      outletId: input.outletId,
      agentId: input.agentId,
      visitId: input.visitId,
      campaignId,
      capturedAt: capture.capturedAt,
      status: 'submitted',
      total: computeTotal(input.lines),
      lines: {
        create: input.lines.map((line) => ({
          skuId: line.skuId,
          quantity: line.quantity,
          unitPrice: line.unitPrice,
        })),
      },
    },
    include: { lines: true },
  });

  // Issue #38: fire best-effort to any webhooks the client has subscribed to
  // this event. dispatchWebhookEvent never throws (swallows delivery errors),
  // so awaiting is safe and avoids open-handle warnings.
  await dispatchWebhookEvent(order.clientId, 'order.created', {
    orderId: order.id,
    outletId: order.outletId,
    total: order.total,
  });

  return order;
}

export interface ListOrdersInput {
  clientId: string;
  // Present only when the caller is a field_agent (scopes to their own orders).
  agentId?: string;
  outletId?: string;
  status?: OrderStatus;
  limit: number;
  cursor?: string;
}

export async function listOrders(input: ListOrdersInput) {
  const rows = await prisma.order.findMany({
    where: {
      clientId: input.clientId,
      ...(input.agentId ? { agentId: input.agentId } : {}),
      ...(input.outletId ? { outletId: input.outletId } : {}),
      ...(input.status ? { status: input.status } : {}),
    },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two orders share a createdAt — same reasoning as alerts.service.ts.
    //
    // Deliberately still `createdAt`, not `capturedAt` (#338). This is the
    // paging order, and a cursor only works over a sequence that does not
    // reshuffle underneath it: `createdAt` only ever grows, so a new order
    // lands at the front and the pages behind the cursor are untouched. An
    // order captured offline days ago and synced now would insert itself into
    // the MIDDLE of a `capturedAt` ordering — a page the reader has already
    // scrolled past — so they would never see it. The list is "orders as they
    // arrived", which is also what the reader of a live list wants; dating an
    // order for measurement is a different question, answered by `capturedAt`.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
    include: { _count: { select: { lines: true } } },
  });
  return buildPage(rows, input.limit);
}

export async function getOrderForClient(orderId: string, clientId: string, agentId?: string) {
  const order = await prisma.order.findFirst({
    where: {
      id: orderId,
      clientId,
      ...(agentId ? { agentId } : {}),
    },
    include: { lines: true },
  });
  if (!order) {
    throw new NotFoundError('Order not found');
  }
  return order;
}

export async function updateOrderStatus(orderId: string, clientId: string, status: OrderStatus) {
  const order = await prisma.order.findFirst({
    where: { id: orderId, clientId },
    select: { id: true },
  });
  if (!order) {
    throw new NotFoundError('Order not found');
  }
  return prisma.order.update({
    where: { id: order.id },
    data: { status },
    include: { lines: true },
  });
}
