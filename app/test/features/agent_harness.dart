import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

/// The two migrated agent routes, stood up in a chosen skin at a pinned size.
///
/// Three things it does that a plain `routedApp` cannot:
///
/// 1. **Pins the skin.** Both screens wrap themselves in a `TorchlightRoute`,
///    which reads `agentSkinProvider` and re-roots the theme. Overriding the
///    provider is therefore the only way a test chooses Night, Day or Veld —
///    and it is also the real code path, so a test cannot accidentally assert
///    against a skin the running app can never produce.
/// 2. **Puts the census boundary around the whole frame**, under the same key
///    `amberCensus` reads. The bottom region is a sibling of the scroll view,
///    so a boundary around the body alone would miss the nav pill — which is
///    amber object #1 in Night.
/// 3. **Pins the size to a 360×640 phone**, because a connected-components
///    count is a function of the layout.

/// The three skins in the order the design says to build them: Night first,
/// then Day, and Veld last.
List<SkinMode> get agentSkinModes => <SkinMode>[
  SkinMode.night,
  SkinMode.day,
  SkinMode.veld,
];

/// Pins [agentSkinProvider] to one mode, through the real controller.
class PinnedAgentSkin extends AgentSkinController {
  PinnedAgentSkin(this.mode);

  final SkinMode mode;

  @override
  SkinMode build() => mode;
}

/// An in-memory database, closed on teardown. Every agent screen carries the
/// sync chip, which watches the outbox, so a test that does not override this
/// reaches for the real on-disk connection and never settles.
LocalDb agentTestDb() {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// The overrides every agent-screen test needs, before the screen's own.
List<Override> agentBaseOverrides({
  required LocalDb db,
  SkinMode skin = SkinMode.night,
  SyncStatus sync = SyncStatus.empty,
  int runningContests = 0,
}) => <Override>[
  localDbProvider.overrideWithValue(db),
  agentSkinProvider.overrideWith(() => PinnedAgentSkin(skin)),
  // Drift's `watch()` reschedules a zero-duration timer on every tick, so
  // `pumpAndSettle` never settles against a real stream. The derived provider
  // is stubbed here; `sync_status_test` covers the real query.
  syncStatusProvider.overrideWith((ref) => Stream<SyncStatus>.value(sync)),
  // The Contests slot's badge (#124). Pinned so no agent screen test reaches
  // for the session and the contests API to draw a number.
  runningContestsCountProvider.overrideWith((ref) async => runningContests),
];

/// The key the amber census reads its pixels back from.
const Key agentBoundaryKey = ValueKey<String>('amber-golden-boundary');

/// Pump [screen] as the route at [path], in [skin].
Future<void> pumpAgentScreen(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
  String path = '/today',
  Size size = const Size(360, 640),
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  List<GoRoute> extraRoutes = const <GoRoute>[],
  bool settle = true,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          devicePixelRatio: 1.0,
          textScaler: TextScaler.linear(textScale),
          // The busy dots, the press scale and the radar are the only animated
          // things on these routes, and a repeating animation makes
          // `pumpAndSettle` hang forever. Every assertion here is about the
          // resting frame, which is also the frame a reduce-motion reader
          // meets.
          disableAnimations: true,
        ),
        child: MaterialApp.router(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          localeListResolutionCallback: resolveAppLocale,
          // The boundary wraps the whole frame, bottom region included: the
          // nav pill is a SIBLING of the scroll view and it is amber object
          // #1 in Night, so a boundary around the body would miss the thing
          // the law is mostly about.
          builder: (context, child) =>
              RepaintBoundary(key: agentBoundaryKey, child: child!),
          routerConfig: GoRouter(
            initialLocation: path,
            routes: <RouteBase>[
              GoRoute(path: path, builder: (context, state) => screen),
              ...extraRoutes,
            ],
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Unmount the tree **inside the test body**, and flush what disposing it
/// schedules.
///
/// ## The drift-`watch()` / `pumpAndSettle` trap, and its other half
///
/// Drift's `watch()` reschedules a zero-duration timer on every tick, so
/// `pumpAndSettle` never settles against a real stream — the test hangs with
/// no output. The usual answer is to override the derived provider with
/// `Stream.value(...)` ([agentBaseOverrides] does it for `syncStatusProvider`).
///
/// A test that is *about* the derivation cannot do that, and then the second
/// half of the trap fires. Cancelling a drift query stream schedules one more
/// zero-duration timer (`StreamQueryStore.markAsClosed`). flutter_test
/// unmounts the tree for you after the body and then calls `pump()` with **no
/// duration** — which flushes microtasks but never elapses the fake clock — so
/// that timer is still pending when `_verifyInvariants` runs, and the test
/// dies on *"A Timer is still pending even after the widget tree was
/// disposed."* The next test in the file then hangs in `db.close()`, waiting
/// on a stream store that a dead `FakeAsync` will never drain.
///
/// So a test that stands a screen up against a real drift-backed provider
/// unmounts it itself and pumps **with** a duration. Call this last.
Future<void> disposeAgentScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // With a duration, so the fake clock actually elapses and the cancellation
  // timer runs. `pump()` with no argument would not.
  await tester.pump(Duration.zero);
}

/// Scroll until [finder] is on screen. The body is a lazy `ListView`, which
/// is the point: on a 360×640 phone the later rows genuinely are past the
/// fold, and a test that pumped a 2000dp viewport would be testing a screen
/// nobody has.
Future<void> scrollAgentTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}

/// Scroll without settling.
///
/// `scrollUntilVisible` calls `pumpAndSettle` on every step, which hangs
/// forever against drift's `watch()` — the same trap [pumpVisitLive] exists
/// to avoid. This drags a fixed distance and pumps a fixed number of frames,
/// which is all a lazy `ListView` needs to build the rows below the fold.
Future<void> dragAgentUp(WidgetTester tester, {double by = 240}) async {
  await tester.drag(find.byType(Scrollable).first, Offset(0, -by));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}
