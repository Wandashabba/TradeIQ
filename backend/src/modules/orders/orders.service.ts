import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

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
}

// Sum of quantity*unitPrice, rounded to 2dp so the stored Float mirrors a
// currency total without binary-fraction drift.
function computeTotal(lines: OrderLineInput[]): number {
  const raw = lines.reduce((sum, line) => sum + line.quantity * line.unitPrice, 0);
  return Math.round(raw * 100) / 100;
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

  // Nested create runs the order + its lines in a single implicit transaction.
  return prisma.order.create({
    data: {
      clientId: input.clientId,
      outletId: input.outletId,
      agentId: input.agentId,
      visitId: input.visitId,
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
}

export interface ListOrdersInput {
  clientId: string;
  // Present only when the caller is a field_agent (scopes to their own orders).
  agentId?: string;
  outletId?: string;
  status?: OrderStatus;
}

export async function listOrders(input: ListOrdersInput) {
  return prisma.order.findMany({
    where: {
      clientId: input.clientId,
      ...(input.agentId ? { agentId: input.agentId } : {}),
      ...(input.outletId ? { outletId: input.outletId } : {}),
      ...(input.status ? { status: input.status } : {}),
    },
    orderBy: { createdAt: 'desc' },
    include: { _count: { select: { lines: true } } },
  });
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
