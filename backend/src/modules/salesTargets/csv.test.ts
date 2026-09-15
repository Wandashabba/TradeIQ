import { CsvSyntaxError, normaliseHeader, parseCsv } from './csv';

describe('parseCsv', () => {
  it('reads plain rows with their row numbers, header as row 1', () => {
    expect(parseCsv('a,b\n1,2\n3,4')).toEqual([
      { row: 1, fields: ['a', 'b'] },
      { row: 2, fields: ['1', '2'] },
      { row: 3, fields: ['3', '4'] },
    ]);
  });

  it('handles quotes, doubled quotes, embedded commas and newlines', () => {
    const records = parseCsv('name,note\r\n"Cola, 2L","say ""hi""\nthere"\r\n');
    expect(records).toEqual([
      { row: 1, fields: ['name', 'note'] },
      { row: 2, fields: ['Cola, 2L', 'say "hi"\nthere'] },
    ]);
  });

  it('keeps empty trailing fields and empty quoted fields', () => {
    expect(parseCsv('a,b,c\n1,,\n"",x,""')).toEqual([
      { row: 1, fields: ['a', 'b', 'c'] },
      { row: 2, fields: ['1', '', ''] },
      { row: 3, fields: ['', 'x', ''] },
    ]);
  });

  it('skips blank lines but keeps counting them, and drops a BOM', () => {
    expect(parseCsv('﻿a\n\n1\n   \n2\n')).toEqual([
      { row: 1, fields: ['a'] },
      { row: 3, fields: ['1'] },
      { row: 5, fields: ['2'] },
    ]);
  });

  it('refuses an unterminated quote', () => {
    expect(() => parseCsv('a\n"open')).toThrow(CsvSyntaxError);
  });

  it('is empty for an empty file', () => {
    expect(parseCsv('')).toEqual([]);
  });
});

describe('normaliseHeader', () => {
  it('ignores case, spaces, underscores and hyphens', () => {
    expect(normaliseHeader(' Target_Units ')).toBe('targetunits');
    expect(normaliseHeader('target-units')).toBe('targetunits');
    expect(normaliseHeader('Target Units')).toBe('targetunits');
  });
});
