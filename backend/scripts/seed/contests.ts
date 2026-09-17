import { addCalendarDays } from '../../src/lib/clientTime';
import { addMonths, dayOfMonth, daysInMonth, localInstant } from './calendar';
import { TERRITORY_ID_BY_CODE } from './catalog';
import { World } from './world';

/**
 * Contests over the points ledger (#124): active, recently ended, upcoming and
 * one cancelled, so every state the console and the assistant can meet exists.
 *
 * Dates are calendar dates, inclusive local days (#124, the campaign-window
 * rule). Standings are not stored — they are computed from the ledger the seed
 * backfills — so each contest is placed and scoped to make a particular story
 * readable:
 * - the visit sprint counts visits only, where the ghost-visit agent sits near
 *   the top, and he leads the (cancelled) Gauteng East spot prize outright;
 * - the execution cup counts the average execution score only, which the
 *   standout agent wins.
 */

export interface ContestRow {
  id: string;
  name: string;
  description: string;
  prizeDescription: string;
  startDate: Date;
  endDate: Date;
  territoryId: string | null;
  eventTypes: string[];
  createdById: string;
  cancelledAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

export function buildContests(world: World): ContestRow[] {
  const m0 = world.anchorMonth;
  const endOf = (month: Date) => dayOfMonth(month, daysInMonth(month));
  const monthName = (month: Date) => `${MONTHS[month.getUTCMonth()]} ${month.getUTCFullYear()}`;
  const quarterStart = addMonths(m0, -(m0.getUTCMonth() % 3));
  const quarter = Math.floor(m0.getUTCMonth() / 3) + 1;
  const lastMonth = addMonths(m0, -1);
  const created = (day: Date) => localInstant(addCalendarDays(day, -7), 9 * 60, world.timeZone);

  const winterWarmer = world.campaigns.find((c) => c.id === 'demo-campaign-winter-warmer')!;

  const rows: Array<Omit<ContestRow, 'createdAt' | 'updatedAt'>> = [
    {
      id: 'demo-contest-visit-sprint',
      name: `${MONTHS[m0.getUTCMonth()]} Visit Sprint`,
      description: 'Most submitted visits this month wins. Every visit counts.',
      prizeDescription: 'R1,500 fuel card',
      startDate: m0,
      endDate: endOf(m0),
      territoryId: null,
      eventTypes: ['visit_submitted'],
      createdById: 'demo-user-mgr-1',
      cancelledAt: null,
    },
    {
      id: 'demo-contest-perfect-store-quarter',
      name: `Q${quarter} ${m0.getUTCFullYear()} Perfect Store Challenge`,
      description: 'Visits, closed tasks and average execution score across the quarter.',
      prizeDescription: 'Weekend away for two',
      startDate: quarterStart,
      endDate: endOf(addMonths(quarterStart, 2)),
      territoryId: null,
      eventTypes: [],
      createdById: 'demo-user-mgr-2',
      cancelledAt: null,
    },
    {
      id: 'demo-contest-kzn-close-the-loop',
      name: 'KZN Close the Loop',
      description: 'Durban team: most verified task closures. The Cola 2L gaps need closing.',
      prizeDescription: 'R1,000 grocery voucher',
      startDate: addCalendarDays(world.anchor, -10),
      endDate: addCalendarDays(world.anchor, 17),
      territoryId: TERRITORY_ID_BY_CODE.KZN!,
      eventTypes: ['task_closed'],
      createdById: 'demo-user-mgr-2',
      cancelledAt: null,
    },
    {
      id: 'demo-contest-execution-cup',
      name: `${monthName(lastMonth)} Execution Cup`,
      description: 'Quality over quantity: the highest average execution score wins.',
      prizeDescription: 'R2,000 cash and a trophy',
      startDate: lastMonth,
      endDate: endOf(lastMonth),
      territoryId: null,
      eventTypes: ['scorecard'],
      createdById: 'demo-user-mgr-1',
      cancelledAt: null,
    },
    {
      id: 'demo-contest-winter-warmer-blitz',
      name: 'Winter Warmer Blitz (Western Cape)',
      description: 'Run alongside the Winter Warmer campaign: visits and execution in Cape Town.',
      prizeDescription: 'Branded jackets for the top three',
      startDate: winterWarmer.startDate,
      endDate: winterWarmer.endDate,
      territoryId: TERRITORY_ID_BY_CODE.WC!,
      eventTypes: ['visit_submitted', 'scorecard'],
      createdById: 'demo-user-mgr-2',
      cancelledAt: null,
    },
    {
      id: 'demo-contest-festive-push',
      name: `Festive Push ${addMonths(m0, 2).getUTCFullYear()}`,
      description: 'Pre-festive coverage drive. Starts mid-November.',
      prizeDescription: 'Double points on the incentive scheme',
      startDate: dayOfMonth(addMonths(m0, 2), 16),
      endDate: dayOfMonth(addMonths(m0, 3), 20),
      territoryId: null,
      eventTypes: [],
      createdById: 'demo-user-mgr-1',
      cancelledAt: null,
    },
    {
      id: 'demo-contest-eku-spot-prize',
      name: 'Gauteng East Spot Prize',
      description: 'Cancelled while visit data in Ekurhuleni is reviewed.',
      prizeDescription: 'R750 voucher',
      startDate: addCalendarDays(world.anchor, -20),
      endDate: addCalendarDays(world.anchor, 10),
      territoryId: TERRITORY_ID_BY_CODE['GP-EKU']!,
      eventTypes: ['visit_submitted'],
      createdById: 'demo-user-mgr-1',
      cancelledAt: localInstant(addCalendarDays(world.anchor, -15), 11 * 60, world.timeZone),
    },
  ];

  return rows.map((row) => {
    const at = created(row.startDate);
    return { ...row, createdAt: at, updatedAt: row.cancelledAt ?? at };
  });
}
