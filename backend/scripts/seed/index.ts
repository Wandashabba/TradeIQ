import { PrismaClient, Prisma } from '@prisma/client';
import { hashPassword } from '../../src/modules/auth/auth.service';
import { normalizeEmail } from '../../src/lib/email';
import { rescoreFraudScores } from '../../src/modules/fraud/fraudRescore';
import { backfillPointsLedger } from '../../src/modules/gamification/pointsLedgerBackfill';
import { computePhotoHashes } from '../../src/modules/photos/photoHash';
import { addCalendarDays } from '../../src/lib/clientTime';
import { HISTORY_MONTHS, SEED_TIME_ZONE, localInstant, resolveAnchorDate } from './calendar';
import {
  DEMO_CLIENT_ID,
  DEMO_PASSWORD,
  DEMO_USERS,
  SKUS,
  TERRITORIES,
  USERS,
  homeCoordinates,
} from './catalog';
import { buildComms } from './comms';
import { buildContests } from './contests';
import { HistoryGenerator, MonthBatch, PhotoSpec, REUSED_PHOTO_POOL } from './history';
import { PhaseTimer, inChunks } from './insert';
import { ALERT_RULE_IDS, INCENTIVE_SCHEMES } from './ops';
import { SECTION_TINTS, demoPhotoDataUrl, shelfPhotoDataUrl } from './photos';
import { resolveSeedPassword } from './password';
import { resetDemoData } from './reset';
import { buildSalesTargets } from './targets';
import { SCORECARD_WEIGHTS } from './visits';
import { World, buildWorld, campaignStatus } from './world';

const GEOFENCE_RADIUS_M = 50;
/** Exists only while the seed scores fraud; see the note where it is created. */
const SEED_SCORING_INDEX = 'seed_tmp_visits_outlet_checkin';

/**
 * `full` is the Ask TradeIQ dataset: 24 months, 400 outlets, 50 agents.
 * `test` is the same world cut down — three months, a sixth of the outlets —
 * for the end-to-end test, which must finish inside a jest timeout.
 */
export type SeedProfile = 'full' | 'test';

export interface SeedOptions {
  profile?: SeedProfile;
  /** Progress lines. Default: console.log for `full`, silent for `test`. */
  log?: (line: string) => void;
}

const PROFILES: Record<SeedProfile, { historyMonths: number; outletFraction: number }> = {
  full: { historyMonths: HISTORY_MONTHS, outletFraction: 1 },
  test: { historyMonths: 3, outletFraction: 0.17 },
};

/** The seed's own kpiThresholds — the four keys the engine reads (#46). */
const KPI_THRESHOLDS = { green: 80, amber: 60, stockoutUnits: 0, priceDeviationPct: 10 };

export async function seedDemoData(prisma: PrismaClient, options: SeedOptions = {}): Promise<void> {
  if (process.env.NODE_ENV === 'production' && !process.argv.includes('--force')) {
    throw new Error(
      'Refusing to seed with NODE_ENV=production. This deletes and rebuilds the demo ' +
        'client\'s data. Pass --force if that is genuinely what you want.',
    );
  }

  // Resolved before anything is deleted: a production seed without its own
  // password must fail while the existing data is still intact (#160).
  const seedPassword = resolveSeedPassword();

  const profileName: SeedProfile =
    options.profile ?? (process.env.SEED_PROFILE === 'test' ? 'test' : 'full');
  const profile = PROFILES[profileName];
  const log = options.log ?? (profileName === 'full' ? (line: string) => console.log(line) : () => undefined);
  const timer = new PhaseTimer();

  // Plan in the client's own zone (#309). The client row survives reseeds, so a
  // zone someone set is honoured; a fresh database gets Johannesburg.
  const existingClient = await prisma.client.findUnique({
    where: { id: DEMO_CLIENT_ID },
    select: { timezone: true },
  });
  const timeZone = existingClient?.timezone ?? SEED_TIME_ZONE;
  const anchor = resolveAnchorDate(process.env, new Date(), timeZone);
  const home = homeCoordinates();
  const world = buildWorld({
    anchor,
    home,
    timeZone,
    historyMonths: profile.historyMonths,
    outletFraction: profile.outletFraction,
  });
  log(
    `Seeding profile "${profileName}": anchor ${anchor.toISOString().slice(0, 10)} (${timeZone}), ` +
      `history from ${world.historyStart.toISOString().slice(0, 10)}, ` +
      `${world.outlets.length} outlets, ${world.agents.length} agents`,
  );

  // Hash once: bcrypt at cost 10 is deliberately slow, and all demo accounts
  // share a password.
  const passwordHash = await hashPassword(seedPassword.password);
  const closurePhotoUrl = await demoPhotoDataUrl(SECTION_TINTS.closure);

  await timer.time('reset', () => resetDemoData(prisma, DEMO_CLIENT_ID));

  await timer.time('reference data', () => writeReferenceData(prisma, world, passwordHash));

  // ── History, a month at a time ─────────────────────────────────────────────
  const history = new HistoryGenerator(world, { closurePhotoUrl });
  const reusedPhotos = await Promise.all(
    Array.from({ length: REUSED_PHOTO_POOL }, (_, i) => shelfPhotoDataUrl(900_001 + i)),
  );
  const totals = { visits: 0, orders: 0, orderLines: 0, tasks: 0, alerts: 0, photos: 0, stock: 0, plans: 0 };
  for (let batch = history.nextMonth(); batch !== null; batch = history.nextMonth()) {
    await writeMonth(prisma, batch, reusedPhotos, timer);
    totals.visits += batch.visits.length;
    totals.orders += batch.orders.length;
    totals.orderLines += batch.orderLines.length;
    totals.tasks += batch.tasks.length;
    totals.alerts += batch.alerts.length;
    totals.photos += batch.photos.length;
    totals.stock += batch.stock.length;
    totals.plans += batch.beatPlans.length;
    log(
      `  ${batch.month.toISOString().slice(0, 7)}: ${batch.visits.length} visits, ` +
        `${batch.orders.length} orders, ${batch.tasks.length} tasks, ${batch.alerts.length} alerts`,
    );
  }

  const upcoming = history.upcoming();
  await timer.time('beat plans (upcoming)', async () => {
    await inChunks(upcoming.beatPlans, (data) =>
      prisma.beatPlan.createMany({ data: data.map((p) => ({ ...p, clientId: DEMO_CLIENT_ID })) }),
    );
    await inChunks(upcoming.beatPlanStops, (data) => prisma.beatPlanStop.createMany({ data }));
  });
  totals.plans += upcoming.beatPlans.length;

  const targets = buildSalesTargets(world, history.plan);
  await timer.time('sales targets', () =>
    inChunks(targets, (data) =>
      prisma.salesTarget.createMany({ data: data.map((t) => ({ ...t, clientId: DEMO_CLIENT_ID })) }),
    ),
  );

  const contests = buildContests(world);
  await timer.time('contests', () =>
    prisma.contest.createMany({ data: contests.map((c) => ({ ...c, clientId: DEMO_CLIENT_ID })) }),
  );

  const comms = buildComms({ anchor: localInstant(anchor, 0, timeZone), users: USERS });
  await prisma.message.createMany({ data: comms.messages.map((m) => ({ ...m, clientId: DEMO_CLIENT_ID })) });
  await prisma.announcement.createMany({
    data: comms.announcements.map((a) => ({ ...a, clientId: DEMO_CLIENT_ID })),
  });

  // Fresh statistics before the heavy reads below: the planner otherwise sees
  // the tables as they were before millions of rows arrived.
  await timer.time('analyze', () => prisma.$executeRawUnsafe('ANALYZE'));

  // #236: GET /fraud/flagged reads the score stored on each visit, and submit is
  // what stores it. The seed writes visits straight to the table, so it scores
  // them itself, once every input the engine reads is in place (sections,
  // photos and their hashes, check-in attempts, the client's thresholds),
  // through the same batched routine as `npm run rescore-fraud`.
  //
  // The repeating-stock-counts signal (#245) walks each visit's earlier visits
  // to its outlet newest-first. With only `visits(outlet_id)` indexed, every
  // lookup sorts the outlet's whole history, and two years of it made scoring
  // the slowest phase of the seed by far (about 100 visits a second, falling).
  // A temporary index on exactly that walk makes it an index range scan; it is
  // dropped again straight afterwards, so the schema is left as migrations made
  // it. (A permanent index is a migration decision, not the seed's.)
  const fraud = await timer.time('fraud scoring', async () => {
    await prisma.$executeRawUnsafe(`DROP INDEX IF EXISTS ${SEED_SCORING_INDEX}`);
    await prisma.$executeRawUnsafe(
      `CREATE INDEX ${SEED_SCORING_INDEX} ON visits (outlet_id, checkin_ts DESC, id DESC)`,
    );
    try {
      return await rescoreFraudScores({ clientId: DEMO_CLIENT_ID, batchSize: 1000 });
    } finally {
      await prisma.$executeRawUnsafe(`DROP INDEX IF EXISTS ${SEED_SCORING_INDEX}`);
    }
  });

  // The seed writes history directly, past the live ledger hooks, so the
  // leaderboard's points ledger (#124) is built from it the way production
  // history is.
  await timer.time('points ledger', () =>
    backfillPointsLedger({ clientId: DEMO_CLIENT_ID, batchSize: 5000 }, prisma),
  );

  log(
    [
      '',
      `Seeded Kalahari Beverages — ${profile.historyMonths} months of history to ${anchor.toISOString().slice(0, 10)}`,
      `sign in with any of: ${DEMO_USERS.map((u) => u.email).join(', ')}`,
      // Only the published default is printed. A supplied SEED_DEMO_PASSWORD is
      // a real secret and does not belong in a terminal or a deploy log.
      `password: ${seedPassword.isWellKnownDefault ? DEMO_PASSWORD : '(from SEED_DEMO_PASSWORD, not printed)'}`,
      `${TERRITORIES.length} territories, ${world.outlets.length} outlets, ${world.agents.length} agents, ${SKUS.length} SKUs`,
      `${totals.visits} visits (${totals.stock} stock lines), ${totals.orders} orders / ${totals.orderLines} lines`,
      `${totals.tasks} tasks, ${totals.alerts} alerts, ${totals.photos} photos, ${totals.plans} beat plans`,
      `${targets.length} sales targets, ${contests.length} contests, ${world.campaigns.length} campaigns`,
      `fraud scores stored on ${fraud.written} visits`,
      '',
      'Home-base outlet (live geofence check-in):',
      `  coordinates: ${home.lat}, ${home.lng} (${home.source === 'env' ? 'from DEMO_HOME_LAT/DEMO_HOME_LNG' : 'FALLBACK — set DEMO_HOME_LAT/DEMO_HOME_LNG to use your own'})`,
      `  geofence radius: ${GEOFENCE_RADIUS_M}m — check-in is REJECTED outside it, not merely flagged.`,
      '  Indoor GPS drifts 20-50m, so verify a check-in before demoing rather than during.',
      '',
      'Timings:',
      timer.summary(),
    ].join('\n'),
  );
}

async function writeReferenceData(prisma: PrismaClient, world: World, passwordHash: string): Promise<void> {
  await prisma.client.upsert({
    where: { id: DEMO_CLIENT_ID },
    update: {},
    create: {
      id: DEMO_CLIENT_ID,
      name: 'Kalahari Beverages',
      industry: 'FMCG',
      scorecardWeights: SCORECARD_WEIGHTS,
      kpiThresholds: KPI_THRESHOLDS,
      timezone: world.timeZone,
    },
  });

  await prisma.user.createMany({
    data: USERS.map((user) => ({
      id: user.id,
      // The catalog's emails are already canonical and a test pins that, but
      // the seed writes through the same normaliser login reads through (#351)
      // so the two can never drift apart here.
      email: normalizeEmail(user.email),
      displayName: user.name,
      passwordHash,
      role: user.role,
      clientId: DEMO_CLIENT_ID,
    })),
  });

  await prisma.territory.createMany({
    data: TERRITORIES.map((t) => ({
      id: t.id,
      clientId: DEMO_CLIENT_ID,
      name: t.name,
      code: t.code,
      region: t.region,
    })),
  });

  await prisma.userTerritory.createMany({
    data: world.agents.map((agent) => ({ userId: agent.id, territoryId: agent.territoryId! })),
  });

  await prisma.sku.createMany({ data: SKUS.map((sku) => ({ ...sku, clientId: DEMO_CLIENT_ID })) });

  await prisma.outlet.createMany({
    data: world.outlets.map((outlet) => ({ ...outlet, clientId: DEMO_CLIENT_ID })),
  });

  await prisma.alertRule.createMany({
    data: [
      { id: ALERT_RULE_IDS.outOfStock, clientId: DEMO_CLIENT_ID, name: 'Out of stock', metric: 'out_of_stock', threshold: 0, severity: 'high', active: true },
      { id: ALERT_RULE_IDS.priceDeviation, clientId: DEMO_CLIENT_ID, name: 'Price deviation', metric: 'price_deviation', threshold: 10, severity: 'normal', active: true },
      { id: ALERT_RULE_IDS.lowScorecard, clientId: DEMO_CLIENT_ID, name: 'Low execution score', metric: 'low_scorecard', threshold: 60, severity: 'high', active: true },
      { id: ALERT_RULE_IDS.slaBreach, clientId: DEMO_CLIENT_ID, name: 'Task SLA breached', metric: 'sla_breach', threshold: null, severity: 'high', active: true },
    ],
  });

  await prisma.incentiveScheme.createMany({
    data: INCENTIVE_SCHEMES.map((scheme) => ({ ...scheme, clientId: DEMO_CLIENT_ID })),
  });

  // Campaigns, their outlets, and the promo-calendar entry each one priced from.
  for (const campaign of world.campaigns) {
    const status = campaignStatus(campaign, world.anchor);
    const outletIds = world.campaignOutlets.get(campaign.id)!;
    await prisma.campaign.create({
      data: {
        id: campaign.id,
        clientId: DEMO_CLIENT_ID,
        name: campaign.name,
        objective: campaign.objective,
        // Calendar dates at UTC midnight: inclusive local days (#324).
        startDate: campaign.startDate,
        endDate: campaign.endDate,
        budget: campaign.budget,
        status,
        createdAt: localInstant(addCalendarDays(campaign.startDate, -21), 10 * 60, world.timeZone),
      },
    });
    await prisma.campaignOutlet.createMany({
      data: outletIds.map((outletId) => ({ campaignId: campaign.id, outletId })),
    });
    if (status !== 'draft' && campaign.discount > 0) {
      await prisma.promoCalendar.create({
        data: {
          id: `${campaign.id}-promo`,
          clientId: DEMO_CLIENT_ID,
          promoName: campaign.name,
          activeFrom: localInstant(campaign.startDate, 0, world.timeZone),
          activeTo: localInstant(addCalendarDays(campaign.endDate, 1), 0, world.timeZone),
          requiredPosm: { poster: true, shelfStrip: true, wobbler: true },
          outletScope: { outletCodes: outletIds.map((id) => world.outletById.get(id)!.code) },
          discountType: 'percent',
          discountValue: Math.round(campaign.discount * 100),
          skuScope: { skuIds: [...campaign.skuIds] },
        },
      });
    }
  }

  await prisma.auditTemplate.create({
    data: {
      id: 'demo-audit-template-1',
      clientId: DEMO_CLIENT_ID,
      name: 'FMCG Standard Store Audit',
      industry: 'FMCG',
      version: 1,
      active: true,
      schema: {
        sections: [
          { key: 's2_stock', label: 'Stock & Availability', fields: ['unitsAvailable', 'daysOutOfStock'] },
          { key: 's3_visibility', label: 'Visibility & Display', fields: ['planogramCompliancePct', 'cleanlinessScore'] },
          { key: 's5_pricing', label: 'Pricing & Promotions', fields: ['priceActual', 'promoActive'] },
        ],
        scoring: SCORECARD_WEIGHTS,
      } as Prisma.InputJsonValue,
    },
  });
}

async function renderPhotos(
  specs: PhotoSpec[],
  reusedPhotos: string[],
): Promise<Array<PhotoSpec & { url: string; contentHash: string | null; perceptualHash: string | null; perceptualHashBands: number[] }>> {
  const out = [];
  const hashCache = new Map<string, Awaited<ReturnType<typeof computePhotoHashes>>>();
  const PARALLEL = 16;
  for (let start = 0; start < specs.length; start += PARALLEL) {
    const slice = specs.slice(start, start + PARALLEL);
    const rendered = await Promise.all(
      slice.map(async (spec) => {
        const url = spec.kind === 'reused' ? reusedPhotos[spec.seed]! : await shelfPhotoDataUrl(spec.seed);
        // Hashed exactly as upload hashes them (#244), so the duplicate-photo
        // signal sees seeded photos the way it sees real ones.
        let hashes = hashCache.get(url);
        if (!hashes) {
          hashes = await computePhotoHashes(url);
          if (spec.kind === 'reused') hashCache.set(url, hashes);
        }
        return { ...spec, url, ...hashes };
      }),
    );
    out.push(...rendered);
  }
  return out;
}

async function writeMonth(
  prisma: PrismaClient,
  batch: MonthBatch,
  reusedPhotos: string[],
  timer: PhaseTimer,
): Promise<void> {
  const clientId = DEMO_CLIENT_ID;
  const json = (value: unknown) => value as Prisma.InputJsonValue;

  await timer.time('history: visits', () =>
    inChunks(batch.visits, (data) => prisma.visit.createMany({ data: data.map((v) => ({ ...v, clientId })) })),
  );
  await timer.time('history: stock', () => inChunks(batch.stock, (data) => prisma.visitStock.createMany({ data }), 6000));
  await timer.time('history: pricing', () =>
    inChunks(batch.pricing, (data) =>
      prisma.visitPricing.createMany({
        data: data.map((row) => ({ ...row, promoMaterialsDetected: json(row.promoMaterialsDetected) })),
      }),
    ),
  );
  await timer.time('history: competitive', () =>
    inChunks(batch.competitive, (data) =>
      prisma.visitCompetitive.createMany({ data: data.map((row) => ({ ...row, geotag: json(row.geotag) })) }),
    ),
  );
  await timer.time('history: visibility', () =>
    inChunks(batch.visibility, (data) =>
      prisma.visitVisibility.createMany({
        data: data.map((row) => ({
          ...row,
          brandingElements: json(row.brandingElements),
          facingsCount: json(row.facingsCount),
        })),
      }),
    ),
  );
  await timer.time('history: capability', () =>
    inChunks(batch.capability, (data) =>
      prisma.visitCapability.createMany({
        data: data.map((row) => ({ ...row, repTrainingStatus: json(row.repTrainingStatus) })),
      }),
    ),
  );
  await timer.time('history: scorecards', () =>
    inChunks(batch.scorecards, (data) =>
      prisma.scorecard.createMany({
        data: data.map((row) => ({ ...row, dimensionScores: json(row.dimensionScores) })),
      }),
    ),
  );
  await timer.time('history: check-ins', () =>
    inChunks(batch.checkIns, (data) =>
      prisma.checkInAttempt.createMany({ data: data.map((row) => ({ ...row, clientId })) }),
    ),
  );

  if (batch.photos.length > 0) {
    const rendered = await timer.time('history: photo render', () => renderPhotos(batch.photos, reusedPhotos));
    await timer.time('history: photos', () =>
      inChunks(
        rendered,
        (data) =>
          prisma.photo.createMany({
            data: data.map((p) => ({
              id: p.id,
              visitId: p.visitId,
              clientId,
              uploadedById: p.uploadedById,
              section: p.section,
              url: p.url,
              gpsTag: json(p.gpsTag),
              timestamp: p.timestamp,
              createdAt: p.timestamp,
              contentHash: p.contentHash,
              perceptualHash: p.perceptualHash,
              perceptualHashBands: p.perceptualHashBands,
            })),
          }),
        500,
      ),
    );
  }

  await timer.time('history: orders', async () => {
    await inChunks(batch.orders, (data) =>
      prisma.order.createMany({ data: data.map((o) => ({ ...o, clientId })) }),
    );
    await inChunks(batch.orderLines, (data) => prisma.orderLine.createMany({ data }), 6000);
  });

  await timer.time('history: tasks & alerts', async () => {
    await inChunks(batch.tasks, (data) => prisma.task.createMany({ data }), 2000);
    await inChunks(batch.alerts, (data) =>
      prisma.alert.createMany({ data: data.map((a) => ({ ...a, clientId })) }),
    );
  });

  await timer.time('history: beat plans', async () => {
    await inChunks(batch.beatPlans, (data) =>
      prisma.beatPlan.createMany({ data: data.map((p) => ({ ...p, clientId })) }),
    );
    await inChunks(batch.beatPlanStops, (data) => prisma.beatPlanStop.createMany({ data }));
  });

  if (batch.templateResponses.length > 0) {
    await prisma.visitTemplateResponse.createMany({
      data: batch.templateResponses.map((r) => ({
        visitId: r.visitId,
        templateId: 'demo-audit-template-1',
        templateVersion: 1,
        answers: json({
          s2_stock: { unitsAvailable: r.stock.unitsAvailable, daysOutOfStock: r.stock.daysOutOfStock },
          s3_visibility: {
            planogramCompliancePct: r.visibility.planogramCompliancePct,
            cleanlinessScore: r.visibility.cleanlinessScore,
          },
          s5_pricing: { priceActual: r.pricing.priceActual, promoActive: r.pricing.promoActive },
        }),
        createdAt: r.createdAt,
      })),
    });
  }
}
