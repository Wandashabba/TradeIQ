# Premium UI Sub-project 2 — Stripe Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The manager dashboard becomes the approved Stripe treatment — glass hero with gradient-area trend, KPI cards with delta pills and gradient micro-trends (no icons), restyled needs-attention and filters — plus the approved one-shot motion set, and the two small "missed" items folded in (bottom bar dark-theme treatment; stale motion doc-comment).

**Architecture:** Pure restyle of `dashboard_shell_screen.dart` panels — same providers, same data, no logic changes. A small shared `DeltaPill` widget carries the pill language. Motion is one-shot entrance animation, `reduceMotion`-gated, with the test-friendliness pattern already proven by the trail's glow (`debugDisable*` kill-switch where needed).

**Tech Stack:** Flutter; flutter_test; pinned Chrome-for-Testing 150.0.7871.129 for proof.

**Spec:** `docs/superpowers/specs/2026-07-24-premium-ui-redesign-design.md`, "Sub-project 2" + "Motion system". Approved mockups: treatment C hero + v4-B KPI cards (user picks recorded in the spec).

**Branch note:** based on the maps tip (`feat/premium-ui-redesign`) with the PR based on `main` — if #196 merges first the PR shows only dashboard commits; either way the superset is mergeable. Do NOT rebase mid-work.

**Chart rules (dataviz, binding):** stat tiles for headline numbers; 2–2.5px lines; one axis; text in ink tokens never series colour; recessive grid; the amber↔green adjacency always labelled/gapped. The hero chart keeps its existing single axis and target line.

---

## Task 1: DeltaPill + glass hero + KPI cards (the C + v4-B treatments)

**Files:**
- Create: `app/lib/core/widgets/delta_pill.dart`
- Modify: `app/lib/features/dashboard/presentation/dashboard_shell_screen.dart` (`_ExecutionScorePanel`, `_KpiStrip`)
- Modify: `app/test/features/dashboard/dashboard_shell_screen_test.dart` (+ a small new `delta_pill_test.dart`)

- [ ] **Step 1: Read the current panels.** `_ExecutionScorePanel` (hero: big number + trend chart via the repo's chart widgets) and `_KpiStrip` (the KPI tiles). Identify exactly what renders the delta arrows today.

- [ ] **Step 2: Failing tests.**
  - `app/test/core/widgets/delta_pill_test.dart`: `DeltaPill(delta: 4.2, tone: DeltaTone.good)` renders `▲ 4.2` inside a rounded wash (`#E7F5E7` bg / `#0B6B0B` text); `DeltaTone.warn` → `#FDF3E2`/`#8A5A00`; `DeltaTone.bad` → `#FDEEEE`/`#A52A2A`; negative deltas render `▼`. A contrast unit test: each text colour vs its wash ≥4.5:1 via the repo's `contrastRatio` helper.
  - Dashboard test additions: hero panel contains a `DeltaPill`; hero card's decoration carries the glass gradient (`#F2F7FF → #FFFFFF`); each KPI tile contains a `DeltaPill` and a micro-trend chart widget; NO `Icon` inside KPI tiles (the user removed icons — guard it: `find.descendant(of: kpiTile, matching: find.byType(Icon))` finds nothing).

- [ ] **Step 3: Implement.**
  - `DeltaPill`: stateless, `(double delta, DeltaTone tone)`, rounded-999 container, 10–11px w700 text, `▲`/`▼` by sign. One shared widget — the pill language for the whole redesign.
  - Hero (`_ExecutionScorePanel`): card decoration gains the glass wash (linear 135°, `#F2F7FF → #FFFFFF`, border `#DBE7FA`); score at 30–32px w700; `DeltaPill` beside it; target stays a dashed line labelled on the chart; the trend line 2.5px with a gradient area fill fading `brand 28% → 0%` and an endpoint dot. Reuse the repo's existing chart widgets (`charts.dart`) — extend minimally if the area-gradient/endpoint-dot options don't exist yet; do NOT hand-roll a parallel chart system.
  - KPI tiles (`_KpiStrip`): label (10–11px, letter-spaced, ink3) → number (19–22px w700) + `DeltaPill` → gradient micro-trend sparkline (≈22px tall, same gradient recipe). No icons. The lagging-metric pill uses `DeltaTone.warn` (wire from whatever signal the tile already has; if none exists, tone by delta sign only and note it).
  - Keep: providers, refresh wiring, filter behaviour, panel order, `_StubCaveat`.

- [ ] **Step 4:** `flutter test test/features/dashboard/ test/core/widgets/ && flutter analyze` — green/clean. Commit: `feat(app): glass hero + pill-and-microtrend KPI cards (premium-ui sub2)`.

## Task 2: Needs-attention + filter pills

**Files:** `dashboard_shell_screen.dart` (`_NeedsAttentionPanel`, `_FilterBar`, `_RangeControl`), dashboard tests.

- [ ] Failing tests: attention rows lead with a colour-coded numeral (existing) but gain the muted-subtitle structure per the mockup; filter chips render as white pills with the ACTIVE chip solid brand (`#0A6CF0` bg, white text) — assert active-chip decoration.
- [ ] Implement: `_FilterBar`/`_RangeControl` chips → pill style (rounded-999, white bg + hairline for inactive, solid brand for active; text 11px w600). `_NeedsAttentionPanel` rows: numeral 14px w700 colour-coded (existing colours), title w650, subtitle ink3 — matching the approved full-dashboard mockup. "View all" stays accent.
- [ ] `flutter test test/features/dashboard/ && flutter analyze` → commit: `feat(app): needs-attention + filter pills restyle (premium-ui sub2)`.

## Task 3: Dashboard motion — the approved one-shot set

**Files:** `dashboard_shell_screen.dart`, possibly `app/lib/core/widgets/charts.dart`, dashboard tests.

All `reduceMotion`-gated; one-shot on first build only; NOTHING loops. Follow the trail's testability pattern (`@visibleForTesting static bool debugDisableDashboardMotion = false` on the shell screen, flipped in existing tests' setUp if pumpAndSettle would otherwise hang — but these are one-shot tweens, so pumpAndSettle SHOULD settle; prefer no kill-switch if tests pass without it, and say which way it went).

- [ ] Failing tests: (a) under `reduceMotion` (FakeAccessibilityFeatures pattern) the score renders its final value on first frame and `pumpAndSettle` completes with no animation frames; (b) without reduceMotion, the score text at t=0 differs from t=700ms (count-up in progress → final).
- [ ] Implement: score counts up 0→value over ~600ms ease-out (`TweenAnimationBuilder`, one-shot); `DeltaPill`s scale-fade in after ~450ms; the hero chart line draws left-to-right once (~700ms — if `charts.dart` supports a progress clip cheaply, use it; otherwise fade the chart in and NOTE the draw-in as deferred rather than hacking the chart internals); KPI sparklines fade in staggered ~40ms apart.
- [ ] `flutter test test/features/dashboard/ && flutter analyze` → commit: `feat(app): one-shot dashboard motion, reduceMotion-gated (premium-ui sub2)`.

## Task 4: The two folded-in misses

**Files:** `app/lib/core/widgets/bottom_nav_bar.dart`, `app/lib/core/widgets/nav_menu_sheet.dart`, `app/lib/core/widgets/agent_motion.dart`, their tests.

- [ ] **Bar dark-theme treatment:** the bar/sheet currently hardcode the light treatment. Make them theme-aware: dark theme → bar bg `rgba(18,21,28,.92)`, hairline `#262B33`, inactive ink `#8A94A6`, active pill `#12305C` bg with `#6DB4FF` icon/label; sheet surfaces follow `colors.surface1`/`line`. Light theme unchanged. Tests: pump the bar under `AppTheme.dark()` and assert the dark bg + pill colours; existing light tests unmodified.
- [ ] **`agent_motion.dart` doc fix:** the file doc claims PulseDot is the app's only looping animation — false since the trail glow. Update the sentence to name both and point at the spec's motion table. Comment-only.
- [ ] `flutter test test/core/widgets/ && flutter analyze` → commit: `fix(app): dark-theme bottom bar + stale motion doc (premium-ui sub2)`.

## Task 5: Verification + browser proof + PR

- [ ] Full app suite + analyze at HEAD; `flutter build web --release`.
- [ ] Pinned CFT Chrome proof (scratchpad `cft/`; re-download via `npx @puppeteer/browsers install chrome@150.0.7871.129` if wiped): login → dashboard screenshots LIGHT and DARK (theme toggle via menu sheet at narrow width or the app-bar toggle): glass hero + pills + micro-trends visible; narrow-width shot with the DARK bar under dark theme; reduced-motion shot (score at final value immediately). LOOK at every shot.
- [ ] PR: base `main`, title `feat: Stripe dashboard — glass hero, delta pills, micro-trends + motion (premium-ui sub-2)`. Body: treatments, motion set, the two folded-in fixes, chart-rule compliance note, screenshots, honest-limits section. Note the branch-superset relationship with #196 if it hasn't merged yet.

## Self-review notes
- Spec coverage: hero C ✓(T1), KPI v4-B no-icons ✓(T1 incl. the no-Icon guard), attention/filters ✓(T2), motion table's dashboard rows ✓(T3), bar dark theme ✓(T4), doc nit ✓(T4). Chart rules restated at top; the dataviz "text in ink tokens" applies — DeltaPill text colours are status washes (allowed: status, not series).
- Names: `DeltaPill`, `DeltaTone{good,warn,bad}` used consistently.
- Deferred-if-hard flagged explicitly: chart draw-in may degrade to fade-in with a note — honesty over hack.
