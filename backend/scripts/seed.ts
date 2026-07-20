// backend/scripts/seed.ts
import { PrismaClient, Prisma, TaskPriority, TaskStatus } from '@prisma/client';
import { hashPassword } from '../src/modules/auth/auth.service';

const prisma = new PrismaClient();

// ---------------------------------------------------------------------------
// Fixed reference dates. Everything is a literal so re-seeding is idempotent
// (no Date.now()/new Date() with no args that would drift between runs).
// ---------------------------------------------------------------------------
const PROMO_ACTIVE_FROM = new Date('2026-07-01T00:00:00.000Z');
const PROMO_ACTIVE_TO = new Date('2026-07-31T23:59:59.000Z');
const VISIT_1_TS = new Date('2026-07-06T08:15:00.000Z');
const VISIT_2_TS = new Date('2026-07-07T09:40:00.000Z');
const VISIT_3_TS = new Date('2026-07-08T11:05:00.000Z');
const SLA_DUE_OPEN = new Date('2026-07-15T17:00:00.000Z');
const SLA_DUE_CLOSED = new Date('2026-07-09T17:00:00.000Z');

// ---------------------------------------------------------------------------
// Seed data shapes (typed so we stay strict/no-any).
// ---------------------------------------------------------------------------
interface OutletSeed {
  id: string;
  name: string;
  code: string;
  channelType: string;
  /// Share of category turnover. A hypermarket is not one kiosk (#93).
  acvWeight: number;
  lat: number;
  lng: number;
}

interface SkuSeed {
  id: string;
  name: string;
  category: string;
  minFacingsStandard: number;
  rrp: number;
}

interface StockSeed {
  skuId: string;
  unitsAvailable: number;
  lastStockinDate: Date;
  daysOutOfStock: number;
  velocityAvg: number;
  coverageDaysPredicted: number;
  salesActual: number;
  salesTarget: number;
}

interface PricingSeed {
  skuId: string;
  priceActual: number;
  priceMaster: number;
  deviationPct: number;
  promoActive: boolean;
  promoMaterialsDetected: Prisma.InputJsonValue;
  commsRating: number;
}

interface CompetitiveSeed {
  competitorSku: string;
  competitorPrice: number;
  /// Facings this competitor holds — the denominator of a real share of shelf.
  facingsCount: number;
  competitorPosmType: string;
  competitorPromoterPresent: boolean;
  geotag: Prisma.InputJsonValue;
}

interface RiskSeed {
  flagType: string;
  severity: string;
  note: string;
}

interface TaskSeed {
  suffix: string;
  findingType: string;
  outletIndex: number;
  requiredFix: string;
  priority: TaskPriority;
  slaDueAt: Date;
  status: TaskStatus;
  closurePhotoUrl?: string;
  closureVerified: boolean;
}

interface VisitSeed {
  id: string;
  outletIndex: number;
  checkinTs: Date;
  checkinLat: number;
  checkinLng: number;
  geofencePass: boolean;
  checkinDistanceM: number;
  stock: StockSeed[];
  visibility: {
    brandingElements: Prisma.InputJsonValue;
    planogramCompliancePct: number;
    facingsCount: Prisma.InputJsonValue;
    highTrafficPass: boolean;
    cleanlinessScore: number;
  };
  pricing: PricingSeed[];
  competitive: CompetitiveSeed[];
  capability: {
    staffHeadcountConfirmed: number;
    repTrainingStatus: Prisma.InputJsonValue;
    quizScore: number;
  };
  risks: RiskSeed[];
  scorecard: {
    dimensionScores: Prisma.InputJsonValue;
    weightedTotal: number;
    ratingBand: string;
  };
  photo: {
    section: string;
    url: string;
    gpsTag: Prisma.InputJsonValue;
    timestamp: Date;
  };
  tasks: TaskSeed[];
}

async function main() {
  const client = await prisma.client.upsert({
    where: { id: 'demo-fmcg-client' },
    update: {},
    create: {
      id: 'demo-fmcg-client',
      name: 'Demo FMCG Brand',
      industry: 'FMCG',
      scorecardWeights: {
        availability: 0.3,
        visibility: 0.25,
        display: 0.15,
        pricing: 0.1,
        salesCapability: 0.1,
        competitive: 0.1,
      },
      // These are the four keys the code actually reads:
      //   green / amber        -> scorecard RAG bands (scorecards.service.ts)
      //   stockoutUnits        -> auto-task trigger (stock.service.ts)
      //   priceDeviationPct    -> auto-task trigger (pricing.service.ts)
      // The seed previously wrote excellent/good/needsImprovement, which no
      // code path reads — the bands silently fell back to their defaults, so
      // the "configurable" thresholds were inert. The values below are those
      // same defaults, now spelled the way the engine reads them (#46).
      kpiThresholds: {
        green: 80,
        amber: 60,
        stockoutUnits: 0,
        priceDeviationPct: 10,
      },
    },
  });

  // The demo client had a manager and an agent and no admin at all — and since
  // POST /users is admin-only and there is no public registration, nobody could
  // create one either. Scoring config, user management and webhooks were locked
  // behind a role that did not exist.
  //
  // For a real deployment, `npm run create-admin` mints the first one. This is
  // the demo's.
  const admin = await prisma.user.upsert({
    where: { email: 'admin@demo-fmcg.tradeiq.com' },
    update: {},
    create: {
      email: 'admin@demo-fmcg.tradeiq.com',
      passwordHash: await hashPassword('demo-password-123'),
      role: 'admin',
      clientId: client.id,
    },
  });

  const manager = await prisma.user.upsert({
    where: { email: 'manager@demo-fmcg.tradeiq.com' },
    update: {},
    create: {
      email: 'manager@demo-fmcg.tradeiq.com',
      passwordHash: await hashPassword('demo-password-123'),
      role: 'manager',
      clientId: client.id,
    },
  });

  const agent = await prisma.user.upsert({
    where: { email: 'agent@demo-fmcg.tradeiq.com' },
    update: {},
    create: {
      email: 'agent@demo-fmcg.tradeiq.com',
      passwordHash: await hashPassword('demo-password-123'),
      role: 'field_agent',
      clientId: client.id,
    },
  });

  // -------------------------------------------------------------------------
  // Outlets — stable ids so visits/tasks reference them deterministically.
  // -------------------------------------------------------------------------
  const outletSeeds: OutletSeed[] = [
    { id: 'demo-outlet-1', name: 'Sandton Hypermarket', code: 'SAN-001', channelType: 'hypermarket', lat: -26.1076, lng: 28.0567, acvWeight: 6.0 },
    { id: 'demo-outlet-2', name: 'Rosebank Supermarket', code: 'ROS-002', channelType: 'supermarket', lat: -26.1467, lng: 28.0436, acvWeight: 3.0 },
    { id: 'demo-outlet-3', name: 'Fourways Convenience', code: 'FOU-003', channelType: 'convenience', lat: -26.0164, lng: 28.0122, acvWeight: 1.0 },
  ];

  const outlets = [];
  for (const outlet of outletSeeds) {
    const record = await prisma.outlet.upsert({
      where: { code: outlet.code },
      update: {},
      create: {
        id: outlet.id,
        name: outlet.name,
        code: outlet.code,
        channelType: outlet.channelType,
        acvWeight: outlet.acvWeight,
        lat: outlet.lat,
        lng: outlet.lng,
        territoryId: 'gauteng-north',
        teamProfile: { headcount: 4 },
        clientId: client.id,
      },
    });
    outlets.push(record);
  }

  // -------------------------------------------------------------------------
  // Planogram templates — realistic shelf-zone maps for the client.
  // -------------------------------------------------------------------------
  const planogramSeeds = [
    {
      id: 'demo-planogram-1',
      zoneMap: {
        fixture: 'Main beverage aisle — 4-shelf gondola',
        zones: [
          { zone: 'eye', shelf: 2, skus: ['demo-sku-1', 'demo-sku-2'], facings: 8 },
          { zone: 'reach', shelf: 3, skus: ['demo-sku-5'], facings: 4 },
          { zone: 'stoop', shelf: 4, skus: ['demo-sku-2'], facings: 3 },
        ],
      },
    },
    {
      id: 'demo-planogram-2',
      zoneMap: {
        fixture: 'Front-of-store snack end-cap',
        zones: [
          { zone: 'eye', shelf: 1, skus: ['demo-sku-4'], facings: 8 },
          { zone: 'reach', shelf: 2, skus: ['demo-sku-3'], facings: 6 },
        ],
      },
    },
  ];

  for (const planogram of planogramSeeds) {
    await prisma.planogramTemplate.upsert({
      where: { id: planogram.id },
      update: {},
      create: {
        id: planogram.id,
        clientId: client.id,
        zoneMap: planogram.zoneMap,
      },
    });
  }

  // -------------------------------------------------------------------------
  // Promo calendar — active window spans "now" (fixed July 2026 dates).
  // -------------------------------------------------------------------------
  const promoSeeds = [
    {
      id: 'demo-promo-1',
      promoName: 'Winter Warmer Beverage Bundle',
      activeFrom: PROMO_ACTIVE_FROM,
      activeTo: PROMO_ACTIVE_TO,
      requiredPosm: { poster: true, shelfStrip: true, wobbler: false },
      outletScope: { outletCodes: ['SAN-001', 'ROS-002', 'FOU-003'] },
    },
    {
      id: 'demo-promo-2',
      promoName: 'Snack Attack Two-for-One',
      activeFrom: PROMO_ACTIVE_FROM,
      activeTo: PROMO_ACTIVE_TO,
      requiredPosm: { poster: true, shelfStrip: false, floorDecal: true },
      outletScope: { outletCodes: ['SAN-001', 'ROS-002'] },
    },
  ];

  for (const promo of promoSeeds) {
    await prisma.promoCalendar.upsert({
      where: { id: promo.id },
      update: {},
      create: {
        id: promo.id,
        clientId: client.id,
        promoName: promo.promoName,
        activeFrom: promo.activeFrom,
        activeTo: promo.activeTo,
        requiredPosm: promo.requiredPosm,
        outletScope: promo.outletScope,
      },
    });
  }

  // -------------------------------------------------------------------------
  // SKUs — ~5 realistic FMCG lines, stable ids demo-sku-1..5.
  // -------------------------------------------------------------------------
  const skuSeeds: SkuSeed[] = [
    { id: 'demo-sku-1', name: 'Demo Cola 500ml', category: 'Beverages', minFacingsStandard: 4, rrp: 24.99 },
    { id: 'demo-sku-2', name: 'Demo Cola 1L', category: 'Beverages', minFacingsStandard: 3, rrp: 34.99 },
    { id: 'demo-sku-3', name: 'Crunchy Chips 125g', category: 'Snacks', minFacingsStandard: 6, rrp: 18.5 },
    { id: 'demo-sku-4', name: 'Choco Bar 50g', category: 'Snacks', minFacingsStandard: 8, rrp: 12.99 },
    { id: 'demo-sku-5', name: 'Sparkling Water 750ml', category: 'Beverages', minFacingsStandard: 4, rrp: 15.99 },
  ];

  for (const sku of skuSeeds) {
    await prisma.sku.upsert({
      where: { id: sku.id },
      update: {},
      create: {
        id: sku.id,
        clientId: client.id,
        name: sku.name,
        category: sku.category,
        minFacingsStandard: sku.minFacingsStandard,
        rrp: sku.rrp,
      },
    });
  }

  // -------------------------------------------------------------------------
  // Demo visits — 3 submitted visits across the 3 outlets, each with a full
  // set of section rows so scorecards/dashboard KPIs compute to a realistic
  // green/amber/red spread. Scorecard bands (defaults, since kpiThresholds
  // has no green/amber keys): green >= 80, amber >= 60, red < 60.
  // -------------------------------------------------------------------------
  const visitSeeds: VisitSeed[] = [
    // Visit 1 — Sandton Hypermarket: strong execution (green).
    {
      id: 'demo-visit-1',
      outletIndex: 0,
      checkinTs: VISIT_1_TS,
      checkinLat: -26.1075,
      checkinLng: 28.0568,
      geofencePass: true,
      checkinDistanceM: 12,
      stock: [
        { skuId: 'demo-sku-1', unitsAvailable: 48, lastStockinDate: new Date('2026-07-05T07:00:00.000Z'), daysOutOfStock: 0, velocityAvg: 9.5, coverageDaysPredicted: 5.1, salesActual: 1180, salesTarget: 1200 },
        { skuId: 'demo-sku-2', unitsAvailable: 30, lastStockinDate: new Date('2026-07-05T07:00:00.000Z'), daysOutOfStock: 0, velocityAvg: 6.0, coverageDaysPredicted: 5.0, salesActual: 900, salesTarget: 950 },
        { skuId: 'demo-sku-3', unitsAvailable: 60, lastStockinDate: new Date('2026-07-04T07:00:00.000Z'), daysOutOfStock: 0, velocityAvg: 12.0, coverageDaysPredicted: 5.0, salesActual: 1050, salesTarget: 1000 },
        { skuId: 'demo-sku-4', unitsAvailable: 80, lastStockinDate: new Date('2026-07-04T07:00:00.000Z'), daysOutOfStock: 0, velocityAvg: 20.0, coverageDaysPredicted: 4.0, salesActual: 990, salesTarget: 1000 },
      ],
      visibility: {
        brandingElements: { poster: true, shelfStrip: true, wobbler: true, endCap: true },
        planogramCompliancePct: 92,
        facingsCount: { total: 23, byZone: { eye: 12, reach: 7, stoop: 4 } },
        highTrafficPass: true,
        cleanlinessScore: 5,
      },
      pricing: [
        { skuId: 'demo-sku-1', priceActual: 24.99, priceMaster: 24.99, deviationPct: 0, promoActive: true, promoMaterialsDetected: { poster: true, shelfStrip: true }, commsRating: 5 },
        { skuId: 'demo-sku-2', priceActual: 35.99, priceMaster: 34.99, deviationPct: 2.86, promoActive: false, promoMaterialsDetected: { poster: false }, commsRating: 4 },
        { skuId: 'demo-sku-3', priceActual: 18.5, priceMaster: 18.5, deviationPct: 0, promoActive: false, promoMaterialsDetected: { poster: false }, commsRating: 5 },
      ],
      competitive: [
        { competitorSku: 'RivalCola 500ml', competitorPrice: 22.99, facingsCount: 4, competitorPosmType: 'shelf_strip', competitorPromoterPresent: false, geotag: { lat: -26.1075, lng: 28.0568 } },
      ],
      capability: {
        staffHeadcountConfirmed: 4,
        repTrainingStatus: { onboarded: true, planogramCertified: true, promoBriefed: true },
        quizScore: 84,
      },
      risks: [
        { flagType: 'price_deviation', severity: 'low', note: 'Demo Cola 1L priced R1 above master; within tolerance but flag for review.' },
      ],
      scorecard: {
        dimensionScores: { availability: 100, visibility: 92, display: 100, pricing: 99, competitive: 100, salesCapability: 84 },
        weightedTotal: 86,
        ratingBand: 'green',
      },
      photo: {
        section: 'visibility',
        url: 'https://demo.tradeiq.local/photos/demo-visit-1-shelf.jpg',
        gpsTag: { lat: -26.1075, lng: 28.0568 },
        timestamp: VISIT_1_TS,
      },
      tasks: [
        {
          suffix: 'price-review',
          findingType: 'price_deviation',
          outletIndex: 0,
          requiredFix: 'Confirm Demo Cola 1L shelf price against master price list and reprint tag.',
          priority: TaskPriority.normal,
          slaDueAt: SLA_DUE_CLOSED,
          status: TaskStatus.closed,
          closurePhotoUrl: 'https://demo.tradeiq.local/photos/demo-visit-1-price-fixed.jpg',
          closureVerified: true,
        },
      ],
    },
    // Visit 2 — Rosebank Supermarket: mixed execution (amber).
    {
      id: 'demo-visit-2',
      outletIndex: 1,
      checkinTs: VISIT_2_TS,
      checkinLat: -26.1468,
      checkinLng: 28.0435,
      geofencePass: true,
      checkinDistanceM: 28,
      stock: [
        { skuId: 'demo-sku-1', unitsAvailable: 22, lastStockinDate: new Date('2026-07-06T07:30:00.000Z'), daysOutOfStock: 0, velocityAvg: 8.0, coverageDaysPredicted: 2.75, salesActual: 760, salesTarget: 1000 },
        { skuId: 'demo-sku-2', unitsAvailable: 15, lastStockinDate: new Date('2026-07-06T07:30:00.000Z'), daysOutOfStock: 0, velocityAvg: 5.0, coverageDaysPredicted: 3.0, salesActual: 640, salesTarget: 900 },
        { skuId: 'demo-sku-3', unitsAvailable: 0, lastStockinDate: new Date('2026-07-03T07:30:00.000Z'), daysOutOfStock: 2, velocityAvg: 11.0, coverageDaysPredicted: 0, salesActual: 420, salesTarget: 950 },
      ],
      visibility: {
        brandingElements: { poster: true, shelfStrip: true, wobbler: false, endCap: false },
        planogramCompliancePct: 70,
        facingsCount: { total: 14, byZone: { eye: 6, reach: 5, stoop: 3 } },
        highTrafficPass: true,
        cleanlinessScore: 4,
      },
      pricing: [
        { skuId: 'demo-sku-1', priceActual: 25.99, priceMaster: 24.99, deviationPct: 4.0, promoActive: true, promoMaterialsDetected: { poster: true, shelfStrip: false }, commsRating: 3 },
        { skuId: 'demo-sku-2', priceActual: 33.49, priceMaster: 34.99, deviationPct: -4.29, promoActive: false, promoMaterialsDetected: { poster: false }, commsRating: 4 },
      ],
      competitive: [
        { competitorSku: 'RivalCola 1L', competitorPrice: 31.99, facingsCount: 9, competitorPosmType: 'poster', competitorPromoterPresent: true, geotag: { lat: -26.1468, lng: 28.0435 } },
      ],
      capability: {
        staffHeadcountConfirmed: 3,
        repTrainingStatus: { onboarded: true, planogramCertified: false, promoBriefed: true },
        quizScore: 58,
      },
      risks: [
        { flagType: 'out_of_stock', severity: 'medium', note: 'Crunchy Chips 125g out of stock for 2 days; back-order pending.' },
      ],
      scorecard: {
        dimensionScores: { availability: 67, visibility: 70, display: 80, pricing: 96, competitive: 100, salesCapability: 58 },
        weightedTotal: 72,
        ratingBand: 'amber',
      },
      photo: {
        section: 'availability',
        url: 'https://demo.tradeiq.local/photos/demo-visit-2-gap.jpg',
        gpsTag: { lat: -26.1468, lng: 28.0435 },
        timestamp: VISIT_2_TS,
      },
      tasks: [
        {
          suffix: 'restock-chips',
          findingType: 'out_of_stock',
          outletIndex: 1,
          requiredFix: 'Expedite Crunchy Chips 125g replenishment and confirm shelf fill.',
          priority: TaskPriority.high,
          slaDueAt: SLA_DUE_OPEN,
          status: TaskStatus.open,
          closureVerified: false,
        },
      ],
    },
    // Visit 3 — Fourways Convenience: weak execution (red).
    {
      id: 'demo-visit-3',
      outletIndex: 2,
      checkinTs: VISIT_3_TS,
      checkinLat: -26.0166,
      checkinLng: 28.0125,
      geofencePass: false,
      checkinDistanceM: 140,
      stock: [
        { skuId: 'demo-sku-1', unitsAvailable: 6, lastStockinDate: new Date('2026-07-07T08:00:00.000Z'), daysOutOfStock: 0, velocityAvg: 4.0, coverageDaysPredicted: 1.5, salesActual: 300, salesTarget: 800 },
        { skuId: 'demo-sku-2', unitsAvailable: 0, lastStockinDate: new Date('2026-07-01T08:00:00.000Z'), daysOutOfStock: 5, velocityAvg: 3.0, coverageDaysPredicted: 0, salesActual: 120, salesTarget: 700 },
        { skuId: 'demo-sku-4', unitsAvailable: 0, lastStockinDate: new Date('2026-07-02T08:00:00.000Z'), daysOutOfStock: 4, velocityAvg: 9.0, coverageDaysPredicted: 0, salesActual: 210, salesTarget: 800 },
        { skuId: 'demo-sku-5', unitsAvailable: 18, lastStockinDate: new Date('2026-07-07T08:00:00.000Z'), daysOutOfStock: 0, velocityAvg: 5.0, coverageDaysPredicted: 3.6, salesActual: 360, salesTarget: 600 },
      ],
      visibility: {
        brandingElements: { poster: false, shelfStrip: false, wobbler: false, endCap: false },
        planogramCompliancePct: 45,
        facingsCount: { total: 7, byZone: { eye: 2, reach: 3, stoop: 2 } },
        highTrafficPass: false,
        cleanlinessScore: 3,
      },
      pricing: [
        { skuId: 'demo-sku-1', priceActual: 27.99, priceMaster: 24.99, deviationPct: 12.0, promoActive: false, promoMaterialsDetected: { poster: false }, commsRating: 2 },
        { skuId: 'demo-sku-5', priceActual: 17.49, priceMaster: 15.99, deviationPct: 9.38, promoActive: false, promoMaterialsDetected: { poster: false }, commsRating: 2 },
      ],
      competitive: [
        { competitorSku: 'RivalCola 500ml', competitorPrice: 21.99, facingsCount: 12, competitorPosmType: 'end_cap', competitorPromoterPresent: true, geotag: { lat: -26.0166, lng: 28.0125 } },
        { competitorSku: 'BudgetChips 150g', competitorPrice: 15.99, facingsCount: 6, competitorPosmType: 'floor_stack', competitorPromoterPresent: false, geotag: { lat: -26.0166, lng: 28.0125 } },
      ],
      capability: {
        staffHeadcountConfirmed: 2,
        repTrainingStatus: { onboarded: true, planogramCertified: false, promoBriefed: false },
        quizScore: 41,
      },
      risks: [
        { flagType: 'geofence_fail', severity: 'high', note: 'Check-in recorded 140m outside outlet geofence.' },
        { flagType: 'price_deviation', severity: 'high', note: 'Demo Cola 500ml priced 12% above master price.' },
      ],
      scorecard: {
        dimensionScores: { availability: 50, visibility: 45, display: 60, pricing: 89, competitive: 100, salesCapability: 41 },
        weightedTotal: 56,
        ratingBand: 'red',
      },
      photo: {
        section: 'competitive',
        url: 'https://demo.tradeiq.local/photos/demo-visit-3-competitor.jpg',
        gpsTag: { lat: -26.0166, lng: 28.0125 },
        timestamp: VISIT_3_TS,
      },
      tasks: [
        {
          suffix: 'price-correct',
          findingType: 'price_deviation',
          outletIndex: 2,
          requiredFix: 'Correct Demo Cola 500ml shelf price to master (R24.99) and remove overcharge tag.',
          priority: TaskPriority.critical,
          slaDueAt: SLA_DUE_OPEN,
          status: TaskStatus.open,
          closureVerified: false,
        },
      ],
    },
  ];

  let stockCount = 0;
  let pricingCount = 0;
  let competitiveCount = 0;
  let riskCount = 0;
  let taskCount = 0;

  for (const visit of visitSeeds) {
    const outlet = outlets[visit.outletIndex];

    await prisma.visit.upsert({
      where: { id: visit.id },
      update: {},
      create: {
        id: visit.id,
        outletId: outlet.id,
        agentId: agent.id,
        clientId: client.id,
        checkinTs: visit.checkinTs,
        checkinLat: visit.checkinLat,
        checkinLng: visit.checkinLng,
        checkinDistanceM: visit.checkinDistanceM,
        geofencePass: visit.geofencePass,
        status: 'submitted',
      },
    });

    for (const row of visit.stock) {
      await prisma.visitStock.upsert({
        where: { id: `${visit.id}-stock-${row.skuId}` },
        update: {},
        create: {
          id: `${visit.id}-stock-${row.skuId}`,
          visitId: visit.id,
          skuId: row.skuId,
          unitsAvailable: row.unitsAvailable,
          lastStockinDate: row.lastStockinDate,
          daysOutOfStock: row.daysOutOfStock,
          velocityAvg: row.velocityAvg,
          coverageDaysPredicted: row.coverageDaysPredicted,
          salesActual: row.salesActual,
          salesTarget: row.salesTarget,
        },
      });
      stockCount += 1;
    }

    await prisma.visitVisibility.upsert({
      where: { id: `${visit.id}-visibility` },
      update: {},
      create: {
        id: `${visit.id}-visibility`,
        visitId: visit.id,
        brandingElements: visit.visibility.brandingElements,
        planogramCompliancePct: visit.visibility.planogramCompliancePct,
        facingsCount: visit.visibility.facingsCount,
        highTrafficPass: visit.visibility.highTrafficPass,
        cleanlinessScore: visit.visibility.cleanlinessScore,
      },
    });

    for (const row of visit.pricing) {
      await prisma.visitPricing.upsert({
        where: { id: `${visit.id}-pricing-${row.skuId}` },
        update: {},
        create: {
          id: `${visit.id}-pricing-${row.skuId}`,
          visitId: visit.id,
          skuId: row.skuId,
          priceActual: row.priceActual,
          priceMaster: row.priceMaster,
          deviationPct: row.deviationPct,
          promoActive: row.promoActive,
          promoMaterialsDetected: row.promoMaterialsDetected,
          commsRating: row.commsRating,
        },
      });
      pricingCount += 1;
    }

    let competitiveIndex = 0;
    for (const row of visit.competitive) {
      await prisma.visitCompetitive.upsert({
        where: { id: `${visit.id}-competitive-${competitiveIndex}` },
        update: {},
        create: {
          id: `${visit.id}-competitive-${competitiveIndex}`,
          visitId: visit.id,
          competitorSku: row.competitorSku,
          facingsCount: row.facingsCount,
          competitorPrice: row.competitorPrice,
          competitorPosmType: row.competitorPosmType,
          competitorPromoterPresent: row.competitorPromoterPresent,
          geotag: row.geotag,
        },
      });
      competitiveIndex += 1;
      competitiveCount += 1;
    }

    await prisma.visitCapability.upsert({
      where: { id: `${visit.id}-capability` },
      update: {},
      create: {
        id: `${visit.id}-capability`,
        visitId: visit.id,
        staffHeadcountConfirmed: visit.capability.staffHeadcountConfirmed,
        repTrainingStatus: visit.capability.repTrainingStatus,
        quizScore: visit.capability.quizScore,
      },
    });

    let riskIndex = 0;
    for (const row of visit.risks) {
      await prisma.visitRisk.upsert({
        where: { id: `${visit.id}-risk-${riskIndex}` },
        update: {},
        create: {
          id: `${visit.id}-risk-${riskIndex}`,
          visitId: visit.id,
          flagType: row.flagType,
          severity: row.severity,
          note: row.note,
        },
      });
      riskIndex += 1;
      riskCount += 1;
    }

    await prisma.photo.upsert({
      where: { id: `${visit.id}-photo` },
      update: {},
      create: {
        id: `${visit.id}-photo`,
        visitId: visit.id,
        section: visit.photo.section,
        url: visit.photo.url,
        gpsTag: visit.photo.gpsTag,
        timestamp: visit.photo.timestamp,
      },
    });

    await prisma.scorecard.upsert({
      where: { visitId: visit.id },
      update: {},
      create: {
        id: `${visit.id}-scorecard`,
        visitId: visit.id,
        dimensionScores: visit.scorecard.dimensionScores,
        weightedTotal: visit.scorecard.weightedTotal,
        ratingBand: visit.scorecard.ratingBand,
      },
    });

    for (const task of visit.tasks) {
      await prisma.task.upsert({
        where: { id: `${visit.id}-task-${task.suffix}` },
        update: {},
        create: {
          id: `${visit.id}-task-${task.suffix}`,
          visitId: visit.id,
          findingType: task.findingType,
          outletId: outlets[task.outletIndex].id,
          requiredFix: task.requiredFix,
          priority: task.priority,
          slaDueAt: task.slaDueAt,
          ownerId: agent.id,
          status: task.status,
          closurePhotoUrl: task.closurePhotoUrl ?? null,
          closureVerified: task.closureVerified,
        },
      });
      taskCount += 1;
    }
  }

  // ── Phase 3 (Activation) demo data ──────────────────────────────────────
  // A territory matching the outlets' territoryId, an agent assignment, a
  // campaign across all outlets, a beat plan, an alert rule, and an audit
  // template. Stable ids + upserts keep re-seeding idempotent.
  const territory = await prisma.territory.upsert({
    where: { clientId_code: { clientId: client.id, code: 'gauteng-north' } },
    update: {},
    create: {
      id: 'demo-territory-1',
      clientId: client.id,
      name: 'Gauteng North',
      code: 'gauteng-north',
      region: 'Gauteng',
    },
  });

  await prisma.userTerritory.upsert({
    where: { userId_territoryId: { userId: agent.id, territoryId: territory.id } },
    update: {},
    create: { id: 'demo-user-territory-1', userId: agent.id, territoryId: territory.id },
  });

  await prisma.campaign.upsert({
    where: { id: 'demo-campaign-1' },
    update: {},
    create: {
      id: 'demo-campaign-1',
      clientId: client.id,
      name: 'Winter Chill Activation',
      objective: 'Drive availability + secondary display for the 500ml/1L range',
      startDate: PROMO_ACTIVE_FROM,
      endDate: PROMO_ACTIVE_TO,
      budget: 50000,
      status: 'active',
    },
  });
  for (const outlet of outlets) {
    await prisma.campaignOutlet.upsert({
      where: { campaignId_outletId: { campaignId: 'demo-campaign-1', outletId: outlet.id } },
      update: {},
      create: {
        id: `demo-campaign-1-${outlet.id}`,
        campaignId: 'demo-campaign-1',
        outletId: outlet.id,
      },
    });
  }

  // Dated to whenever the seed runs, not a fixed day.
  //
  // The agent's home screen shows the plan whose *local* date is today and
  // otherwise says nobody planned a route. A hardcoded date therefore left
  // every demo and every tester looking at an empty home screen on every day
  // but one — which reads as "the app is broken", not "no route today".
  //
  // 06:00 UTC is 08:00 SAST: inside the working day in the tenant's timezone,
  // so the local-date comparison lands on the intended day rather than
  // slipping either side of midnight.
  const now = new Date();
  const beatPlanDate = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 6, 0, 0),
  );

  await prisma.beatPlan.upsert({
    where: { id: 'demo-beatplan-1' },
    // Re-dated on every reseed. With `update: {}` an already-seeded database
    // would keep its original date forever, so the fix would never reach the
    // environments that need it most.
    update: { scheduledDate: beatPlanDate },
    create: {
      id: 'demo-beatplan-1',
      clientId: client.id,
      agentId: agent.id,
      territoryId: territory.id,
      name: 'Gauteng North — Mon route',
      scheduledDate: beatPlanDate,
      status: 'planned',
    },
  });
  for (let i = 0; i < outlets.length; i += 1) {
    await prisma.beatPlanStop.upsert({
      where: { id: `demo-beatplan-1-stop-${i + 1}` },
      update: {},
      create: {
        id: `demo-beatplan-1-stop-${i + 1}`,
        beatPlanId: 'demo-beatplan-1',
        outletId: outlets[i].id,
        sequence: i + 1,
        visited: i === 0,
      },
    });
  }

  await prisma.alertRule.upsert({
    where: { id: 'demo-alert-rule-1' },
    update: {},
    create: {
      id: 'demo-alert-rule-1',
      clientId: client.id,
      name: 'Out-of-stock on any SKU',
      metric: 'out_of_stock',
      severity: 'high',
      active: true,
    },
  });

  await prisma.auditTemplate.upsert({
    where: { id: 'demo-audit-template-1' },
    update: {},
    create: {
      id: 'demo-audit-template-1',
      clientId: client.id,
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

  console.log(
    [
      `Seeded client ${client.name}`,
      `users: admin ${admin.email} + manager ${manager.email} + agent ${agent.email}`,
      'all three sign in with: demo-password-123',
      `${outlets.length} outlets`,
      `${skuSeeds.length} SKUs`,
      `${planogramSeeds.length} planogram templates`,
      `${promoSeeds.length} promotions`,
      `${visitSeeds.length} submitted visits`,
      `${stockCount} stock rows`,
      `${pricingCount} pricing rows`,
      `${competitiveCount} competitive rows`,
      `${riskCount} risk flags`,
      `${visitSeeds.length} visibility + ${visitSeeds.length} capability + ${visitSeeds.length} scorecard + ${visitSeeds.length} photo rows`,
      `${taskCount} tasks`,
      `Phase 3: 1 territory + 1 campaign (${outlets.length} outlets) + 1 beat plan + 1 alert rule + 1 audit template`,
    ].join(', '),
  );
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
