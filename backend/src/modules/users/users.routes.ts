import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import { DISPLAY_NAME_MAX_LENGTH, parseDisplayName } from '../../lib/personName';
import { createUser, listUsersForClient, Role, updateUser } from './users.service';

const ROLES = ['field_agent', 'manager', 'admin'] as const;

function isRole(value: unknown): value is Role {
  return typeof value === 'string' && (ROLES as readonly string[]).includes(value);
}

export const usersRouter = Router();
usersRouter.use(requireAuth);

usersRouter.post('/', requireRole('admin'), async (req: AuthedRequest, res) => {
  const { email, password, role, displayName } = req.body as {
    email?: unknown;
    password?: unknown;
    role?: unknown;
    displayName?: unknown;
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

  const name = parseDisplayName(displayName);
  if (!name.ok) {
    res
      .status(400)
      .json({ error: `displayName must be a string of at most ${DISPLAY_NAME_MAX_LENGTH} characters` });
    return;
  }

  try {
    const user = await createUser({
      clientId: req.user!.clientId,
      email,
      password,
      role,
      displayName: name.value ?? null,
    });
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
  const { limit, cursor } = parsePagination(req);
  const page = await listUsersForClient({ clientId: req.user!.clientId, limit, cursor });
  res.status(200).json(page);
});

usersRouter.patch('/:id', requireRole('admin'), async (req: AuthedRequest, res) => {
  const { active, role, displayName } = req.body as {
    active?: unknown;
    role?: unknown;
    displayName?: unknown;
  };

  const activeValid = active === undefined || typeof active === 'boolean';
  const roleValid = role === undefined || isRole(role);
  const name = parseDisplayName(displayName);
  const nothingToUpdate = active === undefined && role === undefined && displayName === undefined;
  if (nothingToUpdate || !activeValid || !roleValid || !name.ok) {
    res.status(400).json({
      error:
        'Provide active (boolean), role (valid role) and/or displayName ' +
        `(string of at most ${DISPLAY_NAME_MAX_LENGTH} characters, or null to clear) to update`,
    });
    return;
  }

  const { id } = req.params as { id: string };

  const user = await updateUser({
    id,
    clientId: req.user!.clientId,
    active: active as boolean | undefined,
    role: role as Role | undefined,
    displayName: name.value,
  });
  res.status(200).json(user);
});
