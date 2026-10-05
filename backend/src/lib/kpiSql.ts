import { Prisma } from '@prisma/client';

/**
 * A facings JSON column's `.total`, in SQL, for a `visit_visibility` row
 * aliased `vv`. Mirrors `kpiMath.facingsTotal` exactly: a non-object column or
 * a non-numeric `total` counts as 0 rather than failing the query.
 *
 * One copy, for the same reason `kpiMath` itself exists. The dashboard tile,
 * the trends series and the assistant's share-of-shelf all divide by this
 * number, and three hand-written copies of one formula is precisely how two
 * KPIs come to disagree (#93). It was written out three times before this.
 *
 * The `vv` alias is part of the contract: a caller must alias
 * `visit_visibility` as `vv`, which all three already did.
 */
export const OWN_FACINGS_SQL = Prisma.sql`CASE
  WHEN jsonb_typeof(vv."facings_count") = 'object'
    AND jsonb_typeof(vv."facings_count"->'total') = 'number'
  THEN (vv."facings_count"->>'total')::float8
  ELSE 0 END`;
