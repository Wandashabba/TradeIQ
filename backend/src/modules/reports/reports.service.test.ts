import { rowsToCsv } from './reports.service';

describe('rowsToCsv', () => {
  it('neutralizes formula-injection cells with a leading apostrophe', () => {
    const csv = rowsToCsv([{ note: "=cmd|'/C calc'!A0", plus: '+1+1', at: '@SUM(1)', minus: '-2' }]);
    const line = csv.split('\n')[1];
    expect(line).toContain("'=cmd");
    expect(line).toContain("'+1+1");
    expect(line).toContain("'@SUM(1)");
    expect(line).toContain("'-2");
  });

  it('quotes and neutralizes a dangerous cell that also contains a comma', () => {
    const csv = rowsToCsv([{ x: '=1,2' }]);
    // Apostrophe goes inside the RFC4180 quotes.
    expect(csv.split('\n')[1]).toBe(`"'=1,2"`);
  });

  it('leaves ordinary cells untouched', () => {
    const csv = rowsToCsv([{ name: 'Corner Shop', qty: '5' }]);
    expect(csv.split('\n')[1]).toBe('Corner Shop,5');
  });
  it('keeps columns aligned when later rows carry different keys', () => {
    // The header was built from the FIRST row's keys alone, so a row with an
    // extra field silently lost it, and a row missing an early field shifted
    // every later value one column left — a report that reads as clean data
    // while attributing values to the wrong column.
    const csv = rowsToCsv([
      { outlet: 'A', qty: 1 },
      { outlet: 'B', qty: 2, note: 'late column' },
      { qty: 3 },
    ]);
    const [header, ...rows] = csv.split('\n');

    expect(header).toBe('outlet,qty,note');
    expect(rows[0]).toBe('A,1,');
    expect(rows[1]).toBe('B,2,late column');
    // Missing leading field stays an empty cell rather than shifting qty left.
    expect(rows[2]).toBe(',3,');
  });

  it('escapes a column name that contains a comma or quote', () => {
    // Header names went out raw. A report definition whose field is named
    // 'price, ex VAT' produced one more header column than every data row.
    const csv = rowsToCsv([{ 'price, ex VAT': 10, 'say "hi"': 'x' }]);
    const header = csv.split('\n')[0];

    expect(header).toBe('"price, ex VAT","say ""hi"""');
    // Quoted commas must not read as extra columns.
    expect(header.split('","')).toHaveLength(2);
  });
});
