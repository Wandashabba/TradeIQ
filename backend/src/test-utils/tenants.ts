import { prisma } from '../lib/prisma';
import { Role, issueToken } from '../modules/auth/auth.service';

let counter = 0;

/**
 * A real, authenticatable user in a real tenant.
 *
 * `requireAuth` re-reads the user on every request, so a token minted for a
 * fabricated `userId` is now a 401 — correctly, since revocation is exactly
 * that lookup. Tests therefore need people who actually exist.
 *
 * This matters most for the cross-tenant cases. They assert that another
 * client's data is invisible (404), and letting those become 401s would leave
 * them passing while the scoping logic they exist to prove was never reached.
 * A foreign tenant has to authenticate successfully and *then* be denied data.
 */
export interface TestUser {
  userId: string;
  clientId: string;
  token: string;
  /**
   * The address the user was created with.
   *
   * `resolveAgent` falls back to matching a typed name against this when the
   * user has no display name. A test exercising name resolution needs the
   * value, and re-querying for it in each suite is how two suites end up
   * disagreeing about the format.
   */
  email: string;
}

/**
 * Creates a user in an existing tenant and returns a usable bearer token.
 *
 * `displayName` is left null unless given, matching accounts that predate the
 * column (#280) — the case every display fallback has to survive.
 */
export async function userIn(
  clientId: string,
  role: Role = 'manager',
  options: { displayName?: string } = {},
): Promise<TestUser> {
  counter += 1;
  const user = await prisma.user.create({
    data: {
      email: `test-${role}-${counter}-${Date.now()}@example.test`,
      displayName: options.displayName ?? null,
      passwordHash: 'not-a-real-hash',
      role,
      clientId,
    },
  });
  return {
    userId: user.id,
    clientId,
    email: user.email,
    token: issueToken({ userId: user.id, role, clientId }),
  };
}

/**
 * Creates a whole separate tenant with one user in it — the stand-in for
 * "somebody else's company", replacing tokens that named `clientId:
 * 'no-such-client'`.
 *
 * Returns a `cleanup` rather than relying on the caller's afterAll, because the
 * user must be deleted before its client or the foreign key blocks it.
 */
export async function foreignTenant(
  role: Role = 'field_agent',
): Promise<TestUser & { cleanup: () => Promise<void> }> {
  counter += 1;
  const client = await prisma.client.create({
    data: {
      name: `FOREIGN-${counter}-${Date.now()}`,
      industry: 'FMCG',
      scorecardWeights: {},
      kpiThresholds: {},
    },
  });
  const user = await userIn(client.id, role);
  return {
    ...user,
    cleanup: async () => {
      await prisma.user.deleteMany({ where: { clientId: client.id } });
      await prisma.client.delete({ where: { id: client.id } });
    },
  };
}
