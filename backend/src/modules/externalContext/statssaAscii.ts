/**
 * Stats SA's "ASCII" time-series format, as published in the zipped time-series
 * downloads for each statistical release (P6242.1 retail trade, P0141 CPI, …).
 *
 * The file is a run of blocks. Each block starts with header lines `Hnn: text`
 * — H01 release, H03 series code, H04/H05 description, H13 region, H15/H16
 * price basis and adjustment, H23 `Release: YYYY MM`, H24 `Start: YYYY MM`,
 * H25 frequency — followed by one value per line, one per month from the start
 * month. A value that is not a number (`..`, blank) is missing, and its month
 * slot still counts.
 *
 * Parsing is strict about shape and lenient about noise: CRLF endings, header
 * case (`RELEASE:` and `Release:` both occur), and trailing blank lines are
 * fine, but a block whose start month cannot be read is rejected rather than
 * guessed — a series shifted by a month is worse than no series.
 */

export interface StatsSaSeries {
  code: string;
  headers: Readonly<Record<string, string>>;
  /** `YYYY-MM` of the first value. */
  start: string;
  /** `YYYY-MM` of the release the file belongs to, when stated. */
  release: string | null;
  values: Array<number | null>;
}

export class StatsSaFormatError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'StatsSaFormatError';
  }
}

const HEADER = /^(H\d\d):\s?(.*)$/;
const YEAR_MONTH = /(\d{4})\s+(\d{1,2})/;

function yearMonth(text: string | undefined): string | null {
  const match = text ? YEAR_MONTH.exec(text) : null;
  if (!match) return null;
  const month = Number(match[2]);
  if (month < 1 || month > 12) return null;
  return `${match[1]}-${String(month).padStart(2, '0')}`;
}

export function parseStatsSaAscii(text: string): StatsSaSeries[] {
  const series: StatsSaSeries[] = [];
  let headers: Record<string, string> | null = null;
  let values: Array<number | null> = [];

  const flush = () => {
    if (!headers) return;
    const code = headers.H03?.trim();
    const start = yearMonth(headers.H24);
    if (!code) throw new StatsSaFormatError('A series block has no H03 series code.');
    if (!start) throw new StatsSaFormatError(`Series ${code} has no readable H24 start month.`);
    // Trailing blank lines are padding, not missing months.
    while (values.length && values[values.length - 1] === null) values.pop();
    series.push({ code, headers, start, release: yearMonth(headers.H23), values });
  };

  let inValues = false;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    const header = HEADER.exec(line);
    if (header) {
      if (header[1] === 'H01' || inValues) {
        flush();
        headers = {};
        values = [];
        inValues = false;
      }
      headers ??= {};
      headers[header[1]] = header[2].trim();
      continue;
    }
    if (!headers) {
      if (line) throw new StatsSaFormatError('The file does not start with a series header.');
      continue;
    }
    inValues = true;
    const value = Number(line.replace(/\s/g, ''));
    values.push(line !== '' && Number.isFinite(value) ? value : null);
  }
  flush();
  return series;
}

/** `YYYY-MM` for the i-th value of a series. */
export function monthAt(series: StatsSaSeries, index: number): string {
  const year = Number(series.start.slice(0, 4));
  const month = Number(series.start.slice(5, 7)) - 1 + index;
  return `${year + Math.floor(month / 12)}-${String((month % 12) + 1).padStart(2, '0')}`;
}

/**
 * Year-on-year % change per month, rounded to one decimal as Stats SA
 * publishes it. Months without a value twelve months earlier are skipped.
 */
export function yearOnYear(series: StatsSaSeries, sinceMonth?: string): Array<{ period: string; value: number }> {
  const out: Array<{ period: string; value: number }> = [];
  for (let i = 12; i < series.values.length; i += 1) {
    const now = series.values[i];
    const then = series.values[i - 12];
    if (now === null || then === null || then === 0) continue;
    const period = monthAt(series, i);
    if (sinceMonth && period < sinceMonth) continue;
    out.push({ period, value: Math.round((now / then - 1) * 1000) / 10 });
  }
  return out;
}
