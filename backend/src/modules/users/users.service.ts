import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { hashPassword } from '../auth/auth.service';

export type Role = 'field_agent' | 'manager' | 'admin';

// The only user fields that may reach the wire. Withholds passwordHash
// (credential) and clientId/lastLat/lastLng (tenant + agent GPS). Adding a
// field here widens /users AND /territories/:id/coverage.
export const safeUserSelect = {
  id: true,
  email: true,
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
}

// Provisions a new user in the caller's client. May throw a Prisma P2002 on a
// duplicate email — the route maps that to a 409.
export async function createUser(input: CreateUserInput) {
  return prisma.user.create({
    data: {
      clientId: input.clientId,
      email: input.email,
      passwordHash: await hashPassword(input.password),
      role: input.role,
      active: true,
    },
    select: safeUserSelect,
  });
}

export function listUsersForClient(clientId: string) {
  return prisma.user.findMany({
    where: { clientId },
    select: safeUserSelect,
    orderBy: { email: 'asc' },
  });
}

export interface UpdateUserInput {
  id: string;
  clientId: string;
  active?: boolean;
  role?: Role;
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

  return prisma.user.update({
    where: { id: input.id },
    data: {
      active: input.active,
      role: input.role,
    },
    select: safeUserSelect,
  });
}
