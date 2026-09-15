import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { buildPage } from '../../lib/pagination';
import { hashPassword } from '../auth/auth.service';
import { purgeAgentLocationPings } from '../locations/locationRetention';

export type Role = 'field_agent' | 'manager' | 'admin';

// The only user fields that may reach the wire. Withholds passwordHash
// (credential) and clientId/lastLat/lastLng (tenant + agent GPS). Adding a
// field here widens /users AND /territories/:id/coverage.
export const safeUserSelect = {
  id: true,
  email: true,
  displayName: true,
  role: true,
  active: true,
  lastSeenAt: true,
} satisfies Prisma.UserSelect;

/** A user as it may be exposed over the wire — never carries passwordHash. */
export type SafeUser = Prisma.UserGetPayload<{ select: typeof safeUserSelect }>;

export interface CreateUserInput {
  clientId: string;
  email: string;
  password: string;
  role: Role;
  /** Already trimmed and validated by the route; `null` when not given. */
  displayName?: string | null;
}

// Provisions a new user in the caller's client. May throw a Prisma P2002 on a
// duplicate email — the route maps that to a 409.
export async function createUser(input: CreateUserInput) {
  return prisma.user.create({
    data: {
      clientId: input.clientId,
      email: input.email,
      displayName: input.displayName ?? null,
      passwordHash: await hashPassword(input.password),
      role: input.role,
      active: true,
    },
    select: safeUserSelect,
  });
}

export interface ListUsersForClientInput {
  clientId: string;
  limit: number;
  cursor?: string;
}

export async function listUsersForClient(input: ListUsersForClientInput) {
  const rows = await prisma.user.findMany({
    where: { clientId: input.clientId },
    select: safeUserSelect,
    // `id` is the unique tiebreaker that makes the cursor deterministic
    // (Email is globally unique — see issue #188 — but two users sharing a
    // client never share an email, so this tiebreaker is belt-and-braces
    // rather than strictly required. It still must match the primary sort's
    // direction, same reasoning as alerts.service.ts.)
    //
    // COPYING THIS PATTERN: the tiebreaker's direction MUST match the primary
    // sort's direction (both `asc` here).
    orderBy: [{ email: 'asc' }, { id: 'asc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
}

export interface UpdateUserInput {
  id: string;
  clientId: string;
  active?: boolean;
  role?: Role;
  /** `undefined` leaves it alone; `null` clears it. */
  displayName?: string | null;
}

// Updates a user scoped to the caller's client, throwing NotFoundError when the
// target does not exist or belongs to another tenant. Undefined fields are left
// untouched by Prisma.
export async function updateUser(input: UpdateUserInput) {
  const existing = await prisma.user.findFirst({
    where: { id: input.id, clientId: input.clientId },
    select: { id: true },
  });
  if (!existing) {
    throw new NotFoundError('User not found');
  }

  const user = await prisma.user.update({
    where: { id: input.id },
    data: {
      active: input.active,
      role: input.role,
      displayName: input.displayName,
    },
    select: safeUserSelect,
  });

  if (input.active === false) {
    // Retention policy (#178): a deactivated agent's raw location pings are
    // folded into day summaries and deleted now, not in 90 days.
    //
    // After the update, and best-effort: deactivation is how someone's access
    // is revoked, and it must not fail because pruning did. Anything missed
    // here is caught by `npm run prune-location-pings`, which sweeps pings of
    // every inactive agent.
    try {
      await purgeAgentLocationPings({ clientId: input.clientId, agentId: input.id });
    } catch (err) {
      console.error('[users] location ping purge on deactivation failed; the prune job will retry', err);
    }
  }

  return user;
}
