import { readFileSync } from 'fs';
import { join } from 'path';
import { monthAt, parseStatsSaAscii, StatsSaFormatError, yearOnYear } from './statssaAscii';
import { readZip, ZipFormatError } from './zip';

/**
 * Parsing runs against files saved from Stats SA, never the network:
 *
 * - `P62421_retail_ascii_202607.zip` — the P6242.1 time-series download for the
 *   July 2026 release, unmodified.
 * - `P0141_CPI_ascii_202607_subset.zip` — the P0141 COICOP download for July
 *   2026, cut to three of its 784 series (headline, food, Western Cape) so the
 *   fixture stays small. Blocks are byte-for-byte from the original.
 */
const fixture = (name: string) => readFileSync(join(__dirname, '__fixtures__', name));

const text = (zipName: string) => {
  const [entry] = readZip(fixture(zipName), (name) => /\.txt$/i.test(name));
  return entry.data.toString('latin1');
};

describe('readZip', () => {
  it('opens a Stats SA download', () => {
    const entries = readZip(fixture('P62421_retail_ascii_202607.zip'));
    expect(entries.map((e) => e.name)).toEqual(['ASCII/ASCII Retail trade sales.txt']);
    expect(entries[0].data.length).toBe(58_688);
  });

  it('refuses something that is not a zip', () => {
    expect(() => readZip(Buffer.from('<html>Service unavailable</html>'))).toThrow(ZipFormatError);
  });
});

describe('parseStatsSaAscii — retail trade (P6242.1)', () => {
  const series = parseStatsSaAscii(text('P62421_retail_ascii_202607.zip'));
  const byCode = new Map(series.map((s) => [s.code, s]));

  it('reads every block with its headers, start and release', () => {
    expect(series).toHaveLength(32);
    const total = byCode.get('con_act')!;
    expect(total.headers.H15).toBe('At constant prices');
    expect(total.headers.H16).toBe('Actual values');
    expect(total.start).toBe('2002-01');
    expect(total.release).toBe('2026-07');
    expect(monthAt(total, total.values.length - 1)).toBe('2026-07');
    expect(byCode.get('con_S621C')!.headers.H05).toBe('General dealers');
  });

  it('computes year-on-year growth at constant prices', () => {
    const yoy = yearOnYear(byCode.get('con_act')!, '2026-01');
    expect(yoy).toEqual([
      { period: '2026-01', value: 4.4 },
      { period: '2026-02', value: 1.6 },
      { period: '2026-03', value: 2.5 },
      { period: '2026-04', value: 1.2 },
      { period: '2026-05', value: 2.2 },
      { period: '2026-06', value: 1.1 },
      { period: '2026-07', value: 3.4 },
    ]);
  });
});

describe('parseStatsSaAscii — CPI (P0141)', () => {
  const series = parseStatsSaAscii(text('P0141_CPI_ascii_202607_subset.zip'));
  const byCode = new Map(series.map((s) => [s.code, s]));

  it('reads CRLF files and upper-case release headers', () => {
    expect(series.map((s) => s.code).sort()).toEqual(['CPA00000', 'CPS00000', 'CPS01000']);
    expect(byCode.get('CPS00000')!.headers.H13).toBe('All urban areas');
    expect(byCode.get('CPS00000')!.release).toBe('2026-07');
    expect(byCode.get('CPS00000')!.start).toBe('2008-01');
  });

  it('computes headline and food inflation', () => {
    expect(yearOnYear(byCode.get('CPS00000')!, '2026-07')).toEqual([{ period: '2026-07', value: 4.3 }]);
    expect(yearOnYear(byCode.get('CPS01000')!, '2026-07')).toEqual([{ period: '2026-07', value: 0.9 }]);
  });
});

describe('parseStatsSaAscii — malformed input', () => {
  it('treats non-numeric values as missing months without shifting later ones', () => {
    const [series] = parseStatsSaAscii(
      ['H01: P0141', 'H03: X', 'H24: Start: 2024 11', '100', '..', '', '102', ''].join('\n'),
    );
    expect(series.values).toEqual([100, null, null, 102]);
    expect(monthAt(series, 3)).toBe('2025-02');
  });

  it('refuses a block with no start month, and an HTML error page', () => {
    expect(() => parseStatsSaAscii('H01: P0141\nH03: X\n1\n2')).toThrow(StatsSaFormatError);
    expect(() => parseStatsSaAscii('<html><body>Maintenance</body></html>')).toThrow(StatsSaFormatError);
  });

  it('skips months with no value a year earlier', () => {
    const values = ['H01: P', 'H03: X', 'H24: Start: 2024 01', ...Array.from({ length: 13 }, (_, i) => (i === 0 ? '..' : '100'))];
    expect(yearOnYear(parseStatsSaAscii(values.join('\n'))[0])).toEqual([]);
  });
});
