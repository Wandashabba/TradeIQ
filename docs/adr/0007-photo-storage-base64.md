# ADR 0007 — Phase-1 photo storage: base64 data URLs in Postgres

Date: 2026-07-09
Status: Accepted

## Context

Phase 1's task lifecycle requires **photo-verified closure**, and the S3-S4 /
S5 audit sections are the integration points for Phase-2 computer vision and
OCR — all of which need captured photos to be persisted. The `Photo` model
existed in the schema from the scaffold but nothing wrote to it: no upload
endpoint, no app capture, and `Task.closurePhotoUrl` was an unvalidated
string.

We needed a working photo pipeline in Phase 1 without taking on the
operational cost of a cloud object store (S3/GCS/Azure Blob), consistent with
ADR 0002 (lean Phase-1 infra).

## Decision

For Phase 1, photos are uploaded as **base64 data URLs in the JSON request
body** to `POST /photos` and stored directly in the `Photo.url` column
(Postgres `text`). No object store, no multipart, no new backend dependency.

- The Express JSON body limit is raised to `12mb`; the `/photos` route caps a
  single `dataUrl` at ~8 MB of base64.
- `Photo` rows carry `visitId`, `section`, `gpsTag` (JSON), `timestamp`, and
  `createdAt`, so the raw image plus its EXIF-style GPS/time context is
  captured — exactly the inputs Phase-2 CV/OCR/fraud need.
- Task closure is genuinely photo-verified: closing a task requires a
  `closurePhotoUrl` that matches an existing `Photo` row belonging to the
  caller's client.

## Consequences

**Positive:** zero new infra/deps; the pipeline works end-to-end offline-first
(app → `/photos` → DB) and unblocks Phase-2 CV/OCR/fraud data capture now
(issues #1, #2, #3). Testable without external services.

**Negative / to revisit in Phase 2+:** base64-in-Postgres is ~33% larger than
binary and bloats the row/DB; it is not CDN-served and not suitable for large
volumes. When Phase 2 adds real CV/OCR, migrate to an object store (presigned
uploads, `Photo.url` becomes an object URL) behind the same `POST /photos`
contract so callers do not change. Tracked with the CV/OCR issues (#1, #2).
