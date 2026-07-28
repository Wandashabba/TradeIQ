# Premium UI Polish Sweep — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Checkbox (`- [ ]`) steps. Two PRs: **A** (visible tweaks + docs, Tasks 1–4) then **B** (shared-widget extractions, Tasks 5–7).

**Goal:** Close out the merged premium redesign — fix the remaining user-visible rough edges and kill the shared-widget drift the reviews kept flagging.

**Architecture:** Presentation-only + refactors on the console design system (theme-aware light + dark). No provider/data/routing changes except #221 (an error-copy helper call). Every touched screen keeps its keys and both-theme tests; every coloured text stays AA-safe (the `crit`→`critText` lesson); grep-guard non-geometry `AppColors.` where converting.

**Tech Stack:** Flutter; `flutter_test`; `context.colors` (TiqColors); console widgets; pinned CFT Chrome for the dashboard shots.

**Branches:** PR A `feat/premium-ui-polish-a` off fresh `main`; PR B `feat/premium-ui-polish-b` off PR A's tip (or fresh main if A merges first). Both PR-base `main`.

**Verified facts (from scout — file:line):**
- Charts paint `points[i].label` raw (`charts.dart` `_LinePainter:363`, columns `:617`, bars `:765`) — formatting is the caller's job. Trends already shortens via a PRIVATE `_shortPeriod` (`trends_screen.dart:120-127`, handles `YYYY-Www`→`Www` and `YYYY-MM-DD`→`MM-DD`, but NOT full-ISO-with-time). Dashboard passes raw `p.period` at `dashboard_shell_screen.dart:272` (hero LineChart) + `:755` (on-shelf ColumnChart) — these periods are full ISO (`2026-07-06T00:00:00.000Z`).
- `StatTile` (`console.dart:326,361-372`) renders `value` (a `String`) statically; only the delta pill animates (`animateDelta`/`OneShotEntrance.pill`). Hero score counts up via `_HeroScoreState` `TweenAnimationBuilder` (`dashboard_shell_screen.dart:334-340`, `Motion.countUp`). `AnimatedCount` (`agent_motion.dart:74`) is int-only + agent-side. Dashboard KPI values assembled at `:610` (`rows[r][c].$2`, a String).
- Territory selector = raw `DropdownButton<String?>` (`dashboard_shell_screen.dart:1558-1582`, key `filter-territory`) beside the pill `_RangeControl` (`:1613`).
- `DeltaBadge` (`charts.dart:1136-1181`, icon + `suffix` + theme good/crit) used ONLY in the scrub tooltip `_ScrubReadout` (`charts.dart:1109`). `DeltaPill` (`delta_pill.dart:25`, glyph + `DeltaTone` + fixed hexes, NO suffix) used widely.
- Status-pill wash pairs duplicated as literal hexes in 4 files: `delta_pill.dart:39-41` (the source), `sla_pill.dart:45-46`, `agent_kit.dart:55-56` (fg only), `today_screen.dart:230-231`. No shared token; `DeltaTone` is just an enum with inlined switch colours (`:38-42`).
- PillSegment idiom hand-rolled 3×: `_RangeControl` (`dashboard_shell_screen.dart:1613-1672`), `_FilterChips` (`tasks_screen.dart:167-225`), `_ScopeSegment` (`visit_outlet_picker_screen.dart:146-195`). All: 160ms `AnimatedContainer`, active `brand`+white / inactive `surface1`+`line`+`ink2`, `radiusPill`, 11px w600, `Semantics(button, selected)`. Alerts `_Segmented` (`alerts_screen.dart:195-254`) is a DIFFERENT connected-tab idiom — LEAVE IT (its doc says so).
- `WorklistRow` recipe (`worklist.dart:415-437`: margin `(8,4,8,4)`, surface1+line+radiusPanel, `ClipRRect(radiusPanel-1)`, 3px edge from `StatusLevel.colorOf` `:319`, 44×44 `thumb` slot `:332`, hover/press wash `AnimatedContainer(150ms)` in InkWell). Today's `_StopCard` (`today_screen.dart:313+`) re-implements it for a `brand` edge (no StatusLevel) + `_Seq` badge (not a thumb) + `PressFeedback`.
- `humanErrorMessage(Object)` exists (`core/network/human_error.dart:10`); my-work error branch renders raw `'$err'` (`my_work_screen.dart:43-50`), not routed through it.
- `design/tokens.css:68-70` — no `--r-pill`, comment "Nothing is a pill" (false), `--r-panel: 4px` (Flutter `radiusPanel = 12`). Spec `docs/superpowers/specs/2026-07-24-premium-ui-redesign-design.md:185` calls the pin glow "the only looping animation anywhere" (false — `PulseDot`).
- `contrastRatio`: `app/test/core/theme/tiq_colors_test.dart`. Pinned CFT Chrome for dashboard proof (dashboard IS web-reachable — manager screen, no local DB).

---

# PR A — Visible tweaks + docs

## Task 1: Shared period-label formatter (#203)

**Files:** create `app/lib/core/format/period_label.dart`; modify `dashboard_shell_screen.dart` (`:272`, `:755`), `trends_screen.dart` (replace private `_shortPeriod`); tests.

- [ ] Failing tests (`app/test/core/format/period_label_test.dart`): `formatPeriodLabel('2026-07-06T00:00:00.000Z')` → `'6 Jul'` (or `'07-06'` — pick a short human form, be consistent, test it); `'2026-W26'` → `'W26'`; `'2026-07-06'` → same short date; a non-date string passes through unchanged. Cover a full-ISO-with-time (the dashboard case the current regex misses).
- [ ] Implement `String formatPeriodLabel(String period)` handling: full ISO (has `T`) → take the date part then format; bare `YYYY-MM-DD` → format; `YYYY-Www` → `Www`; else passthrough. Dashboard hero LineChart (`:272`) + on-shelf ColumnChart (`:755`) map their labels through it; `trends_screen` replaces its private `_shortPeriod` with the shared helper (keep behaviour). Dataviz rule: axis text stays in ink tokens (unchanged — just the string).
- [ ] `cd app && flutter test test/core/format/ test/features/dashboard/ test/features/trends/ && flutter analyze`; full `flutter test`. Commit `fix(app): readable chart period labels on the dashboard (premium-ui polish) — closes #203` + `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## Task 2: KPI tile count-ups (#200)

**Files:** modify `console.dart` (`StatTile`), `dashboard_shell_screen.dart` (KPI assembly `:610`), tests.

- [ ] Failing tests: a `StatTile` given an opt-in numeric count-up renders 0→value over ~`Motion.countUp` (t=0 differs from final, equals final after settle), formatted (e.g. `72.7%`); under `reduceMotion` the final value is on the first frame; static (no numeric) tiles unchanged. Dashboard KPI figures count up (assert one tile's text changes t0→settle without reduceMotion; final under reduceMotion).
- [ ] Implement: add optional `num? countUpValue` + `String Function(num) countUpFormat` to `StatTile` (keep the `String value` path for static tiles). When provided, a `TweenAnimationBuilder<double>` (0→value, `Motion.countUp`, reduceMotion→`Duration.zero`) formats each frame; one-shot (latch like the hero — don't replay on refresh/rebuild). Dashboard passes the KPI numeric + a formatter (percent/number) instead of the pre-formatted string where it has the number; a small stagger (~`Motion.stagger`×index) is optional. Keep the delta pill + sparkline. NOTHING loops.
- [ ] `flutter test test/core/widgets/ test/features/dashboard/ && flutter analyze`; full suite. Commit `feat(app): KPI figures count up on load (premium-ui polish) — closes #200`.

## Task 3: Territory selector → pill-styled trigger (#199)

**Files:** modify `dashboard_shell_screen.dart` (`_FilterBar` territory dropdown `:1558-1582`), tests.

- [ ] Note: territories are an arbitrary-length list, so this is a pill-STYLED dropdown TRIGGER (surface1 + `line` + `radiusPill` + selected label + chevron) opening the menu — NOT a segmented pill row. Match the range chips' inactive-pill look.
- [ ] Failing tests (both themes): the territory trigger renders as a pill (surface1 bg, `line` border, `radiusPill`, ink1/ink2 text, a chevron) — assert decoration off the rendered tree; opening it still lists territories + "All territories" and selecting sets `filter.territoryId` (key `filter-territory` preserved; behaviour unchanged). AA: trigger text ≥4.5:1 both themes.
- [ ] Implement with a `PopupMenuButton`/`DropdownButtonHideUnderline` styled as a pill (or a pill button that shows a menu), `context.colors`, keeping the provider wiring + key. `flutter test test/features/dashboard/ && flutter analyze`; full suite. Commit `feat(app): territory selector gets the pill treatment (premium-ui polish) — closes #199`.

## Task 4: my-work error copy + DeltaBadge doc + doc drift (#221, #202, #201)

**Files:** `my_work_screen.dart`; `delta_pill.dart` + `charts.dart` (docs); `design/tokens.css`; the spec doc; a small my-work test.

- [ ] **#221:** my-work error branch (`my_work_screen.dart:43-50`) → `subtitle: humanErrorMessage(err)` (import the helper). Test: pump the error branch with a non-connectivity error, assert the rendered subtitle equals `humanErrorMessage(thatError)` and the raw `'$err'`/"Unsupported operation" text is absent.
- [ ] **#202:** document the exception — in `DeltaBadge` (charts.dart) and `DeltaPill` (delta_pill.dart) docs, state that `DeltaBadge` is the chart-scrub-tooltip delta (icon + suffix + theme good/crit) and `DeltaPill` is the status pill (glyph + fixed `DeltaTone` washes); they are deliberately distinct, not a fork to merge. Comment-only. (Closes #202 as documented.)
- [ ] **#201:** `design/tokens.css` — add `--r-pill: 999px;`, fix the geometry comment (remove "Nothing is a pill"), correct `--r-panel` to `12px` (match Flutter `radiusPanel`), and the "replaces the pill tab row" line if now false. Spec `:185` — reword so the pin glow is no longer "the only looping animation anywhere" (name `PulseDot` too / point at the accurate motion state).
- [ ] `flutter test test/features/audit/my_work_screen_test.dart && flutter analyze`; full suite. Commit `fix(app): my-work error one-voice + doc drift; document DeltaBadge/DeltaPill (premium-ui polish) — closes #221 #202 #201`.

## Task A-verify: gate + dashboard browser proof + PR A

- [ ] Full gate + `flutter build web --release`. Pinned CFT Chrome (dashboard IS web-reachable): screenshot the dashboard LIGHT + DARK showing readable chart period labels + KPI count-ups (a burst mid-count if cheap) + the pill territory selector. LOOK at each.
- [ ] PR A base `main`, title `fix: readable chart labels, KPI count-ups, territory pill + doc/error polish (premium-ui polish A)`. Body: the four tweaks, closes #203 #200 #199 #221 #202 #201, screenshots, honest limits.

---

# PR B — Shared-widget extractions (kill the drift)

## Task 5: Shared status-pill wash tokens (#214)

**Files:** create `app/lib/core/theme/status_pill_colors.dart` (or add to an existing tokens file); migrate `delta_pill.dart`, `sla_pill.dart`, `agent_kit.dart`, `today_screen.dart`; tests.

- [ ] Failing test: a single source (e.g. `const StatusPillWash good = (bg: Color(0xFFE7F5E7), fg: Color(0xFF0B6B0B)); warn = (…FDF3E2/…8A5A00); bad = (…FDEEEE/…A52A2A);`) exists and each pair clears 4.5:1 (`contrastRatio`); the four consumers reference it (no more literal `0xFFE7F5E7`/`0xFF0B6B0B` outside the shared source — grep-guard test across those 4 files).
- [ ] Implement the shared const, migrate all four consumers (DeltaPill `:38-42`, SlaPill `:45-46`, agent_kit `:55-56` fg, today_screen `:230-231`). No visual change (values identical) — pinned by the existing pill tests. Remove the "kept in sync" comments (now single-sourced).
- [ ] `flutter test test/core/widgets/ test/features/ && flutter analyze`; full suite. Commit `refactor(app): single-source the status-pill wash pairs (premium-ui polish) — closes #214`.

## Task 6: `PillSegment` shared control (#215)

**Files:** create `app/lib/core/widgets/pill_segment.dart`; migrate `_RangeControl` (dashboard), `_FilterChips` (tasks), `_ScopeSegment` (picker); tests. LEAVE alerts `_Segmented`.

- [ ] Failing tests (both themes): `PillSegment` (a single segment) + `PillSegmentBar<T>` (the row) — active = solid `brand`+white, inactive = `surface1`+`line`+`ink2`, 160ms `AnimatedContainer`, `radiusPill`, 11px w600, `Semantics(button, selected)`, optional fixed height/expand; AA both themes (white-on-brand, ink2-on-surface1). Then: the dashboard range control, tasks filter chips, and picker scope control all render via the shared widget (assert the shared type present; the three screens' existing pill tests keep passing with updated finders where needed).
- [ ] Implement the shared widget parameterizing (label, selected, onTap, fixed-height/expand, semantics key); migrate the 3 consumers; keep their keys + behaviour (range/filter/scope selection, counts). Do NOT touch alerts `_Segmented`.
- [ ] `flutter test test/features/dashboard/ test/features/tasks/ test/features/audit/ test/core/widgets/ && flutter analyze`; full suite. Commit `refactor(app): shared PillSegment control (premium-ui polish) — closes #215`.

## Task 7: WorklistRow base for edge/leading variants (#216)

**Files:** modify `worklist.dart` (parameterize) + `today_screen.dart` (`_StopCard` → reuse); tests.

- [ ] Failing tests: `WorklistRow` (or a shared base it/`_StopCard` both use) accepts an arbitrary `Color edgeColor` (not only `StatusLevel`) and a free `leading` widget (not only the 44×44 thumb); Today's stop rows render via the shared base with a `brand` next-stop edge + the `_Seq` badge; the `radiusPanel-1` clip lives in ONE place now. Existing WorklistRow consumers (tasks/alerts/picker) + Today tests keep passing.
- [ ] Implement carefully (this is the riskiest extraction — WorklistRow has hover/press wash + StatusLevel; _StopCard uses PressFeedback + brand edge + badge). Option: extract a `WorklistCardShell` (the margin+surface1+line+radiusPanel+clip+edge) that both `WorklistRow` and `_StopCard` compose, rather than forcing `_StopCard` to become a full WorklistRow. Keep both consumers' interaction models. If the shell can't cleanly absorb both without regressions, extract just the `radiusPanel-1` clip + card decoration helper and note the rest deferred — DON'T force a fragile merge.
- [ ] `flutter test test/core/widgets/ test/features/beatplans/ test/features/tasks/ test/features/alerts/ && flutter analyze`; full suite. Commit `refactor(app): shared worklist card shell (edge+leading variants) (premium-ui polish) — closes #216`.

## Task B-verify: gate + PR B

- [ ] Full gate. Widget tests carry the coverage (pure refactors, no visual change — assert none intended). PR B base `main`, title `refactor: single-source status-pill tokens, PillSegment, worklist card shell (premium-ui polish B)`. Body: closes #214 #215 #216, "no visual change" note, the alerts `_Segmented` left-as-is rationale.

## Self-review notes
- Visible tweaks (#203/#200/#199) are user-facing; extractions (#214/#215/#216) are no-visual-change refactors pinned by existing tests. #221/#202/#201 are copy/doc.
- AA preserved (crit→critText already shipped; the shared status-pill token keeps the validated pairs). reduceMotion-gated count-up; nothing loops.
- #216 is the risk — the plan permits a partial extraction (card shell only) rather than a fragile full merge.
- Keys preserved everywhere; grep-guard non-geometry `AppColors.` on converted files.
