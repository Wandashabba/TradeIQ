/**
 * A small RFC 4180 reader for the sales-target upload (#119).
 *
 * Deliberately not a dependency: the upload is one narrow, manager-authored
 * file, and what matters is that every row keeps its number so an error can
 * say "row 7". Quoted fields may contain commas, doubled quotes and newlines;
 * CRLF and LF both end a record; a leading UTF-8 BOM (Excel's "CSV UTF-8") is
 * dropped. Records that are entirely blank are skipped but still counted, so
 * row numbers match what a spreadsheet shows.
 */
export interface CsvRecord {
  /** 1-based record number; the header is row 1. */
  row: number;
  fields: string[];
}

export class CsvSyntaxError extends Error {}

export function parseCsv(text: string): CsvRecord[] {
  const input = text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
  const records: CsvRecord[] = [];
  let fields: string[] = [];
  let field = '';
  let inQuotes = false;
  let row = 1;
  let i = 0;

  const endRecord = () => {
    fields.push(field);
    if (!(fields.length === 1 && fields[0].trim() === '')) {
      records.push({ row, fields });
    }
    fields = [];
    field = '';
    row += 1;
  };

  while (i < input.length) {
    const ch = input[i];
    if (inQuotes) {
      if (ch === '"') {
        if (input[i + 1] === '"') {
          field += '"';
          i += 2;
          continue;
        }
        inQuotes = false;
        i += 1;
        continue;
      }
      field += ch;
      i += 1;
      continue;
    }
    if (ch === '"' && field.trim() === '') {
      field = '';
      inQuotes = true;
    } else if (ch === ',') {
      fields.push(field);
      field = '';
    } else if (ch === '\r' && input[i + 1] === '\n') {
      endRecord();
      i += 1;
    } else if (ch === '\n' || ch === '\r') {
      endRecord();
    } else {
      field += ch;
    }
    i += 1;
  }

  if (inQuotes) {
    throw new CsvSyntaxError(`Unterminated quoted field starting on row ${row}`);
  }
  if (field !== '' || fields.length > 0) {
    endRecord();
  }
  return records;
}

/** Header names compared without case, spaces, underscores or hyphens. */
export function normaliseHeader(name: string): string {
  return name.trim().toLowerCase().replace(/[\s_-]+/g, '');
}
