# Premium UI Sub-project 4 — Tasks, Alerts, Evidence & Brand Media Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox (`- [ ]`) steps for tracking.

**Goal:** Tasks and Alerts become the approved premium worklists — filter chips with live counts, SLA pills, severity edges with inline acknowledge, real evidence-photo thumbnails — the shared list widgets carry the card language to all ~20 consumer screens, lists gain cascade/ack-collapse motion, and the Gemini build-time media pipeline exists (script + wired slots; generation/curation is the user's step by design).

**Spec:** `docs/superpowers/specs/2026-07-24-premium-ui-redesign-design.md` §Sub-project 4 + Motion + Accessibility/honesty. Key rules: pills always carry words; **no photo → no thumbnail, never placeholder/generated art on data rows**; app never calls a generative API at runtime.

**Branch:** `feat/premium-ui-sub4` off the sub-2 tip (`feat/premium-ui-dashboard`); PR bases on `main` (superset pattern — sub-2 commits vanish from the PR when #198 merges). Do NOT rebase mid-work.

**Verified facts (scouted 2026-07-25, don't re-derive):**
- `Task.slaDueAt` exists (required DateTime) but `TaskItem` (app) doesn't parse it yet. Tasks `GET /tasks` returns a bare array (NOT `{data,nextCursor}` — pagination is #194's job, do not convert). Alerts list IS paginated; provider drops the cursor.
- Both `TaskItem`/`AlertItem` have `visitId`. No Task/Alert↔Photo relation — linkage via shared `visitId`. `Photo.url` holds the full base64 data URL (~8MB cap, #65); no image lib in backend; `GET /photos?visitId` returns full base64 JSON (manager+agent auth).
- `WorklistRow` (worklist.dart) already does 3-channel severity (left edge + chip + word), hover wash; consumed by ~20 screens. `EmptyState` is text-only. No list entrance motion exists. `OneShotEntrance`/`Motion` shipped in sub-2 (console.dart / agent_motion.dart).
- No `tool/` dir; no GEMINI key var anywhere in env examples.
- Alerts acknowledge is already inline (`PATCH /alerts/:id/ack`); alerts have NO `ackedAt` timestamp (boolean only) — don't invent one.

---

## Task 1: Backend evidence read path (thumbnail endpoint + list linkage)

**Files:** create `backend/src/modules/photos/thumbnails.ts` (or inside photos.service), modify `photos.routes.ts`, `tasks.service.ts`, `alerts.service.ts`, their tests. New dep: `sharp`.

- [ ] Failing tests first (jest, `--maxWorkers=4`): (a) `GET /photos/:id/thumbnail` returns 200 `image/jpeg`, byte length < 60KB for a seeded ~1MB fixture photo, `Cache-Control: private, max-age=86400, immutable`; 404 unknown id; 401 unauthed; second call served from cache (spy or timing-free assertion via a cache-size probe/export). (b) tasks list response rows gain `evidencePhotoId: string|null` (newest photo of the linked visit; null when no visit/no photos). (c) same for alerts list (inside the `{data,...}` envelope, no cursor/sort changes — verify current orderBy against the file FIRST and do not change it).
- [ ] Implement: `sharp` resize (width 256, JPEG quality 70, rotate() for EXIF) decoding the base64 data URL; in-memory LRU (~50 entries, keyed photoId) — module-level Map with insertion-order eviction is fine. Batched linkage: one `photo.findMany({ where: { visitId: { in: [...] } }, orderBy: createdAt desc, select: {id, visitId} })` per list call, first-per-visit in JS — NO per-row queries. Auth: same guard as existing photos routes (manager + field_agent).
- [ ] `npm test -- --maxWorkers=4 && npm run lint && npx tsc --noEmit` (lint is CI-gating; never `as any` — use `as unknown as <T>`). Commit: `feat(backend): photo thumbnail endpoint + evidence linkage on task/alert lists (premium-ui sub4)`.

## Task 2: Shared worklist card language + cascade motion

**Files:** `app/lib/core/widgets/worklist.dart`, its tests; touches nothing per-screen.

- [ ] Failing tests: `WorklistRow` renders as a white card (surface1 ground, `line` hairline, `radiusPanel`, the Stripe static shadow from console.dart's PanelCard) with the severity left edge INSIDE the card radius (clipped); optional new `thumb:` widget slot renders leading at 44×44 rounded-8 when provided, absent otherwise; a new `WorklistCascade` (or param on existing lists' build helper) wraps rows in `OneShotEntrance` with `Motion.stagger` per index, capped at the first 12 rows (13+ render instantly), one-shot latched, reduceMotion → static. Dark theme: card uses tokens, contrast-assert title/meta on the rendered ground.
- [ ] Implement. Keep: 3-channel severity semantics, hover/press wash, `resolved` dimming, all existing params/keys. Row spacing moves to 8px card gaps (check consumers don't double-pad — fix at the shared level, not per screen).
- [ ] `flutter test test/core/widgets/ && flutter analyze`; then FULL `flutter test` (20 consumer screens ride on this widget — fallout must be fixed here). Commit: `feat(app): worklist rows become cards + cascade entrance (premium-ui sub4)`.

## Task 3: Tasks screen — chips with counts, SLA pills, evidence thumbnails

**Files:** `tasks_screen.dart`, `tasks_admin_repository.dart`, new `app/lib/core/widgets/sla_pill.dart`, new `app/lib/core/widgets/evidence_thumb.dart` (+ small photos-repo addition), tests.

- [ ] Failing tests: `SlaPill` renders per spec — red `OVERDUE 2d`, amber `DUE TODAY`, muted `DUE FRI` (weekday for <7d, else date), green `✓ DONE`; words always; wash pairs ≥4.5:1 via `contrastRatio`; uses a `now` param (no untestable clock). `TaskItem` parses `slaDueAt` + `evidencePhotoId`. Filter chips (reuse the pill treatment from sub-2's `_RangeControl`, extract if sensible) show live counts `Open · N`, `Overdue · N`, `Done` (client-computed; Overdue = open && slaDueAt < now). Each row shows `SlaPill`; rows with `evidencePhotoId` show an `EvidenceThumb`; rows without show NOTHING in the slot (assert absence — honesty rule).
- [ ] `EvidenceThumb`: fetches `GET /photos/:id/thumbnail` as BYTES through the app's authed http client (web can't send auth headers via `Image.network` — must be bytes + `Image.memory`), in-memory cache keyed photoId, 44×44 cover, tap → dialog showing the FULL photo (lazy: existing `GET /photos?visitId` on open), loading shimmer none — just a neutral rounded box until bytes land, alt-semantics label "Shelf photo evidence".
- [ ] Keep: triage strip, close-with-photo + verify actions, providers. The segmented state control may merge into the new chips (Open/Overdue/Done/All) — chips become the single filter row per the mockup.
- [ ] `flutter test test/features/tasks/ test/core/widgets/ && flutter analyze`. Commit: `feat(app): tasks worklist — count chips, SLA pills, evidence thumbnails (premium-ui sub4)`.

## Task 4: Alerts screen — acked fade, ✓ ACKED pill, ack-collapse, thumbnails

**Files:** `alerts_screen.dart`, `alerts_repository.dart` (`evidencePhotoId`), tests.

- [ ] Failing tests: acked rows show muted `✓ ACKED` pill (words, not colour-alone) + reduced opacity (~0.62, still ≥4.5:1 for title — compute against the composited ground); unacked keep inline `Acknowledge` + `View visit` (View visit only when visitId != null — navigates to the visit/trail context that exists today; if no sensible destination exists, keep only Acknowledge and report); acknowledging COLLAPSES the row (SizeTransition ~200ms, reduceMotion → instant removal) BEFORE the provider refresh lands — test with a delayed fake repo; `evidencePhotoId` thumbnails same rules as tasks.
- [ ] Implement. Severity edge/chip/word channels unchanged. No `ackedAt` exists — do not display fake timestamps.
- [ ] `flutter test test/features/alerts/ && flutter analyze`. Commit: `feat(app): alerts worklist — acked fade, ack-collapse, evidence thumbnails (premium-ui sub4)`.

## Task 5: Brand media pipeline (Gemini build-time) + empty-state slots

**Files:** create `tool/generate_brand_media/` (`generate.mjs`, `prompts.mjs`, `README.md`, `.gitignore` for `out/`); modify `worklist.dart` (`EmptyState.illustration`), new `app/lib/core/brand_media.dart`, `nav_menu_sheet.dart` header slot, pubspec assets, tests.

- [ ] Script: Node, reads `GEMINI_API_KEY` from env (NEVER hardcoded/logged), Imagen REST calls, one prompt per asset (tasks all-clear, no alerts, generic empty list, menu-sheet header; splash/sign-in video takes via Veo documented in README as optional manual step), writes `out/<slug>-<n>.png` candidates. README: run → curate → copy chosen files to `app/assets/images/brand/` → add pubspec lines → set paths in `brand_media.dart` → commit. The app repo ships NO generated asset in this PR — slots stay null until the user curates (spec: user curates; honesty: no uncurated art).
- [ ] App wiring: `BrandMedia` — nullable const asset paths (`tasksAllClear`, `noAlerts`, `emptyGeneric`, `menuHeader`), all null now. `EmptyState` gains optional `illustration` (asset path) rendered ≤160px above the message when non-null (test both arms). Menu sheet: optional header image band when `BrandMedia.menuHeader != null` (test the null arm renders today's layout byte-identically). Tasks/alerts empty states pass their `BrandMedia` slots.
- [ ] If `GEMINI_API_KEY` is present in the environment at execution time (`test -n` — never echo it), run the script once to produce candidates in `out/` (gitignored, NOT committed) and say so in the report; if absent, skip generation and say so.
- [ ] `flutter test test/core/widgets/ && flutter analyze`; script smoke-test with a fake key expecting clean auth-error handling. Commit: `feat(app): brand media pipeline + empty-state illustration slots (premium-ui sub4)`.

## Task 6: Verification + browser proof + PR

- [ ] Full suites both stacks at HEAD: backend `npm test -- --maxWorkers=4 && npm run lint`, app full `flutter test && flutter analyze`, `flutter build web --release`.
- [ ] Browser proof (throwaway scratchpad Postgres; pinned CFT Chrome 150.0.7871.129; CDP 127.0.0.1; login/splash/session facts as sub-2). Ensure ≥1 task and ≥1 alert link to a visit WITH a photo (seed or insert one via SQL/API — a small real JPEG, not 8MB). Shots: tasks light (chips w/ counts, SLA pills incl. an OVERDUE, a thumbnail on a row WITH photo and nothing on a row without), alert ack flow (before/after: inline button, collapse, acked fade+pill), tasks empty-state arm if cheap, dark-theme worklist card. LOOK at every shot.
- [ ] PR: base `main`, title `feat: premium worklists — SLA pills, evidence thumbnails, ack-collapse + brand media pipeline (premium-ui sub-4)`. Honest-limits: brand assets not yet generated/curated (user step + how), tasks pagination untouched (#194), superset note if #198 unmerged.

## Self-review notes
- Honesty: no-photo→no-thumbnail asserted by test (T3); no fake `ackedAt` (T4); no uncurated art committed (T5); SLA pills always words (T3).
- Perf: thumbnails ≤60KB tested (T1); batched linkage no N+1 (T1); bytes-not-URL loading for web auth (T3).
- Every motion piece one-shot + reduceMotion-gated (T2 cascade, T4 collapse); cascade capped at 12 rows.
- Backend scope stays within the spec's "photo-thumbnail read path" carve-out (+ the linkage field it requires).
