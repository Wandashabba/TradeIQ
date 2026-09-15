import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { DEFAULT_CLIENT_TIME_ZONE } from '../../lib/clientTime';

// The runtime scorecard configuration exposed to (and editable by) a client.
// Only the config-relevant columns are surfaced; secrets/relations stay hidden.
const CLIENT_CONFIG_SELECT = {
  id: true,
  name: true,
  industry: true,
  scorecardWeights: true,
  kpiThresholds: true,
  // Readable so the app knows whether to offer the assistant at all, but
  // deliberately absent from UpdateClientConfigInput below: this is a rollout
  // lever, not a customer preference. A client admin flipping on an unproven,
  // metered AI feature for their own tenant is the exact thing a rollout flag
  // exists to prevent. Operators toggle it directly until there is a
  // cross-tenant admin surface to do it from.
  assistantEnabled: true,
  // IANA zone every calendar-day rule reads (#309). Editable by managers and
  // admins — it is a fact about where the team works, not a scoring policy.
  timezone: true,
} satisfies Prisma.ClientSelect;

export type ClientConfig = Prisma.ClientGetPayload<{ select: typeof CLIENT_CONFIG_SELECT }>;

export async function getClientConfig(clientId: string): Promise<ClientConfig> {
  const client = await prisma.client.findUnique({
    where: { id: clientId },
    select: CLIENT_CONFIG_SELECT,
  });
  if (!client) {
    throw new NotFoundError('Client not found');
  }
  return client;
}

/**
 * The IANA zone a client's calendar days are counted in (#309).
 *
 * Falls back to the schema default for a client id that does not resolve,
 * rather than throwing: every caller is already inside a tenant-scoped request
 * or a best-effort side effect, and "which day" must not become the reason a
 * submission or a report fails.
 */
export async function getClientTimeZone(clientId: string): Promise<string> {
  const client = await prisma.client.findUnique({
    where: { id: clientId },
    select: { timezone: true },
  });
  return client?.timezone ?? DEFAULT_CLIENT_TIME_ZONE;
}

export interface UpdateClientConfigInput {
  scorecardWeights?: Prisma.InputJsonValue;
  kpiThresholds?: Prisma.InputJsonValue;
  /** Already validated with `isValidTimeZone`. */
  timezone?: string;
}

export async function updateClientConfig(
  clientId: string,
  input: UpdateClientConfigInput,
): Promise<ClientConfig> {
  return prisma.client.update({
    where: { id: clientId },
    data: input,
    select: CLIENT_CONFIG_SELECT,
  });
}
