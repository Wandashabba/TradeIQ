# Dual Theme System (Plan A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A light "Paper & Ink" theme alongside the existing dark theme, switchable from the manager top bar, persisted across restarts, with the field-agent flow pinned dark.

**Architecture:** A `TiqColors` `ThemeExtension` carries every semantic color slot with `dark` and `light` const instances; both `ThemeData`s are built from one shared `_base(TiqColors)` so component themes can't drift. Feature code migrates mechanically from static `AppColors.x` to `context.colors.x`. A Riverpod `Notifier<ThemeMode>` persists the choice via the existing `flutter_secure_storage` (mirroring `TokenStore`'s testable-store pattern).

**Tech Stack:** Flutter, Riverpod 3, flutter_secure_storage (already present — no new dependencies in this plan).

**Spec:** `docs/superpowers/specs/2026-07-17-premium-ui-theme-motion-design.md`

---

### Task 1: `TiqColors` extension, dual `AppTheme`, `context.colors`, contrast test

**Files:**
- Create: `app/lib/core/theme/tiq_colors.dart`
- Modify: `app/lib/core/theme/app_theme.dart` (full rewrite, same public `AppTheme.dark()` entry point plus new `AppTheme.light()`)
- Test: `app/test/core/theme/tiq_colors_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/core/theme/tiq_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';

/// WCAG relative luminance.
double _luminance(Color c) => c.computeLuminance();

/// WCAG contrast ratio between two colors.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const white = Color(0xFFFFFFFF);

  test('light series and status colors hold >=3:1 on white panels', () {
    const c = TiqColors.light;
    for (final (name, color) in [
      ('series1', c.series1),
      ('series2', c.series2),
      ('series3', c.series3),
      ('good', c.good),
      ('warn', c.warn),
      ('crit', c.crit),
    ]) {
      expect(_contrast(color, white), greaterThanOrEqualTo(3.0),
          reason: '$name fails 3:1 against white');
    }
  });

  test('light ink holds >=4.5:1 on plane and panel', () {
    const c = TiqColors.light;
    expect(_contrast(c.ink1, c.plane), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.ink1, c.surface1), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.ink2, c.surface1), greaterThanOrEqualTo(4.5));
  });

  test('dark values are unchanged from the historical palette', () {
    const c = TiqColors.dark;
    expect(c.plane, const Color(0xFF0B0C10));
    expect(c.surface1, const Color(0xFF14161C));
    expect(c.ink1, const Color(0xFFE9EBEE));
    expect(c.brand, const Color(0xFF0A6CF0));
    expect(c.series1, const Color(0xFF3987E5));
    expect(c.good, const Color(0xFF0CA30C));
  });

  test('both themes register the TiqColors extension and correct brightness', () {
    expect(AppTheme.dark().extension<TiqColors>(), same(TiqColors.dark));
    expect(AppTheme.light().extension<TiqColors>(), same(TiqColors.light));
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(AppTheme.light().brightness, Brightness.light);
  });

  testWidgets('context.colors resolves the active theme extension',
      (tester) async {
    late TiqColors seen;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(builder: (context) {
        seen = context.colors;
        return const SizedBox();
      }),
    ));
    expect(seen, same(TiqColors.light));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/theme/tiq_colors_test.dart`
Expected: FAIL — `tiq_colors.dart` does not exist (import error).

- [ ] **Step 3: Create `app/lib/core/theme/tiq_colors.dart`**

```dart
import 'package:flutter/material.dart';

/// The TradeIQ color scheme as a theme extension — one instance per mode, so
/// every slot flips with the toggle. Slot semantics (and the dark values) are
/// identical to the static [AppColors] table; light is the "Paper & Ink"
/// direction: white panels on a cool paper ground, with the dark theme's ink
/// carried over as the text color so both modes read as one product.
///
/// Slot discipline is unchanged from the dark palette: status colors are
/// reserved (never used as series colors), and meaning never rides on color
/// alone. The light series/status values are contrast-locked >=3:1 against
/// white by test/core/theme/tiq_colors_test.dart.
@immutable
class TiqColors extends ThemeExtension<TiqColors> {
  const TiqColors({
    required this.brightness,
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

  final Brightness brightness;

  // Planes & surfaces.
  final Color plane;
  final Color surface1;
  final Color surface2;
  final Color surface3;

  // Hairlines.
  final Color line;
  final Color lineStrong;

  // Ink.
  final Color ink1;
  final Color ink2;
  final Color ink3;

  // Brand.
  final Color brand;
  final Color brandHover;

  // Data series — fixed slots, never cycled.
  final Color series1;
  final Color series2;
  final Color series3;

  // Status — reserved.
  final Color good;
  final Color warn;
  final Color crit;

  // Chart chrome.
  final Color grid;
  final Color axis;

  /// Panel drop shadow. Transparent in dark mode — borders do that job there.
  final Color shadow;

  /// Drawer/backdrop scrim (alpha baked in).
  final Color scrim;

  /// Today's palette, exactly — mirrors the static AppColors table.
  static const dark = TiqColors(
    brightness: Brightness.dark,
    plane: Color(0xFF0B0C10),
    surface1: Color(0xFF14161C),
    surface2: Color(0xFF1A1D25),
    surface3: Color(0xFF21252E),
    line: Color(0xFF23262F),
    lineStrong: Color(0xFF2F333E),
    ink1: Color(0xFFE9EBEE),
    ink2: Color(0xFF99A1AD),
    ink3: Color(0xFF6A7280),
    brand: Color(0xFF0A6CF0),
    brandHover: Color(0xFF1F7CF5),
    series1: Color(0xFF3987E5),
    series2: Color(0xFF199E70),
    series3: Color(0xFFC98500),
    good: Color(0xFF0CA30C),
    warn: Color(0xFFFAB219),
    crit: Color(0xFFD03B3B),
    grid: Color(0xFF22252D),
    axis: Color(0xFF2F333E),
    shadow: Color(0x00000000),
    scrim: Color(0x99000000),
  );

  /// Paper & Ink. Same geometry, same brand blue, the dark theme's ink as text.
  static const light = TiqColors(
    brightness: Brightness.light,
    plane: Color(0xFFF7F8FA),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F2F5),
    surface3: Color(0xFFE8EAEF),
    line: Color(0xFFE3E5EA),
    lineStrong: Color(0xFFD2D6DE),
    ink1: Color(0xFF14161C),
    ink2: Color(0xFF4C5361),
    ink3: Color(0xFF8A909C),
    brand: Color(0xFF0A6CF0),
    brandHover: Color(0xFF0857C4), // darken on hover in light, not lighten
    series1: Color(0xFF2069C9),
    series2: Color(0xFF177A57),
    series3: Color(0xFF9A6700),
    good: Color(0xFF0B7A0B),
    warn: Color(0xFF935F00),
    crit: Color(0xFFB32E2E),
    grid: Color(0xFFE9EBF0),
    axis: Color(0xFFD2D6DE),
    shadow: Color(0xFF14161C), // applied at low opacity by the shadow tokens
    scrim: Color(0x8014161C),
  );

  @override
  TiqColors copyWith() => this; // slots only ever swap wholesale by mode

  @override
  TiqColors lerp(TiqColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// `context.colors.ink1` — the migration target for every `AppColors.x` read
/// in theme-following (manager/shared) code.
extension TiqColorsContext on BuildContext {
  TiqColors get colors => Theme.of(this).extension<TiqColors>()!;
}
```

- [ ] **Step 4: Rewrite `app/lib/core/theme/app_theme.dart`**

Replace the whole file. `dark()` keeps its exact current visual output; both modes are produced by one `_base(TiqColors)`:

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'tiq_colors.dart';

/// The TradeIQ themes — one `_base` parameterized by [TiqColors], so light and
/// dark cannot drift component-by-component.
///
/// Geometry is squared off — controls are 3px, panels 4px, and nothing is a
/// stadium/pill. One type family throughout (Inter). Mirrors `design/tokens.css`.
class AppTheme {
  AppTheme._();

  static const _control = BorderRadius.all(
    Radius.circular(AppColors.radiusControl),
  );
  static const _panel = BorderRadius.all(
    Radius.circular(AppColors.radiusPanel),
  );

  static final ThemeData _dark = _base(TiqColors.dark);
  static final ThemeData _light = _base(TiqColors.light);

  static ThemeData dark() => _dark;
  static ThemeData light() => _light;

  static ThemeData _base(TiqColors c) {
    final isDark = c.brightness == Brightness.dark;
    final fieldBorder = OutlineInputBorder(
      borderRadius: _control,
      borderSide: BorderSide(color: c.lineStrong),
    );

    return ThemeData(
      brightness: c.brightness,
      extensions: [c],
      scaffoldBackgroundColor: c.plane,
      canvasColor: c.surface1,
      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: c.brand,
        onPrimary: Colors.white,
        secondary: c.series1,
        onSecondary: Colors.white,
        surface: c.surface1,
        onSurface: c.ink1,
        error: c.crit,
        onError: Colors.white,
        outline: c.lineStrong,
      ),
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
      // Inverted tooltip: readable on any surface, in both modes.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF05060A) : c.ink1,
          border: Border.fromBorderSide(BorderSide(color: c.lineStrong)),
          borderRadius: _control,
        ),
        textStyle: TextStyle(
          color: isDark ? c.ink1 : Colors.white,
          fontSize: 11.5,
        ),
      ),
      drawerTheme: DrawerThemeData(scrimColor: c.scrim),
      useMaterial3: true,
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/theme/tiq_colors_test.dart`
Expected: PASS (5/5).

Then confirm nothing else moved: `cd app && flutter analyze && flutter test`
Expected: analyze clean; full suite passes — `dark()`'s output is visually identical (same values through `_base`), so no existing assertion should move.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/theme/tiq_colors.dart app/lib/core/theme/app_theme.dart app/test/core/theme/tiq_colors_test.dart
git commit -m "feat(app): TiqColors theme extension + dual light/dark AppTheme"
```

---

### Task 2: Theme-mode controller, toggle, wiring, agent dark-pinning

**Files:**
- Create: `app/lib/core/theme/theme_mode_controller.dart`
- Create: `app/lib/core/theme/pinned_dark.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/core/widgets/manager_scaffold.dart` (toggle button in the AppBar `actions`)
- Modify: `app/lib/core/widgets/agent_scaffold.dart` (wrap in `PinnedDark`)
- Modify: `app/lib/features/auth/presentation/login_screen.dart`, `app/lib/features/auth/presentation/landing_screen.dart` (wrap their `Scaffold`s in `PinnedDark`)
- Test: `app/test/core/theme/theme_mode_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/core/theme/theme_mode_controller_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/theme_mode_controller.dart';

class _MemoryStore implements ThemeModeStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String mode) async => value = mode;
}

void main() {
  test('defaults to dark when nothing is stored', () async {
    final container = ProviderContainer(overrides: [
      themeModeStoreProvider.overrideWithValue(_MemoryStore()),
    ]);
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('toggle flips to light and persists', () async {
    final store = _MemoryStore();
    final container = ProviderContainer(overrides: [
      themeModeStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).toggle();
    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(store.value, 'light');

    await container.read(themeModeProvider.notifier).toggle();
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(store.value, 'dark');
  });

  test('restores a stored light preference', () async {
    final store = _MemoryStore()..value = 'light';
    final container = ProviderContainer(overrides: [
      themeModeStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).restore();
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('an unreadable store still yields dark', () async {
    final container = ProviderContainer(overrides: [
      themeModeStoreProvider.overrideWithValue(_ThrowingStore()),
    ]);
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).restore();
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });
}

class _ThrowingStore implements ThemeModeStore {
  @override
  Future<String?> read() async => throw Exception('keychain unavailable');
  @override
  Future<void> write(String mode) async => throw Exception('keychain unavailable');
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/theme/theme_mode_controller_test.dart`
Expected: FAIL — `theme_mode_controller.dart` does not exist.

- [ ] **Step 3: Create `app/lib/core/theme/theme_mode_controller.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the theme choice across restarts. Abstracted so the controller can
/// be unit-tested with an in-memory fake — same shape as auth's TokenStore.
abstract class ThemeModeStore {
  Future<String?> read();
  Future<void> write(String mode);
}

class SecureThemeModeStore implements ThemeModeStore {
  SecureThemeModeStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'tiq.themeMode';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String mode) => _storage.write(key: _key, value: mode);
}

final themeModeStoreProvider =
    Provider<ThemeModeStore>((ref) => SecureThemeModeStore());

/// Light/dark only — no `system` (managers on desktop web; two explicit modes
/// are clearer than three). Default and every failure path: dark, the app's
/// historical appearance. Persistence is best-effort: a failed write keeps the
/// in-memory choice for this session and stays silent.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    restore();
    return ThemeMode.dark;
  }

  Future<void> restore() async {
    try {
      final stored = await ref.read(themeModeStoreProvider).read();
      if (stored == 'light') state = ThemeMode.light;
    } catch (_) {
      // Unreadable storage -> keep dark.
    }
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      await ref
          .read(themeModeStoreProvider)
          .write(state == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {
      // Best-effort persistence.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/theme/theme_mode_controller_test.dart`
Expected: PASS (4/4).

- [ ] **Step 5: Create `app/lib/core/theme/pinned_dark.dart`**

```dart
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Pins a subtree to the dark theme regardless of the app-level ThemeMode.
///
/// The field-agent flow (and the pre-auth screens) ship dark-only in this
/// pass: their screens still read the static AppColors table, which is the
/// dark palette by definition — letting the ambient theme go light underneath
/// them would tear surfaces apart. Agent light mode is a separate ticket.
class PinnedDark extends StatelessWidget {
  const PinnedDark({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: AppTheme.dark(), child: child);
}
```

- [ ] **Step 6: Wire `main.dart`, `AgentScaffold`, login/landing, and the manager toggle**

`app/lib/main.dart` — replace the build:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';

void main() {
  runApp(const ProviderScope(child: TradeIqApp()));
}

class TradeIqApp extends ConsumerWidget {
  const TradeIqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TradeIQ',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
```

`app/lib/core/widgets/agent_scaffold.dart` — add the import and wrap the existing `Scaffold` (do not otherwise change it):

```dart
import '../theme/pinned_dark.dart';
// ...
    return PinnedDark(
      child: Scaffold(
        // ... existing Scaffold exactly as-is ...
      ),
    );
```

`login_screen.dart` and `landing_screen.dart` — same one-line treatment: import `../../../core/theme/pinned_dark.dart` and wrap each screen's top-level `Scaffold` in `PinnedDark(child: ...)`.

`app/lib/core/widgets/manager_scaffold.dart` — add the theme toggle to the AppBar `actions`, before the logout button. Add imports for `theme_mode_controller.dart`:

```dart
import '../theme/theme_mode_controller.dart';
// ... inside AppBar actions, before the logout IconButton:
          IconButton(
            key: const ValueKey('theme-toggle'),
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 18,
            ),
            tooltip: ref.watch(themeModeProvider) == ThemeMode.dark
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: () =>
                ref.read(themeModeProvider.notifier).toggle(),
          ),
```

- [ ] **Step 7: Add the integration-level widget tests**

Append to `app/test/core/theme/theme_mode_controller_test.dart`:

```dart
// (add these imports at the top of the file)
// import 'package:tradeiq_app/core/theme/app_theme.dart';
// import 'package:tradeiq_app/core/theme/pinned_dark.dart';
// import 'package:tradeiq_app/core/theme/tiq_colors.dart';

  testWidgets('themeMode flips the active scaffold palette', (tester) async {
    final container = ProviderContainer(overrides: [
      themeModeStoreProvider.overrideWithValue(_MemoryStore()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(builder: (context, ref, _) {
        return MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ref.watch(themeModeProvider),
          home: const Scaffold(body: SizedBox()),
        );
      }),
    ));

    Color bg() => Theme.of(tester.element(find.byType(Scaffold)))
        .scaffoldBackgroundColor;

    expect(bg(), TiqColors.dark.plane);
    await container.read(themeModeProvider.notifier).toggle();
    await tester.pumpAndSettle();
    expect(bg(), TiqColors.light.plane);
  });

  testWidgets('PinnedDark keeps its subtree dark under a light ambient theme',
      (tester) async {
    late TiqColors seen;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: PinnedDark(
        child: Builder(builder: (context) {
          seen = context.colors;
          return const SizedBox();
        }),
      ),
    ));
    expect(seen, same(TiqColors.dark));
  });
```

- [ ] **Step 8: Run the tests and the full suite**

Run: `cd app && flutter test test/core/theme/ && flutter analyze && flutter test`
Expected: theme tests all pass; analyze clean; full suite green (the app still *defaults* dark, so no existing screen test changes).

- [ ] **Step 9: Commit**

```bash
git add app/lib/core/theme/theme_mode_controller.dart app/lib/core/theme/pinned_dark.dart app/lib/main.dart app/lib/core/widgets/manager_scaffold.dart app/lib/core/widgets/agent_scaffold.dart app/lib/features/auth/presentation/login_screen.dart app/lib/features/auth/presentation/landing_screen.dart app/test/core/theme/theme_mode_controller_test.dart
git commit -m "feat(app): theme toggle with persistence; agent flow pinned dark"
```

---

### Task 3: Migrate core manager widgets to `context.colors`

**Files:**
- Modify: `app/lib/core/widgets/worklist.dart` (17 refs)
- Modify: `app/lib/core/widgets/console.dart` (21 refs)
- Modify: `app/lib/core/widgets/manager_scaffold.dart` (16 refs)
- Modify: `app/lib/core/widgets/charts.dart` (39 refs)

This is a mechanical migration with three precise rules. **No behavior change in dark mode is permitted** — `context.colors.x` under the dark theme resolves to the exact same value `AppColors.x` had.

**Rule 1 — plain widget code with a BuildContext in scope:**
`AppColors.x` → `context.colors.x`. Add `import '../theme/tiq_colors.dart';` (adjust relative path per file). Any `const` widget constructor that now takes a runtime color loses its `const` keyword (and only that keyword — do not restructure). Example:

```dart
// before
const Text('x', style: TextStyle(color: AppColors.ink2))
// after
Text('x', style: TextStyle(color: context.colors.ink2))
```

**Rule 2 — static/const tables and default parameter values** (e.g. a `StatusLevel.color` mapping, default colors in constructors): convert the lookup into a method that takes the scheme, resolved at the use site. Example shape:

```dart
// before
enum StatusLevel { good, warning, critical, neutral }
extension on StatusLevel { Color get color => switch (this) { ... AppColors.good ... }; }
// after
extension on StatusLevel {
  Color colorOf(TiqColors c) => switch (this) {
    StatusLevel.good => c.good,
    StatusLevel.warning => c.warn,
    StatusLevel.critical => c.crit,
    StatusLevel.neutral => c.ink3,
  };
}
// use sites: level.color -> level.colorOf(context.colors)
```

(The real names in `console.dart`/`worklist.dart` may differ — apply the same shape to whatever static color lookups exist there. Keep old member names when possible by turning `Color get color` into `Color colorOf(TiqColors c)` and fixing every call site in the same commit.)

**Rule 3 — `CustomPainter`s and other context-free classes (`charts.dart`):** painters must not reach for statics. Pass the scheme (or the specific colors) in via the constructor from the widget's `build`:

```dart
// before
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.grid;
// after
class _GridPainter extends CustomPainter {
  _GridPainter({required this.colors});
  final TiqColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colors.grid;
// build site: CustomPaint(painter: _GridPainter(colors: context.colors))
```

When a painter gains a field, also update its `shouldRepaint` to compare it (`oldDelegate.colors != colors`) so a theme flip repaints.

- [ ] **Step 1: Migrate `worklist.dart`** (Rules 1+2)
- [ ] **Step 2: Migrate `console.dart`** (Rules 1+2 — this holds `StatusChip`/`StatusLevel`-style lookups)
- [ ] **Step 3: Migrate `manager_scaffold.dart`** (Rule 1; the toggle from Task 2 is already there)
- [ ] **Step 4: Migrate `charts.dart`** (Rules 1+3)
- [ ] **Step 5: Verify zero statics remain in these files**

Run: `cd app && grep -c "AppColors\." lib/core/widgets/worklist.dart lib/core/widgets/console.dart lib/core/widgets/manager_scaffold.dart lib/core/widgets/charts.dart`
Expected: `0` for every file (grep exits non-zero on zero matches — that's the pass condition).

- [ ] **Step 6: Run the full suite**

Run: `cd app && flutter analyze && flutter test`
Expected: clean and green. Existing tests run under the default dark theme, where every migrated value is identical — a failure here means a migration typo, not a needed test change. Do not "fix" a test to make this pass; fix the migration.

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/widgets/worklist.dart app/lib/core/widgets/console.dart app/lib/core/widgets/manager_scaffold.dart app/lib/core/widgets/charts.dart
git commit -m "refactor(app): core manager widgets read TiqColors, not statics"
```

---

### Task 4: Migrate manager/shared feature screens to `context.colors`

**Files (the complete list — every manager/shared screen with `AppColors` refs; counts as of planning):**
- `app/lib/features/trends/presentation/trends_screen.dart` (15)
- `app/lib/features/dashboard/presentation/dashboard_shell_screen.dart` (15)
- `app/lib/features/collaboration/presentation/messages_screen.dart` (15)
- `app/lib/features/clients/presentation/client_config_screen.dart` (13)
- `app/lib/features/tasks/presentation/tasks_screen.dart` (12)
- `app/lib/features/audit/presentation/my_work_screen.dart` (12 — shared route, managers reach it)
- `app/lib/features/alerts/presentation/alerts_screen.dart` (9)
- `app/lib/features/dispatch/presentation/dispatch_screen.dart` (3)
- `app/lib/features/beatplans/presentation/beatplans_screen.dart` (3)
- `app/lib/features/alerts/presentation/alert_rules_screen.dart` (3)
- `app/lib/features/orders/presentation/orders_screen.dart` (2)
- `app/lib/features/fraud/presentation/fraud_screen.dart` (2)
- `app/lib/features/webhooks/presentation/webhooks_screen.dart` (1)
- `app/lib/features/users/presentation/users_screen.dart` (1)
- `app/lib/features/territories/presentation/territories_screen.dart` (1)
- `app/lib/features/templates/presentation/templates_screen.dart` (1)
- `app/lib/features/outlets/presentation/outlets_list_screen.dart` (1 — shared route)
- `app/lib/features/incentives/presentation/incentives_screen.dart` (1)
- `app/lib/features/gamification/presentation/leaderboard_screen.dart` (1)
- `app/lib/features/campaigns/presentation/campaigns_screen.dart` (1)

**Not migrated (agent-pinned-dark, keep statics):** `agent_kit.dart`, `agent_motion.dart`, `agent_scaffold.dart`, `photo_capture_field.dart`, `primary_gradient_button.dart`, `audit_shell_screen.dart`, `visit_outcome_screen.dart`, `submit_gate_screen.dart`, `today_screen.dart`, `s2_stock_screen.dart`, `login_screen.dart`, `landing_screen.dart`, and `app_theme.dart`/`app_colors.dart` themselves.

Apply Task 3's Rules 1 and 2 (Rule 3 will not come up — these screens have no painters; if one appears, apply Rule 3). Same absolute constraints: no dark-mode behavior change, drop `const` only where forced, do not restructure.

- [ ] **Step 1: Migrate the 6 heavier files** (trends, dashboard_shell, messages, client_config, tasks, my_work)
- [ ] **Step 2: Migrate the remaining 14 light files**
- [ ] **Step 3: Verify zero statics remain in manager/shared code**

Run:
```bash
cd app && grep -rl "AppColors\." lib --include="*.dart" | sort
```
Expected output — exactly this set and nothing else:
```
lib/core/theme/app_colors.dart
lib/core/theme/app_theme.dart
lib/core/widgets/agent_kit.dart
lib/core/widgets/agent_motion.dart
lib/core/widgets/agent_scaffold.dart
lib/core/widgets/photo_capture_field.dart
lib/core/widgets/primary_gradient_button.dart
lib/features/audit/presentation/audit_shell_screen.dart
lib/features/audit/presentation/sections/s2_stock_screen.dart
lib/features/audit/presentation/submit_gate_screen.dart
lib/features/audit/presentation/visit_outcome_screen.dart
lib/features/auth/presentation/landing_screen.dart
lib/features/auth/presentation/login_screen.dart
lib/features/beatplans/presentation/today_screen.dart
```
(`app_theme.dart` appears only for the two `AppColors.radius*` geometry consts — that's fine.)

- [ ] **Step 4: Run the full suite**

Run: `cd app && flutter analyze && flutter test`
Expected: clean and green, same reasoning (and same rule) as Task 3 Step 6.

- [ ] **Step 5: Commit**

```bash
git add -A app/lib/features
git commit -m "refactor(app): manager screens read TiqColors, not statics"
```

---

### Task 5: `design/tokens.css` light block + final verification

**Files:**
- Modify: `design/tokens.css` (append a light block; do not touch the dark values)

- [ ] **Step 1: Append the light token block to `design/tokens.css`**

At the end of the file, add:

```css
/* Light — "Paper & Ink". Same geometry, same brand blue; the dark theme's ink
   carried over as text. Series/status values are contrast-locked >=3:1 against
   #ffffff (mirrors app/test/core/theme/tiq_colors_test.dart). Mirrors
   TiqColors.light in app/lib/core/theme/tiq_colors.dart. */
[data-theme="light"] {
  --plane: #f7f8fa;
  --surface-1: #ffffff;
  --surface-2: #f1f2f5;
  --surface-3: #e8eaef;
  --line: #e3e5ea;
  --line-strong: #d2d6de;
  --ink-1: #14161c;
  --ink-2: #4c5361;
  --ink-3: #8a909c;
  --brand: #0a6cf0;
  --brand-hover: #0857c4;
  --series-1: #2069c9;
  --series-2: #177a57;
  --series-3: #9a6700;
  --good: #0b7a0b;
  --warn: #935f00;
  --crit: #b32e2e;
  --grid: #e9ebf0;
  --axis: #d2d6de;
  --shadow: rgba(20, 22, 28, 0.06);
  --scrim: rgba(20, 22, 28, 0.5);
}
```

Before committing, open the existing dark block and match its exact variable
names (`--surface-1` vs `--surface1` etc.) — the light block must use the same
names the dark block already defines, adding `--shadow`/`--scrim` to the dark
block too (as `transparent` and `rgba(0,0,0,0.6)` respectively) if they don't
exist yet.

- [ ] **Step 2: Full app verification**

Run: `cd app && flutter analyze && flutter test`
Expected: clean, all tests green.

- [ ] **Step 3: Commit**

```bash
git add design/tokens.css
git commit -m "design: light-mode token block mirroring TiqColors.light"
```

---

## Out of scope for this plan (Plan B, separate)

Shared-axis page transitions, drawer scrim/stagger polish, panel shadows, and
hover/pressed/focus interaction states — all depend on this plan's tokens and
land in `2026-07-17-motion-polish` (Plan B) next.
