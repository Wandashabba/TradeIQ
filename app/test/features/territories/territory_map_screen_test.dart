import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/territories/presentation/territory_map_gate.dart';
import 'package:tradeiq_app/features/territories/presentation/territory_map_screen.dart';

import '../../core/design/amber_golden.dart';
import '../../core/widgets/torchlight/torch_harness.dart' show torchSkins;
import '../territory_harness.dart';

final List<Outlet> _outlets = <Outlet>[
  outlet('o1', 'Kasi Corner Spaza', visited: true, lat: -26.2, lng: 28.0),
  outlet('o2', 'Shoprite Klipspruit Mall', lat: -26.25, lng: 28.05),
];

/// A map lives inside a `FlutterMap`, whose `TileLayer` keeps retrying a
/// network fetch that is blocked in a test environment. `pumpAndSettle` never
/// returns against it, so every pump here is a fixed number of frames — the
/// same rule §12.7 states for a drift stream, for the same reason.
Future<FakeTerritoriesRepository> _pump(
  WidgetTester tester, {
  List<Outlet> outlets = const <Outlet>[],
  Object? coverageFailure,
  bool coveragePending = false,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  Size size = const Size(360, 900),
  int frames = 3,
}) async {
  final repository = FakeTerritoriesRepository(
    coverageFor: <String, TerritoryCoverage>{
      'ter-1': coverage(
        outletCount: outlets.length,
        outlets: outlets,
        visited: outlets.where((o) => o.visited).length,
        total: outlets.length,
        rate: outlets.isEmpty ? 0 : 50,
      ),
    },
    coverageFailure: coverageFailure,
    coveragePending: coveragePending,
  );
  await pumpConsole(
    tester,
    const TerritoryMapScreen(territory: north),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    settle: false,
    overrides: <Override>[
      territoriesRepositoryProvider.overrideWithValue(repository),
    ],
  );
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return repository;
}

void main() {
  group('the list is the map\'s equal', () {
    testWidgets('every store is a row, outstanding first, with its state', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);

      expect(find.byType(SoftRow), findsNWidgets(2));
      expect(find.text('Visited'), findsWidgets);
      expect(find.text('Not visited yet'), findsWidgets);
      // The outstanding store is above the visited one: the list is the work.
      final rows = tester.widgetList<SoftRow>(find.byType(SoftRow)).toList();
      expect(rows.first.title, 'Shoprite Klipspruit Mall');
      expect(rows.last.title, 'Kasi Corner Spaza');
    });

    testWidgets('a row opens the same sheet a pin does', (tester) async {
      await _pump(tester, outlets: _outlets);

      await tester.tap(find.byKey(const ValueKey<String>('outlet-row-o1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TorchSheet), findsOneWidget);
      expect(find.text('KCS-001'.toUpperCase()), findsNothing);
      expect(find.text('O1'), findsWidgets);
      expect(
        find.text('A visit landed here inside the coverage window.'),
        findsOneWidget,
      );
    });

    testWidgets('a pin carries its state in words for a screen reader', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);

      expect(
        find.bySemanticsLabel('Kasi Corner Spaza, Visited'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Shoprite Klipspruit Mall, Not visited yet'),
        findsOneWidget,
      );
    });
  });

  group('the three ways there is no map', () {
    testWidgets('Veld draws no basemap and says why', (tester) async {
      await _pump(tester, outlets: _outlets, skin: TiqSkin.veld());

      expect(find.byType(FlutterMap), findsNothing);
      expect(
        find.text(
          'The map is off in bright sun. Your stores are listed below, '
          'nearest first.',
        ),
        findsOneWidget,
      );
      // The figure list that replaces it is the list that was always there.
      expect(find.byType(SoftRow), findsNWidgets(2));
    });

    testWidgets('no tiles is a designed state, not an error', (tester) async {
      TerritoryMapScreen.debugFailureThreshold = 0;
      addTearDown(() => TerritoryMapScreen.debugFailureThreshold = 6);

      await _pump(tester, outlets: _outlets);

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('No map here'), findsOneWidget);
      // Not an error state: nothing failed that a manager can act on.
      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(SoftRow), findsNWidgets(2));
    });

    testWidgets('a territory with no outlets is a sentence, not a blank', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('No outlets in this territory'), findsOneWidget);
      expect(find.byType(SoftRow), findsNothing);
    });
  });

  group('the phases', () {
    testWidgets('loading reserves the map band and shows no figure', (
      tester,
    ) async {
      await _pump(tester, coveragePending: true, frames: 0);
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(SkeletonShell), findsWidgets);
      expect(find.byType(SoftRow), findsNothing);
    });

    testWidgets('a failed coverage block offers one retry', (tester) async {
      await _pump(tester, coverageFailure: Exception('boom'));

      expect(find.byType(ErrorState), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('territory-map-retry')),
        findsOneWidget,
      );
    });
  });

  group('the gate', () {
    testWidgets('an id that matches nothing is a designed state', (
      tester,
    ) async {
      await pumpConsole(
        tester,
        const TerritoryMapGate(territoryId: 'nope'),
        settle: false,
        overrides: <Override>[
          territoriesRepositoryProvider.overrideWithValue(
            FakeTerritoriesRepository(),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('We could not find that territory'), findsOneWidget);
      // It never guesses at the first row instead.
      expect(find.text('Gauteng North'), findsNothing);
    });

    testWidgets('a known id opens that territory', (tester) async {
      await pumpConsole(
        tester,
        const TerritoryMapGate(territoryId: 'ter-1'),
        settle: false,
        overrides: <Override>[
          territoriesRepositoryProvider.overrideWithValue(
            FakeTerritoriesRepository(
              coverageFor: <String, TerritoryCoverage>{
                'ter-1': coverage(
                  outletCount: 1,
                  outlets: <Outlet>[outlet('o1', 'Kasi Corner Spaza')],
                  visited: 0,
                  total: 1,
                  rate: 0,
                ),
              },
            ),
          ),
        ],
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.text('Gauteng North'), findsWidgets);
      expect(find.text('Kasi Corner Spaza'), findsWidgets);
    });
  });

  group('every button is operable by a screen reader', () {
    testWidgets('the pins and the rows both activate', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, outlets: _outlets);

      // The pins are the case this guard exists for: each is a
      // `Semantics(button: true, …, excludeSemantics: true)` around a
      // GestureDetector, which is exactly the shape that shipped inert.
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });
  });

  group('the amber census, per phase × skin', () {
    for (final skin in torchSkins) {
      for (final phase in const <String>['loaded', 'empty', 'error']) {
        testWidgets('${skin.mode.name} · $phase', (tester) async {
          await _pump(
            tester,
            skin: skin,
            outlets: phase == 'empty' ? const <Outlet>[] : _outlets,
            coverageFailure: phase == 'error' ? Exception('boom') : null,
          );

          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'territory map',
            phase: phase,
          );
          // A map is a reading: no nav, no primary, nothing lit anywhere.
          expect(census.objectCount, 0, reason: census.describe());
        });
      }
    }
  });

  group('2.0× text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0× on a 320dp phone', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        textScale: 2.0,
        size: const Size(320, 1100),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans says the two states in Afrikaans', (tester) async {
      await _pump(tester, outlets: _outlets, locale: const Locale('af'));

      expect(find.text('Besoek'), findsWidgets);
      expect(find.text('Nog nie besoek nie'), findsWidgets);
      expect(find.text('Visited'), findsNothing);
    });

    testWidgets('Afrikaans says the empty territory in Afrikaans', (
      tester,
    ) async {
      await _pump(tester, locale: const Locale('af'));

      expect(find.text('Geen winkels in hierdie gebied nie'), findsOneWidget);
    });
  });
}
