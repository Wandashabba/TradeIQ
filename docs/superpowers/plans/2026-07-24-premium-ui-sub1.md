# Premium UI Sub-project 1 — Foundation + Journey + Responsive Nav Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flip the console light-first, turn the landing page into a 5-second auto-advancing splash that flows through a dark sign-in into the light console, and replace the narrow-width nav with an Apple News-style floating bottom bar + menu sheet.

**Architecture:** Token/default changes ride the existing theme system (light values already exist and pass contrast). The splash self-manages navigation under a `max(5s, session-restore)` rule, so the router's redirect gets a splash exemption for `/`. A shared `DimmedAisleBackdrop` gives splash and sign-in the same dimmed footage with a gradient fallback for tests. `ManagerScaffold` drops its icon-rail and drawer modes: ≥1080px keeps the full rail, below it a floating pill bar + bottom sheet take over.

**Tech Stack:** Flutter + Riverpod + go_router + video_player; flutter_test.

**Spec:** `docs/superpowers/specs/2026-07-24-premium-ui-redesign-design.md`

---

## Verified context (read before starting; do not re-derive)

- **Theme default is dark today** — `ThemeModeController.build()` returns `ThemeMode.dark` and every failure path falls back dark (`app/lib/core/theme/theme_mode_controller.dart:58-70`). The light token set (`TiqColors.light`) already exists and passes contrast.
- **The router bounces authed users off `/` immediately** (`app_router.dart:50-55`): logged-in + public route → `/dashboard` or `/today`. Left as-is this preempts the 5-second hold — Task 3 adds the exemption.
- **Session restore is an `AsyncNotifier`** (`SessionController`, `app/lib/core/auth/session_controller.dart`): `AsyncLoading` on cold start, resolves to a `SessionState(role, token)`; expired tokens resolve to an empty session. `sessionRefreshListenableProvider` already re-fires the router on changes.
- **Landing today** (`app/lib/features/auth/presentation/landing_screen.dart`, 279 lines): video controller + WCAG pause toggle + Continue button, wrapped in `PinnedDark`. Widget tests have no platform video — the screen must work with the video uninitialised (existing behaviour: blank/gradient background).
- **`reduceMotion(context)`** helper lives in `app/lib/core/widgets/agent_motion.dart` and is honoured at ~24 sites; keep using it.
- **`ManagerScaffold`** (`app/lib/core/widgets/manager_scaffold.dart`): `_railBreakpoint = 1080`, plus a `_drawerBreakpoint` with icon-collapse and overlay-drawer modes that this plan REMOVES in favour of the bottom bar.
- **Card chrome:** `AppColors.radiusPanel = 4` (`app_colors.dart:77`); `PanelCard` draws `Border.all(colors.line)` + a shadow (`console.dart:147-153`).

## File structure

**Create:**
- `app/lib/core/widgets/dimmed_aisle_backdrop.dart` — shared splash/sign-in backdrop (video + dim overlay, gradient fallback, reduceMotion static).
- `app/lib/core/widgets/nav_destinations.dart` — single source of manager nav destinations (moved out of `manager_scaffold.dart`).
- `app/lib/core/widgets/bottom_nav_bar.dart` — floating pill bar.
- `app/lib/core/widgets/nav_menu_sheet.dart` — the ☰ bottom sheet.
- Tests: `app/test/core/widgets/bottom_nav_bar_test.dart`, `app/test/features/auth/splash_flow_test.dart`.

**Modify:**
- `app/lib/core/theme/theme_mode_controller.dart` — default light.
- `app/lib/core/theme/app_colors.dart` — `radiusPanel` 4 → 12.
- `app/lib/core/widgets/console.dart` — softer card shadow, hairline border in light.
- `app/lib/features/auth/presentation/landing_screen.dart` — becomes the splash.
- `app/lib/features/auth/presentation/login_screen.dart` — backdrop + card polish.
- `app/lib/core/router/app_router.dart` — splash exemption + splash→login fade.
- `app/lib/core/widgets/manager_scaffold.dart` — two modes, destinations import.
- Existing tests that assert the dark default, the Continue button, or drawer behaviour — updated honestly, listed per task.

---

## Task 1: Theme default flips light + Stripe chrome constants

**Files:**
- Modify: `app/lib/core/theme/theme_mode_controller.dart`
- Modify: `app/lib/core/theme/app_colors.dart:77`
- Modify: `app/lib/core/widgets/console.dart:147-153`
- Test: existing `app/test/core/theme/` and any test asserting `ThemeMode.dark` default

- [ ] **Step 1: Find every test that asserts the dark default**

```bash
cd app && grep -rn "ThemeMode.dark" test/ | grep -vE "toggle|write|dark_all"
```
Note each hit — Step 4 updates them to the light default (an honest contract change, not a weakening).

- [ ] **Step 2: Flip the default**

In `theme_mode_controller.dart`, the controller currently reads:

```dart
/// light/dark only — ThemeMode.system is deliberately out of scope (managers
/// on desktop web; two explicit modes are clearer than three). Default and
/// every failure path: dark, so nobody's console changes until they touch the
/// toggle.
class ThemeModeController extends Notifier<ThemeMode> {
  ...
  @override
  ThemeMode build() {
    Future.microtask(_restore); // build() must return synchronously
    return ThemeMode.dark;
  }
```

Change the default and the comment to:

```dart
/// light/dark only — ThemeMode.system is deliberately out of scope (managers
/// on desktop web; two explicit modes are clearer than three). Default and
/// every failure path: LIGHT — the 2026-07-24 redesign makes the light console
/// the product's face (see the premium-ui spec); dark stays one toggle away,
/// and a persisted choice still wins over this default.
class ThemeModeController extends Notifier<ThemeMode> {
  ...
  @override
  ThemeMode build() {
    Future.microtask(_restore); // build() must return synchronously
    return ThemeMode.light;
  }
```

A user who previously persisted `dark` keeps dark — `_restore` already wins over the default. Splash and sign-in are unaffected: they render inside `PinnedDark`, which pins the dark theme regardless of mode.

- [ ] **Step 3: Stripe chrome constants**

`app_colors.dart:77`: `static const double radiusPanel = 4;` → `static const double radiusPanel = 12;`

`console.dart` (~147–153) — `PanelCard`'s box decoration. Soften the shadow to the spec value and keep the hairline border:

```dart
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(AppColors.radiusPanel),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D14161C), // rgba(20,22,28,.05) — Stripe-soft
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
```

(Replace the existing `BoxShadow` values; keep everything else in the decoration as-is. If other widgets in `console.dart` share the old shadow, apply the same value there — report which.)

- [ ] **Step 4: Update the tests found in Step 1**

Each dark-default assertion flips to `ThemeMode.light` with the comment "default flipped by the 2026-07-24 premium-ui redesign". Do not touch toggle/persistence tests — the mechanism is unchanged.

- [ ] **Step 5: Run and verify**

```bash
cd app && flutter test test/core/ && flutter analyze
```
Expected: PASS / "No issues found!". Then run the FULL app suite once — the radius/shadow change may trip golden-ish layout assertions elsewhere; fix honestly (values, not assertions, unless the assertion hard-codes the old radius, in which case update it to the new one).

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/theme/ app/lib/core/widgets/console.dart app/test/
git commit -m "feat(app): light-first console, Stripe card chrome (premium-ui sub1)"
```

---

## Task 2: Shared DimmedAisleBackdrop

**Files:**
- Create: `app/lib/core/widgets/dimmed_aisle_backdrop.dart`
- Test: covered via the splash/login tests in Tasks 3–4 (the widget itself is trivial composition; no standalone test file)

- [ ] **Step 1: Write the widget**

```dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The dark brand backdrop shared by the splash and the sign-in screen: the
/// store-aisle footage dimmed to near-black (spec: 88–92% overlay) so it reads
/// as texture, not content.
///
/// The controller is OWNED BY THE CALLER (the splash creates it, sign-in may
/// receive null) because two screens must not fight over one video. When
/// [controller] is null or uninitialised — widget tests have no platform
/// video, and sign-in skips the video entirely — the fallback is a plain
/// near-black gradient, which keeps every layout identical.
class DimmedAisleBackdrop extends StatelessWidget {
  const DimmedAisleBackdrop({super.key, this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final video = controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (video != null && video.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: video.value.size.width,
              height: video.value.size.height,
              child: VideoPlayer(video),
            ),
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF101216), Color(0xFF0A0C10), Color(0xFF07080B)],
              ),
            ),
          ),
        // The dim that makes footage read as texture. 90% sits mid-spec.
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xE6060709)), // 90% #060709
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
cd app && flutter analyze
```
Expected: clean. (Behavioural verification lands with Tasks 3–4.)

- [ ] **Step 3: Commit**

```bash
git add app/lib/core/widgets/dimmed_aisle_backdrop.dart
git commit -m "feat(app): shared dimmed-aisle backdrop for splash and sign-in (premium-ui sub1)"
```

---

## Task 3: The splash — 5s hold, tap-skip, max(5s, restore)

**Files:**
- Modify: `app/lib/features/auth/presentation/landing_screen.dart`
- Modify: `app/lib/core/router/app_router.dart` (redirect exemption)
- Create: `app/test/features/auth/splash_flow_test.dart`
- Existing test: `app/test/features/auth/landing_screen_test.dart` — rewrite honestly (the Continue button and pause toggle it asserts are being removed by design)

- [ ] **Step 1: Write the failing tests**

Create `app/test/features/auth/splash_flow_test.dart`. Read `app/test/helpers/routed_app.dart` first; these tests need a real router (the splash calls `context.go`), so pump the app's actual `routerProvider` with session overridden:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/router/app_router.dart';

/// A session controller pinned to a known state, so tests control the
/// max(5s, restore) race deterministically.
class _FixedSession extends SessionController {
  _FixedSession(this._state);
  final SessionState _state;
  @override
  Future<SessionState> build() async => _state;
}

/// A session controller that never resolves — restore still pending.
class _HangingSession extends SessionController {
  @override
  Future<SessionState> build() => Completer<SessionState>().future;
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: Consumer(builder: (context, ref, _) {
        return MaterialApp.router(routerConfig: ref.watch(routerProvider));
      }),
    );

void main() {
  testWidgets('holds for 5 seconds, then advances to sign-in when logged out',
      (tester) async {
    await tester.pumpWidget(_app([
      sessionControllerProvider.overrideWith(() => _FixedSession(const SessionState())),
    ]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sign in'), findsNothing); // still on splash

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Sign in'), findsNothing); // 4.1s — still holding

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget); // past 5s — advanced
  });

  testWidgets('tap anywhere skips the hold immediately', (tester) async {
    await tester.pumpWidget(_app([
      sessionControllerProvider.overrideWith(() => _FixedSession(const SessionState())),
    ]));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(200, 300));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('a restored manager session lands on the dashboard, not sign-in',
      (tester) async {
    await tester.pumpWidget(_app([
      sessionControllerProvider.overrideWith(
          () => _FixedSession(const SessionState(role: 'manager', token: 't'))),
      // Dashboard pulls live data; that is fine — AsyncSection shows loaders.
    ]));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Execution overview'), findsOneWidget);
  });

  testWidgets('never advances before restore resolves, even after 5s and a tap',
      (tester) async {
    await tester.pumpWidget(_app([
      sessionControllerProvider.overrideWith(_HangingSession.new),
    ]));
    await tester.pump(const Duration(seconds: 6));
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(seconds: 2));
    // Restore never resolved → still on the splash, no navigation.
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Execution overview'), findsNothing);
  });
}
```

Add `import 'dart:async';` for `Completer`. Adjust the two landing assertions ('Sign in', 'Execution overview') to the real visible strings — verify with the login/dashboard screens before running.

- [ ] **Step 2: Run and watch them fail**

```bash
cd app && flutter test test/features/auth/splash_flow_test.dart
```
Expected: FAIL — today the splash never auto-advances (Continue button flow), and the router bounces the authed case before 5s (wrong reason to pass; the hold test fails).

- [ ] **Step 3: Router — the splash exemption + fade to login**

In `app_router.dart`'s redirect, add the exemption FIRST, before the auth checks:

```dart
    redirect: (context, state) {
      final location = state.matchedLocation;
      // The splash ('/') owns its own navigation: it holds for max(5s,
      // session-restore) as a deliberate brand moment (premium-ui spec) and
      // then routes by role itself. Redirecting here would cut the hold short.
      if (location == '/') return null;

      final session = ref.read(sessionControllerProvider).value;
      ...
```

(The rest of the redirect is unchanged — `/login` still bounces an authed user to their home, so a stale link cannot re-login.)

Give the login route a fade transition so splash→sign-in is the spec's crossfade:

```dart
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
```

- [ ] **Step 4: Rewrite the landing screen as the splash**

`landing_screen.dart` keeps its name/route and its video-controller init (asset, looping, muted, 0.45 speed, `reduceMotion` → stay on first frame). Remove: the Continue button, the `_MotionToggle` and `_togglePlayback` (a ≤5s auto-advancing screen doesn't need a pause control — the tap surface is the skip), and the old center logo/tagline layout. The new state and build:

```dart
class _LandingScreenState extends ConsumerState<LandingScreen> {
  late final VideoPlayerController _videoController;
  Timer? _hold;
  bool _holdDone = false;
  bool _skipped = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // (existing video init stays here unchanged)
    _hold = Timer(const Duration(seconds: 5), () {
      _holdDone = true;
      _maybeAdvance();
    });
    // Session restore resolving is the other half of max(5s, restore).
    ref.listenManual(sessionControllerProvider, (_, __) => _maybeAdvance());
  }

  /// Navigates when BOTH gates are open: (5s elapsed OR user tapped) AND the
  /// session restore has resolved. Never before restore — advancing blind
  /// would route a logged-in manager to sign-in (spec: the race, defined).
  void _maybeAdvance() {
    if (_navigated || !mounted) return;
    if (!_holdDone && !_skipped) return;
    final session = ref.read(sessionControllerProvider);
    if (session.isLoading) return;
    _navigated = true;
    final role = session.value?.role;
    context.go(switch (role) {
      null => '/login',
      'field_agent' => '/today',
      _ => '/dashboard',
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return PinnedDark(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _skipped = true;
          _maybeAdvance();
        },
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              DimmedAisleBackdrop(controller: _videoController),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: still ? 1 : 0, end: 1),
                  duration: Duration(milliseconds: still ? 0 : 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 12),
                      child: child,
                    ),
                  ),
                  child: const Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'TRADE'),
                      TextSpan(
                          text: 'IQ',
                          style: TextStyle(color: AppColors.blueLight)),
                    ]),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Imports: `dart:async`, the backdrop, `session_controller.dart`. Keep `didChangeDependencies`'s reduceMotion autoplay decision, minus the `_playing` state it no longer needs.

- [ ] **Step 5: Rewrite `landing_screen_test.dart` honestly**

The old tests assert the Continue button, the pause control, and the WCAG loop behaviour — all removed BY DESIGN (screen now ≤5s). Replace with: renders the wordmark; does not navigate in the first 100ms; `reduceMotion` renders without a `TweenAnimationBuilder` animating (duration zero). State in the commit message that these assertions were replaced because the screen's contract changed, not to make tests pass.

- [ ] **Step 6: Run everything**

```bash
cd app && flutter test test/features/auth/ && flutter analyze
```
Expected: all splash tests PASS, analyze clean.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/auth/ app/lib/core/router/app_router.dart app/test/features/auth/
git commit -m "feat(app): landing becomes a 5s auto-advancing splash with max(5s,restore) (premium-ui sub1)"
```

---

## Task 4: Sign-in — the dark hinge

**Files:**
- Modify: `app/lib/features/auth/presentation/login_screen.dart`
- Existing tests: `app/test/features/auth/login_screen_test.dart` (and any screen test pumping LoginScreen)

- [ ] **Step 1: Read the current login screen**, then apply exactly three changes:

1. **Backdrop:** behind the existing card, replace the current background with `const DimmedAisleBackdrop()` (no controller — gradient fallback; sign-in doesn't spin up a second video). Layout, fields, submit flow, error handling: untouched.
2. **Card chrome:** the card's radius goes to `AppColors.radiusPanel` (now 12) and its fill to a translucent dark `Color(0xF2101216)` over the backdrop, border `Color(0xFF262B33)`.
3. **Entrance:** wrap the card in the same `TweenAnimationBuilder` fade-up used by the splash wordmark (400ms, `reduceMotion` → 0ms).

- [ ] **Step 2: Run the login tests**

```bash
cd app && flutter test test/features/auth/login_screen_test.dart
```
Expected: PASS unchanged — behaviour was not touched. If a test asserts the old background colour, update that assertion to the new constant and say so.

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/auth/presentation/login_screen.dart app/test/features/auth/
git commit -m "feat(app): sign-in joins the splash's dark world (premium-ui sub1)"
```

---

## Task 5: Nav destinations extracted + floating bottom bar + menu sheet

**Files:**
- Create: `app/lib/core/widgets/nav_destinations.dart`
- Create: `app/lib/core/widgets/bottom_nav_bar.dart`
- Create: `app/lib/core/widgets/nav_menu_sheet.dart`
- Modify: `app/lib/core/widgets/manager_scaffold.dart`
- Create: `app/test/core/widgets/bottom_nav_bar_test.dart`
- Existing tests: any asserting the drawer/icon-rail at narrow widths — update per Step 6.

- [ ] **Step 1: Extract the destination list**

`manager_scaffold.dart` holds the manager destinations (routes, labels, icons, groups OPERATE/INSIGHT/CONFIGURE). Move them VERBATIM — every entry, no additions or omissions — into `nav_destinations.dart`:

```dart
import 'package:flutter/material.dart';

class NavDestination {
  const NavDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.group,
  });
  final String route;
  final String label;
  final IconData icon;
  final NavGroup group;
}

enum NavGroup { operate, insight, configure }

/// Single source of manager navigation. The sidebar, the floating bottom
/// bar's Menu sheet, and the router guard all read THIS list — a destination
/// added here appears everywhere at once.
const managerDestinations = <NavDestination>[
  // … every existing entry from manager_scaffold.dart, moved verbatim …
];
```

`ManagerScaffold` imports and consumes it; behaviour identical at desktop width. If the current entries carry extra fields (e.g. role restrictions), carry those fields over too.

- [ ] **Step 2: Failing tests for the bar**

Create `app/test/core/widgets/bottom_nav_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/bottom_nav_bar.dart';

import '../../helpers/routed_app.dart';

void main() {
  testWidgets('shows the five slots with the active tab pilled', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: SizedBox.expand()),
      path: '/dashboard',
      overrides: const [],
    ));
    // The bar is injected by ManagerScaffold below 1080 — here we pump it
    // directly to test its own contract.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: const [
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: TiqBottomNavBar(activeRoute: '/dashboard'),
          ),
        ]),
      ),
    ));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-pill-/dashboard')), findsOneWidget);
  });

  testWidgets('menu slot opens the grouped sheet with sign-out', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: const [
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: TiqBottomNavBar(activeRoute: '/dashboard'),
          ),
        ]),
      ),
    ));
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('OPERATE'), findsOneWidget);
    expect(find.text('INSIGHT'), findsOneWidget);
    expect(find.text('CONFIGURE'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
```

Run: `cd app && flutter test test/core/widgets/bottom_nav_bar_test.dart` — FAIL (widget doesn't exist).

- [ ] **Step 3: Build the bar**

`bottom_nav_bar.dart` — the five fixed slots (Home `/dashboard`, Tasks `/tasks`, Alerts `/alerts`, Map `/agents/activity`, Menu opens the sheet), floating pill container per the spec (white92 + blur, hairline, soft shadow, 12px inset), active slot in a blue pill keyed `bottom-nav-pill-<route>`, pill movement via `AnimatedAlign` (250ms, `reduceMotion` → 0ms). Navigation uses `context.go(route)`; Menu calls `showNavMenuSheet(context, ref)`. Icons: `Icons.home_outlined`, `Icons.task_alt`, `Icons.warning_amber_outlined`, `Icons.location_on_outlined`, `Icons.menu` — icon + label on every slot (never colour alone).

- [ ] **Step 4: Build the menu sheet**

`nav_menu_sheet.dart` — `showModalBottomSheet` (rounded top 18px, drag handle) rendering `managerDestinations` grouped by `NavGroup` as a two-column grid of bordered items; below a divider: the theme toggle row (reuses `themeModeProvider.toggle()`) and `Sign out` (calls the existing `SessionController.logout()`; router redirect handles the rest). Tapping a destination `context.go`s and pops the sheet.

- [ ] **Step 5: ManagerScaffold — two modes**

Below `_railBreakpoint` (1080): no rail, no drawer — body plus the floating bar in a `Stack`, body given `MediaQuery` bottom padding of 76 so content clears the bar. At/above 1080: the existing rail, unchanged. Delete the icon-collapse and drawer code paths and their helpers.

- [ ] **Step 6: Update narrow-width tests honestly**

```bash
cd app && grep -rln "drawer\|Drawer" test/ | head
```
Tests asserting the drawer/collapsed rail at narrow widths now assert the bar instead (`find.byType(TiqBottomNavBar)`). The contract changed by design — say so in the commit.

- [ ] **Step 7: Run affected suites**

```bash
cd app && flutter test test/core/ test/features/dashboard/ && flutter analyze
```
Expected: PASS / clean. The dashboard shell tests pump at 800×600 (below 1080) — they will now exercise the bar path; fix layout fallout in the scaffold, not by resizing the tests.

- [ ] **Step 8: Commit**

```bash
git add app/lib/core/widgets/ app/test/core/widgets/ app/test/
git commit -m "feat(app): floating bottom nav bar + menu sheet below 1080px (premium-ui sub1)"
```

---

## Task 6: Full verification, real-browser proof, PR

- [ ] **Step 1: Suites**

```bash
cd app && flutter test && flutter analyze
cd ../backend && npx jest --maxWorkers=4   # untouched, but prove it
```
Expected: all green (backend 694+). Anything reproducible in a touched area is a regression — stop and fix.

- [ ] **Step 2: Real-browser verification (this class of change cannot be trusted to widget tests)**

`flutter build web --release`, serve `build/web`, drive headless Chrome (the session's existing CDP scripts in the scratchpad work). Verify by SCREENSHOT + timing:
1. Cold load `/` logged out → splash with dimmed footage & wordmark; screenshot at ~1s and ~6s — second shot must show sign-in (dark card over backdrop).
2. Tap at ~1s → sign-in immediately.
3. Log in → light dashboard (the theme flip is visible proof of Task 1).
4. Resize to <1080 (or open at 900px width) → floating bar present, pill on Home; navigate Tasks via the bar; open Menu sheet.
5. Reduced-motion spot check: emulate `prefers-reduced-motion` in CDP, reload `/` — wordmark static, still advances at 5s.

- [ ] **Step 3: PR**

Branch `feat/premium-ui-redesign`, base `main`. Body: what changed (light default, splash flow, dark hinge, responsive bar), the spec link, screenshots from Step 2, the honest-test-rewrite notes (landing + drawer tests), and the callout that persisted dark users are unaffected.

---

## Self-review notes

- Spec coverage: light default (T1), chrome (T1), splash incl. race + reduceMotion + tap (T3), redirect exemption (T3), crossfade (T3 Step 3), dark sign-in (T4), bar set A + pill slide + sheet with groups/toggle/sign-out (T5), desktop rail unchanged (T5), verification incl. browser + reduced motion (T6). Motion items beyond this sub-project (stat count-ups, chart draws, map shimmer) belong to sub-projects 2–3 — not gaps here.
- Names used consistently: `DimmedAisleBackdrop(controller:)`, `TiqBottomNavBar(activeRoute:)`, `showNavMenuSheet`, `managerDestinations`, `NavGroup`.
- Known judgement calls for the implementer to verify, not assume: exact visible strings asserted in splash tests; whether extra fields exist on the current destination entries; which other `console.dart` widgets share the old shadow.
