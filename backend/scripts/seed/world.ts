import { HISTORY_MONTHS, SEED_TIME_ZONE, addMonths, monthStart } from './calendar';
import {
  AGENTS,
  CoordinateSource,
  OutletSeed,
  PROBLEM_OUTLET_CODES,
  UserSeed,
  assignOutletsToAgents,
  buildOutlets,
} from './catalog';
import { makeRng, jitter } from './rng';
import { CampaignSeed, campaignSeeds } from './scenario';

/**
 * The fixed frame every generator reads: who covers which outlets, which
 * outlets each campaign ran in, and the window of history. Pure — built from
 * the anchor date and the catalog, no database.
 */
export interface World {
  /** The seed's "today", a calendar date (UTC midnight of the local date). */
  anchor: Date;
  /** First of the anchor's month. */
  anchorMonth: Date;
  /** First of the oldest month of history. */
  historyStart: Date;
  timeZone: string;
  outlets: OutletSeed[];
  outletById: Map<string, OutletSeed>;
  /** outlet id → owning agent id */
  ownerByOutlet: Map<string, string>;
  agents: UserSeed[];
  agentById: Map<string, UserSeed>;
  /** A stable 0-1 per agent, for the small individual differences. */
  agentSeed: Map<string, number>;
  /** agent id → the outlets on their route, in code order */
  routes: Map<string, OutletSeed[]>;
  /** A stable execution-score offset per outlet, so outlets rank consistently. */
  outletOffset: Map<string, number>;
  problemOutletIds: Set<string>;
  campaigns: CampaignSeed[];
  /** campaign id → outlet ids */
  campaignOutlets: Map<string, string[]>;
  campaignOutletSets: Map<string, Set<string>>;
}

export interface BuildWorldInput {
  anchor: Date;
  home: CoordinateSource;
  timeZone?: string;
  /** Months of history before the anchor month. Default HISTORY_MONTHS. */
  historyMonths?: number;
  /** Share of outlets to keep; 1 is the full dataset. */
  outletFraction?: number;
}

const CAMPAIGN_CHANNEL_PRIORITY = ['hypermarket', 'wholesaler', 'supermarket', 'convenience', 'forecourt', 'spaza'];

export function buildWorld(input: BuildWorldInput): World {
  const anchorMonth = monthStart(input.anchor);
  const outlets = buildOutlets(input.home, { fraction: input.outletFraction ?? 1 });
  const ownerByOutlet = assignOutletsToAgents(outlets);
  const agents = AGENTS;
  const rng = makeRng(424242);

  const agentSeed = new Map<string, number>();
  for (const agent of agents) agentSeed.set(agent.id, rng());

  const outletOffset = new Map<string, number>();
  for (const outlet of outlets) outletOffset.set(outlet.id, jitter(rng, 6));

  const routes = new Map<string, OutletSeed[]>();
  for (const agent of agents) routes.set(agent.id, []);
  for (const outlet of [...outlets].sort((a, b) => a.code.localeCompare(b.code))) {
    const owner = ownerByOutlet.get(outlet.id);
    if (owner) routes.get(owner)!.push(outlet);
  }

  const campaigns = campaignSeeds(anchorMonth);
  const campaignOutlets = new Map<string, string[]>();
  for (const campaign of campaigns) {
    const eligible = outlets
      .filter((o) => campaign.territoryCodes.includes(o.territoryId))
      .sort(
        (a, b) =>
          CAMPAIGN_CHANNEL_PRIORITY.indexOf(a.channelType) - CAMPAIGN_CHANNEL_PRIORITY.indexOf(b.channelType) ||
          a.code.localeCompare(b.code),
      );
    const count = Math.max(3, Math.round(campaign.outletCount * (input.outletFraction ?? 1)));
    campaignOutlets.set(campaign.id, eligible.slice(0, count).map((o) => o.id));
  }

  const problemCodes = new Set<string>(PROBLEM_OUTLET_CODES);

  return {
    anchor: input.anchor,
    anchorMonth,
    historyStart: addMonths(anchorMonth, -(input.historyMonths ?? HISTORY_MONTHS)),
    timeZone: input.timeZone ?? SEED_TIME_ZONE,
    outlets,
    outletById: new Map(outlets.map((o) => [o.id, o])),
    ownerByOutlet,
    agents,
    agentById: new Map(agents.map((a) => [a.id, a])),
    agentSeed,
    routes,
    outletOffset,
    problemOutletIds: new Set(outlets.filter((o) => problemCodes.has(o.code)).map((o) => o.id)),
    campaigns,
    campaignOutlets,
    campaignOutletSets: new Map([...campaignOutlets].map(([id, list]) => [id, new Set(list)])),
  };
}

/**
 * The campaign running at an outlet on a calendar date, or null — inclusive
 * local days (#324). Windows never overlap for one outlet in the scenario;
 * were they to, the most recently started wins, as order attribution does.
 * Drafts never run.
 */
export function campaignAt(world: World, outletId: string, day: Date): CampaignSeed | null {
  let best: CampaignSeed | null = null;
  for (const campaign of world.campaigns) {
    if (campaign.startDate.getTime() > world.anchor.getTime()) continue; // not started: a draft
    if (day.getTime() < campaign.startDate.getTime() || day.getTime() > campaign.endDate.getTime()) continue;
    if (!world.campaignOutletSets.get(campaign.id)!.has(outletId)) continue;
    if (!best || campaign.startDate.getTime() > best.startDate.getTime()) best = campaign;
  }
  return best;
}

/** draft | active | completed, from the dates and the anchor. */
export function campaignStatus(campaign: CampaignSeed, anchor: Date): 'draft' | 'active' | 'completed' {
  if (campaign.startDate.getTime() > anchor.getTime()) return 'draft';
  if (campaign.endDate.getTime() < anchor.getTime()) return 'completed';
  return 'active';
}
