import { localCalendarDate } from '../../lib/clientTime';
import { storedCampaignDate } from '../campaigns/campaignWindow';

/**
 * The pure rules of a contest (#124): which ledger reasons can count, what a
 * contest's dates mean, its computed status, and how tied agents are ranked.
 * No Prisma import, so every rule is testable without a database.
 */

/** Ledger reasons a contest can filter on (see pointsLedger.ts). */
export const CONTEST_EVENT_TYPES = ['visit_submitted', 'task_closed', 'scorecard'] as const;
export type ContestEventType = (typeof CONTEST_EVENT_TYPES)[number];

export function isContestEventType(value: unknown): value is ContestEventType {
  return typeof value === 'string' && (CONTEST_EVENT_TYPES as readonly string[]).includes(value);
}

/**
 * `cancelled` is set by a manager. The other three are never stored: they
 * follow from the dates and the client's local "today", so a contest turns
 * active and ends on its own.
 */
export type ContestStatus = 'upcoming' | 'active' | 'ended' | 'cancelled';

/** How long an ended contest stays on the agent's Contests view. */
export const RECENTLY_ENDED_DAYS = 30;

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * A strict `YYYY-MM-DD` calendar date, as UTC midnight of that date (the
 * clientTime.ts convention). Null for anything else, including a date that
 * does not exist (`2026-02-30`) and full ISO instants: a contest's dates are
 * days, and accepting an instant would mean guessing which zone it meant.
 */
export function parseCalendarDate(value: unknown): Date | null {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return null;
  }
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
    return null;
  }
  return date;
}

/** A stored calendar date as `YYYY-MM-DD`. */
export function formatCalendarDate(stored: Date): string {
  return storedCampaignDate(stored).toISOString().slice(0, 10);
}

/** The client's local calendar date right now. */
export function localToday(timeZone: string, now: Date = new Date()): Date {
  return localCalendarDate(now, timeZone);
}

export interface ContestSchedule {
  startDate: Date;
  endDate: Date;
  cancelledAt: Date | null;
}

/** Status on the local calendar date `today` (a calendar date, not an instant). */
export function contestStatus(contest: ContestSchedule, today: Date): ContestStatus {
  if (contest.cancelledAt) {
    return 'cancelled';
  }
  const t = today.getTime();
  if (t < storedCampaignDate(contest.startDate).getTime()) {
    return 'upcoming';
  }
  if (t > storedCampaignDate(contest.endDate).getTime()) {
    return 'ended';
  }
  return 'active';
}

/**
 * Local days left in an active contest, counting today: 1 on the last day.
 * Null for any other status — "days left" means nothing before it starts or
 * after it ends.
 */
export function contestDaysLeft(contest: ContestSchedule, today: Date): number | null {
  if (contestStatus(contest, today) !== 'active') {
    return null;
  }
  return Math.round((storedCampaignDate(contest.endDate).getTime() - today.getTime()) / DAY_MS) + 1;
}

export interface Rankable {
  agentId: string;
  email: string;
  points: number;
}

/**
 * Competition ranking ("1, 1, 3"): agents on equal points share a rank, and
 * the next agent's rank counts everyone above them. A contest has a prize, so
 * an arbitrary tiebreak must never decide who is first — two agents on the
 * same points are both first, and the manager decides what that means.
 *
 * The *listing* order inside a tie is still deterministic: email, then id,
 * compared by code unit rather than locale so every server orders them alike.
 * `points` are expected already rounded (round2), so float noise cannot split
 * a tie.
 */
export function rankStandings<T extends Rankable>(rows: T[]): Array<T & { rank: number }> {
  const byCodeUnit = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);
  const sorted = [...rows].sort(
    (a, b) => b.points - a.points || byCodeUnit(a.email, b.email) || byCodeUnit(a.agentId, b.agentId),
  );
  let rank = 0;
  return sorted.map((row, index) => {
    if (index === 0 || row.points !== sorted[index - 1].points) {
      rank = index + 1;
    }
    return { ...row, rank };
  });
}
