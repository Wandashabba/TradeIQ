import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

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

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/** Ratio helper that returns 0 (never NaN) on an empty denominator. */
function pct(numerator: number, denominator: number): number {
  return denominator > 0 ? round2((100 * numerator) / denominator) : 0;
}

function mean(values: number[]): number {
  return values.length > 0 ? round2(values.reduce((sum, v) => sum + v, 0) / values.length) : 0;
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

export async function listCampaigns(clientId: string) {
  return prisma.campaign.findMany({
    where: { clientId },
    include: { _count: { select: { outlets: true } } },
    orderBy: { startDate: 'desc' },
  });
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
  const campaign = await prisma.campaign.findFirst({
    where: { id, clientId },
    include: { outlets: { select: { outletId: true } } },
  });
  if (!campaign) {
    throw new NotFoundError('Campaign not found');
  }

  const outletIds = campaign.outlets.map((link) => link.outletId);
  const outletsTotal = outletIds.length;

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
            checkinTs: { gte: campaign.startDate, lte: campaign.endDate },
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
