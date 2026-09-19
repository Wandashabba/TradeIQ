import 'dart:async';
import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/geo/geofence.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/agent_map/data/agent_map.dart';
import 'package:tradeiq_app/features/agent_map/presentation/agent_map_screen.dart';
import 'package:tradeiq_app/features/agent_map/presentation/outlet_map.dart';
import 'package:tradeiq_app/features/agent_map/presentation/outlet_sheet.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';

const _kasi = Outlet(
  id: 'o1',
  name: 'Kasi Corner Spaza',
  code: 'KC-0412',
  lat: -26.2400,
  lng: 27.8580,
);
const _sunrise = Outlet(
  id: 'o2',
  name: 'Sunrise Spaza',
  code: 'SS-0221',
  lat: -26.2520,
  lng: 27.8580,
);
const _khumalo = Outlet(
  id: 'o3',
  name: 'Khumalo Superette',
  code: 'KS-0014',
  lat: -26.2600,
  lng: 27.8580,
);

/// A phone that gives the next answer each time it is asked, and remembers
/// how often that was. The last answer repeats.
class _WalkingPhone extends LocationService {
  _WalkingPhone(this.answers);

  final List<LocationResult> answers;
  int calls = 0;

  @override
  Future<LocationResult> getCurrentPosition() async {
    calls += 1;
    return answers[(calls - 1).clamp(0, answers.length - 1)];
  }
}

/// The ordinary frame: one stop done, one next, one store in the patch, and a
/// fix that is 1,2 km from anything — so nothing is at the door.
AgentMapView _view({
  bool located = true,
  bool atDoor = false,
  bool disputed = false,
  int patch = 1,
}) {
  double? metres(double value) => located ? value : null;
  return AgentMapView(
    pins: <MapOutlet>[
      MapOutlet(
        outlet: _kasi,
        state: MapPinState.doneToday,
        sequence: 1,
        distanceMeters: metres(atDoor ? 12 : 1200),
      ),
      MapOutlet(
        outlet: _sunrise,
        state: MapPinState.nextUp,
        sequence: 2,
        distanceMeters: metres(1330),
        disputed: disputed,
      ),
      for (var i = 0; i < patch; i++)
        MapOutlet(
          outlet: i == 0
              ? _khumalo
              : Outlet(
                  id: 'x$i',
                  name: 'Store $i',
                  code: 'XX-$i',
                  lat: -26.26 - i * 0.001,
                  lng: 27.858,
                ),
          state: MapPinState.territory,
          distanceMeters: metres(2400.0 + i),
        ),
    ],
    here: located ? const Coordinates(lat: -26.2399, lng: 27.858) : null,
    problem: located ? null : MapLocationProblem.denied,
    planName: 'Naledi · Soweto East',
  );
}

/// Pump the map.
///
/// **Never `pumpAndSettle`.** flutter_map's tile layer keeps retrying a fetch
/// the test environment blocks, so a settle here never returns — the same trap
/// `territories_screen_test` documents, and a cousin of the drift-`watch()`
/// one in torchlight-aisle §12.7. A fixed number of frames is all a built
/// frame needs.
Future<void> _pump(
  WidgetTester tester, {
  AgentMapView? view,
  bool error = false,
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Size size = const Size(360, 640),
  Locale locale = const Locale('en'),
  LocalDb? db,
}) async {
  final database = db ?? agentTestDb();
  await pumpAgentScreen(
    tester,
    const AgentMapScreen(),
    path: '/map',
    size: size,
    overrides: <Override>[
      ...agentBaseOverrides(db: database, skin: skin),
      agentMapProvider.overrideWith((ref) async {
        if (error) throw StateError('no signal');
        return view ?? _view();
      }),
    ],
    textScale: textScale,
    locale: locale,
    settle: false,
    extraRoutes: <GoRoute>[
      GoRoute(path: '/today', builder: (c, s) => const Text('Today')),
      GoRoute(path: '/my-work', builder: (c, s) => const Text('My work')),
      GoRoute(
        path: '/leaderboard/contests',
        builder: (c, s) => const Text('Contests view'),
      ),
      GoRoute(path: '/audit', builder: (c, s) => const Text('Outlet picker')),
      GoRoute(
        path: '/audit/:outletId',
        builder: (c, s) => Text('Visit ${s.pathParameters['outletId']}'),
      ),
    ],
  );
  await _frames(tester);
}

/// Enough frames for a future to resolve and its tree to lay out, and no more.
Future<void> _frames(WidgetTester tester, {int count = 5}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Scroll the body until [finder] exists.
///
/// It drags from a point **below the map band**, not from the middle of the
/// scroll view: a drag that starts on the map pans the map, which is correct
/// behaviour and useless for reaching the list. And it pumps fixed frames, for
/// the same reason `_pump` does not settle.
Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, {
  int maxDrags = 12,
}) async {
  for (var i = 0; i < maxDrags && finder.evaluate().isEmpty; i++) {
    await tester.dragFrom(const Offset(180, 470), const Offset(0, -180));
    await _frames(tester, count: 3);
  }
  if (finder.evaluate().isNotEmpty) {
    // A lazy list builds a row inside its cache extent before it is on screen,
    // so "it exists" is not "you can tap it". `.first` because a word like
    // "Visited today" is on the legend and on a row, and the legend is not the
    // thing being scrolled to.
    await tester.ensureVisible(finder.first);
    await _frames(tester, count: 3);
  }
}

/// Reach a store's row and open its sheet.
Future<void> _openSheet(WidgetTester tester, String outletId) async {
  final row = find.byKey(ValueKey<String>('map-store-$outletId'));
  await _scrollTo(tester, row);
  await tester.tap(row);
  await _frames(tester, count: 8);
}

void main() {
  // flutter_map 8 caches tiles on disk, and the cache asks path_provider for
  // the OS cache directory the first time any tile layer is built. A widget
  // test has no path_provider plugin, so that first ask throws a
  // MissingPluginException asynchronously — and which test it lands in
  // depends on how long the first map-drawing test happens to run. Run one
  // census case on its own and it lands in that case. Answering the channel
  // with a scratch directory makes the order of the tests irrelevant.
  late final Directory cacheDir;
  setUpAll(() {
    cacheDir = Directory.systemTemp.createTempSync('agent-map-tiles');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => cacheDir.path,
        );
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  setUp(() {
    // `TorchSheets.openCount` is a static, and a test that ends with a sheet
    // up leaves it at 1 — which makes the NEXT test's route think it is
    // beneath a sheet and put every amber out. That presents as a census of
    // zero on a screen that painted its nav tab correctly, which is a
    // confusing hour if you do not know to look here.
    TorchSheets.resetForTest();
    // The map is drawn unless a test says otherwise. Every tile fetch fails in
    // a widget test, so the real threshold would make "is the map drawn?" a
    // question about how many frames were pumped.
    AgentOutletMap.debugFailureThreshold = 1 << 30;
  });
  tearDown(() => AgentOutletMap.debugFailureThreshold = 6);

  group('the stores, and where they are', () {
    testWidgets('the map draws over a list of the same stores', (tester) async {
      await _pump(tester);

      expect(find.byType(FlutterMap), findsOneWidget);
      await _scrollTo(tester, find.text('Kasi Corner Spaza'));
      expect(find.text('Kasi Corner Spaza'), findsWidgets);
      expect(find.text('Sunrise Spaza'), findsWidgets);
      expect(find.text('KC-0412'), findsOneWidget);
    });

    testWidgets('every pin state is named in words beside its silhouette', (
      tester,
    ) async {
      await _pump(tester);

      // The four states are four shapes on the map; on a row they are a shape
      // AND a word, which is the channel that survives greyscale and glare.
      await _scrollTo(tester, find.text('Visited today'));
      expect(find.text('Visited today'), findsWidgets);
      expect(find.text('Next up'), findsWidgets);
      expect(find.byType(MapPinGlyph), findsWidgets);
    });

    testWidgets('the route and the patch are separate sections', (
      tester,
    ) async {
      await _pump(tester);

      await _scrollTo(tester, find.text('Today’s route'));
      expect(find.text('Today’s route'), findsOneWidget);
      await _scrollTo(tester, find.text('The rest of your patch'));
      expect(find.text('The rest of your patch'), findsOneWidget);
    });

    testWidgets('no plan still lists the patch, and says the route is empty', (
      tester,
    ) async {
      await _pump(
        tester,
        view: const AgentMapView(
          pins: <MapOutlet>[
            MapOutlet(
              outlet: _khumalo,
              state: MapPinState.territory,
              distanceMeters: 2400,
            ),
          ],
          here: Coordinates(lat: -26.2399, lng: 27.858),
          problem: null,
          planName: null,
        ),
      );

      await _scrollTo(tester, find.text('No route planned for today.'));
      expect(find.text('No route planned for today.'), findsOneWidget);
      await _scrollTo(tester, find.text('Khumalo Superette'));
      expect(find.text('Khumalo Superette'), findsWidgets);
    });
  });

  group('when the phone will not say where it is', () {
    testWidgets('it says so once, in words, and shows no distance at all', (
      tester,
    ) async {
      await _pump(tester, view: _view(located: false));

      expect(
        find.textContaining('Location is off for this app'),
        findsOneWidget,
      );
      expect(find.textContaining('km'), findsNothing);
      expect(
        find.text('—'),
        findsNothing,
        reason:
            'an em dash on every row is the same sentence forty times; the '
            'screen says it once and shows no figures',
      );
    });

    testWidgets('the map still draws the stores', (tester) async {
      await _pump(tester, view: _view(located: false));

      expect(
        find.byType(FlutterMap),
        findsOneWidget,
        reason: 'the stores are where they are whether or not we are located',
      );
      await _scrollTo(tester, find.text('Kasi Corner Spaza'));
      expect(find.text('Kasi Corner Spaza'), findsWidgets);
    });
  });

  group('the three screens with no map on them', () {
    testWidgets('Veld replaces it with the list, and says why', (tester) async {
      await _pump(tester, skin: SkinMode.veld);

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.textContaining('The map is off in bright sun'), findsOneWidget);
      expect(find.text('Kasi Corner Spaza'), findsWidgets);
    });

    testWidgets('offline says no map here, and keeps every store', (
      tester,
    ) async {
      AgentOutletMap.debugFailureThreshold = 0;
      await _pump(tester);

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('No map here'), findsOneWidget);
      expect(
        find.textContaining('the list needs no connection'),
        findsOneWidget,
      );
      await _scrollTo(tester, find.text('Kasi Corner Spaza'));
      expect(find.text('Kasi Corner Spaza'), findsWidgets);
    });

    testWidgets('a viewport with no room for one drops it silently', (
      tester,
    ) async {
      await _pump(tester, size: const Size(360, 560));

      expect(find.byType(FlutterMap), findsNothing);
      expect(
        find.text('Kasi Corner Spaza'),
        findsWidgets,
        reason: 'the fold budget takes the map, never the stores',
      );
    });
  });

  group('one store, and what you can do there', () {
    testWidgets('a row opens the sheet, which carries the one action', (
      tester,
    ) async {
      await _pump(tester);

      await _openSheet(tester, 'o2');

      expect(find.text('SS-0221'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('map-sheet-check-in')),
        findsOneWidget,
      );
    });

    testWidgets('checking in from the sheet lands on that store\'s visit', (
      tester,
    ) async {
      await _pump(tester);

      await _openSheet(tester, 'o2');
      await tester.tap(find.byKey(const ValueKey<String>('map-sheet-check-in')));
      await _frames(tester, count: 8);

      expect(find.text('Visit o2'), findsOneWidget);
    });

    testWidgets('a store already done today offers a ghost, not a commit', (
      tester,
    ) async {
      await _pump(tester);

      await _openSheet(tester, 'o1');

      expect(find.text('You checked in here today.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('map-sheet-check-in')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('map-sheet-check-in-again')),
        findsOneWidget,
      );
    });

    testWidgets('a pin under review says so, and keeps its own state', (
      tester,
    ) async {
      await _pump(tester, view: _view(disputed: true));

      await _openSheet(tester, 'o2');

      expect(
        find.textContaining('reported this pin as wrong'),
        findsOneWidget,
      );
      expect(
        find.text('Next up'),
        findsWidgets,
        reason: 'a disputed pin is still the next stop',
      );
    });
  });

  // The fix is shared with Today and kept until somebody drops it. The map is
  // where an agent asks *where am I now*, and its circle routes to the store
  // the fix puts them in — so a fix taken at the first store must not still be
  // the answer when they open the map at the second.
  group('coming back to the map asks where the phone is again', () {
    Future<_WalkingPhone> pumpLive(
      WidgetTester tester,
      List<LocationResult> answers,
    ) async {
      final phone = _WalkingPhone(answers);
      await pumpAgentScreen(
        tester,
        const AgentMapScreen(),
        path: '/map',
        overrides: <Override>[
          ...agentBaseOverrides(db: agentTestDb()),
          // The real view model, on a stubbed route, patch and phone — the
          // thing under test is which fix it is built from.
          todayRouteProvider.overrideWith(
            (ref) async => const TodayRoute(
              planName: 'Naledi · Soweto East',
              hasLocation: true,
              stops: <RouteStop>[
                RouteStop(
                  sequence: 1,
                  outlet: _kasi,
                  visited: false,
                  distanceMeters: null,
                ),
                RouteStop(
                  sequence: 2,
                  outlet: _sunrise,
                  visited: false,
                  distanceMeters: null,
                ),
              ],
            ),
          ),
          myTerritoryOutletsProvider.overrideWith(
            (ref) async => const <Outlet>[_kasi, _sunrise, _khumalo],
          ),
          locationServiceProvider.overrideWithValue(phone),
        ],
        settle: false,
        extraRoutes: <GoRoute>[
          GoRoute(path: '/today', builder: (c, s) => const Text('Today')),
        ],
      );
      await _frames(tester);
      return phone;
    }

    Future<void> leaveAndComeBack(WidgetTester tester) async {
      // A page transition keeps the outgoing route mounted while it runs, so
      // each hop waits it out: "left" has to mean the map's state is gone.
      GoRouter.of(tester.element(find.byType(AgentMapFrame))).go('/today');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(AgentMapScreen), findsNothing);
      GoRouter.of(tester.element(find.text('Today'))).go('/map');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _frames(tester, count: 8);
    }

    MapOutlet? door(WidgetTester tester) =>
        tester.widget<AgentMapFrame>(find.byType(AgentMapFrame)).atDoor;

    testWidgets('the circle follows the agent to the next store', (
      tester,
    ) async {
      final phone = await pumpLive(tester, <LocationResult>[
        LocationGranted(_kasi.lat, _kasi.lng),
        LocationGranted(_sunrise.lat, _sunrise.lng),
      ]);
      expect(phone.calls, 1);
      expect(door(tester)?.outlet.id, 'o1');

      await leaveAndComeBack(tester);

      expect(
        phone.calls,
        2,
        reason: 'opening the map again must ask the phone again',
      );
      expect(
        door(tester)?.outlet.id,
        'o2',
        reason: 'a cached fix would still arm "check in here" for Kasi, and '
            'route the circle to /audit/o1, while the agent stands in Sunrise',
      );
    });

    testWidgets('a refusal is asked again, not kept for the session', (
      tester,
    ) async {
      final phone = await pumpLive(tester, <LocationResult>[
        LocationDenied(),
        LocationGranted(_kasi.lat, _kasi.lng),
      ]);
      expect(door(tester), isNull);

      await leaveAndComeBack(tester);

      expect(phone.calls, 2);
      expect(
        door(tester)?.outlet.id,
        'o1',
        reason: 'an agent who turned location on and came back must not need '
            'to restart the app to be located',
      );
    });
  });

  group('the bar the fourth tab came back to', () {
    testWidgets('four slots, and Map is the one that is lit', (tester) async {
      await _pump(tester);

      final pill = tester.widget<TorchNavPill>(find.byType(TorchNavPill));
      expect(pill.slots.length, 4);
      expect(pill.slots[TodayFrame.mapSlot].label, 'Map');
      expect(pill.activeIndex, TodayFrame.mapSlot);
    });

    testWidgets('Today is still one tap away', (tester) async {
      await _pump(tester);

      // By glyph, not by word: four English labels do not fit a 360dp bar, so
      // the bar renders icon-only as a whole (unify §1.2). The word is still
      // in the semantics — `nav_afrikaans_test` owns that rule.
      await tester.tap(
        find
            .descendant(
              of: find.byType(TorchNavPill),
              matching: find.byType(TorchGlyph),
            )
            .at(TodayFrame.todaySlot),
      );
      await _frames(tester, count: 6);

      expect(find.text('Today'), findsOneWidget);
    });
  });

  group('the states that are not the happy one', () {
    testWidgets('loading keeps the chrome and reserves the map band', (
      tester,
    ) async {
      final db = agentTestDb();
      await pumpAgentScreen(
        tester,
        const AgentMapScreen(),
        path: '/map',
        overrides: <Override>[
          ...agentBaseOverrides(db: db),
          // Never completes: the loading frame is the subject.
          agentMapProvider.overrideWith((ref) => Completer<AgentMapView>().future),
        ],
        settle: false,
      );
      await _frames(tester);

      expect(find.byType(TorchNavPill), findsOneWidget);
      expect(find.text('Map'), findsWidgets);
    });

    testWidgets('a failure says what still works', (tester) async {
      await _pump(tester, error: true);

      expect(find.text('Your stores did not load'), findsOneWidget);
      expect(find.text('Pick a store to visit'), findsOneWidget);
    });

    testWidgets('no stores at all names who fixes it', (tester) async {
      await _pump(
        tester,
        view: const AgentMapView(
          pins: <MapOutlet>[],
          here: null,
          problem: MapLocationProblem.denied,
          planName: null,
        ),
      );

      expect(find.text('No stores yet'), findsOneWidget);
      expect(find.textContaining('A manager assigns both'), findsOneWidget);
    });
  });

  group('big text, and a longer language', () {
    testWidgets('2.0× lays the screen out without losing a store', (
      tester,
    ) async {
      await _pump(tester, textScale: 2.0);

      // An overflow is an exception, and an exception fails the test — so the
      // assertion here is that the frame built at all, plus that the list is
      // still the list.
      await _scrollTo(tester, find.text('Today’s route'));
      expect(find.text('Today’s route'), findsOneWidget);
      await _scrollTo(tester, find.text('The rest of your patch'));
      expect(find.text('The rest of your patch'), findsOneWidget);
    });

    testWidgets('Afrikaans says the states in Afrikaans', (tester) async {
      await _pump(tester, locale: const Locale('af'));

      expect(find.text('Kaart'), findsWidgets);
      await _scrollTo(tester, find.text('Vandag besoek'));
      expect(find.text('Vandag besoek'), findsWidgets);
      expect(find.text('Vandag se roete'), findsOneWidget);
    });

    testWidgets('Afrikaans at 2.0× still builds every row', (tester) async {
      await _pump(tester, locale: const Locale('af'), textScale: 2.0);

      // By key, not by name: an outlet name middle-truncates before a status
      // word does, so at 2.0× the painted string is "Khumalo …rette" and
      // asserting on the whole name would be asserting that truncation is
      // broken.
      final row = find.byKey(const ValueKey<String>('map-store-o3'));
      await _scrollTo(tester, row, maxDrags: 20);
      expect(row, findsOneWidget);
    });
  });

  group('the amber census', () {
    testWidgets('Night, nothing at the door: one object — the nav tab', (
      tester,
    ) async {
      await _pump(tester);
      final census = await amberCensus(tester);

      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.night),
        route: 'map',
        phase: 'loaded',
      );
      expect(
        census.objectCount,
        1,
        reason:
            'There is no primary on this screen and the circle is not the '
            'expected move from 1,2 km away, so the nav tab is the only lit '
            'object.\n\n${census.describe()}',
      );
    });

    testWidgets('Night, standing in a shop: two — the tab and the circle', (
      tester,
    ) async {
      await _pump(tester, view: _view(atDoor: true));
      final census = await amberCensus(tester);

      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.night),
        route: 'map',
        phase: 'loaded',
      );
      expect(
        census.objectCount,
        2,
        reason:
            'inside a store\'s own fence, "check in here" is the move — and '
            'it is the screen\'s one content grant\n\n${census.describe()}',
      );
    });

    for (final skin in <SkinMode>[SkinMode.day, SkinMode.veld]) {
      testWidgets('${skin.name}: nothing is armed, so nothing is lit', (
        tester,
      ) async {
        await _pump(tester, view: _view(atDoor: true), skin: skin);
        final census = await amberCensus(tester);

        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'map',
          phase: 'loaded',
        );
        expect(
          census.objectCount,
          0,
          reason:
              'on a light ground the only amber is a primary commit block, '
              'and this screen has none\n\n${census.describe()}',
        );
      });
    }

    testWidgets('Night, loading: one — the tab, and no map yet', (
      tester,
    ) async {
      final db = agentTestDb();
      await pumpAgentScreen(
        tester,
        const AgentMapScreen(),
        path: '/map',
        overrides: <Override>[
          ...agentBaseOverrides(db: db),
          agentMapProvider.overrideWith((ref) => Completer<AgentMapView>().future),
        ],
        settle: false,
      );
      await _frames(tester);
      final census = await amberCensus(tester);

      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.night),
        route: 'map',
        phase: 'loading',
      );
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, a sheet open: one — the sheet\'s own commit', (
      tester,
    ) async {
      await _pump(tester);
      await _openSheet(tester, 'o2');
      final census = await amberCensus(tester);

      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.night),
        route: 'map',
        phase: 'sheet',
      );
      expect(
        census.objectCount,
        1,
        reason:
            'a sheet puts out every amber beneath it — the nav tab '
            'included — so the only light left is the thing the sheet is '
            'for\n\n${census.describe()}',
      );
    });

    // THE MATRIX. The cases above are the ones with a story; this is every
    // phase in every skin, so no phase can go uncounted in a skin nobody
    // thought to open it in. Night keeps the nav tab whenever the nav renders
    // and nothing else is armed in these phases; Day and Veld have no primary
    // commit on the route, so they are dark — until a sheet puts its own
    // "Check in here" up, which is the one amber object in every skin.
    const matrix = <String, Map<SkinMode, int>>{
      'loading': {SkinMode.night: 1, SkinMode.day: 0, SkinMode.veld: 0},
      'error': {SkinMode.night: 1, SkinMode.day: 0, SkinMode.veld: 0},
      'empty': {SkinMode.night: 1, SkinMode.day: 0, SkinMode.veld: 0},
      'loaded': {SkinMode.night: 1, SkinMode.day: 0, SkinMode.veld: 0},
      'located-off': {SkinMode.night: 1, SkinMode.day: 0, SkinMode.veld: 0},
      'offline': {SkinMode.night: 1, SkinMode.day: 0, SkinMode.veld: 0},
      'sheet': {SkinMode.night: 1, SkinMode.day: 1, SkinMode.veld: 1},
      'sheet-done': {SkinMode.night: 0, SkinMode.day: 0, SkinMode.veld: 0},
    };

    for (final MapEntry(key: phase, value: bySkin) in matrix.entries) {
      for (final MapEntry(key: skin, value: expected) in bySkin.entries) {
        testWidgets('matrix — $phase × ${skin.name}: $expected', (
          tester,
        ) async {
          switch (phase) {
            case 'loading':
              await pumpAgentScreen(
                tester,
                const AgentMapScreen(),
                path: '/map',
                overrides: <Override>[
                  ...agentBaseOverrides(db: agentTestDb(), skin: skin),
                  agentMapProvider.overrideWith(
                    (ref) => Completer<AgentMapView>().future,
                  ),
                ],
                settle: false,
              );
              await _frames(tester);
            case 'error':
              await _pump(tester, error: true, skin: skin);
            case 'empty':
              await _pump(
                tester,
                skin: skin,
                view: const AgentMapView(
                  pins: <MapOutlet>[],
                  here: null,
                  problem: null,
                  planName: null,
                ),
              );
            case 'located-off':
              await _pump(tester, view: _view(located: false), skin: skin);
            case 'offline':
              AgentOutletMap.debugFailureThreshold = 0;
              await _pump(tester, skin: skin);
            case 'sheet':
              await _pump(tester, skin: skin);
              await _openSheet(tester, 'o2');
              expect(find.byType(OutletSheet), findsOneWidget);
            case 'sheet-done':
              await _pump(tester, skin: skin);
              await _openSheet(tester, 'o1');
              expect(find.byType(OutletSheet), findsOneWidget);
            default:
              await _pump(tester, skin: skin);
          }
          final census = await amberCensus(tester);

          expectWithinAmberBudget(
            census,
            agentSkinFor(skin),
            route: 'map',
            phase: phase,
          );
          expect(census.objectCount, expected, reason: census.describe());
        });
      }
    }
  });
}
