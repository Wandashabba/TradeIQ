import { z } from 'zod';
import { RETAILER_ADAPTERS } from '../../competitorPrices/adapters';
import {
  getCompetitorShelfPrices,
  type CompetitorShelfPrices,
} from '../../competitorPrices/competitorPrices.service';
import { competitorPriceGate } from '../../competitorPrices/gate';
import { eraseToolTypes, ToolFacingError, type AnyAssistantTool } from '../types';
import type { ToolContext } from './execution';

/**
 * `getCompetitorShelfPrices` — competitor prices read from retailers' PUBLIC
 * WEBSITES, for the SKUs an admin has mapped.
 *
 * **Gated off by default** (`toolGates.ts`): not declared unless the client's
 * legal gate is open. `run` checks the gate again anyway, because a declared
 * roster can outlive the switch — an artifact re-run, or a turn that started
 * before an admin turned it off.
 *
 * Everything it returns is outside data and says so in the result itself:
 * `dataOrigin`, an `about` line, and per-figure provenance (retailer, URL,
 * retrieved date). A price older than the stale threshold is marked stale with
 * a label that says it is not current, and no price gap is computed from it.
 */

const retailerIds = RETAILER_ADAPTERS.filter((a) => !a.fixtureOnly).map((a) => a.id) as [string, ...string[]];

export function buildCompetitorPriceTools(ctx: ToolContext): AnyAssistantTool[] {
  const { user, now } = ctx;

  return [
    eraseToolTypes({
      name: 'getCompetitorShelfPrices',
      pillar: 'competition' as const,
      description:
        'Call this when the user asks what a named retailer (e.g. Checkers, Pick n Pay, Shoprite, ' +
        'Makro, Woolworths) charges ONLINE or on its website for a competitor product, how a ' +
        "competitor's public retailer price has moved, or how our price compares with competitors' " +
        'retailer-website prices. Returns, for each competitor SKU an admin has mapped, the latest ' +
        'shelf and promo price per retailer, the trend, and the gap to our own price. This is ' +
        'OUTSIDE, PUBLIC data: quote every figure with its retailer and retrieved date, say it comes ' +
        'from retailer websites, and never call a price marked stale current. Do NOT use it for a ' +
        'general "what are competitors pricing at" with no website or retailer named, or for ' +
        'competitor prices, brands or promoters our agents saw in outlets (use getCompetitorActivity) ' +
        'or for our own shelf prices against RRP (use getPriceCompliance).',
      args: z.object({
        competitorSku: z
          .string()
          .min(1)
          .max(80)
          .optional()
          .describe('Optional part of a competitor product or brand name, e.g. "Coca-Cola 2L".'),
        retailer: z
          .enum(retailerIds)
          .optional()
          .describe('Optional retailer id, to narrow to one retailer.'),
        trendDays: z
          .number()
          .int()
          .min(7)
          .max(90)
          .default(30)
          .describe('How many days of price history to summarise. Default 30.'),
      }),
      run: async (args) => {
        if (!(await competitorPriceGate(user.clientId)).active) {
          throw new ToolFacingError(
            'Competitor shelf prices from retailer websites are not switched on for this business, so there is no such data to report.',
          );
        }
        return getCompetitorShelfPrices({
          clientId: user.clientId,
          now,
          competitorSku: args.competitorSku,
          retailer: args.retailer,
          trendDays: args.trendDays,
        });
      },
      // Each retailer page quoted, cited with the date it was READ — which is
      // what makes a stale price visibly stale in the app's source list too.
      sources: (_args, result) =>
        (result as CompetitorShelfPrices).sources.map((s) => ({
          url: s.url,
          title: s.title,
          origin: 'competitor_prices',
          // A retailer's own shelf page: the retailer IS the publisher, and it
          // states no release date — the read date is the only date there is.
          publisher: s.title,
          publishedAt: null,
          snippet: null,
          pageAge: null,
          retrievedAt: s.retrievedAt,
        })),
    }),
  ] as AnyAssistantTool[];
}
