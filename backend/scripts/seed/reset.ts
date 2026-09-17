import { Prisma, PrismaClient } from '@prisma/client';

/**
 * Foreign-key columns with no index of their own, which a large delete has to
 * check once per deleted parent row: deleting an order looks for its
 * `order_lines`, deleting a visit looks for its `orders`. Without an index each
 * check is a sequential scan, so a two-year reseed spent minutes-to-hours on
 * two DELETE statements. These exist only while the reset runs and are dropped
 * again, so the schema is left exactly as the migrations made it.
 */
const RESET_INDEXES: ReadonlyArray<readonly [string, string]> = [
  ['seed_tmp_order_lines_order_id', 'order_lines (order_id)'],
  ['seed_tmp_orders_visit_id', 'orders (visit_id)'],
];

/**
 * Deletes every demo row for one client, children before parents.
 *
 * The seed resets rather than upserts because its dates are anchored to the run
 * day: a second run would otherwise leave the previous run's rows fossilised at
 * their old dates alongside the new ones.
 *
 * Every delete is scoped by `clientId` (directly, or through a join to a row
 * that carries it). There is deliberately no bare `deleteMany({})` and no
 * unscoped `DELETE` anywhere in this file — it must be impossible for a demo
 * reseed to touch another tenant's data.
 *
 * The high-volume visit children (a two-year demo has millions of them) are
 * deleted with one joined `DELETE … USING` each rather than Prisma's relation
 * filter, which is the difference between seconds and minutes. The scope is
 * the same: the join to `visits`/`orders` on `client_id`.
 *
 * `Client` itself is NOT deleted: `index.ts` upserts it, and keeping the row
 * avoids a needless id churn — and keeps the client's settings (assistant flag,
 * timezone, working hours) across reseeds.
 */
export async function resetDemoData(prisma: PrismaClient, clientId: string): Promise<void> {
  for (const [name, target] of RESET_INDEXES) {
    await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS ${name} ON ${target}`);
  }
  try {
    await deleteDemoRows(prisma, clientId);
  } finally {
    for (const [name] of RESET_INDEXES) {
      await prisma.$executeRawUnsafe(`DROP INDEX IF EXISTS ${name}`);
    }
  }
}

async function deleteDemoRows(prisma: PrismaClient, clientId: string): Promise<void> {
  const viaVisit = (table: string) =>
    prisma.$executeRaw(
      Prisma.sql`DELETE FROM ${Prisma.raw(`"${table}"`)} AS t USING visits v
        WHERE t.visit_id = v.id AND v.client_id = ${clientId}`,
    );

  // Visit children — all reachable only through a visit.
  await prisma.$executeRaw(
    Prisma.sql`DELETE FROM order_lines AS l USING orders o WHERE l.order_id = o.id AND o.client_id = ${clientId}`,
  );
  await viaVisit('visit_template_responses');
  await viaVisit('scorecards');
  await viaVisit('visit_risks');
  await viaVisit('visit_capability');
  await viaVisit('visit_competitive');
  await viaVisit('visit_pricing');
  await viaVisit('visit_visibility');
  await viaVisit('visit_stock');

  // Rows that reference visits and/or outlets. Ledger entries point at visits,
  // tasks and scorecards without a foreign key, so they would otherwise outlive
  // them and inflate the leaderboard after a reseed.
  await prisma.pointsLedgerEntry.deleteMany({ where: { clientId } });
  await prisma.task.deleteMany({ where: { outlet: { clientId } } });
  await prisma.order.deleteMany({ where: { clientId } });
  await prisma.alert.deleteMany({ where: { clientId } });
  await prisma.checkInAttempt.deleteMany({ where: { clientId } });
  // Message attachments cascade with their message; the photos behind them
  // (#125) have no visit, so they are deleted by client below.
  await prisma.message.deleteMany({ where: { clientId } });
  await viaVisit('photos');
  await prisma.photo.deleteMany({ where: { clientId } });
  await prisma.visit.deleteMany({ where: { clientId } });

  // Planning, targets, contests and comms.
  await prisma.beatPlanStop.deleteMany({ where: { beatPlan: { clientId } } });
  await prisma.beatPlan.deleteMany({ where: { clientId } });
  await prisma.campaignOutlet.deleteMany({ where: { campaign: { clientId } } });
  await prisma.campaign.deleteMany({ where: { clientId } });
  // Sales targets reference skus, territories, outlets and their author; contests
  // reference a territory with RESTRICT. Both must go before any of those.
  await prisma.salesTarget.deleteMany({ where: { clientId } });
  await prisma.contest.deleteMany({ where: { clientId } });
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
