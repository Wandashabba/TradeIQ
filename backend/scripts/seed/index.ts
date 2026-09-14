import { PrismaClient, Prisma, TaskPriority, TaskStatus } from '@prisma/client';
import { hashPassword } from '../../src/modules/auth/auth.service';
import { addDays, HISTORY_WEEKS, startOfUtcDay } from './calendar';
import {
  DEMO_CLIENT_ID,
  DEMO_PASSWORD,
  HOME_OUTLET_ID,
  SKUS,
  TERRITORIES,
  USERS,
  buildOutlets,
  homeCoordinates,
} from './catalog';
import { buildComms } from './comms';
import { ALERT_RULE_IDS, buildOps } from './ops';
import { SECTION_TINTS, demoPhotoDataUrl } from './photos';
import { resetDemoData } from './reset';
import { buildVisitHistory } from './visits';

const GEOFENCE_RADIUS_M = 50;

export async function seedDemoData(prisma: PrismaClient): Promise<void> {
  if (process.env.NODE_ENV === 'production' && !process.argv.includes('--force')) {
    throw new Error(
      'Refusing to seed with NODE_ENV=production. This deletes and rebuilds the demo ' +
        'client\'s data. Pass --force if that is genuinely what you want.',
    );
  }

  const anchor = startOfUtcDay(new Date());
  const home = homeCoordinates();
  const outlets = buildOutlets(home);
  const agents = USERS.filter((u) => u.role === 'field_agent');

  // Hash once: bcrypt at cost 10 is deliberately slow, and all demo accounts
  // share a password.
  const passwordHash = await hashPassword(DEMO_PASSWORD);

  const [visibilityPhoto, pricingPhoto, competitivePhoto, closurePhoto] = await Promise.all([
    demoPhotoDataUrl(SECTION_TINTS.visibility!),
    demoPhotoDataUrl(SECTION_TINTS.pricing!),
    demoPhotoDataUrl(SECTION_TINTS.competitive!),
    demoPhotoDataUrl(SECTION_TINTS.closure!),
  ]);
  const sectionPhotos = [visibilityPhoto, pricingPhoto, competitivePhoto];

  const visits = buildVisitHistory({ anchor, outlets, agents, skus: SKUS });
  const ops = buildOps({ anchor, visits, outlets, agents, closurePhotoUrl: closurePhoto });
  const comms = buildComms({ anchor, users: USERS });

  await resetDemoData(prisma, DEMO_CLIENT_ID);

  await prisma.client.upsert({
    where: { id: DEMO_CLIENT_ID },
    update: {},
    create: {
      id: DEMO_CLIENT_ID,
      name: 'Kalahari Beverages',
      industry: 'FMCG',
      scorecardWeights: {
        availability: 0.3,
        visibility: 0.25,
        display: 0.15,
        pricing: 0.1,
        salesCapability: 0.1,
        competitive: 0.1,
      },
      // The four keys the engine actually reads (#46).
      kpiThresholds: { green: 80, amber: 60, stockoutUnits: 0, priceDeviationPct: 10 },
    },
  });

  await prisma.user.createMany({
    data: USERS.map((user) => ({
      id: user.id,
      email: user.email,
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
    data: agents.map((agent) => ({
      userId: agent.id,
      territoryId: agent.territoryId!,
    })),
  });

  await prisma.sku.createMany({
    data: SKUS.map((sku) => ({ ...sku, clientId: DEMO_CLIENT_ID })),
  });

  await prisma.outlet.createMany({
    data: outlets.map((outlet) => ({ ...outlet, clientId: DEMO_CLIENT_ID })),
  });

  await prisma.promoCalendar.create({
    data: {
      id: 'demo-promo-1',
      clientId: DEMO_CLIENT_ID,
      promoName: 'Winter Warmer Multibuy',
      activeFrom: addDays(anchor, -30),
      activeTo: addDays(anchor, 30),
      requiredPosm: { poster: true, shelfStrip: true, wobbler: true },
      outletScope: { all: true },
      discountType: 'percent',
      discountValue: 15,
      skuScope: { skuIds: SKUS.slice(0, 4).map((s) => s.id) },
    },
  });

  await prisma.alertRule.createMany({
    data: [
      { id: ALERT_RULE_IDS.outOfStock, clientId: DEMO_CLIENT_ID, name: 'Out of stock', metric: 'out_of_stock', threshold: 0, severity: 'high', active: true },
      { id: ALERT_RULE_IDS.priceDeviation, clientId: DEMO_CLIENT_ID, name: 'Price deviation', metric: 'price_deviation', threshold: 10, severity: 'normal', active: true },
      { id: ALERT_RULE_IDS.lowScorecard, clientId: DEMO_CLIENT_ID, name: 'Low execution score', metric: 'low_scorecard', threshold: 60, severity: 'high', active: true },
    ],
  });

  // Visits and their children. createMany per table rather than a nested create
  // per visit: ~350 visits x 12 child rows is 4000+ rows, and one round trip per
  // row makes the seed take minutes instead of seconds.
  await prisma.visit.createMany({
    data: visits.map((v) => ({
      id: v.id,
      outletId: v.outletId,
      agentId: v.agentId,
      clientId: DEMO_CLIENT_ID,
      checkinTs: v.checkinTs,
      checkinLat: v.checkinLat,
      checkinLng: v.checkinLng,
      checkinDistanceM: v.checkinDistanceM,
      geofencePass: v.geofencePass,
      status: 'submitted' as const,
      submittedAtClient: v.checkinTs,
    })),
  });

  await prisma.visitStock.createMany({
    data: visits.flatMap((v) => v.stock.map((row) => ({ ...row, visitId: v.id }))),
  });

  await prisma.visitPricing.createMany({
    data: visits.flatMap((v) => v.pricing.map((row) => ({ ...row, visitId: v.id }))),
  });

  await prisma.visitCompetitive.createMany({
    data: visits.flatMap((v) =>
      v.competitive.map((row) => ({
        ...row,
        visitId: v.id,
        geotag: row.geotag as Prisma.InputJsonValue,
      })),
    ),
  });

  await prisma.visitVisibility.createMany({
    data: visits.map((v) => ({
      visitId: v.id,
      brandingElements: v.visibility.brandingElements as Prisma.InputJsonValue,
      planogramCompliancePct: v.visibility.planogramCompliancePct,
      facingsCount: v.visibility.facingsCount as Prisma.InputJsonValue,
      highTrafficPass: v.visibility.highTrafficPass,
      cleanlinessScore: v.visibility.cleanlinessScore,
      createdAt: v.visibility.createdAt,
    })),
  });

  await prisma.visitCapability.createMany({
    data: visits.map((v) => ({
      visitId: v.id,
      staffHeadcountConfirmed: v.capability.staffHeadcountConfirmed,
      repTrainingStatus: v.capability.repTrainingStatus as Prisma.InputJsonValue,
      quizScore: v.capability.quizScore,
      createdAt: v.capability.createdAt,
    })),
  });

  await prisma.scorecard.createMany({
    data: visits.map((v) => ({
      visitId: v.id,
      dimensionScores: v.scorecard.dimensionScores as Prisma.InputJsonValue,
      weightedTotal: v.scorecard.weightedTotal,
      ratingBand: v.scorecard.ratingBand,
      // The #204 fix: explicit, equal to the visit time. /trends buckets on this.
      createdAt: v.scorecard.createdAt,
    })),
  });

  await prisma.photo.createMany({
    data: visits.map((v, index) => ({
      visitId: v.id,
      section: ['visibility', 'pricing', 'competitive'][index % 3]!,
      // Real decodable JPEGs (#209) — the old seed's demo.tradeiq.local URLs 422'd.
      url: sectionPhotos[index % 3]!,
      gpsTag: { lat: v.checkinLat, lng: v.checkinLng } as Prisma.InputJsonValue,
      timestamp: v.checkinTs,
      createdAt: v.checkinTs,
    })),
  });

  await prisma.checkInAttempt.createMany({
    data: visits.map((v) => ({
      clientId: DEMO_CLIENT_ID,
      outletId: v.outletId,
      agentId: v.agentId,
      lat: v.checkinLat,
      lng: v.checkinLng,
      distanceM: v.checkinDistanceM,
      passed: true,
      createdAt: v.checkinTs,
    })),
  });

  // A handful of rejected attempts — the negative signal the fraud engine exists
  // for, and a screen that is otherwise entirely empty.
  await prisma.checkInAttempt.createMany({
    data: visits.slice(0, 6).map((v) => ({
      clientId: DEMO_CLIENT_ID,
      outletId: v.outletId,
      agentId: v.agentId,
      lat: v.checkinLat + 0.004,
      lng: v.checkinLng + 0.004,
      distanceM: 610,
      passed: false,
      createdAt: addDays(v.checkinTs, -1),
    })),
  });

  await prisma.task.createMany({
    data: ops.tasks.map((task) => ({
      id: task.id,
      visitId: task.visitId,
      findingType: task.findingType,
      outletId: task.outletId,
      requiredFix: task.requiredFix,
      priority: task.priority as TaskPriority,
      slaDueAt: task.slaDueAt,
      ownerId: task.ownerId,
      status: task.status as TaskStatus,
      closurePhotoUrl: task.closurePhotoUrl ?? null,
      closureVerified: task.closureVerified,
      createdAt: task.createdAt,
    })),
  });

  await prisma.alert.createMany({
    data: ops.alerts.map((alert) => ({
      id: alert.id,
      clientId: DEMO_CLIENT_ID,
      ruleId: alert.ruleId,
      visitId: alert.visitId,
      outletId: alert.outletId,
      metric: alert.metric,
      message: alert.message,
      severity: alert.severity,
      acknowledged: alert.acknowledged,
      createdAt: alert.createdAt,
    })),
  });

  await prisma.incentiveScheme.createMany({
    data: ops.incentiveSchemes.map((scheme) => ({ ...scheme, clientId: DEMO_CLIENT_ID })),
  });

  await prisma.message.createMany({
    data: comms.messages.map((m) => ({ ...m, clientId: DEMO_CLIENT_ID })),
  });

  await prisma.announcement.createMany({
    data: comms.announcements.map((a) => ({ ...a, clientId: DEMO_CLIENT_ID })),
  });

  // Today's beat plan for the demo agent, opening with the home-base outlet so
  // the live geofence check-in is the natural next action.
  const demoAgent = agents[0]!;
  // Outlets carry the territory CODE; the BeatPlan below carries the territory
  // ID, because `BeatPlan.territoryId` is a real foreign key while
  // `Outlet.territoryId` is free text mirroring the code. Same field name, two
  // different meanings, one line apart — which is exactly how the id ended up
  // on the outlets in the first place.
  const gautengOutlets = outlets.filter((o) => o.territoryId === 'GP');
  const stopOutlets = [
    outlets.find((o) => o.id === HOME_OUTLET_ID)!,
    ...gautengOutlets.filter((o) => o.id !== HOME_OUTLET_ID).slice(0, 4),
  ];

  await prisma.beatPlan.create({
    data: {
      id: 'demo-beatplan-today',
      clientId: DEMO_CLIENT_ID,
      agentId: demoAgent.id,
      territoryId: 'demo-territory-gp',
      name: "Today's route",
      scheduledDate: anchor,
      status: 'in_progress',
      stops: {
        create: stopOutlets.map((outlet, index) => ({
          outletId: outlet.id,
          sequence: index + 1,
          visited: false,
        })),
      },
    },
  });

  await prisma.campaign.create({
    data: {
      id: 'demo-campaign-1',
      clientId: DEMO_CLIENT_ID,
      name: 'Winter Warmer Activation',
      objective: 'Drive multibuy visibility across the top 20 outlets by ACV.',
      startDate: addDays(anchor, -30),
      endDate: addDays(anchor, 30),
      budget: 250000,
      status: 'active',
      outlets: {
        create: outlets.slice(0, 20).map((outlet) => ({ outletId: outlet.id })),
      },
    },
  });

  const template = await prisma.auditTemplate.create({
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
        scoring: { availability: 0.3, visibility: 0.25, display: 0.15, pricing: 0.1, competitive: 0.1, salesCapability: 0.1 },
      } as Prisma.InputJsonValue,
    },
  });

  await prisma.visitTemplateResponse.createMany({
    data: visits.slice(0, 25).map((v) => ({
      visitId: v.id,
      templateId: template.id,
      templateVersion: 1,
      answers: {
        s2_stock: { unitsAvailable: v.stock[0]?.unitsAvailable ?? 0, daysOutOfStock: v.stock[0]?.daysOutOfStock ?? 0 },
        s3_visibility: { planogramCompliancePct: v.visibility.planogramCompliancePct, cleanlinessScore: v.visibility.cleanlinessScore },
        s5_pricing: { priceActual: v.pricing[0]?.priceActual ?? 0, promoActive: v.pricing[0]?.promoActive ?? false },
      } as Prisma.InputJsonValue,
      createdAt: v.checkinTs,
    })),
  });

  // In-store orders on the most recent visits.
  for (const visit of visits.slice(-15)) {
    const lines = SKUS.slice(0, 3).map((sku) => ({
      skuId: sku.id,
      quantity: 12,
      unitPrice: sku.rrp,
    }));
    await prisma.order.create({
      data: {
        clientId: DEMO_CLIENT_ID,
        outletId: visit.outletId,
        agentId: visit.agentId,
        visitId: visit.id,
        status: 'submitted',
        total: lines.reduce((sum, l) => sum + l.quantity * l.unitPrice, 0),
        createdAt: visit.checkinTs,
        lines: { create: lines },
      },
    });
  }

  const openTasks = ops.tasks.filter((t) => t.status === 'open').length;
  const openAlerts = ops.alerts.filter((a) => !a.acknowledged).length;

  console.log(
    [
      `Seeded ${'Kalahari Beverages'} — ${HISTORY_WEEKS} weeks of history ending today`,
      `sign in with any of: ${USERS.map((u) => u.email).join(', ')}`,
      `password: ${DEMO_PASSWORD}`,
      `${outlets.length} outlets, ${SKUS.length} SKUs, ${visits.length} visits`,
      `${ops.tasks.length} tasks (${openTasks} open), ${ops.alerts.length} alerts (${openAlerts} unacknowledged)`,
      `${comms.messages.length} messages, ${comms.announcements.length} announcements`,
    ].join('\n'),
  );

  console.log(
    [
      '',
      'Home-base outlet (live geofence check-in):',
      `  coordinates: ${home.lat}, ${home.lng} (${home.source === 'env' ? 'from DEMO_HOME_LAT/DEMO_HOME_LNG' : 'FALLBACK — set DEMO_HOME_LAT/DEMO_HOME_LNG to use your own'})`,
      `  geofence radius: ${GEOFENCE_RADIUS_M}m — check-in is REJECTED outside it, not merely flagged.`,
      '  Indoor GPS drifts 20-50m, so verify a check-in before demoing rather than during.',
    ].join('\n'),
  );
}
