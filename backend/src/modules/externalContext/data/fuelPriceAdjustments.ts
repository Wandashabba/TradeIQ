import type { DataTable } from './types';

/**
 * Monthly South African fuel price adjustments — a MANUAL-REFRESH table.
 *
 * There is no official machine-readable feed. The Department of Mineral and
 * Petroleum Resources (DMPR) announces each month's adjustment in a media
 * statement (republished on gov.za) a few days before it takes effect on the
 * first Wednesday of the month, and the Central Energy Fund (CEF) publishes the
 * working as a PDF. Scraping either would break on the next redesign, so the
 * figures are typed in here, with the statement they came from, and the
 * refresh job copies this table into `economic_observations`.
 *
 * **How to refresh (monthly, after the announcement — usually the last working
 * days of the month):**
 * 1. Open the DMPR statement on gov.za ("Minister … announces adjustment of fuel
 *    prices effective …"). Take the 95 ULP (inland) and 0.005% diesel changes
 *    in cents per litre; an increase is positive.
 * 2. Take the Gauteng 95 ULP retail price from the CEF press release PDF
 *    (cefgroup.co.za → Press Release … Change …), page 2 history table, once
 *    it is published. Leave it null until then — never add the change to last
 *    month's price yourself.
 * 3. Add the row, bump `version`, set `verifiedAt`, and add the year to
 *    `coveredYears` when January's row goes in. `tables.test.ts` fails in a year
 *    with no rows.
 * The next scheduled refresh (daily) writes it to Postgres; or run
 * `npm run refresh-economic-context`.
 */
export interface FuelPriceAdjustment {
  /** `YYYY-MM` the adjustment took effect in. */
  month: string;
  effectiveDate: string;
  /** When the statement was published. */
  announcedOn: string;
  /** Change in c/l for 95 ULP, inland. Positive is an increase. */
  petrol95InlandChange: number;
  /** Change in c/l for 0.005% sulphur diesel (wholesale). Null when sources disagree. */
  diesel0005Change: number | null;
  /** Gauteng 95 ULP retail price after the adjustment, c/l. Null until CEF publishes it. */
  petrol95GautengPriceCents: number | null;
  sourceUrl: string;
  /** Where the Gauteng price was read, when it is not the statement. */
  priceSourceUrl?: string;
  note?: string;
}

const GOV = 'https://www.gov.za/news/media-statements/';
const CEF_HISTORY_AUG_2026 =
  'https://cefgroup.co.za/wp-content/uploads/2026/08/Press-Release-31-July-2026-Change-05-August-2026.pdf';

const row = (
  month: string,
  effectiveDate: string,
  announcedOn: string,
  petrol95InlandChange: number,
  diesel0005Change: number | null,
  petrol95GautengPriceCents: number | null,
  slug: string,
  extra: Partial<FuelPriceAdjustment> = {},
): FuelPriceAdjustment => ({
  month,
  effectiveDate,
  announcedOn,
  petrol95InlandChange,
  diesel0005Change,
  petrol95GautengPriceCents,
  sourceUrl: slug.startsWith('https://') ? slug : `${GOV}${slug}`,
  ...(petrol95GautengPriceCents !== null ? { priceSourceUrl: CEF_HISTORY_AUG_2026 } : {}),
  ...extra,
});

export const FUEL_PRICE_ADJUSTMENTS: DataTable<FuelPriceAdjustment> = {
  version: '2026-09-17.1',
  source: 'Department of Mineral and Petroleum Resources fuel price adjustment statements',
  sourceUrl: 'https://www.dmpr.gov.za/',
  verifiedAt: '2026-09-17',
  coveredYears: [2025, 2026],
  entries: [
    row('2025-01', '2025-01-01', '2024-12-28', 12, 7.5, 2159, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-1-january'),
    row('2025-02', '2025-02-05', '2025-02-04', 82, 105, 2241, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-5-february'),
    row('2025-03', '2025-03-05', '2025-03-04', -7, -17.5, 2234, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effect-5-march-2025'),
    row('2025-04', '2025-04-02', '2025-04-01', -72, -83.8, 2162, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-2-april'),
    row('2025-05', '2025-05-07', '2025-05-02', -22, -42, 2140, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-02-may-2025'),
    row('2025-06', '2025-06-04', '2025-06-03', -5, -36.9, 2135, 'mineral-and-petroleum-resources-announces-adjustment-fuel-prices-effective-4'),
    row('2025-07', '2025-07-02', '2025-07-01', 52, 82, 2187, 'mineral-and-petroleum-resources-announces-adjustment-fuel-prices-2-july-2025'),
    row('2025-08', '2025-08-06', '2025-08-05', -28, 65, 2159, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-6-august'),
    row('2025-09', '2025-09-03', '2025-09-03', -4, -56, 2155, 'mineral-and-petroleum-resources-announces-adjustment-fuel-prices-effective-3'),
    row(
      '2025-10',
      '2025-10-01',
      '2025-09-26',
      8,
      -10,
      2163,
      'https://cefgroup.co.za/wp-content/uploads/2025/10/Press-Release-26-September-2025-Change-01-October-25.pdf',
      { note: 'From the CEF release; the DMPR statement could not be retrieved.' },
    ),
    row('2025-11', '2025-11-05', '2025-11-03', -51, -21, 2112, 'https://www.gov.za/news/media-advisories/minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-5-november'),
    row('2025-12', '2025-12-03', '2025-12-02', 29, 65.48, 2141, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-3-december'),
    row('2026-01', '2026-01-07', '2026-01-04', -66, -137, 2075, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-6-0'),
    row('2026-02', '2026-02-04', '2026-02-02', -65, -50, 2010, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-4-february'),
    row('2026-03', '2026-03-04', '2026-03-02', 20, 62, 2030, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-4-march'),
    row('2026-04', '2026-04-01', '2026-03-31', 306, 737, 2336, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-1st-april'),
    row('2026-05', '2026-05-06', '2026-05-06', 327, null, 2663, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-6-may-2026', {
      note: 'Diesel left out: the statement (+619 c/l) and the CEF final release (+526.70 c/l) disagree.',
    }),
    row('2026-06', '2026-06-03', '2026-06-01', 143, -324.96, 2806, 'mineral-and-petroleum-resources-announces-adjustment-fuel-prices-effective-0'),
    row('2026-07', '2026-07-01', '2026-06-30', -196, -313.8, 2610, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-1-july'),
    row('2026-08', '2026-08-05', '2026-08-03', -52, 138.44, 2558, 'minister-gwede-mantashe-announces-adjustment-fuel-prices-effective-5-august-0'),
    row(
      '2026-09',
      '2026-09-02',
      '2026-08-31',
      129,
      293.9,
      null,
      'https://www.dmpr.gov.za/Media-Centre/ArtMID/1168/ArticleID/1030/MEDIA-STATEMENT-FUEL-PRICE-ADJUSTMENTS-EFFECTIVE-FROM-THE-2ND-OF-SEPTEMBER-2026',
    ),
  ],
};
