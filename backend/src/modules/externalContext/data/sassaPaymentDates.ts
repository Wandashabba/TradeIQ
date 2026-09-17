import type { DataTable } from './types';

/**
 * SASSA social grant payment dates: the three days each month on which older
 * persons', disability, and children's and other grants are paid.
 *
 * SASSA publishes a schedule per financial year (April to March), usually in
 * March. The old sassa.gov.za schedule pages were removed when the site was
 * rebuilt, so months before April 2026 are sourced from SASSA's and
 * GovernmentZA's own announcements where they could be opened, and from news
 * reports otherwise — `sourceKind` says which.
 *
 * **A month that is not here is not guessed.** The calendar service reports it
 * as missing and the assistant says so.
 *
 * **Upkeep:** each March, add the next financial year from the SASSA or DSD
 * announcement, add the calendar year to `coveredYears` once all twelve months
 * of it are present, bump `version`, and set `verifiedAt`. Watch for revisions
 * when a payment day becomes a declared public holiday (e.g. 4 November 2026).
 */
export interface SassaPaymentMonth {
  month: string;
  olderPersons: string;
  disability: string;
  childAndOtherGrants: string;
  sourceUrl: string;
  sourceKind: 'official' | 'news';
  publishedAt?: string;
  note?: string;
}

const SCHEDULE_2026_27 =
  'https://www.dsd.gov.za/index.php/latest-news/21-latest-news/680-SASSA-confirms-2026-2027-social-grant-payment-schedule-and-increases';

const official2026 = (
  month: string,
  olderPersons: string,
  disability: string,
  childAndOtherGrants: string,
  note?: string,
): SassaPaymentMonth => ({
  month,
  olderPersons,
  disability,
  childAndOtherGrants,
  sourceUrl: SCHEDULE_2026_27,
  sourceKind: 'official',
  publishedAt: '2026-03-20',
  ...(note ? { note } : {}),
});

export const SASSA_PAYMENT_DATES: DataTable<SassaPaymentMonth> = {
  version: '2026-09-17.1',
  source: 'South African Social Security Agency (SASSA) grant payment schedule',
  sourceUrl: SCHEDULE_2026_27,
  verifiedAt: '2026-09-17',
  coveredYears: [2025, 2026],
  entries: [
    {
      month: '2025-01',
      olderPersons: '2025-01-03',
      disability: '2025-01-06',
      childAndOtherGrants: '2025-01-07',
      sourceUrl: 'https://www.facebook.com/SASSANewsZA/posts/social-grant-payment-dates-for-january-2025-older-persons-03-january-2025-disabi/982782563878172/',
      sourceKind: 'official',
      publishedAt: '2024-12-19',
    },
    {
      month: '2025-02',
      olderPersons: '2025-02-04',
      disability: '2025-02-05',
      childAndOtherGrants: '2025-02-06',
      sourceUrl: 'https://www.ewn.co.za/2025/01/17/sassa-confirms-february-payment-dates',
      sourceKind: 'news',
      publishedAt: '2025-01-17',
    },
    {
      month: '2025-03',
      olderPersons: '2025-03-04',
      disability: '2025-03-05',
      childAndOtherGrants: '2025-03-06',
      sourceUrl: 'https://www.gov.za/news/media-statements/communications-and-digital-technologies-assures-public-social-grants-payment',
      sourceKind: 'official',
      note: 'The source gives the payment cycle as 4 to 6 March.',
    },
    {
      month: '2025-04',
      olderPersons: '2025-04-02',
      disability: '2025-04-03',
      childAndOtherGrants: '2025-04-04',
      sourceUrl: 'https://x.com/OfficialSASSA/status/1905513163363094564',
      sourceKind: 'official',
    },
    {
      month: '2025-05',
      olderPersons: '2025-05-06',
      disability: '2025-05-07',
      childAndOtherGrants: '2025-05-08',
      sourceUrl: 'https://www.ewn.co.za/2025/04/17/sassa-confirms-grant-payment-dates-for-may-2025',
      sourceKind: 'news',
      publishedAt: '2025-04-17',
      note: "Reports of this month disagree on the older persons date; 6 May matches SASSA's own post.",
    },
    {
      month: '2025-06',
      olderPersons: '2025-06-03',
      disability: '2025-06-04',
      childAndOtherGrants: '2025-06-05',
      sourceUrl: 'https://www.ewn.co.za/2025/05/20/sassa-confirms-grant-payment-dates-for-june-2025',
      sourceKind: 'news',
      publishedAt: '2025-05-20',
    },
    {
      month: '2025-07',
      olderPersons: '2025-07-02',
      disability: '2025-07-03',
      childAndOtherGrants: '2025-07-04',
      sourceUrl: 'https://iol.co.za/news/2025-07-01-sassa-announces-july-2025-grant-payments-dates/',
      sourceKind: 'news',
      publishedAt: '2025-07-01',
    },
    {
      month: '2025-08',
      olderPersons: '2025-08-05',
      disability: '2025-08-06',
      childAndOtherGrants: '2025-08-07',
      sourceUrl: 'https://www.ewn.co.za/2025/07/21/sassa-confirms-august-2025-grant-payment-dates',
      sourceKind: 'news',
      publishedAt: '2025-07-21',
    },
    {
      month: '2025-09',
      olderPersons: '2025-09-02',
      disability: '2025-09-03',
      childAndOtherGrants: '2025-09-04',
      sourceUrl: 'https://www.ewn.co.za/2025/08/21/sassa-confirms-grant-payment-dates-for-september-2025',
      sourceKind: 'news',
      publishedAt: '2025-08-21',
    },
    {
      month: '2025-10',
      olderPersons: '2025-10-02',
      disability: '2025-10-03',
      childAndOtherGrants: '2025-10-06',
      sourceUrl: 'https://iol.co.za/news/south-africa/2025-09-21-sassa-heres-when-to-collect-your-social-grant-funds-in-october-2025/',
      sourceKind: 'news',
      publishedAt: '2025-09-21',
    },
    {
      month: '2025-11',
      olderPersons: '2025-11-04',
      disability: '2025-11-05',
      childAndOtherGrants: '2025-11-06',
      sourceUrl: 'https://www.ewn.co.za/2025/10/20/sassa-confirms-november-grant-payment-dates',
      sourceKind: 'news',
      publishedAt: '2025-10-20',
    },
    {
      month: '2025-12',
      olderPersons: '2025-12-02',
      disability: '2025-12-03',
      childAndOtherGrants: '2025-12-04',
      sourceUrl: 'https://x.com/GovernmentZA/status/1995463391784189973',
      sourceKind: 'official',
    },
    {
      month: '2026-01',
      olderPersons: '2026-01-06',
      disability: '2026-01-07',
      childAndOtherGrants: '2026-01-08',
      sourceUrl: 'https://x.com/OfficialSASSA/status/2001631942287273988',
      sourceKind: 'official',
    },
    {
      month: '2026-02',
      olderPersons: '2026-02-03',
      disability: '2026-02-04',
      childAndOtherGrants: '2026-02-05',
      sourceUrl: 'https://x.com/GovernmentZA/status/2018217867892994180',
      sourceKind: 'official',
    },
    {
      month: '2026-03',
      olderPersons: '2026-03-03',
      disability: '2026-03-04',
      childAndOtherGrants: '2026-03-05',
      sourceUrl: 'https://www.citizen.co.za/alberton-record/news-headlines/local-news/2026/02/25/sassa-announces-march-grant-payment-dates-for-older-persons-disability-and-childrens-grants/',
      sourceKind: 'news',
      publishedAt: '2026-02-25',
    },
    official2026('2026-04', '2026-04-02', '2026-04-07', '2026-04-08'),
    official2026('2026-05', '2026-05-05', '2026-05-06', '2026-05-07'),
    official2026('2026-06', '2026-06-02', '2026-06-03', '2026-06-04'),
    official2026('2026-07', '2026-07-02', '2026-07-03', '2026-07-06'),
    official2026('2026-08', '2026-08-04', '2026-08-05', '2026-08-06'),
    official2026('2026-09', '2026-09-02', '2026-09-03', '2026-09-04'),
    official2026('2026-10', '2026-10-02', '2026-10-05', '2026-10-06'),
    official2026(
      '2026-11',
      '2026-11-03',
      '2026-11-04',
      '2026-11-05',
      '4 November was declared an election public holiday after this schedule was published; the disability grant date may move.',
    ),
    official2026('2026-12', '2026-12-02', '2026-12-03', '2026-12-04'),
    official2026('2027-01', '2027-01-05', '2027-01-06', '2027-01-07'),
    official2026('2027-02', '2027-02-02', '2027-02-03', '2027-02-04'),
    official2026('2027-03', '2027-03-02', '2027-03-03', '2027-03-04'),
  ],
};
