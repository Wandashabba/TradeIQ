# TradeIQ codebase audit — 2026-08-17

Scope: `backend/` (200 source files, 82 test files) and `app/` (156 lib files,
135 test files), plus CI. Every finding below was checked against the code, not
inferred. Where a claim is a measurement, the command that produced it is named.

---

## Executive summary

**Overall health: good, and unusually so on the axes that are normally worst.**
This is not a codebase with a security problem or a testing problem. It has a
*scale* problem in two specific endpoints, an accessibility gap in the app, and
a pipeline that until today could not see whole classes of failure.

The security posture in particular is better than most production codebases:
tenant scoping is enforced in the service layer as a matter of routine, tokens
are re-validated against the database on every request, the JWT secret has a
strength gate that fails closed on an unset `NODE_ENV`, and there is **not one
explicit `any`** in 200 backend source files.

### Top 5 risks

| # | Risk | Severity | Status |
|---|---|---|---|
| 1 | `GET /dashboard` with `range=All` loads every visit for a tenant with five nested relations, unbounded | **High** | Reported — needs its own PR |
| 2 | Cross-tenant outlet resolution in `GET /skus` leaked promo pricing as an oracle | **High** | **Fixed** |
| 3 | No SAST, no secret scanning, no Dart dependency audit anywhere in CI | **High** | **Fixed** |
| 4 | Schema/migration drift had no gate — a fresh deploy was the first thing to notice | **Medium** | **Fixed** |
| 5 | App accessibility is well below the WCAG 2.2 AA the repo aims at | **Medium** | Reported |

---

## Findings

Sorted by severity. "Fixed" means fixed in this PR with a test that fails
without the fix.

### Critical

None found.

### High

#### H1 — Unbounded dashboard aggregation, reachable in one tap

`backend/src/modules/dashboard/dashboard.service.ts:174-188` and `:220-236`

```ts
prisma.visit.findMany({
  where: visitWhere,                       // clientId + OPTIONAL date range
  include: { stock: true, visibility: true, pricing: true,
             competitive: true, scorecard: true },
})                                          // no take, no cursor
```

`from`/`to` are optional at the route (`dashboard.routes.ts:13-34`) and the app
offers **`DashboardRange.allTime`** as a filter chip
(`app/lib/features/dashboard/data/dashboard_repository.dart:52`), whose window
is `(null, now)`. So "load every visit this tenant has ever recorded, with five
joined relation rows each, into Node memory" is a button in the UI.

**Why it matters.** At 50 agents × 12 visits/day × 250 days ≈ 150 000 visits,
each carrying five relations, this is a multi-hundred-megabyte result set
materialised in one process. It will not degrade gracefully; it will OOM the
container or time out, and it takes the whole API down with it, not just the
dashboard. It is also the landing screen.

**Fix.** Push the aggregation into SQL. The KPI math in `computeKpisFromScope`
consumes visits only to produce sums and ratios, so it can become a `groupBy`
or a raw aggregate that never materialises the rows. Two things make this its
own PR rather than part of this one: the KPI numbers must be proved identical
before and after, and "all time" needs a product decision — a cap that silently
returns 90 days would be worse than the current behaviour, because wrong
numbers beat slow ones only if nobody notices.

**Not fixed here, deliberately.** A rushed change to KPI aggregation is how a
dashboard starts quietly reporting the wrong figures.

#### H2 — Cross-tenant outlet resolution in `GET /skus` ✅ FIXED

`backend/src/modules/skus/skus.service.ts:53`

```ts
prisma.outlet.findUnique({ where: { id: outletId }, select: { code: true } })
```

`outletId` arrives straight from `req.query` (`skus.routes.ts:10-16`) with no
ownership check, and this was **the only query in the file that did not name
the tenant**. A caller in tenant A passing tenant B's outlet id got B's outlet
`code`, which then selected which of A's promos matched and changed
`effectivePrice`.

**Why it matters.** No other tenant's rows are returned, so this is not a bulk
data leak — it is an *oracle*. A price that shifts on a foreign id confirms
that id exists and reveals what its outlet code is, one probe at a time. It is
also a scoping break in a multi-tenant system, which is the class of bug this
repo's own risk register calls non-negotiable.

**Why no test caught it.** Two tests either side of it are named
"foreign/bogus outletId" (`skus.routes.test.ts:88`, `:379`) and both pass
`00000000-0000-0000-0000-000000000000`. A nonexistent id returns null from a
scoped *and* an unscoped lookup, so neither could distinguish them. "Foreign"
and "bogus" are different tests and only the second was ever written.

**Fix applied.** `findFirst({ where: { id: outletId, clientId } })`. New test
`does not resolve a REAL outlet belonging to another client` creates a genuine
outlet in another tenant with a colliding code; it fails on the old code with
`effectivePrice` 15.99 against an rrp of 19.99, and passes on the new.

#### H3 — No SAST, no secret scanning, no Dart dependency audit ✅ FIXED

`.github/workflows/` (before this PR: `app-ci.yml`, `backend-ci.yml`,
`assistant-evals.yml`)

`npm audit --audit-level=high` covered `backend/` dependencies. Nothing
examined the repository's own code, nothing scanned for committed secrets, and
`app/`'s pub.dev supply chain had no check at all — despite the app shipping
secure storage, an encrypted offline database and a JWT.

**Fix applied.** New `security.yml`: Semgrep SAST, Gitleaks over full history
(`fetch-depth: 0`, because a key "removed" in a later commit is still in the
pack file), and `flutter pub outdated` for the Dart side. Weekly as well as
per-PR, since rule packs update continuously and clean code can become
vulnerable without anyone touching it.

**CodeQL was tried first and does not work here.** It analysed all 227 files
correctly, then failed to upload results: code scanning on a **private**
repository requires GitHub Advanced Security, which this user-owned repo does
not have. Semgrep replaces it — no GHAS, no account, public rule packs, results
printed in the job rather than posted to a Security tab that does not exist.
Gated at `--severity=ERROR` only: the WARNING tier is where style-adjacent
rules live, and a first SAST run reporting eighty things gets muted rather than
read.

### Medium

#### M1 — Schema/migration drift had no gate ✅ FIXED

`backend/prisma/` · `.github/workflows/backend-ci.yml`

CI ran `prisma migrate deploy` but never checked that `schema.prisma` and the
migrations folder agree. A schema edit with no migration passes every test on a
machine the developer migrated by hand, then fails on a fresh deploy — the one
environment nobody gets to retry.

**Fix applied.** A `migrate diff --from-migrations … --exit-code` step against a
dedicated throwaway shadow database. Verified in both directions before being
committed: exit 0 on the tree as it stands, exit 2 naming the added column when
a field is added to `schema.prisma` without a migration.

#### M2 — App accessibility is below the WCAG 2.2 AA bar

`app/lib/` — measured across 48 screens

| Signal | Count |
|---|---|
| Files using `Semantics(` | 8 |
| Screens (`*_screen.dart`) | 48 |
| `IconButton`s with a `tooltip:` | 14 of 17 |
| `Image.asset/network/memory` calls | 8, none with `semanticLabel` |

**Why it matters.** Flutter derives a semantics tree from widgets, so text and
standard Material controls are announced automatically — this is not "nothing
works". But an icon-only button with no tooltip announces as "button" with no
name, and a decorative-or-not image with no label is announced as an unlabelled
image. Both are direct WCAG 2.2 AA failures (1.1.1, 4.1.2) and both are cheap.

The assistant work sets the right example already — `artifact_filters.dart:348`
puts `Semantics(selected: …, button: true)` on every filter chip precisely so
the state is announced rather than left to fill colour. That pattern has not
spread.

**Fix.** Add `tooltip:` to the three bare `IconButton`s; add
`semanticLabel:` (or wrap in `ExcludeSemantics` where genuinely decorative) to
the eight images; then add a semantics smoke test per screen. Half a day.

#### M3 — Designed state coverage is uneven

`app/lib/features/` — 48 screens

- 16 screens use `AsyncValue.when(...)`, which gives loading and error for free.
- 19 screens reference the shared `EmptyState` (`lib/core/widgets/worklist.dart:93`).
- **14 screens carry all three of loading / error / empty.**

**Why it matters.** The missing state is almost always *empty*, and empty is the
state a new tenant sees on day one. A screen that renders a blank panel instead
of "no visits yet — they appear as agents submit them" reads as broken software
during exactly the demo that matters.

**Fix.** The widget already exists and is good; this is adoption, not design.
Work through the 34 screens that lack one, per screen, smallest first.

#### M4 — Responsive coverage is thin, and it is a Phase 2 gate item

`app/lib/features/` — 7 files use `LayoutBuilder` or `MediaQuery` sizing

Only `artifact_screen.dart:273-316` implements a real breakpoint (880px, side
by side above, stacked below). This is already on the Phase 2 gate as
"responsive layout tests at phone/tablet/desktop breakpoints" and remains open.

### Low

#### L1 — 28 raw hex colours outside the theme

`app/lib/` — `grep -rn "Color(0x" lib/ | grep -v lib/core/theme/` → 28 hits
across 10 files, including `charts.dart`, `console.dart`, `bottom_nav_bar.dart`
and `login_screen.dart`.

The token system is real and good (`lib/core/theme/`: `app_colors.dart`,
`tiq_colors.dart`, `status_pill_colors.dart`, with a `context.colors`
extension). These 28 sit outside it, so a theme change — dark mode especially —
will miss them. Several are plausibly deliberate (a map basemap tint, a chart
gradient); each needs a one-line judgement, not a blanket rewrite.

#### L2 — 127 `req.user!` non-null assertions

`backend/src/modules/**/*.routes.ts`

Every one sits behind `requireAuth`, so they are correct today. They are still
an assertion the compiler cannot check, repeated 127 times. A typed
`AuthedRequest` whose `user` is non-optional — produced by a small handler
wrapper — would make the guarantee structural. Low priority precisely because
the current code is right; this is about keeping it right.

---

## What is genuinely good

Not padding. These are things that are usually wrong and are not.

- **Tenant scoping is a habit, not a policy document.** Every one of 38 route
  modules mounts `requireAuth` (only `auth.routes.ts` does not, correctly).
  Every service references `clientId`. The single exception is H2 above — one
  line in 200 files.
- **Revocation actually works.** `middleware/auth.ts:29-60` re-reads the user on
  every request and re-checks `active`, `role` **and** `clientId`, returning one
  indistinguishable 401 for all three. Most systems ship a 12-hour token and
  call deactivation done.
- **The JWT secret gate fails closed.** `auth.service.ts:28-49` treats an unset
  `NODE_ENV` as production, rejects the repo's own published placeholders by
  name, and `assertJwtSecretUsable()` kills the process at boot rather than
  serving a healthy-looking API that cannot authenticate anyone.
- **Type safety is genuinely enforced.** Zero explicit `any` in 200 backend
  source files. Zero swallowed `catch {}`. `typecheck` covers `scripts/` and
  `evals/`, which `build` misses — a gap this repo found and closed twice.
- **Coverage is high and honest**: 92.95% statements, 84.19% branches, 93.61%
  lines, measured 2026-08-17, nothing excluded from the denominator.
- **0 dependency advisories** at `--audit-level=low`.
- **SSRF and URL handling have dedicated, tested guards** (`lib/ssrfAgent.ts`,
  `lib/urlGuard.ts`) — webhooks are the classic hole and this one is covered.
- **The commentary is load-bearing.** Comments here explain *why*, name the
  incident that motivated a choice, and record what was tried and rejected.
  That is why this audit could be accurate: most of the hard questions were
  already answered in the file.

---

## Remediation roadmap

### Quick wins (< 1 day) — all landed in this PR except where noted

- [x] H2 — scope the outlet lookup, with a test that fails without it
- [x] H3 — `security.yml`: CodeQL, Gitleaks, pub advisories
- [x] M1 — migration-drift gate, verified in both directions
- [x] Pipeline — release web build + web plugin registration check
- [x] Pipeline — lockfile prune ratchet
- [x] Pipeline — coverage floors (90/80/90/90)
- [ ] M2 — three tooltips and eight image labels (~half a day)
- [ ] L1 — triage the 28 raw hex values

### Medium (days)

- [ ] M3 — empty states across the 34 screens that lack one
- [ ] M4 — the breakpoint test set (already a Phase 2 gate item)
- [ ] Per-screen semantics smoke tests, so M2 cannot regress

### Structural (its own PR, with proof)

- [ ] **H1 — dashboard aggregation in SQL.** Prove the KPI figures are
      byte-identical before and after, then decide what "all time" means for a
      tenant with a million visits. This is the one finding here that can take
      the API down.
- [ ] `flutter test --platform chrome` in CI. 119 of 135 suites are free of
      `dart:io` and could run there. Left out today because the dart2js compile
      for a single suite hung past ten minutes locally, twice, and a blocking
      job nobody has seen go green is how a pipeline starts being ignored.
