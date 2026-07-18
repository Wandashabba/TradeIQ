# UI Motion & Polish (Plan B of 2) — Shared-Axis Transitions, Drawer Stagger, Elevation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add the premium motion and polish layer on top of the merged theme system (Plan A): Material shared-axis page transitions for the manager console, a deeper drawer scrim with a staggered nav fade-up, and light-mode elevation (soft shadows) plus hover/pressed/focus interaction states — all reduced-motion-aware, with dark mode visually unchanged.

**Architecture:** A `managerPage()` helper wraps manager `GoRoute`s in a `CustomTransitionPage` using the `animations` package's `SharedAxisTransition` (horizontal, 250ms), falling back to a 100ms fade under reduced motion. The drawer gains `scrimColor: context.colors.scrim` and a one-controller staggered fade-up of nav rows. Elevation reads `context.colors.shadow` (transparent in dark → zero dark change; visible in light). Interaction washes read `context.colors.surface2/3`.

**Tech Stack:** Flutter 3.44, go_router 17.3, flutter_riverpod 3.3.2, `animations` package (new). Reuses the existing `reduceMotion(context)` helper in `agent_motion.dart`.

**Spec:** `docs/superpowers/specs/2026-07-17-premium-ui-theme-motion-design.md` §4 (Motion) + §5 (Premium polish). §1–3 were Plan A (merged).

**Branch:** `feat/ui-motion-polish` (off main; Plan A's `TiqColors.shadow`/`scrim` slots already present).

---

## CRITICAL — invariants

1. **Dark mode's appearance must not change.** `context.colors.shadow` is `transparent` in dark, so every shadow `BoxShadow` renders invisibly there; the scrim in dark is `black54` (Flutter's default), so the drawer looks identical. Only **light** mode gains visible elevation and a deeper scrim. The existing 388 tests (dark-themed) must stay green.
2. **Agent routes keep their existing motion.** Only manager-shell routes switch to shared-axis. The `/`, `/login`, `/today`, `/audit*`, `/my-work` routes are left on their current `builder:` (agent flow uses `agent_motion.dart`; public screens need no transition). See the route split in Task 2.
3. **Reduce motion is honored everywhere.** Reuse `reduceMotion(context)` (`agent_motion.dart:54`, wraps `MediaQuery.disableAnimationsOf`). Under it: page transition → 100ms fade; drawer stagger → skipped (rows appear at once).
4. **No layout, navigation-structure, or copy changes.** Surfaces, motion, and state feedback only.
5. **Test-frame implications.** Shared-axis transitions animate on push, so a widget test that `pump()`s once then asserts may need `pumpAndSettle()`. Do NOT rewrite assertions — only add settling where a test drives navigation. Most screen tests pump a single screen directly (no navigation), so they are unaffected.

**Commands** (from `app/`): `flutter analyze` (fast per-task gate, expect `No issues found!`), `flutter test <targeted>` per task, full `flutter test` only at the Task 8 checkpoint. Machine is resource-constrained — never run two Flutter processes at once; a full run is slow.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `app/pubspec.yaml` | Deps | Modify — add `animations` |
| `app/lib/core/router/manager_page.dart` | Shared-axis page helper | Create |
| `app/lib/core/router/app_router.dart` | Route table | Modify — manager routes → `pageBuilder: managerPage(...)` |
| `app/lib/core/widgets/manager_scaffold.dart` | Console shell + drawer | Modify — scrim + staggered nav fade-up + nav hover/pressed |
| `app/lib/core/widgets/console.dart` | `PanelCard` / tiles | Modify — elevation shadow (rest/hover) |
| `app/lib/core/widgets/worklist.dart` | `WorklistRow` | Modify — hover/pressed wash |
| `app/lib/core/theme/app_theme.dart` | Focus theme | Modify — focus ring on `brand` 1.5px |
| `app/test/core/router/manager_page_test.dart` | Transition + reduced-motion | Create |
| `app/test/core/widgets/manager_scaffold_test.dart` | Drawer scrim/stagger | Modify — add assertions |

---

### Task 1: Add the `animations` package

**Files:** Modify `app/pubspec.yaml`.

- [ ] **Step 1:** In `pubspec.yaml` under `dependencies:` (after `go_router: ^17.3.0`), add:
```yaml
  animations: ^2.0.11
```
- [ ] **Step 2:** `cd app && flutter pub get` — expect `Got dependencies!` (or `Changed N dependencies!`). If `2.0.11` is unavailable for this Flutter/Dart, use the latest `^2.0.x` `flutter pub get` resolves to and note it.
- [ ] **Step 3:** `flutter analyze` → `No issues found!` (nothing uses it yet; confirms resolution is clean).
- [ ] **Step 4:** Commit:
```bash
git add pubspec.yaml pubspec.lock
git commit -m "build(app): add the animations package for shared-axis transitions

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `managerPage()` shared-axis helper + reduced-motion fallback

**The manager/agent route split** (read from `app_router.dart`):
- **Manager → switch to `managerPage`:** `/dashboard`, `/outlets`, `/outlets/create`, `/tasks`, `/campaigns`, `/alerts`, `/alert-rules`, `/territories`, `/orders`, `/beatplans`, `/leaderboard`, `/fraud`, `/reports`, `/messages`, `/users`, `/incentives`, `/webhooks`, `/client-config`, `/audit-templates`, `/audit-templates/:templateId/preview`, `/dispatch`, `/trends` (22 routes).
- **Leave unchanged:** `/` (landing), `/login`, `/today`, `/audit`, `/audit/:outletId`, `/audit/:outletId/done`, `/my-work` (public + agent flow).

**Files:** Create `app/lib/core/router/manager_page.dart`; Test `app/test/core/router/manager_page_test.dart`.

- [ ] **Step 1: Write the failing test** — `app/test/core/router/manager_page_test.dart`:
```dart
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trade_iq/core/router/manager_page.dart';

void main() {
  testWidgets('managerPage builds a SharedAxisTransition when motion is on', (tester) async {
    final page = managerPage(const Text('x'));
    expect(page, isA<CustomTransitionPage<void>>());
    final ctp = page as CustomTransitionPage<void>;
    // Build the transition with animations running.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => ctp.transitionsBuilder(
              context,
              const AlwaysStoppedAnimation(1),
              const AlwaysStoppedAnimation(0),
              const Text('child'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SharedAxisTransition), findsOneWidget);
  });

  testWidgets('managerPage falls back to a fade under reduced motion', (tester) async {
    final page = managerPage(const Text('x')) as CustomTransitionPage<void>;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => page.transitionsBuilder(
              context,
              const AlwaysStoppedAnimation(1),
              const AlwaysStoppedAnimation(0),
              const Text('child'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SharedAxisTransition), findsNothing);
    expect(find.byType(FadeTransition), findsOneWidget);
  });
}
```
(Confirm the package name in imports is `trade_iq` — check an existing test's import prefix and match it.)

- [ ] **Step 2:** `flutter test test/core/router/manager_page_test.dart` → FAIL (`manager_page.dart` missing).

- [ ] **Step 3: Create `app/lib/core/router/manager_page.dart`:**
```dart
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/agent_motion.dart' show reduceMotion;
import '../theme/tiq_colors.dart';

/// A go_router page for manager-shell destinations. Switching between
/// same-hierarchy top-level screens (Dashboard ↔ Tasks ↔ Alerts …) uses
/// Material's shared-axis (horizontal) transition. Under reduced motion it
/// degrades to a short fade. Agent/public routes do not use this.
CustomTransitionPage<void> managerPage(Widget child, {LocalKey? key}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion(context)) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      }
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: context.colors.plane,
        child: child,
      );
    },
  );
}
```

- [ ] **Step 4:** `flutter test test/core/router/manager_page_test.dart` → both pass. `flutter analyze` → clean.

- [ ] **Step 5: Wire the 22 manager routes.** In `app_router.dart`, for each manager route in the list above, change `builder: (context, state) => const XScreen(),` to `pageBuilder: (context, state) => managerPage(const XScreen()),`. Add `import '../router/manager_page.dart';` (adjust path — it's the same dir, so `'manager_page.dart'`). Leave the 7 agent/public routes on `builder:`. For the two parameterized manager routes (`/audit-templates/:templateId/preview` and any with args) pass the built widget: `pageBuilder: (context, state) => managerPage(TemplateFormScreen(...))`.

- [ ] **Step 6:** `flutter analyze` → clean. Targeted: `flutter test test/core/router/` → green. Then a nav-driving screen test to catch pump issues: `flutter test test/features/dashboard/ test/core/widgets/manager_scaffold_test.dart` → green (add `pumpAndSettle()` only if a test that navigates now hangs on the 250ms transition; do not change assertions).

- [ ] **Step 7:** Commit:
```bash
git add lib/core/router/ test/core/router/
git commit -m "feat(app): shared-axis page transitions for manager routes

managerPage() wraps the 22 manager-shell destinations in a horizontal
SharedAxisTransition (250ms), fading under reduced motion. Agent/public
routes keep their existing builders.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Drawer scrim

**Files:** Modify `app/lib/core/widgets/manager_scaffold.dart`; Test `manager_scaffold_test.dart`.

- [ ] **Step 1:** In `ManagerScaffold.build`, on the `Scaffold` that carries `drawer:`, add:
```dart
      drawerScrimColor: context.colors.scrim,
```
(`context.colors` is available — the scaffold already reads it after Plan A. In dark this is `black54` = unchanged; in light it is the deeper `rgba(16,24,40,.60)`.)

- [ ] **Step 2:** Add a test to `manager_scaffold_test.dart` asserting the scaffold's `drawerScrimColor` resolves to `TiqColors.dark.scrim` under the dark theme (pump the scaffold at drawer width, find the `Scaffold`, read `drawerScrimColor`).

- [ ] **Step 3:** `flutter analyze` clean; `flutter test test/core/widgets/manager_scaffold_test.dart` green. Commit:
```bash
git add lib/core/widgets/manager_scaffold.dart test/core/widgets/manager_scaffold_test.dart
git commit -m "feat(app): drawer scrim reads context.colors.scrim (deeper in light)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Staggered nav fade-up on drawer open

**Files:** Modify `manager_scaffold.dart` (`_NavRail`/`_NavRow`).

- [ ] **Step 1:** Make `_NavRail` a `StatefulWidget` with a single `AnimationController` (duration `20ms*rows + 150ms`), started in `initState` **only when rendered inside the drawer** (pass a `staggered: bool` flag from `ManagerScaffold` — true for the `drawer:` instance, false for the persistent rail). Each `_NavRow` gets an interval-based `FadeTransition` + slight upward `SlideTransition` (e.g. `Tween(begin: Offset(0,0.06), end: Offset.zero)`), its interval offset by `index * 20ms`. Under `reduceMotion(context)`, skip the controller and render rows at full opacity/position (no animation).

Exact shape:
```dart
// In _NavRail (now stateful), build each row wrapped:
Widget _staggered(BuildContext context, int index, int count, Widget row) {
  if (!staggered || reduceMotion(context)) return row;
  final start = (index * 20) / (count * 20 + 150);
  final anim = CurvedAnimation(
    parent: _controller,
    curve: Interval(start.clamp(0, 1), 1, curve: Curves.easeOut),
  );
  return FadeTransition(
    opacity: anim,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(anim),
      child: row,
    ),
  );
}
```
Reuse `reduceMotion` from `agent_motion.dart`.

- [ ] **Step 2:** Wire `staggered: true` on the `Drawer`'s `_NavRail`, `false` on the persistent side rail (`body:` branch).

- [ ] **Step 3:** Add a widget test: with `disableAnimations: true`, opening the drawer shows all nav rows immediately (no `FadeTransition` wrapping them, or opacity 1). With motion on, the controller exists. `flutter analyze` clean; targeted test green.

- [ ] **Step 4:** Commit:
```bash
git add lib/core/widgets/manager_scaffold.dart test/core/widgets/manager_scaffold_test.dart
git commit -m "feat(app): staggered nav fade-up when the drawer opens

One AnimationController drives a 20ms-per-row interval fade+slide; skipped
under reduced motion. No change to the drawer's slide.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Elevation — soft shadows on PanelCard/tiles

**Files:** Modify `app/lib/core/widgets/console.dart`.

- [ ] **Step 1:** In `PanelCard` (and the KPI `StatTile` if it has its own container), add a `BoxShadow` list driven by `context.colors.shadow`. Translate the spec's CSS (`rest 0 1px 2px @6%`, `hover 0 4px 12px @10%`) to Flutter. Since `context.colors.shadow` already encodes the base alpha (transparent in dark, `rgba(16,24,40,.08)` in light), use it directly and scale via `blurRadius`/`offset`:
```dart
// rest state
boxShadow: [
  BoxShadow(
    color: context.colors.shadow,
    blurRadius: 2,
    offset: const Offset(0, 1),
  ),
],
```
For a hover-aware card, wrap in a `MouseRegion`/`StatefulWidget` that swaps to the lifted shadow (`blurRadius: 12, offset: Offset(0,4)`, and a slightly stronger color if desired) on hover, animated via `AnimatedContainer(duration: 150ms)`. In dark, `shadow` is transparent so both states render invisibly — dark is unchanged.

- [ ] **Step 2:** Ensure the `PanelCard` container is an `AnimatedContainer` (150ms) if adding hover; otherwise a plain `Container`/`DecoratedBox` with the rest shadow. Keep the existing border + radius.

- [ ] **Step 3:** `flutter analyze` clean. Targeted: `flutter test test/core/widgets/console_test.dart` — existing assertions (border, colors) must stay green; the shadow is additive. Commit:
```bash
git add lib/core/widgets/console.dart
git commit -m "feat(app): PanelCard elevation via context.colors.shadow

Two-layer soft shadow (rest + hover-lifted), 150ms. Dark keeps shadow
transparent, so dark is visually unchanged; light gains real elevation.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Interaction states — WorklistRow + nav hover/pressed

**Files:** Modify `app/lib/core/widgets/worklist.dart` (`WorklistRow`) and `manager_scaffold.dart` (`_NavRow`).

- [ ] **Step 1:** `WorklistRow`: wrap its tap surface in an `InkWell`/`Material` (or `MouseRegion` + `AnimatedContainer` 150ms) so hover paints `context.colors.surface2` and pressed paints `context.colors.surface3`. Keep the existing edge-bar/mark/word severity encoding untouched.
- [ ] **Step 2:** `_NavRow`: same hover (`surface2`) / pressed (`surface3`) wash, 150ms, on top of the existing selected state.
- [ ] **Step 3:** `flutter analyze` clean; `flutter test test/core/widgets/ test/features/tasks/ test/features/alerts/` green (worklist is exercised via those screens). Commit:
```bash
git add lib/core/widgets/worklist.dart lib/core/widgets/manager_scaffold.dart
git commit -m "feat(app): hover/pressed washes on WorklistRow and nav items (150ms)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Focus ring

**Files:** Modify `app/lib/core/theme/app_theme.dart`.

- [ ] **Step 1:** In `_base`, add a `focusColor` / and where components define focus, standardize a visible ring on `c.brand` at 1.5px. For buttons/inputs the `focusedBorder` already uses `brand` 1.5px (Plan A). Add `focusColor: c.brand.withValues(alpha: 0.12)` to the theme and ensure `WidgetStateProperty` overlay for focus on the nav/worklist uses `c.brand`. Keep it minimal — the goal is a consistent keyboard-focus affordance.
- [ ] **Step 2:** `flutter analyze` clean; `flutter test test/core/theme/` green (dark assertions unchanged). Commit:
```bash
git add lib/core/theme/app_theme.dart
git commit -m "feat(app): standardize keyboard focus ring on brand 1.5px

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Verify — full suite + analyze checkpoint

- [ ] **Step 1:** `cd app && flutter analyze` → `No issues found!`.
- [ ] **Step 2:** Full suite: `flutter test` → `All tests passed!` (388 + any new motion tests). If a navigation-driving test hangs on the 250ms transition, add `await tester.pumpAndSettle()` after the nav call (do NOT change assertions). If a test fails because a widget it queried is now wrapped in an animation, adjust the finder, not the assertion.
- [ ] **Step 3:** Manually reason about reduced motion: confirm `managerPage` fades and the drawer stagger is skipped under `disableAnimations` (covered by the Task 2/4 tests).
- [ ] **Step 4:** Push the branch and open a PR to main. Do NOT merge.

---

## Self-Review

**Spec coverage.** §4: shared-axis transitions → Task 2; reduced-motion fallback → Task 2 (+ Task 4 for stagger); drawer scrim → Task 3; drawer stagger → Task 4. §5: elevation → Task 5; interaction states → Task 6; focus → Task 7; "no layout/copy changes" → invariant 4. Dependency → Task 1.

**Dark no-op.** Tasks 3 (scrim=black54), 5 (shadow=transparent) are visually inert in dark by construction. The 388 dark tests must not move; Task 8 confirms.

**Risk.** The main risk is existing tests that drive navigation now needing `pumpAndSettle()` for the 250ms transition — Task 2 Step 6 and Task 8 Step 2 handle this by settling, never by weakening assertions. Most screen tests pump one screen directly and are unaffected.

**Deferred / not in scope.** Agent-side motion (untouched), `ThemeMode.system`, backdrop blur (web perf), any layout/nav/copy change.
