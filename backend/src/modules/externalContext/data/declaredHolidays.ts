import type { DataTable } from './types';

/**
 * One-off public holidays declared by the President under section 2A of the
 * Public Holidays Act 36 of 1994 ("The President may by proclamation in the
 * Gazette declare any day to be a public holiday").
 *
 * No rule produces these, so they are typed in from the declaration. Sunday
 * rollovers under section 2(1) are computed in `holidays.ts` and must NOT be
 * added here.
 *
 * **Upkeep:** when a new day is declared (elections, a Christmas that falls on
 * a Sunday, a national celebration), add it with the statement URL, bump
 * `version`, and set `verifiedAt`. Check at least every January, and whenever
 * an election date is proclaimed.
 */
export interface DeclaredHoliday {
  date: string;
  name: string;
  /** When the declaration was made or announced, if known. */
  declaredOn?: string;
  sourceUrl: string;
}

export const DECLARED_HOLIDAYS: DataTable<DeclaredHoliday> = {
  version: '2026-09-17.1',
  source: 'Presidential declarations under section 2A of the Public Holidays Act (gov.za, SAnews, The Presidency)',
  sourceUrl: 'https://www.gov.za/about-sa/public-holidays',
  verifiedAt: '2026-09-17',
  coveredYears: [2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026],
  entries: [
    {
      date: '2016-08-03',
      name: 'Local government elections',
      declaredOn: '2016-06-24',
      sourceUrl:
        'https://www.gov.za/speeches/president-jacob-zuma-declares-3-august-2016-public-holiday-24-jun-2016-0000',
    },
    {
      date: '2016-12-27',
      name: 'Day after Day of Goodwill (Christmas on a Sunday)',
      declaredOn: '2016-09-19',
      sourceUrl:
        'https://www.gov.za/speeches/president-jacob-zuma-declares-27-december-2016-public-holiday-19-sep-2016-0000',
    },
    {
      date: '2019-05-08',
      name: 'General elections',
      declaredOn: '2019-02-26',
      sourceUrl: 'https://www.sanews.gov.za/south-africa/election-day-declared-public-holiday',
    },
    {
      date: '2021-11-01',
      name: 'Local government elections',
      sourceUrl:
        'https://www.gov.za/news/media-statements/president-cyril-ramaphosa-declares-election-day-1-november-2021-public',
    },
    {
      date: '2022-12-27',
      name: 'Day after Day of Goodwill (Christmas on a Sunday)',
      declaredOn: '2022-12-08',
      sourceUrl:
        'https://www.gov.za/news/media-statements/president-cyril-ramaphosa-declares-27-december-public-holiday-08-dec-2022',
    },
    {
      date: '2023-12-15',
      name: 'Rugby World Cup victory holiday',
      declaredOn: '2023-10-30',
      sourceUrl: 'https://www.sanews.gov.za/south-africa/president-ramaphosa-declares-15-december-public-holiday',
    },
    {
      date: '2024-05-29',
      name: 'General elections',
      declaredOn: '2024-02-23',
      sourceUrl: 'https://www.thepresidency.gov.za/president-proclaims-election-date-and-public-holiday',
    },
    {
      date: '2026-11-04',
      name: 'Local government elections',
      declaredOn: '2026-09-15',
      sourceUrl: 'https://www.gov.za/news/media-statements/president-cyril-ramaphosa-declares-election-day',
    },
  ],
};
