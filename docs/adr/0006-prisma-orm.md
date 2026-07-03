# 0006. Prisma as the backend ORM

Date: 2026-07-02
Status: Accepted

## Context

Needed to choose between raw SQL migrations (e.g. via Knex) and a
type-safe ORM, for a 16-table schema that will grow as Phase 1 features are
implemented.

## Decision

Use Prisma. `backend/prisma/schema.prisma` is the single source of truth for
the data model; migrations are generated via `prisma migrate dev`.

## Consequences

- Type-safe queries throughout `backend/src/modules/*`.
- New tables/columns require a schema.prisma edit + `prisma migrate dev`,
  not hand-written SQL — documented in `docs/architecture/data-model.md`.
- Pinned to Prisma 6.x (`"prisma": "^6.19.3"`) after a breaking change in
  Prisma 7 surfaced during Task 4; revisit the major-version bump once it's
  been vetted separately.
