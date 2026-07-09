# Architecture Overview

TradeIQ Phase 1 is a monorepo:

- `app/` — Flutter, single codebase for the field-agent mobile audit flow
  and the manager/admin web dashboard. State management: Riverpod.
  Offline-first: Drift (SQLite) local DB + a sync-queue table flushed by
  `app/lib/core/sync/sync_service.dart` when connectivity returns.
- `backend/` — Node.js + Express + TypeScript. Prisma ORM against
  PostgreSQL. One module per data-model entity group under
  `backend/src/modules/*` (`auth`, `outlets`, `visits`, `stock`,
  `visibility`, `pricing`, `competitive`, `capability`, `risks`, `tasks`,
  `scorecards`, `dashboard` — see `backend/src/app.ts` for the full route
  mount list). JWT auth with role guards (`field_agent` / `manager` /
  `admin`).
- `docs/` — this documentation system.
- `backend/scripts/` — currently just the backend demo-data seed script
  (`backend/scripts/seed.ts`, run via `npm run seed`).

## Request flow (proof-of-concept slice)

1. Agent/manager logs in via `POST /auth/login` (`backend/src/modules/auth/auth.routes.ts`)
   → `400` if `email`/`password` are missing, `401` on bad credentials,
   otherwise a JWT + role.
2. App calls `GET /outlets` with `Authorization: Bearer <token>`.
3. `requireAuth` middleware (`backend/src/middleware/auth.ts`) verifies the
   JWT and attaches `req.user` (`userId`, `role`, `clientId`).
4. `outlets.routes.ts` calls `outlets.service.ts`, which queries Postgres via
   Prisma, scoped to `req.user.clientId`. `POST /outlets` additionally
   validates that `name`, `code`, `channelType`, `lat`, `lng`, and
   `territoryId` are present (`400` if not) and returns `409` if the
   Prisma unique-constraint on `code` is violated (`P2002`).
5. App's `OutletsListScreen` (`app/lib/features/outlets/presentation/outlets_list_screen.dart`)
   renders the response via `outletsListProvider`, a Riverpod
   `FutureProvider` defined in
   `app/lib/features/outlets/data/outlets_repository.dart`.

Every other S1–S10 module follows the same shape once implemented (see
`docs/architecture/stubs-and-interfaces.md` and the follow-up implementation
plan for each section).

## Audit capture flow (implemented: S1, S2, S3–S4)

The field-agent flow is offline-first. On check-in the app writes a local
`VisitDrafts` row plus a `SyncQueueItems` outbox entry, then best-effort
flushes to `POST /visits`. Section captures (S2 stock → `POST /stock`, S3–S4
visibility → `POST /visibility`) and visit submit (`POST /visits/:id/submit`)
enqueue their own outbox items the same way.

Because a visit is created with a *client* id offline, the sync flusher
records the server-assigned id on `VisitDrafts.remoteId` after `POST /visits`
succeeds; dependent items (stock, visibility, submit) resolve that `remoteId`
at flush time and retry if the visit hasn't synced yet. The queue flushes in
FIFO order so a visit always syncs before its children. See
`app/lib/core/sync/sync_service.dart`.

All write routes are role-guarded: check-in/capture/submit are `field_agent`,
outlet creation is `manager`/`admin`. See `backend/src/middleware/roleGuard.ts`.

## Real logic vs. stubbed logic

See `docs/architecture/stubs-and-interfaces.md` for the definitive list.
Short version: geofencing (`backend/src/lib/geofence.ts`), SLA due-date
computation (`backend/src/lib/slaClock.ts`), and stock coverage-days
prediction (`backend/src/services/forecast.service.ts`) are real and
shipped. Computer vision (`vision.stub.ts`), OCR (`ocr.stub.ts`), fraud
detection (`fraud.stub.ts`), and predictive dispatch (`dispatch.stub.ts`) —
all under `backend/src/services/` — are stubbed behind interfaces pending
Phase 2+.
