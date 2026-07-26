# Premium UI Sub-5b-2 — The 8 Raw Capture Sections — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the 8 raw-Material field-agent capture sections (S1, S3-4, S5, S6, S7, S8, S9, S10) on the console design system, theme-aware (light + dark), adding the two missing kit form primitives they need.

**Architecture:** These sections are raw `package:flutter/material.dart` — `Card`, `TextField`, `DropdownButtonFormField`, `SwitchListTile`, `CheckboxListTile`, `ElevatedButton`, `TextButton` — with default Material theming (mostly no `AppColors` at all). The console-ising is: wrap rows in `PanelCard`/console cards; replace dropdowns with the existing kit `ChoiceRow<T>` (segmented chips — a better phone pattern than a dropdown); replace switches/checkboxes with two NEW kit primitives (`AgentToggle`, `AgentCheck`); wrap text inputs in the existing `AgentField` over a theme-tokened field; replace save `ElevatedButton`s with `AgentButton`; drop the redundant inline section headers (the shared `_SectionScreen` wrapper already titles each). Save stays each section's own trigger (the wrapper's "Done" only pops — established in 5b-1). No provider/data/routing changes; all `ValueKey`s preserved. Photo sections (S3-4, S5) reuse the now-theme-aware `PhotoCaptureField` (shipped in 5b-1).

**Tech Stack:** Flutter; Riverpod; `flutter_test`; `context.colors` (TiqColors); existing kit (`ChoiceRow`, `AgentField`, `AgentButton`, `CountStepper`); console `PanelCard`; pinned Chrome-for-Testing for what's reachable.

**Spec:** `docs/superpowers/specs/2026-07-25-premium-ui-sub5-agent-app-design.md` §Screens 4 (the 10 sections), §Scope 5b-2.

**Branch:** `feat/premium-ui-sub5b2` off fresh `main` (has 5a + 5b-1); PR bases on `main`.

**Verified facts (code-grounded; don't re-derive):**
- Existing kit (`app/lib/core/widgets/agent_kit.dart`, all theme-aware via `context.colors`): `ChoiceRow<T>({options: List<({T value, String label})>, selected: T?, onChanged: ValueChanged<T>})` — a segmented single-select chip row (`_Choice`: selected = brand@14% + brand border + ink1; unselected = surface2 + lineStrong + ink2; `kTapTarget` tall). `AgentField({label, child, help})` — a labelled column wrapping a `child` input. `AgentButton({label, icon?, secondary?, onPressed})`. `CountStepper`, `StatusBanner`, `BarNote`.
- `context.colors` tokens: `plane, surface1, surface2, surface3, line, lineStrong, ink1, ink2, ink3, brand, brandHover, good, warn, crit, critText, series1-3, heroWash, heroBorder`. Geometry stays `AppColors.radiusPanel/radiusControl`.
- **The AA lesson (5b-1):** a `crit`/`warn`-on-its-own-wash self-tint fails 4.5:1. Text-carrying coloured chips → `critText`/AA-safe fg on an OPAQUE `Color.alphaBlend(token@12%, surface1)` wash; assert the RENDERED pair both themes.
- **Section text-field theming:** FIRST check `app/lib/core/theme/app_theme.dart` for an `inputDecorationTheme` — if the app theme already themes `TextField`/`InputDecoration` (fill, borders) per light/dark, then a raw `TextField` inside `AgentField` renders correctly and only needs the `AgentField` label wrapper (no new field primitive). If NOT, build a minimal `AgentTextField` (a `TextField` with a `context.colors`-tokened `InputDecoration`: surface2 fill, `line`/`lineStrong` border, `brand` focus). Task 1 decides and reports which.
- The 8 raw sections + current widgets + what each captures (from the scout):
  - **S1** `s1_outlet_info_screen.dart` — 22-line stub: `Center/Column/Text` showing check-in ts. No repo. Just needs console text/tokens.
  - **S3-4** `s3_4_visibility_display_screen.dart` — `CheckboxListTile` (branding present), `TextField`×3 (planogram %, facings, notes), `SwitchListTile` (high-traffic), `ElevatedButton` + `PhotoCaptureField('Shelf photo')`. → `visibilityRepositoryProvider.saveVisibility` + photo `section:'visibility'`.
  - **S5** `s5_pricing_promotions_screen.dart` — `Card`, `TextField`(`_numField` price), `SwitchListTile`(promo active), comms rating, `ElevatedButton` + `PhotoCaptureField('Shelf-price photo')`. → `pricingRepositoryProvider.savePricing` (skips blank price) + photo `section:'pricing'`.
  - **S6** `s6_competitive_screen.dart` — `Card`, `TextField`×4 (sku/price/posm/facings), `SwitchListTile`(promoter present), `TextButton`('add'), `ElevatedButton`. → `competitiveRepositoryProvider.saveCompetitive` (skips blank name). Dynamic add-entry list.
  - **S7** `s7_capability_screen.dart` — `TextField`×2 (headcount, quiz), `CheckboxListTile`×3 (training topics), `ElevatedButton`. → `capabilityRepositoryProvider.saveCapability`.
  - **S8** `s8_risks_screen.dart` — dynamic list: `Card`, `TextField`(flag type key `risk-type-$i`), `DropdownButtonFormField`(severity key `risk-severity-$i`, options critical/high/normal), `TextField`(note key `risk-note-$i`), `TextButton`(key `add-risk`), `ElevatedButton`. → `risksRepositoryProvider.saveRisks` (skips blank flag).
  - **S9** `s9_action_plan_screen.dart` — `TextField`×2 (findingType, requiredFix), `DropdownButtonFormField`(priority), `ElevatedButton`(key from test — read it). → `tasksRepositoryProvider.saveTask`.
  - **S10** `s10_scorecard_screen.dart` — `FutureBuilder` reading `scorecardServiceProvider.computeForVisit`, `Row/Text` dimension scores + total/band, `TextButton`(refresh), `ElevatedButton`(finalize → `finalizeScorecard`). Read-only display + finalize.
- Each section's `Save` `ElevatedButton` is the ONLY save trigger (wrapper "Done" just pops). KEEP it, restyle to `AgentButton`.
- Every section shows a redundant `Text('Sn …')` header duplicating the wrapper title — drop it.
- Tests per section in `app/test/features/audit/` (s3_4/s5/s6/s7/s8/s9/s10 + no s1 test). They tap save-button text + field keys + assert repo `.save*` calls. PRESERVE all keys; the dropdown→ChoiceRow change means tests that drove `DropdownButtonFormField` must switch to tapping the ChoiceRow chip (update + note).
- `contrastRatio` helper: `app/test/core/theme/tiq_colors_test.dart`.

---

## Task 1: Missing kit form primitives — `AgentToggle` + `AgentCheck` (+ text-field decision)

**Files:** modify `app/lib/core/widgets/agent_kit.dart`; add `app/test/core/widgets/agent_kit_form_test.dart` (or extend an existing kit test).

- [ ] **Step 1 — Decide the text-field path:** read `app/lib/core/theme/app_theme.dart`; report whether `inputDecorationTheme` themes fields per-theme. If yes, no field primitive needed (sections use `AgentField` + raw `TextField`). If no, add a minimal `AgentTextField` primitive in this task.
- [ ] **Step 2 — Failing tests (both themes):** for `AgentToggle` (a labelled on/off control) and `AgentCheck` (a labelled checkbox row): pump each under light + dark; assert on/off (checked/unchecked) states use `context.colors` (active = `brand`, track/box = surface/line tokens), the label is `ink1`/`ink2`, tapping flips via `onChanged`, `Semantics(toggled:/checked:)` set, and the control clears `kTapTarget` height. Contrast: label + any on-state text/glyph ≥4.5:1 both themes.
- [ ] **Step 3 — Watch fail.**
- [ ] **Step 4 — Implement** `AgentToggle({label, value, onChanged, help?})` (a themed row: label + a `Switch`/custom track using `brand`/`surface3`/`lineStrong`, `Semantics(toggled:)`) and `AgentCheck({label, value, onChanged})` (a themed check row: a box that fills `brand` with a white tick when checked, `Semantics(checked:)`, `kTapTarget`), both `context.colors`. (If Step 1 said so, also `AgentTextField`.) Match the kit's existing style conventions.
- [ ] **Step 5 — Verify + commit:** `cd app && flutter test test/core/widgets/ && flutter analyze`, full `flutter test`. `dart format`. Commit: `feat(app): kit toggle + checkbox form primitives (premium-ui sub5b2)` + trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## Task 2: S8 risks + S9 action plan (dropdown → ChoiceRow)

**Files:** modify `s8_risks_screen.dart`, `s9_action_plan_screen.dart`; modify their tests.

- [ ] **Step 1 — Failing tests (both themes):** (a) no raw `Card`/`DropdownButtonFormField`/`ElevatedButton`/`TextButton`(for save/add — the add affordance becomes an `AgentButton` secondary) remain; (b) severity (S8) / priority (S9) render as a `ChoiceRow` (segmented chips) — selecting a chip sets the value (assert the active chip via ChoiceRow's selected state); (c) rows are console cards (`PanelCard`); text inputs wrapped in `AgentField`; (d) grep-guard no non-geometry `AppColors.`; (e) existing behaviour tests keep passing — the tests that drove `DropdownButtonFormField('risk-severity-$i')` now tap the ChoiceRow chip (update, note); keep field keys (`risk-type-$i`, `risk-note-$i`, `add-risk`) and the S9 save/field keys (read the S9 test for its keys); the skip-blank-flag / saveRisks / saveTask behaviour unchanged.
- [ ] **Step 2 — Watch fail.**
- [ ] **Step 3 — Implement:** `context.colors` throughout; dynamic risk/task cards → `PanelCard`; severity/priority → `ChoiceRow<String>(options: [(value:'critical',label:'Critical'),…])`; "Flag a risk"/add → `AgentButton(secondary)`; save `ElevatedButton` → `AgentButton`; drop the `Text('S8 …')`/`Text('S9 …')` headers; keep `_saved` "queued for sync" confirmation (theme-aware, S8's mentions auto-created tasks — verbatim). Preserve repo wiring, skip-blank logic, dispose of controllers, keys.
- [ ] **Step 4 — Verify + commit:** `flutter test test/features/audit/s8_risks_screen_test.dart test/features/audit/s9_action_plan_screen_test.dart && flutter analyze`, full `flutter test`. `dart format`. Commit: `feat(app): S8 risks + S9 action plan on the console system (premium-ui sub5b2)` + trailer.

## Task 3: S6 competitive + S7 capability

**Files:** modify `s6_competitive_screen.dart`, `s7_capability_screen.dart`; modify their tests.

- [ ] **Step 1 — Failing tests (both themes):** (a) no raw `Card`/`SwitchListTile`/`CheckboxListTile`/`ElevatedButton`/`TextButton`(save/add) remain; (b) S6 promoter-present + S7 training-topics use `AgentToggle`/`AgentCheck`; (c) rows are `PanelCard`s, inputs in `AgentField`; (d) grep-guard `AppColors.`; (e) behaviour tests pass — `SwitchListTile`/`CheckboxListTile` finders swap to the new primitives (update, note); S6 skip-blank-SKU + facings-for-share-of-shelf, S7 saveCapability, all keys preserved.
- [ ] **Step 2 — Watch fail.**
- [ ] **Step 3 — Implement:** `context.colors`; S6 dynamic competitor cards → `PanelCard`, its `SwitchListTile`(promoter) → `AgentToggle`, add/save → `AgentButton`; S7 `CheckboxListTile`×3 → `AgentCheck`, `TextField`×2 → `AgentField`, save → `AgentButton`; drop redundant headers; keep confirmations, repo wiring, skip-blank, keys.
- [ ] **Step 4 — Verify + commit:** `flutter test test/features/audit/s6_competitive_screen_test.dart test/features/audit/s7_capability_screen_test.dart && flutter analyze`, full `flutter test`. `dart format`. Commit: `feat(app): S6 competitive + S7 capability on the console system (premium-ui sub5b2)` + trailer.

## Task 4: S3-4 visibility + S5 pricing (the photo pair)

**Files:** modify `s3_4_visibility_display_screen.dart`, `s5_pricing_promotions_screen.dart`; modify their tests.

- [ ] **Step 1 — Failing tests (both themes):** (a) no raw `Card`/`CheckboxListTile`/`SwitchListTile`/`ElevatedButton` remain; (b) S3-4 branding-present → `AgentCheck`, high-traffic → `AgentToggle`; S5 promo-active → `AgentToggle`; (c) `PhotoCaptureField` still present (`section:'visibility'` / `'pricing'`) and renders theme-aware; (d) inputs in `AgentField`, cards `PanelCard`; (e) grep-guard `AppColors.`; (f) behaviour tests pass — saveVisibility / savePricing (+ skip-blank-price) + photo queue unchanged; toggle/check finders updated; keys preserved.
- [ ] **Step 2 — Watch fail.**
- [ ] **Step 3 — Implement:** `context.colors`; fields → `AgentField`; checkboxes/switches → `AgentCheck`/`AgentToggle`; cards → `PanelCard`; save → `AgentButton`; keep `PhotoCaptureField` usage verbatim (it's already theme-aware); drop redundant headers; keep confirmations, repo + photo wiring, skip-blank, keys.
- [ ] **Step 4 — Verify + commit:** `flutter test test/features/audit/s3_4_visibility_display_screen_test.dart test/features/audit/s5_pricing_promotions_screen_test.dart && flutter analyze`, full `flutter test`. `dart format`. Commit: `feat(app): S3-4 visibility + S5 pricing on the console system (premium-ui sub5b2)` + trailer.

## Task 5: S1 outlet info + S10 scorecard

**Files:** modify `s1_outlet_info_screen.dart`, `s10_scorecard_screen.dart`; modify the s10 test; add a small s1 test.

- [ ] **Step 1 — Failing tests (both themes):** (a) S1 renders its check-in info on `context.colors` (no raw default-Material text — use console text tokens / a `PanelCard` info block); (b) S10 dimension scores + total/band render as console cards/rows on tokens, no raw `Card`/`ElevatedButton`; the finalize action is an `AgentButton`, refresh an `AgentButton(secondary)` or icon; (c) grep-guard `AppColors.`; (d) S10 behaviour (renders dimension scores/total/band, finalize queues via `finalizeScorecard`) preserved — update colour/structure finders, keep keys.
- [ ] **Step 2 — Watch fail.**
- [ ] **Step 3 — Implement:** both on `context.colors`; S1 → a console info block (the check-in confirmation — honesty: it's read-only, "confirmed at check-in"); S10 → console score cards + `AgentButton` finalize/refresh; the score band/colour coding stays honest (never colour-alone — band carries a word). Preserve `scorecardServiceProvider` wiring, keys.
- [ ] **Step 4 — Verify + commit:** `flutter test test/features/audit/s10_scorecard_screen_test.dart && flutter analyze`, full `flutter test`. `dart format`. Commit: `feat(app): S1 outlet info + S10 scorecard on the console system (premium-ui sub5b2)` + trailer.

## Task 6: Verification + browser proof + PR

- [ ] **Full gate:** `cd app && flutter test && flutter analyze && flutter build web --release`.
- [ ] **Browser proof (both themes, phone 420×900).** As in 5b-1: the capture sections live behind a *successful* geofence check-in, which writes the local Drift DB — **unavailable on the web build** (sql.js WASM not bundled, #177/#140), so the sections are likely unreachable live on web. Attempt the geolocation-override path; if the hub/sections can't be reached (expected), rely on the both-theme widget tests (which every section now has) and say so honestly — screenshot whatever IS reachable (the `_TooFar` check-in already proven in 5b-1). If a mobile/emulator target is quick to stand up, prefer it for real section screenshots; otherwise widget tests are the coverage of record.
- [ ] **PR:** base `main`, title `feat: the 8 raw capture sections on the console system (premium-ui sub-5b-2)`. Body: the 8 rebuilt sections + the two new kit primitives (AgentToggle/AgentCheck); dropdowns→ChoiceRow; honesty carry-forwards (out-of-stock/risk/score never colour-alone, read-only context preserved, "queued for sync" copy); both-theme widget-test coverage; honest limit (sections unreachable on web build — same #177/#140 as 5b-1); note this completes 5b (with 5b-1), leaving 5c.

## Self-review notes
- Spec coverage: all 8 raw sections ✓ (T2-T5), the missing primitives ✓ (T1). Guided camera (5c) not here — PhotoCaptureField reused as-is (theme-aware).
- Honesty preserved: skip-blank logic (no fabricated entries), read-only context lines, "queued for sync" confirmations, score band + risk severity never colour-alone (word present), auto-created-tasks note verbatim.
- Contrast: any coloured chip/label clears 4.5:1 both themes (rendered pair) — the 5b-1 lesson; ChoiceRow is already AA (brand@14% + ink1/ink2).
- No data/provider/routing changes; save stays each section's trigger; all `ValueKey`s preserved (dropdown→ChoiceRow test updates noted per task).
- Deferred: #214/#215 shared-widget extractions still open; the new AgentToggle/AgentCheck are the kit's, not per-screen forks.
