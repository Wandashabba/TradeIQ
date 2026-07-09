import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  createOrder,
  getOrderForClient,
  listOrders,
  ORDER_STATUSES,
  OrderLineInput,
  OrderStatus,
  updateOrderStatus,
} from './orders.service';

export const ordersRouter = Router();
ordersRouter.use(requireAuth);

function isValidStatus(value: unknown): value is OrderStatus {
  return typeof value === 'string' && (ORDER_STATUSES as readonly string[]).includes(value);
}

function isValidLine(line: unknown): line is OrderLineInput {
  if (typeof line !== 'object' || line === null) return false;
  const l = line as Record<string, unknown>;
  return (
    typeof l.skuId === 'string' &&
    typeof l.quantity === 'number' &&
    Number.isInteger(l.quantity) &&
    l.quantity > 0 &&
    typeof l.unitPrice === 'number' &&
    l.unitPrice >= 0
  );
}

ordersRouter.post('/', requireRole('field_agent', 'manager'), async (req: AuthedRequest, res) => {
  const { outletId, visitId, lines } = req.body as {
    outletId?: unknown;
    visitId?: unknown;
    lines?: unknown;
  };

  if (
    typeof outletId !== 'string' ||
    (visitId !== undefined && typeof visitId !== 'string') ||
    !Array.isArray(lines) ||
    lines.length === 0 ||
    !lines.every(isValidLine)
  ) {
    res.status(400).json({
      error:
        'outletId and a non-empty lines[] of { skuId, quantity (int>0), unitPrice (number>=0) } are required; visitId must be a string when given',
    });
    return;
  }

  const order = await createOrder({
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
    outletId,
    visitId,
    lines,
  });
  res.status(201).json(order);
});

ordersRouter.get('/', async (req: AuthedRequest, res) => {
  const { outletId, status } = req.query as { outletId?: unknown; status?: unknown };

  if (
    (outletId !== undefined && typeof outletId !== 'string') ||
    (status !== undefined && !isValidStatus(status))
  ) {
    res.status(400).json({
      error: 'status must be submitted|confirmed|cancelled and outletId must be a string',
    });
    return;
  }

  // Field agents see only their own orders; managers/admins see the whole client.
  const agentId = req.user!.role === 'field_agent' ? req.user!.userId : undefined;

  const orders = await listOrders({
    clientId: req.user!.clientId,
    agentId,
    outletId: outletId as string | undefined,
    status: status as OrderStatus | undefined,
  });
  res.status(200).json(orders);
});

ordersRouter.get('/:id', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const agentId = req.user!.role === 'field_agent' ? req.user!.userId : undefined;

  const order = await getOrderForClient(id, req.user!.clientId, agentId);
  res.status(200).json(order);
});

ordersRouter.patch('/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { status } = req.body as { status?: unknown };

  if (!isValidStatus(status)) {
    res.status(400).json({ error: 'status must be submitted|confirmed|cancelled' });
    return;
  }

  const { id } = req.params as { id: string };
  const order = await updateOrderStatus(id, req.user!.clientId, status);
  res.status(200).json(order);
});
