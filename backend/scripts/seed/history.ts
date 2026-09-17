import { addCalendarDays, isoWeekdayOfCalendarDate } from '../../src/lib/clientTime';
import { haversineDistanceMeters } from '../../src/lib/geofence';
import {
  addMinutes,
  addMonths,
  calendarDaysBetween,
  isWorkday,
  lastWorkdaysOfMonth,
  localInstant,
  monthsAgo as monthsBefore,
  workdaysBetween,
} from './calendar';
import { HOME_OUTLET_ID, OutletSeed } from './catalog';
import { findingsForVisit, AlertRow, TaskRow } from './ops';
import { OrderLineRow, OrderRow, SalesPlan, planStop, takeOrder } from './orders';
import { chance, intBetween, makeRng } from './rng';
import { FRAUD_AGENT_ID, FRAUD_MONTHS, agentProfile } from './scenario';
import {
  CapabilityRow,
  CompetitiveRow,
  PricingRow,
  ScorecardRow,
  StockMemory,
  StockRow,
  VisibilityRow,
  VisitRow,
  captureVisit,
  offsetPoint,
} from './visits';
import { World, campaignAt } from './world';

/**
 * Walks the history one calendar month at a time: every working day, every
 * agent works their route — visits, captures, orders, the tasks and alerts the
 * captures raise, check-in attempts, photo specs and beat plans.
 *
 * A month at a time so the seed never holds two years of rows in memory: the
 * caller inserts a batch and drops it before asking for the next. The random
 * stream is consumed in a fixed order (month → day → agent → stop), so the
 * same world produces the same batches every run.
 */

export interface CheckInRow {
  id: string;
  outletId: string;
  agentId: string;
  lat: number;
  lng: number;
  distanceM: number;
  passed: boolean;
  createdAt: Date;
}

/** A photo to render and store; the image itself is made by `photos.ts`. */
export interface PhotoSpec {
  id: string;
  visitId: string;
  uploadedById: string;
  section: 'visibility' | 'pricing' | 'competitive';
  /** `shelf`: a unique image from `seed`. `reused`: one of the ghost agent's few stock photos. */
  kind: 'shelf' | 'reused';
  seed: number;
  gpsTag: { lat: number; lng: number };
  timestamp: Date;
}

export interface TemplateResponseSpec {
  visitId: string;
  stock: StockRow;
  visibility: VisibilityRow;
  pricing: PricingRow;
  createdAt: Date;
}

export interface BeatPlanRow {
  id: string;
  agentId: string;
  territoryId: string | null;
  name: string;
  scheduledDate: Date;
  status: 'planned' | 'in_progress' | 'completed';
  createdAt: Date;
}

export interface BeatPlanStopRow {
  id: string;
  beatPlanId: string;
  outletId: string;
  sequence: number;
  visited: boolean;
}

export interface MonthBatch {
  month: Date;
  visits: VisitRow[];
  stock: StockRow[];
  pricing: PricingRow[];
  competitive: CompetitiveRow[];
  visibility: VisibilityRow[];
  capability: CapabilityRow[];
  scorecards: ScorecardRow[];
  checkIns: CheckInRow[];
  photos: PhotoSpec[];
  orders: OrderRow[];
  orderLines: OrderLineRow[];
  tasks: TaskRow[];
  alerts: AlertRow[];
  templateResponses: TemplateResponseSpec[];
  beatPlans: BeatPlanRow[];
  beatPlanStops: BeatPlanStopRow[];
}

/** Recent visits carry one real, unique evidence photo; older ones none (see photos.ts). */
export const PHOTO_WINDOW_DAYS = 21;
/** Beat plans are materialised for this many recent weeks, plus the week ahead. */
export const BEAT_PLAN_WEEKS = 12;
const TEMPLATE_RESPONSE_DAYS = 60;
const TEMPLATE_RESPONSE_EVERY = 40;
/** The ghost agent's few gallery photos, reused visit after visit. */
export const REUSED_PHOTO_POOL = 3;
/**
 * Where the ghost agent actually is while "visiting": a spot in Benoni well
 * clear of every outlet, so the photo GPS and the far-away failed check-ins
 * point somewhere a reviewer can see is not a store.
 */
export const FRAUD_HIDEOUT = { lat: -26.1452, lng: 28.4018 };

const DWELL_MINUTES: Readonly<Record<string, readonly [number, number]>> = {
  hypermarket: [25, 45],
  wholesaler: [20, 40],
  supermarket: [15, 35],
  convenience: [10, 22],
  forecourt: [8, 20],
  spaza: [8, 18],
};

const WEEKDAY_NAMES = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

export interface HistoryOptions {
  /** Real JPEG data URL for recent task closures (#209). */
  closurePhotoUrl: string;
}

export function monthKeyOf(date: Date): string {
  return date.toISOString().slice(0, 7);
}

export class HistoryGenerator {
  readonly plan = new SalesPlan();
  private readonly rng = makeRng(987654321);
  private readonly memory = new StockMemory();
  private readonly routePointer = new Map<string, number>();
  private month: Date;
  private visitCounter = 0;
  private orderCounter = 0;
  private taskCounter = 0;
  private alertCounter = 0;
  private attemptCounter = 0;
  private photoCounter = 0;
  private planCounter = 0;
  private readonly now: Date;
  private readonly firstPlanDay: Date;

  constructor(
    private readonly world: World,
    private readonly options: HistoryOptions,
  ) {
    this.month = world.historyStart;
    this.now = localInstant(world.anchor, 0, world.timeZone);
    this.firstPlanDay = addCalendarDays(world.anchor, -7 * BEAT_PLAN_WEEKS);
  }

  /** The next month of history, or null once the anchor's month is done. */
  nextMonth(): MonthBatch | null {
    const { world } = this;
    if (this.month.getTime() > world.anchorMonth.getTime()) return null;
    const month = this.month;
    this.month = addMonths(month, 1);

    const batch: MonthBatch = {
      month, visits: [], stock: [], pricing: [], competitive: [], visibility: [], capability: [],
      scorecards: [], checkIns: [], photos: [], orders: [], orderLines: [], tasks: [], alerts: [],
      templateResponses: [], beatPlans: [], beatPlanStops: [],
    };

    const end = this.month.getTime() < world.anchor.getTime() ? this.month : world.anchor;
    const monthEndDays = new Set(lastWorkdaysOfMonth(month, 3).map((d) => d.getTime()));
    for (const day of workdaysBetween(month, end)) {
      for (const agent of world.agents) {
        this.workDay(batch, agent.id, day, monthEndDays.has(day.getTime()));
      }
    }
    return batch;
  }

  /**
   * Today's and the coming week's plans (no visits yet), and the rest of the
   * anchor month's plan, which the month's sales target is set from.
   */
  upcoming(): { beatPlans: BeatPlanRow[]; beatPlanStops: BeatPlanStopRow[] } {
    const { world } = this;
    const out = { beatPlans: [] as BeatPlanRow[], beatPlanStops: [] as BeatPlanStopRow[] };
    const monthEnd = addMonths(world.anchorMonth, 1);
    const monthEndDays = new Set(lastWorkdaysOfMonth(world.anchorMonth, 3).map((d) => d.getTime()));
    const planUntil = addCalendarDays(world.anchor, 8);
    const lastDay = monthEnd.getTime() > planUntil.getTime() ? monthEnd : planUntil;

    for (let day = world.anchor; day.getTime() < lastDay.getTime(); day = addCalendarDays(day, 1)) {
      if (!isWorkday(day)) continue;
      for (const agent of world.agents) {
        const t = monthsBefore(day, world.anchor);
        const profile = agentProfile(agent.id, world.agentSeed.get(agent.id)!, t);
        let stops = this.nextStops(agent.id, profile.plannedStops);
        if (stops.length === 0) continue;
        const isToday = day.getTime() === world.anchor.getTime();
        if (isToday && agent.id === 'demo-user-agent-1') {
          // The live geofence demo opens at the home-base outlet.
          const home = world.outletById.get(HOME_OUTLET_ID);
          if (home) stops = [home, ...stops.filter((o) => o.id !== HOME_OUTLET_ID)];
        }
        if (day.getTime() < monthEnd.getTime()) {
          for (const outlet of stops) {
            planStop(this.plan, {
              outlet, day, monthKey: monthKeyOf(day), monthsAgo: 0,
              monthEnd: monthEndDays.has(day.getTime()),
            });
          }
        }
        if (day.getTime() < planUntil.getTime()) {
          this.pushPlan(out, agent.id, day, stops, () => false,
            isToday && agent.id === 'demo-user-agent-1' ? 'in_progress' : 'planned');
        }
      }
    }
    return out;
  }

  private nextStops(agentId: string, planned: number): OutletSeed[] {
    const route = this.world.routes.get(agentId) ?? [];
    if (route.length === 0) return [];
    const count = Math.min(planned, route.length);
    const start = this.routePointer.get(agentId) ?? 0;
    this.routePointer.set(agentId, (start + count) % route.length);
    return Array.from({ length: count }, (_, i) => route[(start + i) % route.length]!);
  }

  private pushPlan(
    out: { beatPlans: BeatPlanRow[]; beatPlanStops: BeatPlanStopRow[] },
    agentId: string,
    day: Date,
    stops: OutletSeed[],
    visited: (outletId: string) => boolean,
    status: BeatPlanRow['status'],
  ): void {
    this.planCounter += 1;
    const id = `demo-beatplan-${String(this.planCounter).padStart(6, '0')}`;
    out.beatPlans.push({
      id,
      agentId,
      territoryId: this.world.agentById.get(agentId)?.territoryId ?? null,
      name: `${WEEKDAY_NAMES[isoWeekdayOfCalendarDate(day)]} route`,
      scheduledDate: day,
      status,
      // Plans are drawn up a few days ahead.
      createdAt: localInstant(addCalendarDays(day, -3), 9 * 60, this.world.timeZone),
    });
    stops.forEach((outlet, index) => {
      out.beatPlanStops.push({
        id: `${id}-${index + 1}`,
        beatPlanId: id,
        outletId: outlet.id,
        sequence: index + 1,
        visited: visited(outlet.id),
      });
    });
  }

  private workDay(batch: MonthBatch, agentId: string, day: Date, monthEnd: boolean): void {
    const { world, rng } = this;
    const t = monthsBefore(day, world.anchor);
    const seed = world.agentSeed.get(agentId)!;
    const profile = agentProfile(agentId, seed, t);
    const fraud = agentId === FRAUD_AGENT_ID && t < FRAUD_MONTHS;

    // Leave: the odd day off, and a festive-season week for about a third of the team.
    const month = day.getUTCMonth();
    const date = day.getUTCDate();
    const festiveLeave = seed < 0.35 && ((month === 11 && date >= 22) || (month === 0 && date <= 2));
    const dayOff = chance(rng, 0.025);
    if (festiveLeave || dayOff) return;

    const stops = this.nextStops(agentId, profile.plannedStops);
    if (stops.length === 0) return;

    const monthKey = monthKeyOf(day);
    const visitedIds = new Set<string>();
    let clock = 7 * 60 + 45 + intBetween(rng, 0, 45); // minutes after local midnight
    const isRecent = calendarDaysBetween(day, world.anchor) <= PHOTO_WINDOW_DAYS;

    stops.forEach((outlet, stopIndex) => {
      planStop(this.plan, { outlet, day, monthKey, monthsAgo: t, monthEnd });
      if (!fraud && chance(rng, profile.skipRate)) return;

      if (stopIndex > 0) clock += fraud ? intBetween(rng, 3, 7) : intBetween(rng, 12, 35);
      const [dwellMin, dwellMax] = DWELL_MINUTES[outlet.channelType] ?? [10, 25];
      const checkinTs = localInstant(day, clock + rng(), world.timeZone);
      const dwellSeconds = fraud ? intBetween(rng, 20, 55) : Math.round((dwellMin + rng() * (dwellMax - dwellMin)) * 60);
      const submittedAtClient = new Date(checkinTs.getTime() + dwellSeconds * 1000);
      clock += dwellSeconds / 60;

      this.visitCounter += 1;
      const visitId = `demo-visit-${String(this.visitCounter).padStart(6, '0')}`;
      const campaign = campaignAt(world, outlet.id, day);
      const isProblemOutlet = world.problemOutletIds.has(outlet.id);

      const captured = captureVisit(rng, this.memory, {
        id: visitId,
        outlet,
        agentId,
        day,
        checkinTs,
        submittedAtClient,
        monthsAgo: t,
        profile,
        outletOffset: world.outletOffset.get(outlet.id) ?? 0,
        isProblemOutlet,
        campaign,
        fraud,
      });
      visitedIds.add(outlet.id);

      batch.visits.push(captured.visit);
      batch.stock.push(...captured.stock);
      batch.pricing.push(...captured.pricing);
      batch.competitive.push(...captured.competitive);
      batch.visibility.push(captured.visibility);
      batch.capability.push(captured.capability);
      batch.scorecards.push(captured.scorecard);

      // ── Check-in attempts: the passing one, and the rejections before it ──
      const failures = fraud
        ? (chance(rng, 0.6) ? intBetween(rng, 1, 2) : 0)
        : (chance(rng, 0.03) ? 1 : 0);
      for (let f = 0; f < failures; f += 1) {
        const from = fraud
          ? offsetPoint(rng, FRAUD_HIDEOUT, rng() * 400)
          : offsetPoint(rng, outlet, 55 + rng() * 125);
        this.attemptCounter += 1;
        batch.checkIns.push({
          id: `demo-checkin-${String(this.attemptCounter).padStart(7, '0')}`,
          outletId: outlet.id,
          agentId,
          lat: from.lat,
          lng: from.lng,
          distanceM: Math.round(haversineDistanceMeters(outlet, from)),
          passed: false,
          createdAt: addMinutes(checkinTs, -intBetween(rng, 2, 12) - f * 3),
        });
      }
      this.attemptCounter += 1;
      batch.checkIns.push({
        id: `demo-checkin-${String(this.attemptCounter).padStart(7, '0')}`,
        outletId: outlet.id,
        agentId,
        lat: captured.visit.checkinLat,
        lng: captured.visit.checkinLng,
        distanceM: captured.visit.checkinDistanceM,
        passed: true,
        createdAt: checkinTs,
      });

      // ── Evidence photos ─────────────────────────────────────────────────
      if (fraud) {
        const sections = ['visibility', 'pricing'] as const;
        sections.forEach((section, i) => {
          if (i === 1 && chance(rng, 0.4)) return;
          this.photoCounter += 1;
          batch.photos.push({
            id: `demo-photo-${String(this.photoCounter).padStart(6, '0')}`,
            visitId,
            uploadedById: agentId,
            section,
            kind: 'reused',
            seed: intBetween(rng, 0, REUSED_PHOTO_POOL - 1),
            gpsTag: offsetPoint(rng, FRAUD_HIDEOUT, rng() * 30),
            timestamp: new Date(checkinTs.getTime() + (i + 1) * 8000),
          });
        });
      } else if (isRecent) {
        this.photoCounter += 1;
        batch.photos.push({
          id: `demo-photo-${String(this.photoCounter).padStart(6, '0')}`,
          visitId,
          uploadedById: agentId,
          section: (['visibility', 'pricing', 'competitive'] as const)[this.visitCounter % 3]!,
          kind: 'shelf',
          seed: this.visitCounter,
          gpsTag: offsetPoint(rng, { lat: captured.visit.checkinLat, lng: captured.visit.checkinLng }, rng() * 15),
          timestamp: new Date(checkinTs.getTime() + Math.round(dwellSeconds * (0.3 + rng() * 0.5)) * 1000),
        });
      }

      // ── Sell-in ─────────────────────────────────────────────────────────
      this.orderCounter += 1;
      const taken = takeOrder(rng, {
        orderId: `demo-order-${String(this.orderCounter).padStart(6, '0')}`,
        visitId,
        agentId,
        agentSalesFactor: profile.salesFactor,
        submittedAtClient,
        campaign,
        anchor: world.anchor,
        timeZone: world.timeZone,
        outlet,
        day,
        monthKey,
        monthsAgo: t,
        monthEnd,
      });
      if (taken) {
        batch.orders.push(taken.order);
        batch.orderLines.push(...taken.lines);
      } else {
        this.orderCounter -= 1;
      }

      // ── Tasks and alerts from what was found ────────────────────────────
      const found = findingsForVisit(rng, {
        captured,
        outlet,
        ownerProfile: profile,
        isProblemOutlet,
        now: this.now,
        closurePhotoUrl: this.options.closurePhotoUrl,
        nextTaskId: () => `demo-task-${String(++this.taskCounter).padStart(6, '0')}`,
        nextAlertId: () => `demo-alert-${String(++this.alertCounter).padStart(6, '0')}`,
      });
      batch.tasks.push(...found.tasks);
      batch.alerts.push(...found.alerts);

      if (
        calendarDaysBetween(day, world.anchor) <= TEMPLATE_RESPONSE_DAYS &&
        this.visitCounter % TEMPLATE_RESPONSE_EVERY === 0
      ) {
        batch.templateResponses.push({
          visitId,
          stock: captured.stock[0]!,
          visibility: captured.visibility,
          pricing: captured.pricing[0]!,
          createdAt: checkinTs,
        });
      }
    });

    if (day.getTime() >= this.firstPlanDay.getTime()) {
      this.pushPlan(batch, agentId, day, stops, (id) => visitedIds.has(id), 'completed');
    }
  }
}
