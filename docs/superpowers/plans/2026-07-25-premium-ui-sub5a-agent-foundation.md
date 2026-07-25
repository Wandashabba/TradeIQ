# Premium UI Sub-5a — Field-Agent System Foundation + Landing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the field-agent app theme-aware (interchangeable light + dark) on the manager console's design tokens, and rebuild the two entry screens — **Today** and the **outlet picker** — in the console card/pill language.

**Architecture:** The agent screens currently hardcode the static **dark** `AppColors.*` palette and are force-wrapped in `PinnedDark`. The root `MaterialApp.router` already drives light/dark from `themeModeProvider`. So the foundation change is: **remove `PinnedDark`**, convert the agent kit + scaffold + the two screens from static `AppColors.*` (dark constants) to theme-aware **`context.colors`** (the `TiqColors` extension, which defines both themes), and add a theme toggle to the agent app bar. Then Today and the picker adopt the console's glass-hero + worklist-card + pill vocabulary. Behaviour, routing, providers, and the offline flow are untouched.

**Tech Stack:** Flutter; Riverpod; `flutter_test`; the existing `TiqColors` `context.colors` extension; console shared widgets (`console.dart`, `worklist.dart`); pinned Chrome-for-Testing 150.0.7871.129 for phone-viewport proof.

**Spec:** `docs/superpowers/specs/2026-07-25-premium-ui-sub5-agent-app-design.md` (§Design language, §Screens 1–2, §Architecture, §5a).

**Branch:** `feat/premium-ui-sub5a` off fresh `main`; PR bases on `main`.

**Verified facts (read before coding; don't re-derive):**
- `context.colors` is the `TiqColors` extension (`app/lib/core/theme/tiq_colors.dart`) — resolves to `TiqColors.light`/`.dark` from the ambient `Theme`. It defines: `plane, surface1, surface2, surface3, line, lineStrong, ink1, ink2, ink3, brand, good, heroWash, heroBorder` (+ nav slots). `contrastRatio` helper lives in `app/test/core/theme/tiq_colors_test.dart`.
- `AppColors` (`app/lib/core/theme/app_colors.dart`) holds the STATIC dark palette AND the theme-independent geometry doubles (`radiusPanel = 12`, `radiusPill = 999`, `radiusControl`). **Geometry stays `AppColors.*`; colours move to `context.colors`.**
- Root `main.dart:23` already sets `themeMode: ref.watch(themeModeProvider)`. `ThemeModeController.toggle()` (`theme_mode_controller.dart:73`) flips + persists light/dark.
- `PinnedDark` (`app/lib/core/widgets/pinned_dark.dart`) wraps every `AgentScaffold` in `Theme(data: AppTheme.dark())`, overriding the app themeMode. Removing it makes agent screens follow the app theme.
- Console reusables: `PanelCard` (console.dart — surface1 + line + radiusPanel + static Stripe shadow; optional `gradient`/`borderColor` for the glass hero), `DeltaPill`/`DeltaTone` (delta_pill.dart), `WorklistRow` (worklist.dart — surface1 card, coloured severity left edge, `thumb` slot, `WorklistCascade`). Reuse these rather than re-hand-rolling.
- Agent kit (`agent_kit.dart`): `kTapTarget = 48`, `AgentButton`, `CountStepper`, `ChoiceRow`/`_Choice`, `AgentField`, `StatusBanner`/`BannerLevel`, `BarNote`, `formatAgo`. All use static `AppColors.*` today.
- Today (`beatplans/presentation/today_screen.dart`) and outlet picker (`audit/presentation/visit_outlet_picker_screen.dart`) are the 5a screens. Existing tests: `test/features/beatplans/today_screen_test.dart`, `test/features/audit/visit_outlet_picker_screen_test.dart`.
- `AgentScaffold` app bar already has a `logout` action and an optional `actions` list — the theme toggle slots in there.

---

## Task 1: Theme-aware agent foundation (kit + scaffold + toggle)

Convert every colour reference in the agent kit and scaffold from static `AppColors.*` to `context.colors.*`, delete `PinnedDark`, and add a theme toggle to the agent app bar. This is the load-bearing task — every later agent screen inherits it.

**Files:**
- Modify: `app/lib/core/widgets/agent_kit.dart` (all `AppColors.<colour>` → `context.colors.<colour>`; keep `AppColors.radius*`/geometry)
- Modify: `app/lib/core/widgets/agent_scaffold.dart` (drop `PinnedDark`; `AppColors` colours → `context.colors`; add toggle action)
- Delete: `app/lib/core/widgets/pinned_dark.dart` (and its usages — grep `PinnedDark`; also referenced by login/landing per its doc — see Step 5)
- Modify: `app/test/core/widgets/agent_kit_test.dart` (if present) + add `app/test/core/widgets/agent_scaffold_test.dart`
- Reference: `app/lib/core/theme/tiq_colors.dart`, `theme_mode_controller.dart`

- [ ] **Step 1 — Failing test: the scaffold is theme-aware, not pinned dark.** In `agent_scaffold_test.dart`: pump an `AgentScaffold` inside a `ProviderScope` + `MaterialApp(theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ...)` (mirror how console tests pump themes; use `routedApp`-style helper if one exists for agent screens, else a minimal `MaterialApp.router` or a `GoRouter` stub — the scaffold reads `GoRouterState` guardedly so a plain `MaterialApp` with the widget under a `Router` or the `_matchedLocation` catch handles it). Assert: under light theme the `Scaffold.backgroundColor` equals `TiqColors.light.plane`; under dark it equals `TiqColors.dark.plane`. (Today it is always `AppColors.plane` = dark — this fails.)
- [ ] **Step 2 — Run it, watch it fail** (`cd app && flutter test test/core/widgets/agent_scaffold_test.dart`). Expected: light-theme assertion fails (background is the dark plane).
- [ ] **Step 3 — Convert `agent_scaffold.dart`:** remove the `PinnedDark` wrapper (return the `Scaffold` directly). Replace every `AppColors.<colour>` (plane, surface1, line, ink1, ink3, …) with `context.colors.<colour>`; the app-bar title/subtitle `TextStyle` colours become `colors.ink1`/`colors.ink3` (read `final colors = context.colors;` at top of `build`). Keep geometry/`kTapTarget`. The `SyncChip`/`StatusBanner` inside likewise theme-aware (Step 4).
- [ ] **Step 4 — Convert `agent_kit.dart`:** each widget's `build` reads `final colors = context.colors;` and every `AppColors.<colour>` → `colors.<colour>`. Cover `AgentButton` (brand fill / secondary surface+line), `CountStepper`, `ChoiceRow`/`_Choice` (selected brand-tint vs surface), `AgentField`, `StatusBanner` (`BannerLevel` → good/warn/bad/info washes from tokens — reuse the console status wash family; ensure each level's text clears 4.5:1 on its wash in BOTH themes), `BarNote`. Leave `AppColors.radius*` and `kTapTarget` as-is. Any `const` widget that now depends on `context.colors` loses `const`.
- [ ] **Step 5 — Add the theme toggle + retire PinnedDark's other users.** In `AgentScaffold.build`, prepend a toggle `IconButton` to `actions` (before logout): `Icon(colors is dark ? Icons.light_mode : Icons.dark_mode)` chosen by `ref.watch(themeModeProvider) == ThemeMode.dark`, `key: ValueKey('agent-theme-toggle')`, `onPressed: () => ref.read(themeModeProvider.notifier).toggle()`, tooltip "Theme". Grep `PinnedDark` across `app/lib` — the login/landing screens use it (per its doc). For 5a, keep login/landing dark by wrapping them locally in `Theme(data: AppTheme.dark(), child: …)` inline (preserve today's behaviour — auth screens staying dark is out of 5a's scope), then delete `pinned_dark.dart`. If that inline change balloons, INSTEAD keep `pinned_dark.dart` for login/landing only and simply stop using it in `AgentScaffold` — pick the smaller diff and note which in the report.
- [ ] **Step 6 — Failing test: toggle flips the theme.** In `agent_scaffold_test.dart`: pump with a real `ProviderScope`; tap `ValueKey('agent-theme-toggle')`; `pump`; assert `Scaffold.backgroundColor` changed from `light.plane` to `dark.plane` (and the toggle icon swapped). Watch fail → implement (Step 5 covers it) → pass.
- [ ] **Step 7 — Contrast guard (both themes).** Add a test asserting, via `contrastRatio`, that `StatusBanner` text clears 4.5:1 on its wash for each `BannerLevel` in BOTH `TiqColors.light` and `.dark`, and the app-bar title (`ink1`) clears 4.5:1 on `plane` in both. (Mutation-kill for a token that reads fine in one theme only.)
- [ ] **Step 8 — Verify + commit.** `cd app && flutter test test/core/widgets/ && flutter analyze`, then full `flutter test` (agent screens use the kit — fix fallout at the source; existing agent tests that asserted dark-only colours get updated to pump an explicit theme and assert `context.colors`, noting each). `dart format`. Stage only your files. Commit: `feat(app): theme-aware agent kit + scaffold, drop PinnedDark (premium-ui sub5a)` + trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## Task 2: Rebuild Today on the console system

**Files:**
- Modify: `app/lib/features/beatplans/presentation/today_screen.dart`
- Modify: `app/test/features/beatplans/today_screen_test.dart`

- [ ] **Step 1 — Failing tests.** Update/extend `today_screen_test.dart` (pump under an explicit light theme, then dark): (a) the route-progress header renders inside a **glass hero** — a `PanelCard` (or Container) whose decoration carries the `heroWash → surface1` gradient + `heroBorder` (assert the gradient/border tokens off the rendered tree, both themes); (b) the big done-count is 30–32px w700 in `colors.ink1`; (c) a `DeltaPill` OR an "on pace / N left" status pill sits beside it (words, not colour-alone); (d) each route stop renders as a card with a coloured **left edge** — green (`good`) for visited, `brand` for the next stop, muted for upcoming — reuse `WorklistRow` if its API fits (title=outlet name, meta=code, leading `_Seq`, trailing distance + DONE/NEXT pill), else a local card matching its recipe; assert the NEXT stop carries a "NEXT" pill and a visited stop a "DONE"/✓ (glyph+word, not colour alone); (e) NO static `AppColors` colour remains (grep the file for `AppColors.` and allow only `AppColors.radius*`/`kTapTarget`).
- [ ] **Step 2 — Watch them fail** (`flutter test test/features/beatplans/today_screen_test.dart`).
- [ ] **Step 3 — Implement.** `final colors = context.colors;` in each `build`. `_Header` → glass hero: `PanelCard(gradient: LinearGradient(...heroWash→surface1...), borderColor: colors.heroBorder)` (reuse the console hero recipe from `dashboard_shell_screen`'s execution-score panel for exact stops), done-count 31px w700 `colors.ink1` via the existing `AnimatedCount`, the "N left / Route done" becomes a status pill (`DeltaPill`-style or a small pill: `good` wash when complete, neutral otherwise, always with the word). `_ProgressBar` colours → `colors.surface3`/`colors.brand`/`colors.good`. `_StopRow`/`_Seq` → console worklist card treatment: card ground `colors.surface1`, hairline `colors.line`, left edge coloured by state (`good`/`brand`/muted), text `colors.ink1/ink2/ink3`, DONE/NEXT as pills. Keep `Reveal` entrance, `PressFeedback`, `context.go('/audit/...')`, refresh, `_NoRoute`, and all keys (`visit-another`, `pick-a-store`).
- [ ] **Step 4 — Verify + commit.** `flutter test test/features/beatplans/ && flutter analyze`; full `flutter test`. `dart format`. Commit: `feat(app): rebuild agent Today on the console system (premium-ui sub5a)` + trailer.

## Task 3: Rebuild the outlet picker on the console system

**Files:**
- Modify: `app/lib/features/audit/presentation/visit_outlet_picker_screen.dart`
- Modify: `app/test/features/audit/visit_outlet_picker_screen_test.dart`

- [ ] **Step 1 — Read the current screen** (raw Material: `ListTile`/`ElevatedButton`/`SwitchListTile`, `assignedOutletsProvider`, `onlyMyTerritoriesProvider`). Identify the scope toggle + list + start-visit action.
- [ ] **Step 2 — Failing tests.** Update `visit_outlet_picker_screen_test.dart` (light + dark): (a) no `ListTile`/`SwitchListTile`/`ElevatedButton` remain (`find.byType` → findsNothing); (b) the territory-scope control renders as a console pill/segment (assert active = solid `brand` + white, inactive = surface1 + line + ink2, off the rendered tree); (c) outlet rows render as cards (surface1 + line + radiusPanel) with the outlet name in `ink1`, code/meta in `ink3`; (d) the start-visit affordance keeps its behaviour/key and routes to `/audit/:id`; (e) grep-guard no non-geometry `AppColors.`.
- [ ] **Step 3 — Watch fail.**
- [ ] **Step 4 — Implement** with `context.colors` + console primitives (reuse the sub-2/sub-4 pill treatment and `WorklistRow`/`PanelCard`); preserve `assignedOutletsProvider`/`onlyMyTerritoriesProvider` wiring, scope-toggle behaviour, empty/loading states, and routing. Wrap rows in `WorklistCascade` for the one-shot entrance if it composes cleanly.
- [ ] **Step 5 — Verify + commit.** `flutter test test/features/audit/visit_outlet_picker_screen_test.dart && flutter analyze`; full `flutter test`. `dart format`. Commit: `feat(app): rebuild agent outlet picker on the console system (premium-ui sub5a)` + trailer.

## Task 4: Verification + phone-viewport browser proof + PR

- [ ] **Step 1 — Full gate at HEAD:** `cd app && flutter test && flutter analyze && flutter build web --release`.
- [ ] **Step 2 — Browser proof (both themes, phone viewport).** Pinned CFT Chrome 150.0.7871.129 (scratchpad `cft/`; re-download if wiped). Throwaway scratchpad Postgres + backend:4000 + release web build served on :8899; log in as a **field_agent** demo user (find/seed one — the manager demo is `manager@…`; the agent flow needs a `field_agent` role account with a beat plan for today so `/today` shows a route; seed one if absent and record it). Drive Chrome at a **phone viewport** (e.g. 420×900 via `Emulation.setDeviceMetricsOverride`). Screenshots: Today **light** + **dark** (glass hero, stop cards, NEXT/DONE pills), the **theme toggle** flipping (before/after), the **outlet picker** light + dark. LOOK at every shot; call out anything off (wrong-theme leftovers = an un-converted `AppColors`).
- [ ] **Step 3 — PR.** Base `main`, title `feat: field-agent app foundation — theme-aware console system + Today & picker (premium-ui sub-5a)`. Body: the theme-aware conversion (PinnedDark removed, `context.colors` throughout, in-app toggle), the two rebuilt screens, honesty carry-forwards (state never colour-alone, sync copy preserved), both-theme screenshots, and honest limits (login/landing theme handling per Task 1 Step 5; remaining agent screens are 5b/5c).

## Self-review notes
- Spec coverage: theme-aware light+dark ✓(T1, both-theme asserts + toggle); console tokens across kit/scaffold ✓(T1); Today rebuilt ✓(T2); outlet picker rebuilt ✓(T3); honesty (state never colour-alone, sync copy) preserved ✓(T1 SyncChip untouched behaviourally, T2 DONE/NEXT words). §5b/§5c screens explicitly deferred.
- No data/provider/routing changes — pure presentation + theme wiring.
- Grep-guard (`AppColors.` non-geometry) is the mutation-kill for a missed static colour that would break one theme.
- Names used consistently: `context.colors`, `ValueKey('agent-theme-toggle')`, `themeModeProvider.notifier.toggle()`.
- Risk noted for the implementer: `PinnedDark` also serves login/landing — Task 1 Step 5 gives two ways to keep those dark; pick the smaller diff and report which.
