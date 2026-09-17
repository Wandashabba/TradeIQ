/**
 * The envelope every static context table shares.
 *
 * These tables are facts a person looked up and typed in, so each one says
 * where it came from (`source`, `sourceUrl`) and when a person last checked it
 * against that source (`verifiedAt`). Bump `version` on every edit; the version
 * travels into the tool result, so an answer can be traced to the table it
 * read.
 *
 * `coveredYears` is the promise the coverage test enforces: a year listed there
 * must be complete, and the current year must be listed — so the table going
 * stale fails CI in January rather than an answer in March.
 */
export interface DataTable<Entry> {
  version: string;
  source: string;
  sourceUrl: string;
  /** `YYYY-MM-DD` a person last checked the entries against the source. */
  verifiedAt: string;
  coveredYears: readonly number[];
  entries: readonly Entry[];
}
