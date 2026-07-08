# Phase 1 Audit & Remediation — July 2026

A full audit of the TradeIQ codebase and the remediation work that followed.
This is a work-log: it records the state we found, what we changed, and what
remains. The code changes live in the pull requests linked below (not yet
merged at time of writing).

## 1. State at audit time

TradeIQ is a well-architected Phase 1 scaffold: a Flutter app (field-agent
audit + manager/web dashboard) and a Node/Express/TypeScript/Prisma/Postgres
backend, in a clean monorepo with ADRs, onboarding docs, a Makefile,
docker-compose, and CI.

**Working end-to-end (one vertical slice):** auth login → outlet list/picker →
S1 geofenced, offline-first check-in (Drift draft + sync outbox → `POST
/visits`) → 10-step audit stepper. Real domain logic shipped for geofencing,
the SLA clock, and stock coverage-days forecasting.

**Intentionally stubbed / not built:** 9 backend modules + `GET /visits`
return `501` by design; app sections S2–S10 and the manager dashboard are
placeholders; Phase 2 stubs (vision, OCR, fraud, dispatch) sit behind
interfaces. Test coverage was strong for everything that existed.

## 2. Findings

Ordered by priority (none were crash bugs; the built paths were correct):

| # | Area | Finding |
|---|------|---------|
| 1 | Build/CI | Fresh `npm ci && npm run build` failed — no `prisma generate` step, and CI never ran `npm run build`. |
| 2 | CI | Node/toolchain drift (CI Node 20 vs local Node 24). |
| 3 | Security | `requireRole` RBAC guard defined but wired to nothing — any authenticated role could create outlets, etc. |
| 4 | Security | Login unhardened (no rate limit), CORS wide open, no `helmet`. |
| 5 | Mobile | API base URL hardcoded to `http://localhost:4000` (breaks emulator/device/deploy). |
| 6 | Mobile | No session persistence — every app restart forced re-login. |
| 7 | Correctness | Sync payload drops `checkinTs`/`geofencePass`; `geofencePass` can never persist `false`. |
| 8 | UX | Login masks all errors (network/500) as "Invalid credentials". |
| 9 | Testing | Backend tests require a live Postgres with no isolation. |
| 10 | Misc | Outlets list never refreshes; no visit submit/discard path; a guarded side-effect in `build()`. |

## 3. Remediation

### PR #17 — Phase 1 foundation fixes (`fix/phase1-foundation-quick-wins`)
Addresses findings 1, 5, 6, 8.
- Backend: `postinstall: prisma generate` + `npm run build` added to CI.
- App: API base URL from `--dart-define=API_BASE_URL` (default localhost).
- App: session persisted via `flutter_secure_storage` (`TokenStore` /
  `SecureTokenStore`), restored on startup, cleared on logout — best-effort so
  storage failures never brick startup or a valid login.
- App: login distinguishes a 401 from connectivity/server errors.
- Tests for each; CI green.

### PR #18 — RBAC + auth hardening (`feat/rbac-and-auth-hardening`, stacked on #17)
Addresses findings 3, 4.
- `requireRole` wired: `POST /outlets` → manager/admin; `POST /visits` →
  field_agent; `GET /outlets` open to all authenticated roles.
- `helmet` security headers.
- CORS: honors a `CORS_ORIGINS` allowlist in production; open policy as a dev
  fallback when unset.
- Login rate limiting (default 10 / 15 min per IP, env-tunable).
- Unit tests for the guard + limiter, a helmet-header assertion, and 403
  integration cases. CI green.

### PR #19 — S2 Stock implementation plan (`docs/s2-stock-plan`)
- A TDD, task-by-task plan for the S2 Stock slice
  (`docs/superpowers/plans/2026-07-08-s2-stock.md`), matching the S1 format.

### CI unblock (folded into #17/#18)
Two pipeline failures surfaced and were fixed:
- **Backend `npm ci`** rejected the committed `package-lock.json` (extraneous
  phantom `@emnapi` entries). Regenerated the lockfile from a clean install and
  bumped CI Node 20 → 24 to match the local resolver.
- **App `flutter pub get`** conflict: `flutter_secure_storage ^9` pins
  `win32 ^5`, clashing with `geolocator 14.0.3`'s transitive `win32 ^6`.
  Bumped to `flutter_secure_storage ^10.3.1`.
- **App login test** hung under the test binding (real secure-storage channel
  never responds → `pumpAndSettle` timeout). Injected an in-memory `TokenStore`
  fake in the widget test.

## 4. Decisions flagged for the owner

- `POST /visits` = field-agent-only was inferred from the seed/tests. If
  managers/admins should record visits, relax that one guard.
- Merge order: **#17 → #18** (stacked); **#19** anytime.

## 5. Remaining Phase 1 work (not yet done)

- Execute the S2 Stock slice (per PR #19's plan) — in progress next.
- Finding 7: send `checkinTs`/`geofencePass` in the visit sync payload and
  reconcile the `geofencePass`-always-true schema issue.
- Findings 9, 10: test-DB isolation; outlets refresh; visit submit/discard.
- S3–S10 sections + the manager dashboard remain placeholders.
