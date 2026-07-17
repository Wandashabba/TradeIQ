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
});
