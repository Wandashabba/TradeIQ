import type { DataTable } from './types';

/**
 * Public school terms, from the Department of Basic Education's gazetted
 * school calendars. Dates are LEARNERS' first and last days (educators start
 * two days earlier and finish two days later; those dates are not used).
 *
 * 2025–2027 each have one national calendar. Earlier years sometimes split
 * inland (GP, FS, LP, MP, NW) from coastal (EC, KZN, NC, WC); a split year is
 * entered as two rows per term with `region` set, and the calendar service
 * picks the row for the province asked about.
 *
 * **Upkeep:** DBE gazettes calendars years ahead. When a new year is gazetted,
 * add its four terms from the gazette (not the gov.za summary page, which has
 * shown draft dates), add the year to `coveredYears`, bump `version`, and set
 * `verifiedAt`. `schoolTerms.test.ts` fails in January if the current year is
 * missing.
 */
export type SchoolRegion = 'inland' | 'coastal';

export interface SchoolTerm {
  year: number;
  term: 1 | 2 | 3 | 4;
  region: SchoolRegion | 'national';
  start: string;
  end: string;
  sourceUrl: string;
}

const GAZETTE_2025 = 'https://www.gov.za/sites/default/files/gcis_document/202302/47972gon2991.pdf';
const GAZETTE_2026 =
  'https://www.education.gov.za/portals/0/documents/publications/2025/Published%202026%20School%20Calendar.pdf';
const GAZETTE_2027 =
  'https://www.education.gov.za/portals/0/documents/publications/2025/Published%202027%20School%20Calendar.pdf';

export const SCHOOL_TERMS: DataTable<SchoolTerm> = {
  version: '2026-09-17.1',
  source: 'Department of Basic Education school calendar (Government Gazette)',
  sourceUrl: 'https://www.education.gov.za/Informationfor/ParentsandGuardians/SchoolCalendar.aspx',
  verifiedAt: '2026-09-17',
  coveredYears: [2025, 2026, 2027],
  entries: [
    // Government Gazette No. 47972, Notice 2991 (31 Jan 2023).
    { year: 2025, term: 1, region: 'national', start: '2025-01-15', end: '2025-03-28', sourceUrl: GAZETTE_2025 },
    { year: 2025, term: 2, region: 'national', start: '2025-04-08', end: '2025-06-27', sourceUrl: GAZETTE_2025 },
    { year: 2025, term: 3, region: 'national', start: '2025-07-22', end: '2025-10-03', sourceUrl: GAZETTE_2025 },
    { year: 2025, term: 4, region: 'national', start: '2025-10-13', end: '2025-12-10', sourceUrl: GAZETTE_2025 },
    // Government Gazette No. 52177 (25 Feb 2025).
    { year: 2026, term: 1, region: 'national', start: '2026-01-14', end: '2026-03-27', sourceUrl: GAZETTE_2026 },
    { year: 2026, term: 2, region: 'national', start: '2026-04-08', end: '2026-06-26', sourceUrl: GAZETTE_2026 },
    { year: 2026, term: 3, region: 'national', start: '2026-07-21', end: '2026-09-23', sourceUrl: GAZETTE_2026 },
    { year: 2026, term: 4, region: 'national', start: '2026-10-06', end: '2026-12-09', sourceUrl: GAZETTE_2026 },
    // Government Gazette No. 52178 (25 Feb 2025). Supersedes the draft dates still on gov.za.
    { year: 2027, term: 1, region: 'national', start: '2027-01-13', end: '2027-03-19', sourceUrl: GAZETTE_2027 },
    { year: 2027, term: 2, region: 'national', start: '2027-04-06', end: '2027-06-25', sourceUrl: GAZETTE_2027 },
    { year: 2027, term: 3, region: 'national', start: '2027-07-20', end: '2027-09-22', sourceUrl: GAZETTE_2027 },
    { year: 2027, term: 4, region: 'national', start: '2027-10-05', end: '2027-12-08', sourceUrl: GAZETTE_2027 },
  ],
};
