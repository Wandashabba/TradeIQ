import { PrismaClient } from '@prisma/client';

/**
 * Deletes every demo row for one client, children before parents.
 *
 * The seed resets rather than upserts because its dates are anchored to the run
 * day: a second run would otherwise leave the previous run's rows fossilised at
 * their old dates alongside the new ones.
 *
 * Every delete is scoped by `clientId` (directly, or through a relation filter).
 * There is deliberately no bare `deleteMany({})` anywhere in this file — it must
 * be impossible for a demo reseed to touch another tenant's data.
 *
 * `Client` itself is NOT deleted: `index.ts` upserts it, and keeping the row
 * avoids a needless id churn.
 */
export async function resetDemoData(prisma: PrismaClient, clientId: string): Promise<void> {
  // Visit children — all reachable only through a visit.
  await prisma.orderLine.deleteMany({ where: { order: { clientId } } });
  await prisma.visitTemplateResponse.deleteMany({ where: { visit: { clientId } } });
  await prisma.scorecard.deleteMany({ where: { visit: { clientId } } });
  await prisma.photo.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitRisk.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitCapability.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitCompetitive.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitPricing.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitVisibility.deleteMany({ where: { visit: { clientId } } });
  await prisma.visitStock.deleteMany({ where: { visit: { clientId } } });

  // Rows that reference visits and/or outlets. Ledger entries point at visits,
  // tasks and scorecards without a foreign key, so they would otherwise outlive
  // them and inflate the leaderboard after a reseed.
  await prisma.pointsLedgerEntry.deleteMany({ where: { clientId } });
  await prisma.task.deleteMany({ where: { outlet: { clientId } } });
  await prisma.order.deleteMany({ where: { clientId } });
  await prisma.alert.deleteMany({ where: { clientId } });
  await prisma.checkInAttempt.deleteMany({ where: { clientId } });
  await prisma.visit.deleteMany({ where: { clientId } });

  // Planning and comms.
  await prisma.beatPlanStop.deleteMany({ where: { beatPlan: { clientId } } });
  await prisma.beatPlan.deleteMany({ where: { clientId } });
  await prisma.campaignOutlet.deleteMany({ where: { campaign: { clientId } } });
  await prisma.campaign.deleteMany({ where: { clientId } });
  // Message attachments cascade with their message; the photos behind them
  // (#125) have no visit, so the visit-scoped photo delete above missed them.
  await prisma.message.deleteMany({ where: { clientId } });
  await prisma.photo.deleteMany({ where: { clientId } });
  await prisma.announcement.deleteMany({ where: { clientId } });

  // Configuration.
  await prisma.reportSchedule.deleteMany({ where: { clientId } });
  await prisma.reportDefinition.deleteMany({ where: { clientId } });
  await prisma.webhook.deleteMany({ where: { clientId } });
  await prisma.incentiveScheme.deleteMany({ where: { clientId } });
  await prisma.visitTemplateResponse.deleteMany({ where: { template: { clientId } } });
  await prisma.auditTemplate.deleteMany({ where: { clientId } });
  await prisma.alertRule.deleteMany({ where: { clientId } });
  await prisma.promoCalendar.deleteMany({ where: { clientId } });

  // Core entities last.
  await prisma.outlet.deleteMany({ where: { clientId } });
  await prisma.sku.deleteMany({ where: { clientId } });
  await prisma.userTerritory.deleteMany({ where: { user: { clientId } } });
  await prisma.territory.deleteMany({ where: { clientId } });
  await prisma.user.deleteMany({ where: { clientId } });
}
