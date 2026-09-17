import { prisma } from '../../lib/prisma';
import { isCollectionGloballyEnabled } from './config';

/**
 * The legal gate, in one place.
 *
 * Competitor shelf prices — collected, stored or shown to the assistant — are
 * live for a client only when ALL of these hold:
 *
 * 1. `COMPETITOR_PRICE_COLLECTION=on` (the global kill switch). Checked FIRST
 *    and without touching the database, so "off" costs nothing and depends on
 *    nothing.
 * 2. `clients.competitor_price_collection_enabled` is true.
 * 3. Both `..._approved_by` and `..._approved_at` are set.
 *
 * Fails closed: an unknown client, a missing row, or a database error is off.
 */

export type GateState =
  | { active: true }
  | { active: false; reason: 'kill_switch' | 'client_disabled' | 'not_approved' };

export async function competitorPriceGate(
  clientId: string,
  env: NodeJS.ProcessEnv = process.env,
): Promise<GateState> {
  if (!isCollectionGloballyEnabled(env)) return { active: false, reason: 'kill_switch' };

  const client = await prisma.client.findUnique({
    where: { id: clientId },
    select: {
      competitorPriceCollectionEnabled: true,
      competitorPriceCollectionApprovedBy: true,
      competitorPriceCollectionApprovedAt: true,
    },
  });
  if (!client?.competitorPriceCollectionEnabled) return { active: false, reason: 'client_disabled' };
  if (!client.competitorPriceCollectionApprovedBy?.trim() || !client.competitorPriceCollectionApprovedAt) {
    return { active: false, reason: 'not_approved' };
  }
  return { active: true };
}

/** The same rule, as a Prisma filter over clients — for the scheduled job. */
export const ENABLED_CLIENT_WHERE = {
  competitorPriceCollectionEnabled: true,
  competitorPriceCollectionApprovedBy: { not: null },
  competitorPriceCollectionApprovedAt: { not: null },
} as const;
