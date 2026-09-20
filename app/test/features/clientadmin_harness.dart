import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/nav_destinations.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

/// THE PUMP FOR THE CONSOLE'S CONFIGURE AND INSIGHT SCREENS.
///
/// Campaigns, contests, clients, users and notifications. It is a sibling of
/// `worklist_harness.dart` rather than a change to it: five groups are
/// migrating in parallel and a shared file with five sets of stub routes in it
/// is a merge conflict per group per day.
///
/// The whole app sits inside a `RepaintBoundary`, so an amber census taken
/// after a pump measures the **composed** frame — chrome included, which is
/// the only way to count the nav's active tab.

/// Every destination a screen in this group can navigate to. Real routes,
/// because `go_router` throws on a destination that does not exist and that
/// throw is worth keeping; stubs, because the assertion is that the screen
/// navigated and not what it navigated to.
List<GoRoute> stubRoutes({
  Map<String, GoRouterWidgetBuilder> real = const <String, GoRouterWidgetBuilder>{},
}) {
  final paths = <String>{
    // Wherever the nav pill and the Menu sheet can send a manager.
    for (final d in managerDestinations) d.route,
    '/today',
    '/account/password',
    '/users/:id/password',
    '/leaderboard/contests',
    '/contests/:id',
    '/visits/:id',
  };
  return <GoRoute>[
    for (final path in paths)
      GoRoute(
        path: path,
        builder: real.containsKey(path)
            ? real[path]!
            : (context, state) => Align(
                alignment: Alignment.topLeft,
                child: Text('stub:${state.matchedLocation}'),
              ),
      ),
  ];
}

/// A signed-in staff member, so a screen that gates on a role sees one.
Override sessionAs(String? role) =>
    sessionControllerProvider.overrideWith(() => _FakeSession(role));

class _FakeSession extends SessionController {
  _FakeSession(this.role);

  final String? role;

  @override
  Future<SessionState> build() async =>
      SessionState(role: role, token: role == null ? null : 'test-token');
}

/// A 360×720 console phone, in [skin], under a real router.
Future<void> pumpConsole(
  WidgetTester tester,
  Widget screen, {
  TiqSkin? skin,
  Size size = const Size(360, 720),
  double textScale = 1.0,
  Locale? locale,
  List<Override> overrides = const <Override>[],
  String path = '/screen',
  Map<String, GoRouterWidgetBuilder> routes =
      const <String, GoRouterWidgetBuilder>{},
  bool settle = true,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // A leaked sheet count from a previous test would extinguish this one's
  // amber, and the failure would name the wrong component.
  TorchSheets.resetForTest();
  addTearDown(TorchSheets.resetForTest);

  final resolved = skin ?? TiqSkin.night();

  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('amber-golden-boundary'),
      child: ColoredBox(
        color: resolved.palette.ground,
        child: ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(
            // The Torchlight theme, so a pushed route (a form) that builds its
            // own `Navigator` page still resolves `context.skin`.
            theme: AppTheme.torchlight(resolved),
            locale: locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            localeListResolutionCallback: resolveAppLocale,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            routerConfig: GoRouter(
              initialLocation: path,
              routes: <GoRoute>[
                GoRoute(path: path, builder: (context, state) => screen),
                ...stubRoutes(real: routes),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // A phase that never resolves — a skeleton with its travelling rule
    // running — has no settled frame to wait for, and `pumpAndSettle` on a
    // repeating animation never returns.
    await tester.pump();
  }
}

/// The same pump, with [screen] **pushed** on top of a host route.
///
/// Forms are pushed in the app and pop themselves when they save. Pumped as a
/// route's own root, that pop disposes the navigator inside the frame that is
/// unmounting it and the test dies on `!_debugLocked` — which reads as a
/// framework bug and is really a fixture that does not match the app.
Future<void> pumpPushedConsole(
  WidgetTester tester,
  Widget screen, {
  TiqSkin? skin,
  Size size = const Size(360, 720),
  double textScale = 1.0,
  Locale? locale,
  List<Override> overrides = const <Override>[],
  String path = '/host',
}) async {
  await pumpConsole(
    tester,
    _PushHost(child: screen),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    overrides: overrides,
    path: path,
  );
  await tester.pumpAndSettle();
}

class _PushHost extends StatefulWidget {
  const _PushHost({required this.child});

  final Widget child;

  @override
  State<_PushHost> createState() => _PushHostState();
}

class _PushHostState extends State<_PushHost> {
  bool _pushed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pushed) return;
    _pushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => widget.child),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Align(alignment: Alignment.topLeft, child: Text('host'));
}

/// Scroll the console body until [finder] is built and on screen.
Future<void> scrollConsoleTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 60,
  );
  await tester.pumpAndSettle();
}

/// Scroll inside an open sheet until [finder] is on screen.
Future<void> scrollSheetTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find
        .descendant(
          of: find.byType(TorchSheet),
          matching: find.byType(Scrollable),
        )
        .first,
    const Offset(0, -80),
  );
  await tester.pumpAndSettle();
}

/// Let a toast live out its dwell and take its timer with it.
///
/// A toast holds a `Timer`, and flutter_test fails a test whose tree is
/// disposed with one still pending — which presents as a hang two tests later
/// rather than as the toast's own fault.
Future<void> settleToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 20));
  await tester.pumpAndSettle();
}

Finder keyed(String key) => find.byKey(ValueKey<String>(key));
