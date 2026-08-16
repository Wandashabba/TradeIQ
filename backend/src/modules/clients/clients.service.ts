import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

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

export interface UpdateClientConfigInput {
  scorecardWeights?: Prisma.InputJsonValue;
  kpiThresholds?: Prisma.InputJsonValue;
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
