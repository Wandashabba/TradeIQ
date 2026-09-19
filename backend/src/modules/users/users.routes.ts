import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { z } from 'zod';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { buildPage, parsePagination } from '../../lib/pagination';
import { DISPLAY_NAME_MAX_LENGTH, parseDisplayName } from '../../lib/personName';
import { checkPassword, PASSWORD_RULE_TEXT } from '../../lib/passwordPolicy';
import {
  changePasswordRateLimiter,
  resetCodeIssueRateLimiter,
} from '../../middleware/rateLimit';
import {
  ForbiddenTargetError,
  issueResetCode,
  listPasswordEvents,
  setPasswordForUser,
} from '../auth/password.service';
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

  if (typeof email !== 'string' || !isRole(role)) {
    res.status(400).json({ error: 'email and a valid role are required' });
    return;
  }

  // One password rule, shared with POST /auth/change-password and
  // POST /auth/reset-password (#400). The inline `password.length < 8` that
  // used to live here was the ONLY rule in the system, because nothing else
  // could set a password at all; now that three doors can, they must agree or
  // an agent is told their new password is unacceptable in one place and given
  // it in another. The reason never echoes what was typed.
  const passwordCheck = checkPassword(password, email);
  if (!passwordCheck.ok) {
    res.status(400).json({ error: passwordCheck.reason });
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
      password: passwordCheck.password,
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

// The zod envelope the other modules use: `{ error, issues }`, one line per
// failed field PATH. Paths and schema messages only — never values, so a
// rejected password cannot reach the wire through the validator either.
function issues(error: z.ZodError) {
  return error.issues.map((i) => `${i.path.join('.') || '<root>'}: ${i.message}`);
}

/**
 * GET /users/password-events — the password audit trail (#400).
 *
 * No `GET /:id` exists on this router, so the literal path cannot be shadowed
 * today. If one is ever added it must be declared AFTER this line, or Express
 * will match `password-events` as a user id.
 *
 * Admin-only and tenant-scoped. A ledger nobody can read is a ledger nobody
 * checks, and "who reset whose password, when" is the first question asked when
 * an account behaves oddly. It cannot leak a secret: the table has no column
 * that could hold one.
 */
usersRouter.get('/password-events', requireRole('admin'), async (req: AuthedRequest, res) => {
  const { limit, cursor } = parsePagination(req);
  const userId = typeof req.query.userId === 'string' ? req.query.userId : undefined;
  const rows = await listPasswordEvents({
    clientId: req.user!.clientId,
    userId,
    limit,
    cursor,
  });
  res.status(200).json(buildPage(rows, limit));
});

const setPasswordBody = z.object({ newPassword: z.string().min(1) }).strict();

/**
 * POST /users/:id/password — an admin, or a manager for a field agent, sets
 * someone's password directly (#400).
 *
 * The in-office move: the agent is at the depot, the manager types a password
 * and hands the phone back. Audited, because someone other than the account
 * holder now knows a password that works.
 *
 * **Role scoping is narrower than the guard.** `requireRole('manager','admin')`
 * only gets you through the door; `staffMaySetPasswordFor` then decides, and a
 * manager may reset field agents and nobody else. A manager who could reset an
 * admin's password could take the tenant, and the existing routes never had to
 * think about that because they have no manager-facing write at all.
 *
 * **Tenant scoping is a 404, not a 403** — the same answer `PATCH /users/:id`
 * gives, so this route cannot be used to discover that a user id exists in some
 * other client.
 *
 * Rate-limited on the acting staff member, sharing the change-password bucket:
 * both are "this identity is setting passwords", and splitting them would let
 * an attacker with one token spend two budgets.
 */
usersRouter.post(
  '/:id/password',
  requireRole('manager', 'admin'),
  changePasswordRateLimiter,
  async (req: AuthedRequest, res) => {
    const parsed = setPasswordBody.safeParse(req.body ?? {});
    if (!parsed.success) {
      res.status(400).json({
        error: `newPassword is required. ${PASSWORD_RULE_TEXT}`,
        issues: issues(parsed.error),
      });
      return;
    }

    const { id } = req.params as { id: string };
    try {
      const result = await setPasswordForUser({
        targetUserId: id,
        clientId: req.user!.clientId,
        actorId: req.user!.userId,
        actorRole: req.user!.role,
        newPassword: parsed.data.newPassword,
      });
      res.status(200).json(result);
    } catch (err) {
      if (err instanceof ForbiddenTargetError) {
        res.status(403).json({ error: err.message });
        return;
      }
      // NotFoundError -> 404 and ValidationError -> 400, through the shared
      // error handler.
      throw err;
    }
  },
);

/**
 * POST /users/:id/password-reset-code — the reset a manager can do in the
 * field (#400).
 *
 * The manager generates a code and reads it out; the agent types it into the
 * app and chooses their own password at `POST /auth/reset-password`. The
 * manager never learns what the agent picked, which is the difference between
 * this and `POST /users/:id/password`.
 *
 * **This response is the only place a code is ever returned, to the one person
 * who asked for it.** It is stored as a bcrypt hash, it is not written to the
 * ledger, it is not logged, and no other endpoint can read it back. Generating
 * a new code retires the previous one, so "try again" leaves exactly one live
 * code rather than a growing set.
 *
 * Same role scoping and same 404-for-another-tenant as the route above.
 */
usersRouter.post(
  '/:id/password-reset-code',
  requireRole('manager', 'admin'),
  resetCodeIssueRateLimiter,
  async (req: AuthedRequest, res) => {
    const { id } = req.params as { id: string };
    try {
      const issued = await issueResetCode({
        targetUserId: id,
        clientId: req.user!.clientId,
        actorId: req.user!.userId,
        actorRole: req.user!.role,
      });
      res.status(201).json(issued);
    } catch (err) {
      if (err instanceof ForbiddenTargetError) {
        res.status(403).json({ error: err.message });
        return;
      }
      throw err;
    }
  },
);
