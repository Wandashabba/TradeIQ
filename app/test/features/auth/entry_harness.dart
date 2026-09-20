import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/session_ended.dart';
import 'package:tradeiq_app/core/auth/token_store.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/theme/torchlight/entry_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

/// THE WAY IN, STOOD UP — the splash and sign-in in a chosen skin at a pinned
/// size.
///
/// The same three jobs as `agent_harness.dart`, against the entry skin:
///
/// 1. **Pins the skin.** Both screens wrap themselves in an
///    `EntryTorchlightRoute`, which reads `entrySkinProvider`. Overriding the
///    provider is the only way a test chooses Night, Day or Veld, and it is
///    also the real code path.
/// 2. **Puts the census boundary around the whole frame**, under the key
///    `amberCensus` reads. The thumb zone is a sibling of the scroll view, so
///    a boundary around the body alone would miss the primary — which on
///    sign-in is the only amber there is.
/// 3. **Pins the size to a 360×640 phone**, because a connected-components
///    count is a function of the layout.

/// Night first, then Day, Veld last — the order the design says to build them.
List<SkinMode> get entrySkinModes => <SkinMode>[
  SkinMode.night,
  SkinMode.day,
  SkinMode.veld,
];

/// Pins [entrySkinProvider] to one mode, through the real controller.
class PinnedEntrySkin extends EntrySkinController {
  PinnedEntrySkin(this.mode);

  final SkinMode mode;

  @override
  SkinMode build() => mode;
}

/// Pins [sessionEndedProvider] to a recorded ending, through the real
/// controller — so a test of the sheet exercises the same state a 401 writes.
class PinnedSessionEnded extends SessionEndedController {
  PinnedSessionEnded(this.ended);

  final SessionEnded? ended;

  @override
  SessionEnded? build() => ended;
}

/// In-memory secure storage. The real one is a platform channel whose calls
/// hang under the test binding.
class FakeTokenStore implements TokenStore {
  StoredSession? session;

  @override
  Future<void> save(StoredSession value) async => session = value;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> clear() async => session = null;
}

/// An in-memory database, closed on teardown.
LocalDb entryTestDb() {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// The overrides every entry-screen test needs, before the screen's own.
List<Override> entryBaseOverrides({
  required LocalDb db,
  SkinMode skin = SkinMode.night,
  AuthRepository? auth,
  TokenStore? tokens,
  SessionEnded? sessionEnded,
}) => <Override>[
  localDbProvider.overrideWithValue(db),
  entrySkinProvider.overrideWith(() => PinnedEntrySkin(skin)),
  tokenStoreProvider.overrideWithValue(tokens ?? FakeTokenStore()),
  if (auth != null) authRepositoryProvider.overrideWithValue(auth),
  if (sessionEnded != null)
    sessionEndedProvider.overrideWith(() => PinnedSessionEnded(sessionEnded)),
];

/// The key the amber census reads its pixels back from.
const Key entryBoundaryKey = ValueKey<String>('amber-golden-boundary');

/// Pump [screen] as the route at [path], in the pinned skin.
Future<void> pumpEntryScreen(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
  String path = '/login',
  Size size = const Size(360, 640),
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  List<GoRoute> extraRoutes = const <GoRoute>[],
  bool settle = true,
  bool disableAnimations = true,
}) async {
  // The open-sheet count is app-wide and static. Sign-in RAISES a sheet on
  // arrival when a session ended with work held, which is not a leak — so
  // this clears the count rather than failing on it, and the tests that are
  // about the sheet assert it was answered themselves.
  TorchSheets.resetForTest();
  addTearDown(TorchSheets.resetForTest);

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
          disableAnimations: disableAnimations,
        ),
        child: MaterialApp.router(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          localeListResolutionCallback: resolveAppLocale,
          builder: (context, child) =>
              RepaintBoundary(key: entryBoundaryKey, child: child!),
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

/// A route that answers to a name, for asserting that a tap went somewhere.
GoRoute namedRoute(String path, String marker) =>
    GoRoute(path: path, builder: (context, state) => Text(marker));

/// Unmount the tree **inside the test body**, and flush what disposing it
/// schedules — §12.7's second half. Call this last in any test that stood a
/// screen up against a real drift-backed provider.
Future<void> disposeEntryScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Scroll until [finder] is built and on screen.
///
/// The body is a lazy `ListView`, which is the point: on a 360×640 phone the
/// foot of the sign-in form genuinely is past the fold, and a test that
/// pumped a 2000dp viewport would be testing a screen nobody has.
Future<void> scrollEntryTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}
