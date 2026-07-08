# S3–S4 Visibility & Display Implementation Plan

**Goal:** Implement the `visibility` backend module (S3–S4) and the Flutter
S3–S4 capture screen so a field agent can record shelf visibility/display
data for a visit: branding elements present, planogram compliance %, facings
count, high-traffic placement, and a cleanliness score. Offline-first via the
existing sync outbox, mirroring S2.

**Data model:** `VisitVisibility` already exists in `schema.prisma`
(one-to-one with `Visit` via a unique `visitId`) — no Prisma migration
needed. Fields: `brandingElements` (Json), `planogramCompliancePct` (Float),
`facingsCount` (Json), `highTrafficPass` (Bool), `cleanlinessScore` (Int).

**Design notes / deltas from S2:**
- **1:1, so upsert.** Unlike stock (many rows/visit), visibility is one row
  per visit. `recordVisibility` upserts on `visitId` so re-submitting is
  idempotent.
- **No local drafts table.** S2 added a `StockDrafts` Drift table, but those
  rows aren't read anywhere yet. To avoid another Drift migration/codegen,
  S3–S4 persists offline via the sync-queue payload only (a `visibility`
  entity type). Add a `VisibilityDrafts` table later if local read-back is
  needed.
- Sync reuses the remote-id reconciliation added in S2: the `visibility`
  flush case resolves the local visit-draft id → `VisitDrafts.remoteId`
  before `POST /visibility`.

**Out of scope:** the `vision.stub` auto-detection (Phase 2), per-SKU facings
breakdown (single total for now), manager rollups.

---

## Task 1: Backend — `visibility.service.ts` (upsert, client-scoped)

`recordVisibility({ visitId, clientId, brandingElements, planogramCompliancePct, facingsCount, highTrafficPass, cleanlinessScore })`:
- verify the visit belongs to `clientId` (404 otherwise);
- `prisma.visitVisibility.upsert` keyed on `visitId`.

## Task 2: Backend — `POST /visibility` route + retire `/visibility` skeleton

- `visibility.routes.ts`: `POST /` (`requireRole('field_agent')`), validate
  `visitId` + the numeric/bool/json fields (400 otherwise), call
  `recordVisibility`, `201`. `GET /` stays `501` with its own test.
- Remove `/visibility` from `moduleSkeletons.test.ts`.
- Tests: 201 upsert + re-submit idempotency, cross-client 404, missing-field
  400, manager 403, no-token 401, GET 501.

## Task 3: App — `VisibilityRepository` (offline-first, enqueue-only)

- `saveVisibility({ visitDraftId, brandingElements, planogramCompliancePct, facingsCount, highTrafficPass, cleanlinessScore })`
  enqueues one `visibility` sync item (payload carries `visitDraftId` + the
  fields) and flushes best-effort.
- Test: enqueues exactly one `visibility` item with the expected payload.

## Task 4: App — `visibility` flush case

- `HttpQueueFlusher`: add `case 'visibility'` — resolve
  `VisitDrafts.remoteId` (throw/retry if not synced), then
  `POST /visibility` with `{ visitId: remoteId, ...fields }`.
- Test: resolves remote id and posts; throws when the visit hasn't synced.

## Task 5: App — S3–S4 form + wire into the stepper

- Replace the `s3_4_visibility_display_screen.dart` placeholder with a form:
  branding-element checkboxes, planogram compliance %, facings count,
  high-traffic switch, cleanliness score; **Save** → `saveVisibility`.
- `AuditShellScreen` passes the visit-draft id to the S3–S4 section (as it
  already does for S2).
- Widget test: enter values, tap Save, assert the repository received them.

## Task 6: Verify

- Backend `npm run lint && npm run build && npm test`.
- App `flutter analyze && flutter test` (CI regenerates Drift code).
