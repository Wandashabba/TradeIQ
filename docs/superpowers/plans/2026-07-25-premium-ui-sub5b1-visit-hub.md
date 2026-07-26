# Premium UI Sub-5b-1 — Visit Hub, Check-in Arrival, Submit Gate, Capture Field — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the field-agent **visit hub** (check-in arrival moment + section list + progress + submit trigger), the **submit gate**, the shared **`PhotoCaptureField`**, and the **S2 stock** section onto the console design system, theme-aware (light + dark).

**Architecture:** These screens are already kit-scaffolded (`AgentScaffold`/`AgentButton`) but reference the static dark `AppColors.*` palette directly — so, like 5a's screens, the core change is `AppColors.<colour>` → `context.colors.<colour>` plus a console restyle (glass hero for the arrival/progress moment, worklist-style section rows with state pills, console cards for the gate/S2). `PhotoCaptureField` is fully raw/static and must become theme-aware (S3/4 + S5 in 5b-2 depend on it; the guided-camera redesign itself is 5c — here just theme-correctness + a console-tokened tile). No provider/data/routing/geofence changes. Keys preserved.

**Tech Stack:** Flutter; Riverpod; `flutter_test`; `context.colors` (TiqColors); console reusables (`PanelCard`, `DeltaPill`, glass-hero recipe); pinned Chrome-for-Testing 150.0.7871.129 for phone-viewport proof.

**Spec:** `docs/superpowers/specs/2026-07-25-premium-ui-sub5-agent-app-design.md` §Screens 3 (visit hub/check-in), 6 (submit gate), 5 (capture — theme-only here), §Scope 5b-1.

**Branch:** `feat/premium-ui-sub5b1` off fresh `main`; PR bases on `main`.

**Verified facts (code-grounded; don't re-derive):**
- `context.colors` tokens (`app/lib/core/theme/tiq_colors.dart`): `plane, surface1, surface2, surface3, line, lineStrong, ink1, ink2, ink3, ink4(marks-only), brand, brandHover, series1-3, good, warn, crit, critText, grid, axis, shadow, scrim, heroWash, heroBorder, nav*`. `TiqColors.dark` is seeded byte-for-byte from `AppColors` consts, so `AppColors.<x>` → `context.colors.<x>` is dark-identical and adds light. Radii (`AppColors.radiusPanel/radiusControl`) stay `AppColors.*`.
- **Visit hub** — `app/lib/features/audit/presentation/audit_shell_screen.dart` (852 lines): kit-scaffolded, uses `AppColors.*` throughout. Check-in switch on `CheckInResult?`: `null`→`_CheckingIn` (radar `_LocatingRadar`); `CheckInSucceeded`→`_hub`; `CheckInGeofenceFailed(:distanceMeters)`→`_TooFar` (distance pill `ValueKey('checkin-distance')` + fraud note); `CheckInLocationUnavailable(:message)`→`_NoLocation`. `_hub` renders `_Progress` (`ValueKey('visit-progress')`, `AnimatedCount`), section list (`AuditSection.values` → `Reveal`→`_SectionRow` keyed `ValueKey('section-<name>')`, `_StateMark`, `REQUIRED TO SUBMIT` pill), submit `AgentButton(ValueKey('submit-visit'))` gated on `progress.canSubmit`→`_openSubmitGate`. `_SectionScreen` (the shared section wrapper: AgentScaffold + "Done · back to visit") lives here too. Keys to preserve: `section-<name>`, `submit-visit`, `checkin-retry`, `checkin-distance`, `visit-progress`.
- **`VisitProgress`/`AuditSection`** (`app/lib/features/audit/data/visit_progress.dart`): `SectionState{notStarted,partial,done}`; hub maps done→`good`, partial→`warn`, notStarted→`ink3`. `blocking`, `canSubmit`, `doneCount`, `captureCount`.
- **Submit gate** — `app/lib/features/audit/presentation/submit_gate_screen.dart` (328 lines): kit-scaffolded, `AppColors.*`. Watches `visitReviewProvider`/`visitProgressProvider`/`syncStatusProvider`. `_CapturedCard`, `_TaskRow` (crit/warn icon box), `_NothingWrong` (good wash), offline `BarNote`, `AgentButton(ValueKey('confirm-submit'))` → `onConfirm`. Submit call itself is in the hub, not here.
- **`PhotoCaptureField`** — `app/lib/core/widgets/photo_capture_field.dart`: RAW, imports `app_colors.dart`, uses `AppColors.ink3/ink2/surface2/radiusControl`. Two `OutlinedButton.icon` (Take photo/Choose) + 92×92 `Image.memory` preview + Retake. Backed by `PhotoCaptureService` + `queuedPhotosRepositoryProvider` (unchanged).
- **S2 stock** — `app/lib/features/audit/presentation/sections/s2_stock_screen.dart`: kit `CountStepper` but wraps rows in raw `Card` + `ElevatedButton` + an `AlertDialog`(`_CountInputDialog` with `TextField`) and hardcodes `AppColors.ink1/ink3/crit/surface1`.
- `contrastRatio` helper: `app/test/core/theme/tiq_colors_test.dart`.
- Tests: `audit_shell_screen_test.dart` (hub: check-in states, submit-opens-gate-not-submits, confirm-submits), `s2_stock_screen_test.dart`, `visit_progress_test.dart`, `visit_review_test.dart`. No standalone submit_gate test (covered via hub). PRESERVE all `ValueKey`s.

---

## Task 1: Theme-aware `PhotoCaptureField`

**Files:** modify `app/lib/core/widgets/photo_capture_field.dart`; add/modify `app/test/core/widgets/photo_capture_field_test.dart`.

- [ ] **Step 1 — Failing test (both themes):** pump `PhotoCaptureField` under explicit light and dark `MaterialApp(theme/darkTheme/themeMode)`; assert the empty-state capture affordance and hint text use `context.colors` (e.g. the container/border is `colors.surface2`/`line` under light vs dark — assert the light values differ from dark, off the rendered tree). Today it's static dark → the light assertion fails.
- [ ] **Step 2 — Watch fail** (`cd app && flutter test test/core/widgets/photo_capture_field_test.dart`).
- [ ] **Step 3 — Implement:** `final colors = context.colors;`; every `AppColors.<colour>` → `colors.<colour>`; keep `AppColors.radiusControl`. Restyle the two capture buttons + preview to console tokens (the guided-camera redesign is 5c — here keep the Take photo/Choose + preview + Retake structure, just theme-correct + console surface/hairline). Preserve `PhotoCaptureService`/`queuedPhotosRepositoryProvider` wiring and all behaviour/keys.
- [ ] **Step 4 — Verify + commit:** `flutter test test/core/widgets/ && flutter analyze`, full `flutter test`. `dart format`. Grep-guard: no non-geometry `AppColors.` in the file. Commit: `feat(app): theme-aware PhotoCaptureField (premium-ui sub5b1)` + trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## Task 2: Visit hub — check-in arrival moment + console section list

**Files:** modify `app/lib/features/audit/presentation/audit_shell_screen.dart`; modify `app/test/features/audit/audit_shell_screen_test.dart`.

- [ ] **Step 1 — Failing tests (both themes; reuse the existing hub test harness):** (a) `_hub`'s progress panel renders as a **glass hero** (heroWash→surface1 gradient + heroBorder) with the `AnimatedCount` at 30–32px `ink1` and a status pill ("Ready to submit"/"N still required" — words, `good` when unblocked) — assert gradient/border/count off the rendered tree, both themes; (b) the **checked-in arrival** shows a green status card with the **honest distance** copy (a subtitle/line stating the agent checked in — keep the existing "In store …" subtitle AND surface the check-in success visibly; do not remove any honesty signal); (c) `_SectionRow`s render as console cards/rows with state via `_StateMark` glyph + word + the `REQUIRED TO SUBMIT` pill (pill must clear 4.5:1 both themes — use `critText` on a crit wash, not raw `crit`-on-crit; add a `contrastRatio` assert); (d) `_TooFar` distance pill + fraud note preserved and theme-aware (`crit`/`critText`); (e) grep-guard no non-geometry `AppColors.` in the file.
- [ ] **Step 2 — Watch fail.**
- [ ] **Step 3 — Implement:** `final colors = context.colors;` in each `build`; every `AppColors.<colour>` → `colors.<colour>`. `_Progress` → glass hero (`PanelCard(gradient: heroWash→surface1, borderColor: heroBorder)`, count 31px w700 `ink1`, status pill). Section list container + `_SectionRow` → console card treatment (surface1 + line + radiusPanel; `_StateMark`: done → `TickMark`/`good`, partial → `warn` glyph, notStarted → `ink3`; the `REQUIRED TO SUBMIT` pill → `critText` on a crit wash pair that clears AA). `_CheckingIn` radar, `_TooFar` (distance pill `critText`/crit wash, fraud note `ink3`), `_NoLocation` (`warn`) all theme-aware. Keep: `AgentScaffold`, `Reveal`, `AnimatedCount`, all `ValueKey`s, `_openSection`/`agentSectionRoute`, `_openSubmitGate`, `_SectionScreen`, the geofence/check-in logic, provider wiring, the "In store …" subtitle + the fraud-note wording (honesty).
- [ ] **Step 4 — Verify + commit:** `flutter test test/features/audit/audit_shell_screen_test.dart && flutter analyze`, full `flutter test`. `dart format`. Commit: `feat(app): visit hub arrival + section list on the console system (premium-ui sub5b1)` + trailer.

## Task 3: Submit gate on the console system

**Files:** modify `app/lib/features/audit/presentation/submit_gate_screen.dart`; add `app/test/features/audit/submit_gate_screen_test.dart` (there's no standalone one today).

- [ ] **Step 1 — Failing tests (both themes):** pump `SubmitGateScreen` with fake `visitReviewProvider`/`visitProgressProvider` overrides (mirror the hub test's provider fakes): (a) `_CapturedCard` renders as a console card (surface1 + line + radiusPanel), "N of M sections complete" + `capturedLine`; (b) each `_TaskRow` shows a crit/warn indicator with WORDS ("Task for the manager · <priority>") — the urgent/normal distinction is not colour-alone (glyph or word present) and any pill clears 4.5:1 both themes; (c) the offline `BarNote` copy preserved; (d) `_NothingWrong` uses a `good` wash; (e) `ValueKey('confirm-submit')` preserved and tapping it calls `onConfirm`; (f) grep-guard no non-geometry `AppColors.`.
- [ ] **Step 2 — Watch fail.**
- [ ] **Step 3 — Implement:** `AppColors.*` → `context.colors`; `_CapturedCard`/`_TaskRow`/`_NothingWrong`/`_Heading` on console cards/tokens; the "This will raise" list in a `PanelCard`; keep the `_accusation`/`capturedLine` copy verbatim (honesty — "you are telling the manager N things are wrong"), the offline BarNote, `onConfirm` wiring, keys.
- [ ] **Step 4 — Verify + commit:** `flutter test test/features/audit/ && flutter analyze`, full `flutter test`. `dart format`. Commit: `feat(app): submit gate on the console system (premium-ui sub5b1)` + trailer.

## Task 4: S2 stock section on the console system

**Files:** modify `app/lib/features/audit/presentation/sections/s2_stock_screen.dart`; modify `app/test/features/audit/s2_stock_screen_test.dart`.

- [ ] **Step 1 — Failing tests (both themes):** (a) no raw `Card`/`ElevatedButton` remain (`find.byType` findsNothing) — SKU rows are console cards, save via the `_SectionScreen` "Done · back to visit" OR a console-styled action (see Step 3); (b) `AppColors.*` colours gone (grep-guard, radii allowed); (c) the `CountStepper` zero-is-a-finding behaviour + `saveStock` wiring preserved (existing tests keep passing — update only colour/structure assertions, not behaviour); (d) the count-input dialog (`_CountInputDialog`) restyled off raw `AlertDialog`+`TextField` to a console-tokened dialog (or a kit input) — keep its behaviour/keys.
- [ ] **Step 2 — Watch fail.**
- [ ] **Step 3 — Implement:** `context.colors` throughout; SKU rows → console cards (surface1 + line + radiusPanel); keep `CountStepper`. The redundant inline `ElevatedButton('Save stock')` — the shared `_SectionScreen` already provides "Done · back to visit"; if S2 saves on that Done (check how save is currently triggered) prefer removing the redundant button, else restyle it to an `AgentButton`; explain the choice. Restyle `_CountInputDialog` to console tokens. Preserve `stockRepositoryProvider.saveStock`, per-SKU logic, keys.
- [ ] **Step 4 — Verify + commit:** `flutter test test/features/audit/s2_stock_screen_test.dart && flutter analyze`, full `flutter test`. `dart format`. Commit: `feat(app): S2 stock section on the console system (premium-ui sub5b1)` + trailer.

## Task 5: Verification + phone browser proof + PR

- [ ] **Full gate:** `cd app && flutter test && flutter analyze && flutter build web --release`.
- [ ] **Browser proof (both themes, phone viewport 420×900).** Pinned CFT Chrome; throwaway/compose Postgres + backend:4000 + release web build served :8899; log in as the field_agent demo (`agent@demo-fmcg.tradeiq.com` / `demo-password-123`, per 5a's proof) with today's beat plan; open a visit (`/audit/:outletId`) — you'll hit the geofence check-in. If the demo geofence blocks (agent not near the seeded outlet coords), either seed the outlet coords near the emulated location OR capture the honest `_TooFar` state (still a valid proof of that screen). Screenshots: the **hub** (glass-hero progress + section list with state marks + REQUIRED pill) **light + dark**; the **check-in** state you can reach (arrival or too-far) both themes; the **submit gate** if reachable (needs required sections done — may need to complete stock/visibility/pricing/capability; if too involved, rely on the widget tests for the gate and note it, as sub-3 did for a hard-to-reach screen). LOOK at every shot.
- [ ] **PR:** base `main`, title `feat: visit hub, check-in arrival, submit gate + capture field — console system (premium-ui sub-5b-1)`. Body: the arrival moment + hub restyle, submit gate, theme-aware PhotoCaptureField, S2; honesty carry-forwards (distance always shown, fraud note verbatim, "you're telling the manager…" copy, state never colour-alone); both-theme screenshots; honest limits (the 8 raw sections are 5b-2; the guided-camera capture redesign is 5c — PhotoCaptureField here is theme-only).

## Self-review notes
- Spec coverage: hub arrival + section list ✓(T2), submit gate ✓(T3), PhotoCaptureField theme-aware ✓(T1), S2 ✓(T4); the 8 raw sections explicitly deferred to 5b-2, guided camera to 5c.
- Honesty preserved: geofence distance (T2), fraud note verbatim (T2), submit-gate accusation copy (T3), state never colour-alone (T2/T3 glyph+word), sync/offline copy (T3).
- Contrast: REQUIRED-to-submit pill + any gate pill use `critText`/AA pairs, asserted both themes (the recurring 5a lesson — self-tint fails AA).
- No data/provider/geofence/routing changes. Grep-guard non-geometry `AppColors.` in every touched file.
- All `ValueKey`s preserved (tests depend on them).
