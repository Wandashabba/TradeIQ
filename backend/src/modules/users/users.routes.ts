import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { createUser, listUsersForClient, Role, updateUser } from './users.service';

const ROLES = ['field_agent', 'manager', 'admin'] as const;

function isRole(value: unknown): value is Role {
  return typeof value === 'string' && (ROLES as readonly string[]).includes(value);
}

export const usersRouter = Router();
usersRouter.use(requireAuth);

usersRouter.post('/', requireRole('admin'), async (req: AuthedRequest, res) => {
  const { email, password, role } = req.body as {
    email?: unknown;
    password?: unknown;
    role?: unknown;
  };

  if (
    typeof email !== 'string' ||
    typeof password !== 'string' ||
    password.length < 8 ||
    !isRole(role)
  ) {
    res
      .status(400)
      .json({ error: 'email, password (min 8 chars) and a valid role are required' });
    return;
  }

  try {
    const user = await createUser({ clientId: req.user!.clientId, email, password, role });
    res.status(201).json(user);
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      res.status(409).json({ error: 'A user with this email already exists' });
      return;
    }
    throw err;
  }
});

usersRouter.get('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const users = await listUsersForClient(req.user!.clientId);
  res.status(200).json(users);
});

usersRouter.patch('/:id', requireRole('admin'), async (req: AuthedRequest, res) => {
  const { active, role } = req.body as { active?: unknown; role?: unknown };

  const activeValid = active === undefined || typeof active === 'boolean';
  const roleValid = role === undefined || isRole(role);
  if ((active === undefined && role === undefined) || !activeValid || !roleValid) {
    res.status(400).json({ error: 'Provide active (boolean) and/or role (valid role) to update' });
    return;
  }

  const { id } = req.params as { id: string };

  const user = await updateUser({
    id,
    clientId: req.user!.clientId,
    active: active as boolean | undefined,
    role: role as Role | undefined,
  });
  res.status(200).json(user);
});
