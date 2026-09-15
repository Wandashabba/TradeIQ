import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { mean, pct } from '../../lib/kpiMath';
import { NotFoundError } from '../../middleware/errorHandler';
import { computeRoi, type Roi } from './roi';
import { baselineWindow, campaignWindow } from './campaignWindow';
import { buildPage } from '../../lib/pagination';
import { getClientTimeZone } from '../clients/clients.service';

export type CampaignStatus = 'draft' | 'active' | 'completed';

export const CAMPAIGN_STATUSES: readonly CampaignStatus[] = ['draft', 'active', 'completed'];

export interface CreateCampaignInput {
  clientId: string;
  name: string;
  startDate: string; // ISO
  endDate: string; // ISO
  objective?: string;
  budget?: number;
  outletIds?: string[];
}

export interface UpdateCampaignInput {
  status?: CampaignStatus;
  name?: string;
  objective?: string;
  budget?: number;
}

export interface CampaignCompliance {
  outletsTotal: number;
  outletsVisited: number;
  visitCoverageRate: number;
  avgPlanogramCompliancePct: number;
  avgAbsPriceDeviationPct: number;
  promoComplianceRate: number;
}

export async function createCampaign(input: CreateCampaignInput) {
  if (input.outletIds && input.outletIds.length > 0) {
    const outlets = await prisma.outlet.findMany({
      where: { id: { in: input.outletIds }, clientId: input.clientId },
      select: { id: true },
    });
    const validIds = new Set(outlets.map((o) => o.id));
    const unknown = input.outletIds.find((id) => !validIds.has(id));
    if (unknown) {
      throw new NotFoundError(`Outlet not found: ${unknown}`);
    }
  }

  // Nested create runs the Campaign row and its CampaignOutlet links in a
  // single atomic write (Prisma wraps nested writes in a transaction).
  return prisma.campaign.create({
    data: {
      clientId: input.clientId,
      name: input.name,
      startDate: new Date(input.startDate),
      endDate: new Date(input.endDate),
      ...(input.objective !== undefined ? { objective: input.objective } : {}),
      ...(input.budget !== undefined ? { budget: input.budget } : {}),
      ...(input.outletIds && input.outletIds.length > 0
        ? { outlets: { create: input.outletIds.map((outletId) => ({ outletId })) } }
        : {}),
    },
    include: { outlets: true },
  });
}

export interface ListCampaignsInput {
  clientId: string;
  limit: number;
  cursor?: string;
}

export async function listCampaigns(input: ListCampaignsInput) {
  const rows = await prisma.campaign.findMany({
    where: { clientId: input.clientId },
    include: { _count: { select: { outlets: true } } },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two campaigns share a startDate — same reasoning as alerts.service.ts.
    orderBy: [{ startDate: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
}

export async function getCampaign(id: string, clientId: string) {
  const campaign = await prisma.campaign.findFirst({
    where: { id, clientId },
    include: { outlets: { include: { outlet: true } } },
  });
  if (!campaign) {
    throw new NotFoundError('Campaign not found');
  }
  return campaign;
}

export async function updateCampaign(id: string, clientId: string, patch: UpdateCampaignInput) {
  const existing = await prisma.campaign.findFirst({ where: { id, clientId }, select: { id: true } });
  if (!existing) {
    throw new NotFoundError('Campaign not found');
  }

  const data: Prisma.CampaignUpdateInput = {
    ...(patch.status !== undefined ? { status: patch.status } : {}),
    ...(patch.name !== undefined ? { name: patch.name } : {}),
    ...(patch.objective !== undefined ? { objective: patch.objective } : {}),
    ...(patch.budget !== undefined ? { budget: patch.budget } : {}),
  };

  return prisma.campaign.update({
    where: { id },
    data,
    include: { outlets: true },
  });
}

export async function getCampaignCompliance(id: string, clientId: string): Promise<CampaignCompliance> {
  const [campaign, timeZone] = await Promise.all([
    prisma.campaign.findFirst({
      where: { id, clientId },
      include: { outlets: { select: { outletId: true } } },
    }),
    getClientTimeZone(clientId),
  ]);
  if (!campaign) {
    throw new NotFoundError('Campaign not found');
  }

  const outletIds = campaign.outlets.map((link) => link.outletId);
  const outletsTotal = outletIds.length;
  // Inclusive local calendar days, half-open as instants (#324).
  const window = campaignWindow(campaign.startDate, campaign.endDate, timeZone);

  // Submitted visits over the campaign's outlets whose check-in falls inside
  // the campaign window. No outlets → no qualifying visits, so short-circuit
  // to an all-zero rollup.
  const visits =
    outletsTotal > 0
      ? await prisma.visit.findMany({
          where: {
            clientId,
            outletId: { in: outletIds },
            status: 'submitted',
            checkinTs: { gte: window.from, lt: window.to },
          },
          include: { visibility: true, pricing: true },
        })
      : [];

  const outletsVisited = new Set(visits.map((visit) => visit.outletId)).size;

  const visibilityRows = visits.flatMap((visit) => (visit.visibility ? [visit.visibility] : []));
  const pricingRows = visits.flatMap((visit) => visit.pricing);

  return {
    outletsTotal,
    outletsVisited,
    visitCoverageRate: pct(outletsVisited, outletsTotal),
    avgPlanogramCompliancePct: mean(visibilityRows.map((row) => row.planogramCompliancePct)),
    avgAbsPriceDeviationPct: mean(pricingRows.map((row) => Math.abs(row.deviationPct))),
    promoComplianceRate: pct(pricingRows.filter((row) => row.promoActive).length, pricingRows.length),
  };
}

export interface CampaignRoi extends Roi {
  campaignId: string;
  outletsTotal: number;
  /**
   * The campaign window as the instants it covers, half-open `[from, to)`:
   * the start of `startDate` to the start of the day after `endDate`, in the
   * client's timezone (#324).
   */
  window: { from: string; to: string };
  /** The window the baseline was measured over: as many local days, `[from, to)`. */
  baselineWindow: { from: string; to: string };
  /** Orders attributed to the campaign, and orders in the baseline window. */
  orderCount: { attributed: number; baseline: number };
}

/**
 * Return on a campaign, as incremental sell-in against spend (#94).
 *
 * `Campaign.budget` was previously stored and read by nothing; this is what
 * reads it. The measurement is deliberately conservative:
 *
 * - **Attributed** revenue comes from `Order.campaignId`, stamped at creation.
 *   It is not recomputed by date here, because an outlet can leave a campaign
 *   and a campaign's window can be edited — recomputing would quietly change a
 *   number someone has already acted on.
 * - **Baseline** is the same outlets over an equal-length, contiguous window
 *   immediately before the campaign, counted by date rather than attribution
 *   (there was no campaign then to attribute to). Both windows are whole local
 *   calendar days in the client's timezone (#324, see `campaignWindow.ts`).
 * - **Cancelled orders are excluded from both sides.** A cancelled order is not
 *   revenue, and leaving it in the baseline while excluding it from the campaign
 *   period would understate the lift.
 */
export async function getCampaignRoi(id: string, clientId: string): Promise<CampaignRoi> {
  const [campaign, timeZone] = await Promise.all([
    prisma.campaign.findFirst({
      where: { id, clientId },
      include: { outlets: { select: { outletId: true } } },
    }),
    getClientTimeZone(clientId),
  ]);
  if (!campaign) {
    throw new NotFoundError('Campaign not found');
  }

  const outletIds = campaign.outlets.map((link) => link.outletId);
  const window = campaignWindow(campaign.startDate, campaign.endDate, timeZone);
  const base = baselineWindow(window, timeZone);

  const [attributed, baseline] = await Promise.all([
    prisma.order.aggregate({
      where: { clientId, campaignId: id, status: { not: 'cancelled' } },
      _sum: { total: true },
      _count: true,
    }),
    // Empty outlet list would make `in: []` match nothing, which is the correct
    // answer for a campaign with no outlets — guarded anyway so intent is plain.
    outletIds.length === 0
      ? Promise.resolve({ _sum: { total: null }, _count: 0 })
      : prisma.order.aggregate({
          where: {
            clientId,
            outletId: { in: outletIds },
            status: { not: 'cancelled' },
            createdAt: { gte: base.from, lt: base.to },
          },
          _sum: { total: true },
          _count: true,
        }),
  ]);

  return {
    campaignId: id,
    outletsTotal: outletIds.length,
    window: { from: window.from.toISOString(), to: window.to.toISOString() },
    baselineWindow: { from: base.from.toISOString(), to: base.to.toISOString() },
    orderCount: { attributed: attributed._count, baseline: baseline._count },
    ...computeRoi({
      attributedRevenue: attributed._sum.total ?? 0,
      baselineRevenue: baseline._sum.total ?? 0,
      spend: campaign.budget,
    }),
  };
}
