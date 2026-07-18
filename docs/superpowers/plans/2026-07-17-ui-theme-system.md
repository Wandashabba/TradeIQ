# UI Theme System (Plan A of 2) — Dual Theme, Toggle, Migration

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the manager console dual-theme (dark unchanged + new "Paper & Ink" light with a persisted toggle) by introducing a `TiqColors` ThemeExtension, `AppTheme.light()/dark()` from one shared base, a Riverpod `themeModeProvider`, agent-side dark pinning, and a mechanical `AppColors.x → context.colors.x` migration of the manager/shared surface.

**Architecture:** A `TiqColors` `ThemeExtension` carries every semantic color slot with two const instances (`dark` seeded from today's exact `AppColors` values; `light` = Paper & Ink). Both `ThemeData`s are built by one `_base(TiqColors c, Brightness b)` so component themes cannot drift; `MaterialApp.router` gets `theme`/`darkTheme`/`themeMode` from a persisted Riverpod notifier. Manager/shared widgets read `context.colors`; the agent flow (plus login/landing) is wrapped in `PinnedDark` and keeps its `AppColors` statics — pinned dark, where statics and `TiqColors.dark` are identical by definition.

**Tech Stack:** Flutter (web + mobile), flutter_riverpod 3.3.2 (`Notifier`), go_router 17, flutter_secure_storage 10 (already a dependency — no new packages). No build_runner step is needed for any task in this plan (codegen is drift-only, untouched here).

**Spec:** `docs/superpowers/specs/2026-07-17-premium-ui-theme-motion-design.md` — this plan implements §1 (theme architecture), §2 (light chart palette), §3 (toggle/persistence/pinning) and the tokens.css bullet. §4 (motion) and §5 (polish) are **Plan B** — do not implement them here.

**Branch:** `feat/ui-theme-system` (already checked out).

---

## CRITICAL — invariants and resolved ambiguities

Read this before Task 1. Every decision below is deliberate; do not "fix" them mid-plan.

1. **The dark theme's values must not change at all.** The existing suite (89 test files, 366 tests — record the exact count in the baseline step) must stay green with **zero test-file edits**. `TiqColors.dark` is seeded from the `AppColors` consts themselves, so parity is true by construction, and Task 1 additionally pins every slot to its literal hex so a slipped value fails loudly.
2. **`context.colors` falls back to dark.** The spec sketches `Theme.of(this).extension<TiqColors>()!`, but 22 existing test files pump a bare `MaterialApp(...)` with no theme, and `test/helpers/routed_app.dart` passes no theme either — a bang would crash all of them. The extension is therefore
   `Theme.of(this).extension<TiqColors>() ?? TiqColors.dark;`
   In production the fallback never fires (both themes register the extension); in an unthemed test it yields exactly the dark constants today's assertions expect. This is a documented amendment to the spec's sketch (update the spec line in Task 1, Step 6).
3. **Tooltips and chart readouts stay the dark instrument surface in both modes.** The `#05060A` tooltip/scrub-readout surface with dark-ink text is kept verbatim in light mode (inverted tooltips are the standard premium treatment; deriving them from light ink would put near-black text on a near-black panel). These sites intentionally keep dark constants — they are listed per-task, not migrated by accident.
4. **`StatusLevel.color` (the context-free getter) is kept.** `console_test.dart` asserts `StatusLevel.critical.color == AppColors.crit` directly. Widgets migrate to a new `colorOf(TiqColors)`; the old getter stays as the dark-constant lookup for tests and agent-pinned callers.
5. **Geometry stays on `AppColors`.** `radiusControl`/`radiusPanel` are not colors and do not move. A migrated file that uses only radii keeps its `app_colors.dart` import; a migrated file with no remaining `AppColors.` reference drops it.
6. **Never leave a file half-migrated.** Each migration batch ends with `flutter analyze` clean + full `flutter test` green + a commit. A file either fully reads `context.colors` (radii excepted) or still fully reads statics.
7. **`photo_capture_field.dart` (agent-pinned) imports `console.dart` (migrated).** This is safe *because of* invariants 2 and the `PinnedDark` wrapper: inside agent flows, `context.colors` resolves to `TiqColors.dark`. Do not migrate `photo_capture_field.dart` itself.
8. **Commands.** All app commands run from `app/`: `cd app && flutter analyze` (expect `No issues found!`) and `cd app && flutter test` (expect `All tests passed!`). Establish the baseline before Task 1 and record the test count:
   ```bash
   cd app && flutter analyze && flutter test
   ```

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `app/lib/core/theme/tiq_colors.dart` | `TiqColors` ThemeExtension (dark + light const instances), `context.colors` | Create |
| `app/lib/core/theme/app_theme.dart` | `AppTheme.light()`/`dark()` from shared `_base(TiqColors, Brightness)` | Modify (rewrite) |
| `app/lib/core/theme/theme_mode_controller.dart` | `ThemeModeStore` (secure-storage persistence) + `themeModeProvider` | Create |
| `app/lib/core/widgets/pinned_dark.dart` | `PinnedDark` wrapper (forces `AppTheme.dark()` on a subtree) | Create |
| `app/lib/core/theme/app_colors.dart` | Dark constant table (seeds `TiqColors.dark`; agent-pinned callers) | Unchanged (values) |
| `app/lib/main.dart` | `theme`/`darkTheme`/`themeMode` wiring | Modify |
| `app/lib/core/widgets/agent_scaffold.dart` | Agent shell | Modify — wrap in `PinnedDark` |
| `app/lib/features/auth/presentation/{login,landing}_screen.dart` | Public screens | Modify — wrap in `PinnedDark` |
| `app/lib/core/widgets/manager_scaffold.dart` | Console shell + theme toggle | Modify — migrate + toggle button |
| `app/lib/core/widgets/{console,worklist,charts}.dart` | Shared console widgets | Modify — migrate to `context.colors` |
| 19 manager feature screens (list in Tasks 10–12) | Feature UI | Modify — mechanical migration |
| `design/tokens.css` | Authoritative design tokens | Modify — `[data-theme="light"]` block + `--shadow`/`--scrim` |
| `app/test/core/theme/tiq_colors_test.dart` | Dark parity + light contrast tests | Create |
| `app/test/core/theme/theme_mode_controller_test.dart` | Persistence/restore/toggle tests | Create |
| `app/test/core/theme/theme_switching_test.dart` | Toggle flips shell; agent stays dark; persistence | Create |
| `app/test/core/theme/app_theme_test.dart` | Existing dark assertions (must stay green) | Modify — add light/extension assertions |

### Migration census (ground truth, from `grep -o "AppColors\.[A-Za-z0-9_]*"`)

**Migrate — 23 files, ~193 refs.** Core: `manager_scaffold.dart` (16), `console.dart` (21), `worklist.dart` (17), `charts.dart` (39). Screens: `dashboard_shell_screen` (15), `trends_screen` (15), `messages_screen` (15), `client_config_screen` (13), `tasks_screen` (12), `alerts_screen` (9), `dispatch_screen` (3), `beatplans_screen` (3), `alert_rules_screen` (3), `orders_screen` (2), `fraud_screen` (2), `campaigns_screen` (1), `leaderboard_screen` (1), `incentives_screen` (1), `outlets_list_screen` (1), `templates_screen` (1), `territories_screen` (1), `users_screen` (1), `webhooks_screen` (1).

**Keep statics (agent-pinned) — 13 files, ~180 refs.** `agent_kit.dart`, `agent_motion.dart`, `agent_scaffold.dart`, `photo_capture_field.dart`, `primary_gradient_button.dart`, `audit_shell_screen.dart`, `my_work_screen.dart`, `submit_gate_screen.dart`, `visit_outcome_screen.dart`, `sections/s2_stock_screen.dart`, `today_screen.dart`, `login_screen.dart`, `landing_screen.dart`.

The manager set uses **only** these members (verified): `plane, surface1..3, line, lineStrong, ink1..3, brand, series1, good, warn, crit, grid, axis` + `radiusControl`/`radiusPanel`. No back-compat aliases (`textPrimary`, `canvas`, `accentOrange`, …) appear on the manager side, so the migration is a pure rename — no alias mapping needed.

---

### Task 1: `TiqColors` ThemeExtension + `context.colors`

**Files:**
- Create: `app/lib/core/theme/tiq_colors.dart`
- Test: `app/test/core/theme/tiq_colors_test.dart`
- Modify: `docs/superpowers/specs/2026-07-17-premium-ui-theme-motion-design.md` (one line, Step 6)

- [ ] **Step 1: Write the failing dark-parity test**

Create `app/test/core/theme/tiq_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';

void main() {
  group('TiqColors.dark parity', () {
    // The dark theme's values must not change AT ALL (spec, Testing section).
    // Literal hex — not AppColors refs — so a slipped value in EITHER table
    // fails loudly.
    test('every slot carries today\'s exact dark value', () {
      const d = TiqColors.dark;
      expect(d.plane, const Color(0xFF0B0C10));
      expect(d.surface1, const Color(0xFF14161C));
      expect(d.surface2, const Color(0xFF1A1D25));
      expect(d.surface3, const Color(0xFF21252E));
      expect(d.line, const Color(0xFF23262F));
      expect(d.lineStrong, const Color(0xFF2F333E));
      expect(d.ink1, const Color(0xFFE9EBEE));
      expect(d.ink2, const Color(0xFF99A1AD));
      expect(d.ink3, const Color(0xFF6A7280));
      expect(d.brand, const Color(0xFF0A6CF0));
      expect(d.brandHover, const Color(0xFF1F7CF5));
      expect(d.series1, const Color(0xFF3987E5));
      expect(d.series2, const Color(0xFF199E70));
      expect(d.series3, const Color(0xFFC98500));
      expect(d.good, const Color(0xFF0CA30C));
      expect(d.warn, const Color(0xFFFAB219));
      expect(d.crit, const Color(0xFFD03B3B));
      expect(d.grid, const Color(0xFF22252D));
      expect(d.axis, const Color(0xFF2F333E));
      // New slots: dark keeps shadow transparent (borders do the job) and the
      // scrim equal to Flutter's default black54, so Plan B's application of
      // these slots changes nothing visually in dark.
      expect(d.shadow, const Color(0x00000000));
      expect(d.scrim, const Color(0x8A000000));
    });

    test('light carries the dark ink forward as its primary text color', () {
      // "the two modes read as one product" — spec §Paper & Ink.
      expect(TiqColors.light.ink1, const Color(0xFF14161C));
      expect(TiqColors.light.plane, const Color(0xFFF7F8FA));
      expect(TiqColors.light.surface1, const Color(0xFFFFFFFF));
      expect(TiqColors.light.line, const Color(0xFFE3E5EA));
    });

    test('lerp interpolates and copyWith replaces a single slot', () {
      final mid = TiqColors.dark.lerp(TiqColors.light, 0.5);
      expect(mid.plane, Color.lerp(TiqColors.dark.plane, TiqColors.light.plane, 0.5));
      final copied = TiqColors.dark.copyWith(brand: const Color(0xFF123456));
      expect(copied.brand, const Color(0xFF123456));
      expect(copied.plane, TiqColors.dark.plane);
    });
  });
}
```

- [ ] **Step 2: Run it — expect FAIL (file does not exist)**

```bash
cd app && flutter test test/core/theme/tiq_colors_test.dart
```

Expected: compilation failure — `Error: Couldn't resolve the package ... tiq_colors.dart`.

- [ ] **Step 3: Create `app/lib/core/theme/tiq_colors.dart`**

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The theme-aware TradeIQ palette — every semantic slot the console uses,
/// carried as a [ThemeExtension] so widgets can respond to the light/dark
/// toggle at runtime.
///
/// [TiqColors.dark] is seeded from the [AppColors] consts, so it is identical
/// to today's static palette by construction. [TiqColors.light] is the
/// "Paper & Ink" scheme from the 2026-07-17 premium-UI spec: `#F7F8FA` page
/// ground, white panels, `#E3E5EA` hairlines — and the dark theme's ink
/// `#14161C` carried forward as primary text, so the two modes read as one
/// product. Its chart series/status colors are darkened variants validated
/// ≥3:1 against white (see tiq_colors_test.dart).
///
/// Slot discipline is unchanged: status colors are never series colors, and
/// meaning never rides on color alone.
///
/// Mirrors `design/tokens.css` (dark `:root` + `[data-theme="light"]`).
class TiqColors extends ThemeExtension<TiqColors> {
  const TiqColors({
    required this.plane,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.lineStrong,
    required this.ink1,
    required this.ink2,
    required this.ink3,
    required this.brand,
    required this.brandHover,
    required this.series1,
    required this.series2,
    required this.series3,
    required this.good,
    required this.warn,
    required this.crit,
    required this.grid,
    required this.axis,
    required this.shadow,
    required this.scrim,
  });

  // ── Planes & surfaces ────────────────────────────────────────────────
  final Color plane;
  final Color surface1;
  final Color surface2;
  final Color surface3;

  // ── Hairlines ────────────────────────────────────────────────────────
  final Color line;
  final Color lineStrong;

  // ── Ink ──────────────────────────────────────────────────────────────
  final Color ink1;
  final Color ink2;
  final Color ink3;

  // ── Brand ────────────────────────────────────────────────────────────
  final Color brand;
  final Color brandHover;

  // ── Data series — fixed slot order. Never cycled, never generated. ───
  final Color series1;
  final Color series2;
  final Color series3;

  // ── Status — reserved. Never a series color. ─────────────────────────
  final Color good;
  final Color warn;
  final Color crit;

  // ── Chart chrome ─────────────────────────────────────────────────────
  final Color grid;
  final Color axis;

  // ── Elevation & overlay (new slots — used by Plan B) ─────────────────
  /// Panel drop-shadow color. Transparent in dark: its borders already carry
  /// elevation, so dark's appearance cannot change.
  final Color shadow;

  /// Drawer overlay wash. Dark equals Flutter's default black54 so applying
  /// the slot (Plan B) is a no-op in dark.
  final Color scrim;

  /// Today's exact dark palette. Seeded from [AppColors] so the static table
  /// and the extension can never disagree.
  static const dark = TiqColors(
    plane: AppColors.plane,
    surface1: AppColors.surface1,
    surface2: AppColors.surface2,
    surface3: AppColors.surface3,
    line: AppColors.line,
    lineStrong: AppColors.lineStrong,
    ink1: AppColors.ink1,
    ink2: AppColors.ink2,
    ink3: AppColors.ink3,
    brand: AppColors.brand,
    brandHover: AppColors.brandHover,
    series1: AppColors.series1,
    series2: AppColors.series2,
    series3: AppColors.series3,
    good: AppColors.good,
    warn: AppColors.warn,
    crit: AppColors.crit,
    grid: AppColors.grid,
    axis: AppColors.axis,
    shadow: Color(0x00000000),
    scrim: Color(0x8A000000), // == Colors.black54
  );

  /// Paper & Ink. ink3 and brand are shared with dark deliberately — both
  /// clear contrast on white (4.85:1 and 4.98:1), and shared anchors keep the
  /// two modes reading as one product.
  static const light = TiqColors(
    plane: Color(0xFFF7F8FA),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F3F6),
    surface3: Color(0xFFE8EBF0),
    line: Color(0xFFE3E5EA),
    lineStrong: Color(0xFFD2D6DE),
    ink1: Color(0xFF14161C), // the dark theme's ink, carried forward
    ink2: Color(0xFF4C5560),
    ink3: Color(0xFF6A7280),
    brand: Color(0xFF0A6CF0),
    brandHover: Color(0xFF0857C4), // hover darkens on a light ground
    series1: Color(0xFF2069C9),
    series2: Color(0xFF177A57),
    series3: Color(0xFF9A6700),
    good: Color(0xFF0B7A0B),
    warn: Color(0xFF935F00),
    crit: Color(0xFFB32E2E),
    grid: Color(0xFFECEEF2),
    axis: Color(0xFFD2D6DE),
    shadow: Color(0x14101828), // 8% slate — Plan B layers opacities on top
    scrim: Color(0x99101828), // 60% slate — deeper than black54's wash reads on light
  );

  @override
  TiqColors copyWith({
    Color? plane,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? line,
    Color? lineStrong,
    Color? ink1,
    Color? ink2,
    Color? ink3,
    Color? brand,
    Color? brandHover,
    Color? series1,
    Color? series2,
    Color? series3,
    Color? good,
    Color? warn,
    Color? crit,
    Color? grid,
    Color? axis,
    Color? shadow,
    Color? scrim,
  }) {
    return TiqColors(
      plane: plane ?? this.plane,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      ink1: ink1 ?? this.ink1,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      brand: brand ?? this.brand,
      brandHover: brandHover ?? this.brandHover,
      series1: series1 ?? this.series1,
      series2: series2 ?? this.series2,
      series3: series3 ?? this.series3,
      good: good ?? this.good,
      warn: warn ?? this.warn,
      crit: crit ?? this.crit,
      grid: grid ?? this.grid,
      axis: axis ?? this.axis,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  TiqColors lerp(ThemeExtension<TiqColors>? other, double t) {
    if (other is! TiqColors) return this;
    return TiqColors(
      plane: Color.lerp(plane, other.plane, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      ink1: Color.lerp(ink1, other.ink1, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandHover: Color.lerp(brandHover, other.brandHover, t)!,
      series1: Color.lerp(series1, other.series1, t)!,
      series2: Color.lerp(series2, other.series2, t)!,
      series3: Color.lerp(series3, other.series3, t)!,
      good: Color.lerp(good, other.good, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      crit: Color.lerp(crit, other.crit, t)!,
      grid: Color.lerp(grid, other.grid, t)!,
      axis: Color.lerp(axis, other.axis, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// `context.colors` — how feature code reads the ambient palette.
///
/// Falls back to [TiqColors.dark] when no theme registers the extension. In
/// production both AppTheme.light() and AppTheme.dark() register it, so the
/// fallback only fires in tests that pump a bare MaterialApp — where dark (the
/// pre-theme-system status quo) is exactly what their assertions expect. This
/// keeps all pre-existing widget tests green with zero edits.
extension TiqColorsContext on BuildContext {
  TiqColors get colors => Theme.of(this).extension<TiqColors>() ?? TiqColors.dark;
}
```

- [ ] **Step 4: Run the test — expect PASS**

```bash
cd app && flutter test test/core/theme/tiq_colors_test.dart
```

Expected: `All tests passed!` (3 tests).

- [ ] **Step 5: Analyze**

```bash
cd app && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 6: Record the `context.colors` amendment in the spec**

In `docs/superpowers/specs/2026-07-17-premium-ui-theme-motion-design.md`, change the `context.colors` bullet (spec §1, the line reading `` `Theme.of(this).extension<TiqColors>()!` ``) to:

```markdown
- **`context.colors`** — a one-line `BuildContext` extension returning
  `Theme.of(this).extension<TiqColors>() ?? TiqColors.dark` (the fallback keeps
  the 22 pre-existing bare-`MaterialApp` test pumps green; production themes
  always register the extension). Feature code migrates mechanically:
  `AppColors.x` → `context.colors.x`.
```

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/theme/tiq_colors.dart app/test/core/theme/tiq_colors_test.dart docs/superpowers/specs/2026-07-17-premium-ui-theme-motion-design.md
git commit -m "feat(app): TiqColors ThemeExtension with dark parity + Paper & Ink light

TiqColors carries every semantic slot plus new shadow/scrim. dark is
seeded from the AppColors consts (identical by construction) and pinned
to literal hex by test; light is the Paper & Ink scheme with the dark
ink carried forward. context.colors falls back to TiqColors.dark so the
22 bare-MaterialApp test pumps stay green — spec amended to match."
```
End the commit message with a blank line then: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

### Task 2: Light chart palette contrast test (WCAG ≥3:1 on white)

**Files:**
- Modify: `app/test/core/theme/tiq_colors_test.dart` (append a group)

- [ ] **Step 1: Append the contrast group to `tiq_colors_test.dart`**

Add below the existing group, inside `main()`:

```dart
  group('TiqColors.light chart palette contrast', () {
    // WCAG 2.x relative luminance + contrast ratio, written out in full so a
    // palette regression fails with the actual ratio in the message.
    // Color.r/.g/.b are already 0..1 doubles on current Flutter.
    double linearize(double channel) => channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

    double relativeLuminance(Color c) =>
        0.2126 * linearize(c.r) + 0.7152 * linearize(c.g) + 0.0722 * linearize(c.b);

    double contrastRatio(Color a, Color b) {
      final la = relativeLuminance(a);
      final lb = relativeLuminance(b);
      final hi = math.max(la, lb);
      final lo = math.min(la, lb);
      return (hi + 0.05) / (lo + 0.05);
    }

    const white = Color(0xFFFFFFFF);
    const l = TiqColors.light;

    // Charts draw on surface1 (#FFFFFF in light). Series and status colors
    // must clear 3:1 there (spec §2). If any value here fails: darken it until
    // it passes, then update BOTH the spec value and TiqColors.light.
    final palette = <String, Color>{
      'series1': l.series1, // #2069C9 ≈ 5.0:1
      'series2': l.series2, // #177A57 ≈ 5.3:1
      'series3': l.series3, // #9A6700 ≈ 4.9:1
      'good': l.good, //       #0B7A0B ≈ 5.5:1
      'warn': l.warn, //       #935F00 ≈ 5.4:1
      'crit': l.crit, //       #B32E2E ≈ 6.3:1
    };

    for (final entry in palette.entries) {
      test('${entry.key} clears 3:1 against white', () {
        final ratio = contrastRatio(entry.value, white);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: '${entry.key} is $ratio:1 on white — darken it and update '
              'the spec (docs/superpowers/specs/2026-07-17-premium-ui-theme-'
              'motion-design.md §2) to the passing value.',
        );
      });
    }
  });
```

And add the import at the top of the file:

```dart
import 'dart:math' as math;
```

- [ ] **Step 2: Run — expect PASS (all six values were pre-computed to clear 3:1)**

```bash
cd app && flutter test test/core/theme/tiq_colors_test.dart
```

Expected: `All tests passed!` (9 tests). If any contrast test fails, follow the reason string: darken the value in `TiqColors.light`, re-run until green, and change the spec §2 value to match — do not lower the 3.0 threshold.

- [ ] **Step 3: Commit**

```bash
git add app/test/core/theme/tiq_colors_test.dart
git commit -m "test(app): assert the six light chart colors clear 3:1 on white

Full WCAG relative-luminance math in the test so a palette regression
fails loudly with the actual ratio."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 3: `AppTheme.light()` + `AppTheme.dark()` from one shared base

**Files:**
- Modify: `app/lib/core/theme/app_theme.dart` (full rewrite below)
- Modify: `app/test/core/theme/app_theme_test.dart` (append tests; the existing one must stay green)

- [ ] **Step 1: Append failing tests to `app_theme_test.dart`**

Keep the existing `dark theme uses the shared AppColors background` test untouched. Append inside `main()`:

```dart
  test('both themes register the TiqColors extension', () {
    expect(AppTheme.dark().extension<TiqColors>(), same(TiqColors.dark));
    expect(AppTheme.light().extension<TiqColors>(), same(TiqColors.light));
  });

  test('dark component themes are byte-identical to the pre-extension values', () {
    final t = AppTheme.dark();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, const Color(0xFF0B0C10));
    expect(t.canvasColor, const Color(0xFF14161C));
    expect(t.colorScheme.primary, const Color(0xFF0A6CF0));
    expect(t.appBarTheme.backgroundColor, const Color(0xFF14161C));
    expect(t.inputDecorationTheme.fillColor, const Color(0xFF1A1D25));
    expect(
      (t.cardTheme.shape as RoundedRectangleBorder).side.color,
      const Color(0xFF23262F),
    );
    expect(t.dividerTheme.color, const Color(0xFF23262F));
    expect(t.chipTheme.backgroundColor, const Color(0xFF1A1D25));
    expect(t.textTheme.bodyMedium?.color, const Color(0xFFE9EBEE));
    expect(t.textTheme.bodySmall?.color, const Color(0xFF99A1AD));
    expect(t.textTheme.labelSmall?.color, const Color(0xFF6A7280));
  });

  test('light derives the same component themes from TiqColors.light', () {
    final t = AppTheme.light();
    expect(t.brightness, Brightness.light);
    expect(t.scaffoldBackgroundColor, TiqColors.light.plane);
    expect(t.appBarTheme.backgroundColor, TiqColors.light.surface1);
    expect(t.inputDecorationTheme.fillColor, TiqColors.light.surface2);
    expect(t.textTheme.bodyMedium?.color, TiqColors.light.ink1);
  });
```

Add the imports at the top:

```dart
import 'package:flutter/material.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
```

- [ ] **Step 2: Run — expect FAIL** (`AppTheme.light` is undefined; no extension registered)

```bash
cd app && flutter test test/core/theme/app_theme_test.dart
```

- [ ] **Step 3: Rewrite `app/lib/core/theme/app_theme.dart`**

Replace the whole file with:

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'tiq_colors.dart';

/// The TradeIQ themes.
///
/// Both modes are built by one [_base] from a [TiqColors] scheme, so component
/// themes (inputs, buttons, cards, appbar, chips…) cannot drift between them.
/// Geometry is squared off — controls are 3px, panels 4px, and nothing is a
/// stadium/pill. One type family throughout (Inter); `tabular-nums` is applied
/// per-widget where digits must align vertically, not globally.
///
/// Mirrors `design/tokens.css`.
class AppTheme {
  AppTheme._();

  static const _control = BorderRadius.all(
    Radius.circular(AppColors.radiusControl),
  );
  static const _panel = BorderRadius.all(
    Radius.circular(AppColors.radiusPanel),
  );

  static ThemeData dark() => _base(TiqColors.dark, Brightness.dark);

  static ThemeData light() => _base(TiqColors.light, Brightness.light);

  static ThemeData _base(TiqColors c, Brightness brightness) {
    final fieldBorder = OutlineInputBorder(
      borderRadius: _control,
      borderSide: BorderSide(color: c.lineStrong),
    );

    final colorScheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: c.brand,
            onPrimary: Colors.white,
            secondary: c.series1,
            onSecondary: Colors.white,
            surface: c.surface1,
            onSurface: c.ink1,
            error: c.crit,
            onError: Colors.white,
            outline: c.lineStrong,
          )
        : ColorScheme.light(
            primary: c.brand,
            onPrimary: Colors.white,
            secondary: c.series1,
            onSecondary: Colors.white,
            surface: c.surface1,
            onSurface: c.ink1,
            error: c.crit,
            onError: Colors.white,
            outline: c.lineStrong,
          );

    return ThemeData(
      brightness: brightness,
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.plane,
      canvasColor: c.surface1,
      colorScheme: colorScheme,
      textTheme: TextTheme(
        // Large standalone figures use proportional digits — tabular figures
        // make `121` look loose at display sizes.
        displaySmall: TextStyle(
          color: c.ink1,
          fontSize: 40,
          height: 1.0,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
        ),
        headlineSmall: TextStyle(
          color: c.ink1,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: c.ink1,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: c.ink1,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: c.ink1, fontSize: 13),
        bodySmall: TextStyle(color: c.ink2, fontSize: 12),
        labelSmall: TextStyle(
          color: c.ink3,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
        ),
      ),
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Arial', 'sans-serif'],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface1,
        foregroundColor: c.ink1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.ink1,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
        shape: Border(bottom: BorderSide(color: c.line)),
      ),
      cardTheme: CardThemeData(
        color: c.surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: _panel,
          side: BorderSide(color: c.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        hintStyle: TextStyle(color: c.ink3, fontSize: 13),
        labelStyle: TextStyle(color: c.ink2, fontSize: 12.5),
        floatingLabelStyle: TextStyle(color: c.series1),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: _control,
          borderSide: BorderSide(color: c.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _control,
          borderSide: BorderSide(color: c.crit),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: _control,
          borderSide: BorderSide(color: c.crit, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.brand.withValues(alpha: .4),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _control),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _control),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink1,
          backgroundColor: c.surface2,
          side: BorderSide(color: c.lineStrong),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          shape: const RoundedRectangleBorder(borderRadius: _control),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.series1,
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(borderRadius: _control),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.brand
              : Colors.transparent,
        ),
        side: BorderSide(color: c.lineStrong),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.line,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.ink3,
        textColor: c.ink2,
        dense: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface2,
        side: BorderSide(color: c.line),
        shape: const RoundedRectangleBorder(borderRadius: _control),
        labelStyle: TextStyle(fontSize: 11.5, color: c.ink2),
      ),
      // Tooltips stay the dark instrument surface in BOTH modes: an inverted
      // tooltip is the standard premium treatment, and deriving it from light
      // ink would put near-black text on a near-black panel. Deliberately
      // AppColors (dark constants), not `c`.
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: Color(0xFF05060A),
          border: Border.fromBorderSide(BorderSide(color: AppColors.lineStrong)),
          borderRadius: _control,
        ),
        textStyle: TextStyle(color: AppColors.ink1, fontSize: 11.5),
      ),
      useMaterial3: true,
    );
  }
}
```

- [ ] **Step 4: Run theme tests, then the FULL suite**

```bash
cd app && flutter test test/core/theme/ && flutter test
```

Expected: all green, same total count as the baseline plus the new tests. The full run is the proof that the `_base` refactor left the dark theme byte-identical — if any pre-existing test fails on a color, a `c.` slot diverged from the old literal; fix the slot, never the test.

- [ ] **Step 5: Analyze + commit**

```bash
cd app && flutter analyze
git add app/lib/core/theme/app_theme.dart app/test/core/theme/app_theme_test.dart
git commit -m "feat(app): AppTheme.light() and dark() from one shared _base(TiqColors)

Every component theme derives from the scheme so light and dark cannot
drift; the TiqColors extension is registered on both. Dark output is
pinned byte-identical by literal-hex test. Tooltips deliberately keep
the fixed dark surface in both modes."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 4: `themeModeProvider` with secure-storage persistence

**Files:**
- Create: `app/lib/core/theme/theme_mode_controller.dart`
- Test: `app/test/core/theme/theme_mode_controller_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `app/test/core/theme/theme_mode_controller_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tradeiq_app/core/theme/theme_mode_controller.dart';

class FakeThemeModeStore implements ThemeModeStore {
  FakeThemeModeStore([this.stored]);
  ThemeMode? stored;

  @override
  Future<ThemeMode?> read() async => stored;

  @override
  Future<void> write(ThemeMode mode) async => stored = mode;
}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  ProviderContainer withStore(ThemeModeStore store) {
    final container = ProviderContainer(
      overrides: [themeModeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ThemeModeController', () {
    test('defaults to dark when nothing is stored', () async {
      final container = withStore(FakeThemeModeStore());
      expect(container.read(themeModeProvider), ThemeMode.dark);
      await Future<void>.delayed(Duration.zero); // let the restore settle
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('restores a persisted light mode', () async {
      final container = withStore(FakeThemeModeStore(ThemeMode.light));
      // Synchronous first read is dark — restore is async by design.
      expect(container.read(themeModeProvider), ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('toggle flips the mode and persists it', () async {
      final store = FakeThemeModeStore();
      final container = withStore(store);
      await container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(store.stored, ThemeMode.light);
      await container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(store.stored, ThemeMode.dark);
    });

    test('a toggle made before the restore lands is not clobbered by it', () async {
      final container = withStore(FakeThemeModeStore(ThemeMode.dark));
      await container.read(themeModeProvider.notifier).toggle(); // → light
      await Future<void>.delayed(Duration.zero); // restore resolves 'dark'
      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });

  group('SecureThemeModeStore', () {
    test('maps stored strings to modes and unknown values to null', () async {
      final storage = _MockSecureStorage();
      final store = SecureThemeModeStore(storage: storage);
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'light');
      expect(await store.read(), ThemeMode.light);
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'banana');
      expect(await store.read(), isNull);
    });

    test('an unreadable store yields null — caller keeps dark', () async {
      final storage = _MockSecureStorage();
      when(() => storage.read(key: any(named: 'key')))
          .thenThrow(PlatformException(code: 'boom'));
      expect(await SecureThemeModeStore(storage: storage).read(), isNull);
    });

    test('writes under the spec key tiq.themeMode', () async {
      final storage = _MockSecureStorage();
      when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      await SecureThemeModeStore(storage: storage).write(ThemeMode.light);
      verify(() => storage.write(key: 'tiq.themeMode', value: 'light')).called(1);
    });
  });
}
```

- [ ] **Step 2: Run — expect FAIL (file does not exist)**

```bash
cd app && flutter test test/core/theme/theme_mode_controller_test.dart
```

- [ ] **Step 3: Create `app/lib/core/theme/theme_mode_controller.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the manager's theme choice across app restarts. Abstracted (like
/// TokenStore) so tests use an in-memory fake instead of the platform
/// keychain. Stored in the already-present flutter_secure_storage — not a
/// secret, but not worth a second storage stack.
abstract class ThemeModeStore {
  /// The persisted mode, or null when missing/unreadable — caller keeps dark.
  Future<ThemeMode?> read();

  Future<void> write(ThemeMode mode);
}

class SecureThemeModeStore implements ThemeModeStore {
  SecureThemeModeStore({FlutterSecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'tiq.themeMode';

  @override
  Future<ThemeMode?> read() async {
    try {
      return switch (await _storage.read(key: _key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => null,
      };
    } catch (_) {
      return null; // unreadable → dark, never a crash on startup
    }
  }

  @override
  Future<void> write(ThemeMode mode) async {
    try {
      await _storage.write(
        key: _key,
        value: mode == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {
      // Best-effort: an unpersisted toggle still applies for this run.
    }
  }
}

final themeModeStoreProvider =
    Provider<ThemeModeStore>((ref) => SecureThemeModeStore());

/// light/dark only — ThemeMode.system is deliberately out of scope (managers
/// on desktop web; two explicit modes are clearer than three). Default and
/// every failure path: dark, so nobody's console changes until they touch the
/// toggle.
class ThemeModeController extends Notifier<ThemeMode> {
  bool _userChose = false;

  @override
  ThemeMode build() {
    Future.microtask(_restore); // build() must return synchronously
    return ThemeMode.dark;
  }

  Future<void> _restore() async {
    final saved = await ref.read(themeModeStoreProvider).read();
    // A toggle that raced the restore wins — it is the newer intent.
    if (saved != null && !_userChose) state = saved;
  }

  Future<void> toggle() async {
    _userChose = true;
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await ref.read(themeModeStoreProvider).write(state);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
```

- [ ] **Step 4: Run — expect PASS (7 tests)**

```bash
cd app && flutter test test/core/theme/theme_mode_controller_test.dart
```

- [ ] **Step 5: Analyze + commit**

```bash
cd app && flutter analyze
git add app/lib/core/theme/theme_mode_controller.dart app/test/core/theme/theme_mode_controller_test.dart
git commit -m "feat(app): themeModeProvider persisted under tiq.themeMode

Riverpod Notifier defaulting to dark; async restore from
flutter_secure_storage with missing/unreadable/unknown all resolving to
dark, and a user toggle always beating a racing restore. light/dark
only — ThemeMode.system is deliberately out of scope."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 5: `PinnedDark` + agent/login/landing pinning

**Files:**
- Create: `app/lib/core/widgets/pinned_dark.dart`
- Modify: `app/lib/core/widgets/agent_scaffold.dart`
- Modify: `app/lib/features/auth/presentation/login_screen.dart`
- Modify: `app/lib/features/auth/presentation/landing_screen.dart`
- Test: `app/test/core/theme/theme_switching_test.dart` (created here, extended in Task 7)

- [ ] **Step 1: Write the failing agent-stays-dark test**

Create `app/test/core/theme/theme_switching_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_scaffold.dart';

void main() {
  testWidgets('an agent screen stays dark while themeMode is light', (tester) async {
    // showSyncChip: false — the chip opens the local DB (see routed_app.dart);
    // this test is about theming, not sync.
    final router = GoRouter(
      initialLocation: '/screen',
      routes: [
        GoRoute(
          path: '/screen',
          builder: (context, state) => const AgentScaffold(
            title: 'Agent',
            body: SizedBox(),
            showSyncChip: false,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.light, // the app-level mode is LIGHT
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Inside the agent shell the ambient theme must still be the dark one.
    final ctx = tester.element(find.byType(AppBar));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(ctx.colors, same(TiqColors.dark));
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`Theme.of(ctx).brightness` is `Brightness.light` — nothing pins the subtree yet)

```bash
cd app && flutter test test/core/theme/theme_switching_test.dart
```

- [ ] **Step 3: Create `app/lib/core/widgets/pinned_dark.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pins its subtree to the dark theme regardless of the app-level ThemeMode.
///
/// The field-agent flow (AgentScaffold screens) and the public login/landing
/// screens ship dark-only in this pass — spec: "Agent side stays pinned
/// dark". Inside this wrapper, `context.colors` resolves to TiqColors.dark,
/// so shared widgets (e.g. console.dart's StatusChip inside
/// photo_capture_field.dart) render dark here while following the toggle in
/// the manager console. Agent light mode is a separate later ticket.
class PinnedDark extends StatelessWidget {
  const PinnedDark({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: AppTheme.dark(), child: child);
}
```

- [ ] **Step 4: Wrap the three scaffolds**

In `app/lib/core/widgets/agent_scaffold.dart`, add the import and wrap the returned `Scaffold` (currently `return Scaffold(` at line 53):

```dart
import 'pinned_dark.dart';
```

```dart
    return PinnedDark(
      child: Scaffold(
        backgroundColor: AppColors.plane,
        // ... existing body of the Scaffold, unchanged ...
      ),
    );
```

(Only the wrapper and the closing `)` change — every line inside the Scaffold stays exactly as it is.)

In `app/lib/features/auth/presentation/login_screen.dart` (the `return Scaffold(` at line 83) and `app/lib/features/auth/presentation/landing_screen.dart` (the `return Scaffold(` at line 52), do the same: add `import '../../../core/widgets/pinned_dark.dart';` and wrap each screen's returned `Scaffold` in `PinnedDark(child: ...)`.

- [ ] **Step 5: Run the new test + the full suite**

```bash
cd app && flutter test test/core/theme/theme_switching_test.dart && flutter test
```

Expected: all green. The existing login/agent tests never assert on `Theme` widget counts, so the extra `Theme` node is invisible to them; the wrapped screens render pixel-identically in dark mode.

- [ ] **Step 6: Analyze + commit**

```bash
cd app && flutter analyze
git add app/lib/core/widgets/pinned_dark.dart app/lib/core/widgets/agent_scaffold.dart app/lib/features/auth/presentation/login_screen.dart app/lib/features/auth/presentation/landing_screen.dart app/test/core/theme/theme_switching_test.dart
git commit -m "feat(app): PinnedDark pins the agent flow and login/landing to dark

Theme(data: AppTheme.dark()) inside AgentScaffold and around the public
screens' scaffolds, so the agent side ignores the manager's theme
toggle. Widget test proves the agent shell stays dark under a light
app-level themeMode."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 6: Wire `MaterialApp.router` to the provider

**Files:**
- Modify: `app/lib/main.dart`

- [ ] **Step 1: Rewrite the build method**

In `app/lib/main.dart`, replace the `MaterialApp.router(...)` expression (lines 16–21) with:

```dart
    return MaterialApp.router(
      title: 'TradeIQ',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Persisted choice; defaults to dark, so nobody's console changes until
      // they touch the toggle (Task 7).
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
```

and add the import:

```dart
import 'core/theme/theme_mode_controller.dart';
```

- [ ] **Step 2: Full suite + analyze**

```bash
cd app && flutter analyze && flutter test
```

Expected: green. `themeMode` defaults to dark and the toggle does not exist yet, so nothing observable changes; manager statics are still statics, which is exactly why this lands before the migration.

- [ ] **Step 3: Commit**

```bash
git add app/lib/main.dart
git commit -m "feat(app): MaterialApp.router carries theme/darkTheme/themeMode

Wired to themeModeProvider. Default stays dark; the toggle arrives with
the ManagerScaffold migration."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 7: ManagerScaffold — migrate + the `theme-toggle` button

**Files:**
- Modify: `app/lib/core/widgets/manager_scaffold.dart`
- Test: `app/test/core/theme/theme_switching_test.dart` (append)
- Test: `app/test/core/widgets/manager_scaffold_test.dart` (must stay green, unmodified)

- [ ] **Step 1: Append the failing toggle tests**

In `app/test/core/theme/theme_switching_test.dart`, add imports:

```dart
import 'package:tradeiq_app/core/theme/theme_mode_controller.dart';
import 'package:tradeiq_app/core/widgets/manager_scaffold.dart';
```

add this fake next to `main()` (top level):

```dart
class FakeThemeModeStore implements ThemeModeStore {
  FakeThemeModeStore([this.stored]);
  ThemeMode? stored;

  @override
  Future<ThemeMode?> read() async => stored;

  @override
  Future<void> write(ThemeMode mode) async => stored = mode;
}
```

and append inside `main()`:

```dart
  Widget managerApp(ThemeModeStore store) {
    // Router hoisted OUTSIDE the Consumer so a theme rebuild never recreates it.
    final router = GoRouter(
      initialLocation: '/screen',
      routes: [
        GoRoute(
          path: '/screen',
          builder: (context, state) =>
              const ManagerScaffold(title: 'T', body: SizedBox()),
        ),
      ],
    );
    return ProviderScope(
      overrides: [themeModeStoreProvider.overrideWithValue(store)],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ref.watch(themeModeProvider),
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('theme-toggle flips the console between the dark and light planes '
      'and persists the choice', (tester) async {
    final store = FakeThemeModeStore();
    await tester.pumpWidget(managerApp(store));
    await tester.pumpAndSettle();

    Color? plane() =>
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor;

    expect(plane(), TiqColors.dark.plane);
    expect(find.byTooltip('Switch to light theme'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    expect(plane(), TiqColors.light.plane);
    expect(store.stored, ThemeMode.light); // persisted
    expect(find.byTooltip('Switch to dark theme'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    expect(plane(), TiqColors.dark.plane);
    expect(store.stored, ThemeMode.dark);
  });

  testWidgets('a persisted light mode restores on startup', (tester) async {
    await tester.pumpWidget(managerApp(FakeThemeModeStore(ThemeMode.light)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      TiqColors.light.plane,
    );
  });
```

- [ ] **Step 2: Run — expect FAIL** (no `theme-toggle` key exists; the scaffold background is the static `AppColors.plane` so the flip assertion also fails)

```bash
cd app && flutter test test/core/theme/theme_switching_test.dart
```

- [ ] **Step 3: Migrate `manager_scaffold.dart` and add the toggle**

In `app/lib/core/widgets/manager_scaffold.dart`:

Replace the theme import and add the two theme imports:

```dart
import '../theme/theme_mode_controller.dart';
import '../theme/tiq_colors.dart';
```

(remove `import '../theme/app_colors.dart';` — this file uses no radii).

In `ManagerScaffold.build`, after `void logout() ...`, add:

```dart
    final colors = context.colors;
    final mode = ref.watch(themeModeProvider);
```

then apply these exact swaps in the same method:
- `backgroundColor: AppColors.plane,` → `backgroundColor: colors.plane,`
- `backgroundColor: AppColors.surface1,` (the Drawer) → `backgroundColor: colors.surface1,`
- `const VerticalDivider(width: 1, color: AppColors.line),` → `VerticalDivider(width: 1, color: colors.line),`

In the AppBar `actions:` list, insert the toggle button **before** the logout `IconButton`:

```dart
        actions: [
          ...?actions,
          IconButton(
            key: const ValueKey('theme-toggle'),
            icon: Icon(
              mode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 18,
            ),
            tooltip: mode == ThemeMode.dark
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            tooltip: 'Log out',
            onPressed: logout,
          ),
          const SizedBox(width: 4),
        ],
```

In `_NavRail.build`, add `final colors = context.colors;` as the first line, then:
- `color: AppColors.surface1,` (the Container) → `color: colors.surface1,`
- `const Divider(height: 17, indent: 16, endIndent: 16, color: AppColors.line)` → `Divider(height: 17, indent: 16, endIndent: 16, color: colors.line)` (drop the `const`)
- in the heading `TextStyle`: `color: AppColors.ink3,` → `color: colors.ink3,` (drop the `const` on that `TextStyle`, keep the `const` on the `EdgeInsets`)
- `const Divider(height: 1, color: AppColors.line),` → `Divider(height: 1, color: colors.line),`

In `_NavRow.build`, add `final colors = context.colors;` first, then:
- `color: selected ? AppColors.surface2 : null,` → `color: selected ? colors.surface2 : null,`
- `color: selected ? AppColors.brand : Colors.transparent,` → `color: selected ? colors.brand : Colors.transparent,`
- `color: selected ? AppColors.series1 : AppColors.ink3,` → `color: selected ? colors.series1 : colors.ink3,`
- `color: selected ? AppColors.ink1 : AppColors.ink2,` → `color: selected ? colors.ink1 : colors.ink2,`

In `_RailFoot.build`, add `final colors = context.colors;` first, then:
- `color: AppColors.surface3,` → `color: colors.surface3,`
- `border: Border.all(color: AppColors.lineStrong),` → `border: Border.all(color: colors.lineStrong),`
- `color: AppColors.ink2,` (avatar icon) → `color: colors.ink2,`
- `color: AppColors.ink1,` (role text — drop the `const` on its `TextStyle`) → `color: colors.ink1,`
- `color: AppColors.ink3,` (logout IconButton) → `color: colors.ink3,`

- [ ] **Step 4: Run the switching tests + the full suite**

```bash
cd app && flutter test test/core/theme/theme_switching_test.dart && flutter test
```

Expected: all green — including the untouched `manager_scaffold_test.dart` (its nav-key/label assertions are color-free, and dark values are unchanged).

- [ ] **Step 5: Analyze, guard-grep, commit**

```bash
cd app && flutter analyze
grep -c "AppColors\." lib/core/widgets/manager_scaffold.dart
```

Expected: `flutter analyze` clean; the grep prints `0`.

```bash
git add app/lib/core/widgets/manager_scaffold.dart app/test/core/theme/theme_switching_test.dart
git commit -m "feat(app): theme toggle in the console top bar; ManagerScaffold reads context.colors

Sun/moon IconButton keyed theme-toggle flips and persists the mode via
themeModeProvider. The shell (scaffold, rail, drawer) is the first
migrated surface, so the toggle is observable end to end: widget tests
cover flip, persistence, and restore."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 8: Migrate `console.dart` + `worklist.dart`

**Files:**
- Modify: `app/lib/core/widgets/console.dart`
- Modify: `app/lib/core/widgets/worklist.dart`
- Test: existing `app/test/core/widgets/console_test.dart` must stay green **unmodified**

- [ ] **Step 1: `console.dart` — StatusLevel gets a theme-aware lookup**

Add `import '../theme/tiq_colors.dart';` (keep the `app_colors.dart` import — the old getter and `radiusPanel` still need it). Replace the `StatusLevelColor` extension with:

```dart
extension StatusLevelColor on StatusLevel {
  /// Dark-constant lookup. Kept for the agent-pinned flow and for tests that
  /// assert the reserved dark hues directly; theme-following widgets use
  /// [colorOf].
  Color get color => switch (this) {
        StatusLevel.critical => AppColors.crit,
        StatusLevel.warning => AppColors.warn,
        StatusLevel.good => AppColors.good,
        StatusLevel.neutral => AppColors.ink3,
      };

  /// Theme-aware lookup — resolves against the ambient [TiqColors].
  Color colorOf(TiqColors c) => switch (this) {
        StatusLevel.critical => c.crit,
        StatusLevel.warning => c.warn,
        StatusLevel.good => c.good,
        StatusLevel.neutral => c.ink3,
      };
}
```

- [ ] **Step 2: `console.dart` — migrate every widget build**

In each build method, first line `final colors = context.colors;`, then swap (dropping `const` only on the constructor invocation that contains the migrated color — keep inner `const` on color-free `EdgeInsets`/`SizedBox` arguments so the linter stays quiet):

- `SectionLabel`: `color: color ?? AppColors.ink3` → `color: color ?? colors.ink3`
- `PanelCard` head: `border: Border(bottom: BorderSide(color: AppColors.line))` → `...colors.line...`; title `color: AppColors.ink1` → `colors.ink1`; subtitle `color: AppColors.ink3` → `colors.ink3`; body `DecoratedBox`: `color: AppColors.surface1` → `colors.surface1`, `Border.all(color: AppColors.line)` → `colors.line` (`BorderRadius.circular(AppColors.radiusPanel)` stays — geometry).
- `DeltaText`: `(glyph, color)` switch → `('▲', colors.good)`, `('▼', colors.crit)`, `('–', colors.ink3)`.
- `StatusChip`: `final color = level.color;` → `final color = level.colorOf(context.colors);`
- `StatTile`: label `AppColors.ink2` → `colors.ink2`; value `AppColors.ink1` → `colors.ink1`; note `AppColors.ink3` → `colors.ink3`.
- `AttentionRow`: border `AppColors.line` → `colors.line`; count `level.color` → `level.colorOf(colors)`; title `AppColors.ink1` → `colors.ink1`; meta `AppColors.ink3` → `colors.ink3`; chevron `AppColors.ink3` → `colors.ink3`.

- [ ] **Step 3: `worklist.dart` — same treatment**

Add `import '../theme/tiq_colors.dart';` (keep `app_colors.dart` only if a radius remains — `FilterRow` uses `AppColors.radiusPanel`, so it stays). Swaps, each build getting `final colors = context.colors;` first:

- `AsyncSection` error text: `AppColors.ink2` → `colors.ink2`.
- `EmptyState`: `AppColors.ink2` → `colors.ink2`, `AppColors.ink3` → `colors.ink3`.
- `TriageStrip` count: `c.count == 0 ? AppColors.ink3 : c.level.color` → `c.count == 0 ? colors.ink3 : c.level.colorOf(colors)`; cell right border `AppColors.line` → `colors.line`.
- `WorklistRow`: bottom border `AppColors.line` → `colors.line`; edge bar `resolved ? AppColors.lineStrong : level.color` → `resolved ? colors.lineStrong : level.colorOf(colors)`; title `AppColors.ink1` → `colors.ink1`; meta `AppColors.ink3` → `colors.ink3`; when `AppColors.ink3` → `colors.ink3`.
- `CodeToken`: `AppColors.surface2` → `colors.surface2`, `AppColors.line` → `colors.line`, `AppColors.ink3` → `colors.ink3`.
- `RowAction`: `tone == StatusLevel.neutral ? AppColors.ink1 : tone.color` → `tone == StatusLevel.neutral ? colors.ink1 : tone.colorOf(colors)`.
- `FilterRow`: `AppColors.surface1` → `colors.surface1`, `Border.all(color: AppColors.line)` → `colors.line` (`AppColors.radiusPanel` stays).

- [ ] **Step 4: Full suite + guard**

```bash
cd app && flutter analyze && flutter test
grep -n "AppColors\." lib/core/widgets/console.dart lib/core/widgets/worklist.dart | grep -v "radius" | grep -v "Color get color"
```

Expected: analyze clean, all tests green (`console_test.dart` untouched — `StatusLevel.color` still exists and unthemed pumps fall back to dark). The guard grep prints only the four `AppColors.` lines inside the kept dark-constant `color` getter (crit/warn/good/ink3) — nothing else.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/widgets/console.dart app/lib/core/widgets/worklist.dart
git commit -m "refactor(app): console + worklist read context.colors

StatusLevel gains colorOf(TiqColors) for theme-following widgets; the
context-free .color getter stays as the dark-constant lookup for the
agent-pinned flow and existing assertions. Dark renders byte-identical."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 9: Migrate `charts.dart` (painters take the scheme)

CustomPainters have no BuildContext, so each painter gains a `final TiqColors colors;` field, passed from the widget's build — this is what makes charts follow the toggle with no logic changes.

**Files:**
- Modify: `app/lib/core/widgets/charts.dart`
- Test: existing `app/test/core/widgets/charts_test.dart` must stay green **unmodified**

- [ ] **Step 1: Label style + `_text` threading**

Add `import '../theme/tiq_colors.dart';`. Replace:

```dart
const _labelStyle = TextStyle(fontSize: 10, color: AppColors.ink3);

TextPainter _text(String s, {TextStyle style = _labelStyle}) {
```

with:

```dart
TextStyle _labelStyle(TiqColors c) => TextStyle(fontSize: 10, color: c.ink3);

TextPainter _text(String s, {required TextStyle style}) {
```

Every `_text(x)` call that relied on the default becomes `_text(x, style: _labelStyle(colors))` (they are all inside painters, where `colors` is the new field — next step).

- [ ] **Step 2: Thread `colors` through the four painters**

For `_LinePainter`, `_ColumnPainter`, `_BarPainter`, `_SparkPainter`: add `required this.colors,` to the constructor (positional `_SparkPainter(this.values)` becomes `_SparkPainter(this.values, this.colors)`), add the field `final TiqColors colors;`, and add `|| old.colors != colors` to each `shouldRepaint` (so the theme's lerp animation repaints). At each construction site pass the ambient scheme:

- `_LineChartState.build`: `painter: _LinePainter(..., colors: context.colors)` — capture `final colors = context.colors;` at the top of `build` and pass it.
- `_ColumnChartState.build`: same, `colors: context.colors`.
- `BarChart.build`: `painter: _BarPainter(..., colors: context.colors)`.
- `Sparkline.build`: `painter: _SparkPainter(values, context.colors)`.

- [ ] **Step 3: Swap the paint-time colors**

Inside the painters, replace every data/chrome color with the field (`AppColors.` → `colors.`): `grid` (hairlines and the bar track), `axis` (baseline, crosshair), `ink3` (target-rule dash paint), `ink2` (endpoint label, bar name/value labels — these use explicit `TextStyle(...)`: change `color: AppColors.ink2` to `color: colors.ink2` and drop that `const`), `series1` (line, area fill `.withValues(alpha: 0.14)`, columns, bars, sparkline, markers), `crit` (below-target bars), `surface1` (the marker punch-out rings — must match the panel, white in light).

In the widgets: `_EmptyPlot` message `AppColors.ink3` → `context.colors.ink3` (via `final colors = context.colors;` in its build); `DeltaBadge` `AppColors.good`/`AppColors.crit` → `context.colors.good`/`context.colors.crit`.

**Deliberately NOT migrated (invariant 3):** `_Tooltip` and `_ScrubReadout` keep `Color(0xFF05060A)`, `AppColors.lineStrong`, `AppColors.ink1`, `AppColors.ink3` — the hover readout is a fixed dark instrument surface in both modes, matching the app-wide tooltipTheme. Add this comment above `_Tooltip`:

```dart
/// The readout surface is deliberately the fixed dark instrument panel in both
/// themes (matching tooltipTheme in app_theme.dart) — an inverted readout on a
/// light chart is the premium convention, and it keeps hover legible without a
/// second derivation. Hence AppColors statics, not context.colors.
```

- [ ] **Step 4: `BarChart.legend()` — theme-aware without changing its signature**

`dashboard_shell_screen.dart:467` and `charts_test.dart:80` both call `BarChart.legend()` with no arguments; a `Builder` keeps them compiling untouched:

```dart
  static Widget legend() => Builder(
        builder: (context) {
          final colors = context.colors;
          return Row(
            children: [
              _LegendItem(color: colors.series1, label: 'Meets target'),
              const SizedBox(width: 14),
              _LegendItem(color: colors.crit, label: 'Below target'),
            ],
          );
        },
      );
```

- [ ] **Step 5: Full suite + guard**

```bash
cd app && flutter analyze && flutter test
grep -n "AppColors\." lib/core/widgets/charts.dart
```

Expected: analyze clean, all green (`charts_test.dart` pumps a bare MaterialApp → fallback dark → identical pixels). The guard grep shows ONLY the `_Tooltip`/`_ScrubReadout` readout lines (`lineStrong`, `ink1`, `ink3`, `radiusControl`) — nothing in any painter.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/widgets/charts.dart
git commit -m "refactor(app): charts read TiqColors — painters take the scheme

Each CustomPainter carries the ambient TiqColors (repainting on theme
lerp), so charts follow the toggle with no logic changes and pick up
the validated light series/status palette. Hover readouts deliberately
stay the fixed dark instrument surface in both modes."
```
Blank line, then the Co-Authored-By trailer.

---

## The mechanical screen migration (Tasks 10–12)

The remaining 19 screens are a pure rename. **The recipe, applied per file:**

1. Add `import '<relative>/core/theme/tiq_colors.dart';` next to the existing theme import.
2. In every `build` method (or helper that has a `BuildContext`), add `final colors = context.colors;` as the first line **iff** the method references `AppColors`; then replace each color reference `AppColors.x` → `colors.x`. For a helper with no context in scope (a top-level function or a static returning a styled widget/TextStyle), thread the scheme through as a `TiqColors colors` parameter from its caller's `context.colors` — do NOT reach for a global.
3. `const` removal: dropping a color const infects the enclosing constructor — remove the `const` keyword from the **nearest enclosing constructor invocation only**, keeping inner `const` on color-free arguments (`EdgeInsets`, `SizedBox`, `Duration`) so `prefer_const_constructors` stays quiet. The compiler errors after step 2 point at every site; fix them all before running tests.
4. `AppColors.radiusControl`/`radiusPanel` references stay. If none remain, delete the `app_colors.dart` import; otherwise keep it.
5. Batch gate: `cd app && flutter analyze` (clean), `cd app && flutter test` (all green — these screens' tests pump via `routedApp`, themeless → fallback dark → identical assertions), guard grep (below), commit.

Guard grep per batch (run from `app/`), which must print nothing:

```bash
grep -n "AppColors\." <batch files> | grep -v "radius"
```

### Task 10: Batch 1 — the heavy four

**Files (refs):**
- Modify: `app/lib/features/dashboard/presentation/dashboard_shell_screen.dart` (15)
- Modify: `app/lib/features/trends/presentation/trends_screen.dart` (15)
- Modify: `app/lib/features/collaboration/presentation/messages_screen.dart` (15)
- Modify: `app/lib/features/clients/presentation/client_config_screen.dart` (13)

- [ ] **Step 1: Apply the recipe to `dashboard_shell_screen.dart`** (note: the `BarChart.legend()` call at line 467 needs no change — Task 9 made it theme-aware in place)
- [ ] **Step 2: Apply the recipe to `trends_screen.dart`**
- [ ] **Step 3: Apply the recipe to `messages_screen.dart`**
- [ ] **Step 4: Apply the recipe to `client_config_screen.dart`**
- [ ] **Step 5: Batch gate**

```bash
cd app && flutter analyze && flutter test
grep -n "AppColors\." lib/features/dashboard/presentation/dashboard_shell_screen.dart lib/features/trends/presentation/trends_screen.dart lib/features/collaboration/presentation/messages_screen.dart lib/features/clients/presentation/client_config_screen.dart | grep -v "radius"
```

Expected: analyze clean, all tests green, guard grep silent.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/dashboard app/lib/features/trends app/lib/features/collaboration app/lib/features/clients
git commit -m "refactor(app): dashboard/trends/messages/client-config read context.colors

Mechanical AppColors.x -> colors.x; dark values unchanged, tests
untouched and green."
```
Blank line, then the Co-Authored-By trailer.

### Task 11: Batch 2 — worklist screens

**Files (refs):**
- Modify: `app/lib/features/tasks/presentation/tasks_screen.dart` (12)
- Modify: `app/lib/features/alerts/presentation/alerts_screen.dart` (9)
- Modify: `app/lib/features/alerts/presentation/alert_rules_screen.dart` (3 — incl. a `dropdownColor: AppColors.surface2` → `colors.surface2`)
- Modify: `app/lib/features/dispatch/presentation/dispatch_screen.dart` (3 — same `dropdownColor` pattern)
- Modify: `app/lib/features/beatplans/presentation/beatplans_screen.dart` (3 — note its second, non-Manager `Scaffold` at line 132 with `backgroundColor: AppColors.plane` → `colors.plane`; it is a manager-side detail view, it follows the toggle)

- [ ] **Step 1: Apply the recipe to all five files**
- [ ] **Step 2: Batch gate**

```bash
cd app && flutter analyze && flutter test
grep -n "AppColors\." lib/features/tasks/presentation/tasks_screen.dart lib/features/alerts/presentation/alerts_screen.dart lib/features/alerts/presentation/alert_rules_screen.dart lib/features/dispatch/presentation/dispatch_screen.dart lib/features/beatplans/presentation/beatplans_screen.dart | grep -v "radius"
```

Expected: analyze clean, all green, guard grep silent.

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/tasks app/lib/features/alerts app/lib/features/dispatch app/lib/features/beatplans/presentation/beatplans_screen.dart
git commit -m "refactor(app): tasks/alerts/alert-rules/dispatch/beatplans read context.colors"
```
Blank line, then the Co-Authored-By trailer.

### Task 12: Batch 3 — the ten light-touch screens

**Files (refs):**
- Modify: `app/lib/features/orders/presentation/orders_screen.dart` (2)
- Modify: `app/lib/features/fraud/presentation/fraud_screen.dart` (2)
- Modify: `app/lib/features/campaigns/presentation/campaigns_screen.dart` (1)
- Modify: `app/lib/features/gamification/presentation/leaderboard_screen.dart` (1)
- Modify: `app/lib/features/incentives/presentation/incentives_screen.dart` (1)
- Modify: `app/lib/features/outlets/presentation/outlets_list_screen.dart` (1)
- Modify: `app/lib/features/templates/presentation/templates_screen.dart` (1)
- Modify: `app/lib/features/territories/presentation/territories_screen.dart` (1)
- Modify: `app/lib/features/users/presentation/users_screen.dart` (1)
- Modify: `app/lib/features/webhooks/presentation/webhooks_screen.dart` (1)

- [ ] **Step 1: Apply the recipe to all ten files**
- [ ] **Step 2: Batch gate + repo-wide census**

```bash
cd app && flutter analyze && flutter test
# The migration is now complete: the ONLY files still referencing AppColors
# colors must be the 13 agent-pinned files, app_theme.dart's tooltip block,
# charts.dart's readouts, console.dart's dark getter, and radius-only refs.
grep -rln "AppColors\." lib --include="*.dart"
```

Expected: analyze clean, all green. The file list from the census is exactly: `app_colors.dart`, `app_theme.dart`, `charts.dart`, `console.dart`, `worklist.dart` (radius only), `agent_kit.dart`, `agent_motion.dart`, `agent_scaffold.dart`, `photo_capture_field.dart`, `primary_gradient_button.dart`, the five audit screens, `today_screen.dart`, `login_screen.dart`, `landing_screen.dart` — plus any migrated screen that kept a radius-only import. Anything else is a missed ref: fix before committing.

- [ ] **Step 3: Manual smoke (recommended, 2 min):** `cd app && flutter run -d chrome`, log in as a manager, toggle — the whole console flips to Paper & Ink; navigate to `/outlets` and back; reload the tab — light persists; log in as an agent — `/today` is dark and has no toggle.

- [ ] **Step 4: Commit**

```bash
git add app/lib/features
git commit -m "refactor(app): remaining ten manager screens read context.colors

Migration complete: 23 files / ~193 refs follow the toggle; the 13
agent-pinned files keep their statics under PinnedDark, where statics
and TiqColors.dark are identical by definition."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 13: `design/tokens.css` — the light block

**Files:**
- Modify: `design/tokens.css`

- [ ] **Step 1: Add the new slots to the dark `:root`**

In the `:root` block, after the `--axis` line, add:

```css
  /* Elevation & overlay. Dark: transparent shadow (borders carry elevation)
     and the default black54 scrim — appearance unchanged. */
  --shadow:       transparent;
  --scrim:        rgba(0, 0, 0, 0.54);
```

- [ ] **Step 2: Add the light block**

Immediately after the closing `}` of `:root`, insert:

```css
/* ── Paper & Ink — the light scheme ─────────────────────────────────────
   Mirrors TiqColors.light in app/lib/core/theme/tiq_colors.dart. The dark
   ink #14161c is carried forward as primary text so the two modes read as
   one product. Series/status steps are darkened variants of the same hues,
   asserted ≥3:1 against #ffffff by app/test/core/theme/tiq_colors_test.dart. */
[data-theme='light'] {
  --plane:        #f7f8fa;
  --surface-1:    #ffffff;
  --surface-2:    #f1f3f6;
  --surface-3:    #e8ebf0;

  --line:         #e3e5ea;
  --line-strong:  #d2d6de;

  --ink-1:        #14161c;
  --ink-2:        #4c5560;
  --ink-3:        #6a7280;

  --brand:        #0a6cf0;
  --brand-hover:  #0857c4;
  --brand-quiet:  rgba(32, 105, 201, 0.10);

  --series-1:     #2069c9;
  --series-2:     #177a57;
  --series-3:     #9a6700;
  --series-1-fill: rgba(32, 105, 201, 0.10);

  --good:         #0b7a0b;
  --warn:         #935f00;
  --crit:         #b32e2e;
  --good-quiet:   rgba(11, 122, 11, 0.10);
  --warn-quiet:   rgba(147, 95, 0, 0.10);
  --crit-quiet:   rgba(179, 46, 46, 0.10);

  --grid:         #eceef2;
  --axis:         #d2d6de;

  --shadow:       rgba(16, 24, 40, 0.08);
  --scrim:        rgba(16, 24, 40, 0.60);
}
```

- [ ] **Step 3: Verify the mirror**

Cross-check every hex in the new block against `TiqColors.light` in `app/lib/core/theme/tiq_colors.dart` — they must match slot for slot (case-insensitive). The `design/*.html` mockup pages are explicitly out of scope (spec, Out of scope).

- [ ] **Step 4: Commit**

```bash
git add design/tokens.css
git commit -m "design: tokens.css gains the Paper & Ink light block + shadow/scrim slots

[data-theme=light] mirrors TiqColors.light; the dark :root gains the
two new slots at values that keep dark's appearance unchanged."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 14: Verify the whole plan

- [ ] **Step 1: Full gate**

```bash
cd app && flutter analyze && flutter test
```

Expected: `No issues found!`; all tests green — the baseline count plus the new theme tests (tiq_colors 9, app_theme +3, theme_mode_controller 7, theme_switching 4), with **zero pre-existing test files modified** (`git diff --stat main -- app/test` shows only the four theme test files above).

- [ ] **Step 2: Confirm the dark theme never moved**

```bash
git diff main -- app/lib/core/theme/app_colors.dart
```

Expected: empty — the constant table is untouched. Combined with the literal-hex parity tests and the green pre-existing suite, that is the "dark changes not at all" proof.

- [ ] **Step 3: Build the web target (managers live there)**

```bash
cd app && flutter build web
```

Expected: builds clean. (No build_runner step — nothing in this plan touches drift codegen.)

- [ ] **Step 4: Update the plan doc checkboxes and hand off**

Mark all tasks complete in this document. Plan B (motion & polish) builds on `TiqColors.shadow`/`scrim`, `context.colors`, and the light block landed here.

---

## Self-Review

**Spec coverage (Plan A bullets):**
- `TiqColors` extension, all slots + `shadow`/`scrim`, two const instances, `copyWith`/`lerp` → Task 1.
- Dual `AppTheme` from shared `_base`, extension on both, component themes preserved for dark → Task 3 (literal-hex parity test).
- `context.colors` → Task 1 (with the documented dark fallback; spec amended in Task 1 Step 6).
- Provider + persistence (`tiq.themeMode`, light/dark only, missing/unreadable → dark, no `ThemeMode.system`) → Task 4.
- `MaterialApp.router` wiring → Task 6. Toggle (`theme-toggle` key, sun/moon, tooltip) → Task 7.
- `PinnedDark` in AgentScaffold + login/landing → Task 5.
- Mechanical migration, core first then batched screens, each batch a green checkpoint → Tasks 7–12 (23 files enumerated in the census; 13 agent-pinned files enumerated and left static).
- Light chart palette + ≥3:1 contrast test with full WCAG math → Tasks 1–2; charts read the scheme → Task 9.
- `tokens.css` light block → Task 13.
- Spec Testing section: toggle-flips-plane test (Task 7), agent-stays-dark test (Task 5), toggle-persists-with-fake-storage test (Tasks 4 + 7), contrast unit test (Task 2), full suite green throughout. The reduced-motion/`SharedAxisTransition` test in the spec's Testing list belongs to Plan B.

**Deliberate deviations (all documented in-plan):** the `context.colors` dark fallback (invariant 2, spec amended); tooltips/chart readouts fixed dark in both modes (invariant 3); `StatusLevel.color` retained alongside `colorOf` (invariant 4). Light values not enumerated by the spec (`surface2/3`, `lineStrong`, `ink2`, `brandHover`, `grid`, `axis`, `shadow`, `scrim`) are pinned here and mirrored into tokens.css so the spec's token authority stays intact.

**Ordering:** every task leaves the app compiling and the suite green. Themes exist (3) before wiring (6); wiring before the toggle is reachable (7); the shell migrates with the toggle so the flip is observable; shared widgets (8–9) before the screens that compose them; no file is ever half-migrated (batch gates + guard greps).

**Type consistency:** `TiqColors.dark`/`light` (Task 1) are the values asserted in Tasks 3, 5, 7; `ThemeModeStore`/`themeModeStoreProvider`/`themeModeProvider` (Task 4) are the names used in Tasks 6–7 tests; `colorOf(TiqColors)` (Task 8) is used in worklist call sites (Task 8) only; `PinnedDark` (Task 5) is referenced nowhere else by name. `FakeThemeModeStore` is defined in both test files that need it (tests don't import each other).

**Known accepted quirks (call out in review, do not "fix"):** `/my-work` is deliberately manager-visible but uses `AgentScaffold`, so it stays dark even for a manager in light mode — it is an agent surface per spec. Shared routes `/outlets`, `/orders`, `/beatplans` use `ManagerScaffold`, so a field agent visiting them sees the toggle and a themeable screen while their own `/today`/audit flow stays pinned dark — consistent with "manager console follows the toggle; agent surfaces are pinned".
