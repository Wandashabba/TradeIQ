import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/territories/presentation/territories_screen.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

import '../../core/design/amber_golden.dart';
import '../../core/widgets/torchlight/torch_harness.dart' show torchSkins;
import '../territory_harness.dart';

final List<AppUser> _roster = <AppUser>[
  person('a1', 'agent@x.com', name: 'Ruan Botha'),
  person('a2', 'unnamed@x.com'),
  person('a3', 'gone@x.com', name: 'Lerato Dube', active: false),
  person('m1', 'boss@x.com', name: 'A Manager', role: 'manager'),
];

Future<FakeTerritoriesRepository> _openSheet(
  WidgetTester tester, {
  Map<String, TerritoryCoverage> coverageFor =
      const <String, TerritoryCoverage>{},
  Object? coverageFailure,
  Object? assignFailure,
  List<AppUser> users = const <AppUser>[],
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  String role = 'manager',
  Size size = const Size(360, 720),
}) async {
  final repository = FakeTerritoriesRepository(
    coverageFor: coverageFor,
    coverageFailure: coverageFailure,
    assignFailure: assignFailure,
  );
  await pumpConsole(
    tester,
    const TerritoriesScreen(),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    role: role,
    users: users,
    overrides: <Override>[
      territoriesRepositoryProvider.overrideWithValue(repository),
    ],
  );
  await tester.tap(find.byKey(const ValueKey<String>('territory-ter-1')));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  group('the evidence pane', () {
    testWidgets('shows coverage as figures, with the visited-of line', (
      tester,
    ) async {
      await _openSheet(tester);

      // The eyebrows are asserted as widget properties rather than as text:
      // the eyebrow role uppercases on the console density, and a test that
      // hardcoded `COVERED` would break the day a density changed.
      final tiles = tester
          .widgetList<StatTile>(
            find.descendant(
              of: find.byType(TorchSheet),
              matching: find.byType(StatTile),
            ),
          )
          .toList();
      expect(tiles.map((t) => t.eyebrow), <String>[
        'Covered',
        'Outlets',
        'Agents',
      ]);
      expect(tiles.first.value, closeTo(66.67, 0.01));
      expect(find.text('2 of 3 visited in this window'), findsOneWidget);
    });

    testWidgets('an unassigned territory says so in words, not a colour', (
      tester,
    ) async {
      await _openSheet(
        tester,
        coverageFor: <String, TerritoryCoverage>{
          'ter-1': coverage(agentCount: 0),
        },
      );

      expect(find.text('Nobody works this territory yet.'), findsOneWidget);
    });

    testWidgets('an empty territory does not print 0% covered', (tester) async {
      await _openSheet(
        tester,
        coverageFor: <String, TerritoryCoverage>{'ter-1': emptyCoverage()},
      );

      expect(find.text('No outlets to cover yet'), findsWidgets);
    });

    testWidgets('a failed coverage block offers one retry inside the sheet', (
      tester,
    ) async {
      await _openSheet(tester, coverageFailure: Exception('boom'));

      expect(
        find.byKey(const ValueKey<String>('coverage-retry')),
        findsOneWidget,
      );
    });

    testWidgets('a field agent gets the map but not the assign verb', (
      tester,
    ) async {
      await _openSheet(tester, role: 'field_agent');

      expect(
        find.byKey(const ValueKey<String>('territory-map-ter-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('territory-assign-ter-1')),
        findsNothing,
      );
    });
  });

  group('the roster pane', () {
    Future<FakeTerritoriesRepository> open(
      WidgetTester tester, {
      Object? assignFailure,
      List<AppUser> users = const <AppUser>[],
    }) async {
      final repository = await _openSheet(
        tester,
        users: users,
        assignFailure: assignFailure,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-assign-ter-1')),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('a row names a person, and only field agents are offered', (
      tester,
    ) async {
      await open(tester, users: _roster);

      expect(find.byType(PersonRow), findsNWidgets(3));
      expect(find.text('Ruan Botha'), findsOneWidget);
      // An account nobody named falls back to the address people mail — which
      // is still not a database id.
      expect(find.text('unnamed@x.com'), findsOneWidget);
      // A manager is not a candidate.
      expect(find.text('A Manager'), findsNothing);
      // The id never appears.
      expect(find.text('a1'), findsNothing);
    });

    testWidgets('a deactivated agent carries the reason and cannot be picked', (
      tester,
    ) async {
      await open(tester, users: _roster);

      expect(find.text('No longer active'), findsOneWidget);
      final row = tester.widget<PersonRow>(
        find.byKey(const ValueKey<String>('assign-agent-a3')),
      );
      expect(row.onTap, isNull);
      expect(row.deactivated, isTrue);
    });

    testWidgets(
      'the commit is blocked with a reason until somebody is picked',
      (tester) async {
        await open(tester, users: _roster);

        final button = tester.widget<TorchPrimaryButton>(
          find.byKey(const ValueKey<String>('assign-agent-confirm')),
        );
        expect(button.onPressed, isNull);
        expect(button.blockedReason, 'Pick a field agent first.');
        expect(find.text('Pick a field agent first.'), findsOneWidget);
      },
    );

    testWidgets('picking then committing assigns that agent', (tester) async {
      final repository = await open(tester, users: _roster);

      await tester.tap(find.byKey(const ValueKey<String>('assign-agent-a1')));
      await tester.pumpAndSettle();
      expect(find.text('Picked'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('assign-agent-confirm')),
      );
      await tester.pumpAndSettle();

      expect(repository.assignedTerritoryId, 'ter-1');
      expect(repository.assignedUserId, 'a1');
      expect(find.text('Assigned to Gauteng North.'), findsOneWidget);
      await settleToasts(tester);
    });

    testWidgets(
      'a failed assignment says nothing changed, and keeps the pick',
      (tester) async {
        await open(tester, users: _roster, assignFailure: Exception('boom'));

        await tester.tap(find.byKey(const ValueKey<String>('assign-agent-a1')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('assign-agent-confirm')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('That agent was not assigned. Nothing changed.'),
          findsOneWidget,
        );
        // The pane is still up with the pick intact, so the retry is one press.
        expect(find.text('Picked'), findsOneWidget);
        await settleToasts(tester);
      },
    );

    testWidgets('an empty roster is a designed state', (tester) async {
      await open(tester);

      expect(find.text('No field agents yet'), findsOneWidget);
    });

    testWidgets('back returns to the evidence pane, and drops the pick', (
      tester,
    ) async {
      await open(tester, users: _roster);

      await tester.tap(find.byKey(const ValueKey<String>('assign-agent-a1')));
      await tester.pumpAndSettle();
      // Three rows plus a commit outgrows the sheet's 88% ceiling, so the
      // bottom-most control genuinely is below the fold.
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('assign-agent-back')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('assign-agent-back')));
      await tester.pumpAndSettle();

      // The evidence pane is back — its verbs are the proof, and they are
      // what a manager reaches for next.
      expect(
        find.byKey(const ValueKey<String>('territory-map-ter-1')),
        findsOneWidget,
      );
      expect(find.byType(PersonRow), findsNothing);
    });
  });

  group('every button is operable by a screen reader', () {
    testWidgets('the evidence pane', (tester) async {
      final handle = tester.ensureSemantics();
      await _openSheet(tester, users: _roster);

      expectEveryButtonActivatable(tester);
      handle.dispose();
    });

    testWidgets('the roster pane', (tester) async {
      final handle = tester.ensureSemantics();
      await _openSheet(tester, users: _roster);
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-assign-ter-1')),
      );
      await tester.pumpAndSettle();

      // Including the rows: PersonRow's onTap is a real Semantics.onTap, and
      // a row a reader can focus and cannot activate is a row that is not
      // there.
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });
  });

  group('the amber census, per pane × skin', () {
    for (final skin in torchSkins) {
      testWidgets('${skin.mode.name} · evidence pane is unlit', (tester) async {
        await _openSheet(tester, skin: skin);

        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              'Coverage is a reading, not an action, and every amber on the '
              'route beneath a sheet is out. ${census.describe()}',
        );
      });

      testWidgets('${skin.mode.name} · roster pane spends exactly one', (
        tester,
      ) async {
        await _openSheet(tester, skin: skin, users: _roster);
        await tester.tap(
          find.byKey(const ValueKey<String>('territory-assign-ter-1')),
        );
        await tester.pumpAndSettle();
        // The primary is blocked until somebody is picked, and a disabled
        // primary is not lit. Pick one, so the lit form is what is counted.
        await tester.tap(find.byKey(const ValueKey<String>('assign-agent-a1')));
        await tester.pumpAndSettle();
        // Veld's full-screen route is taller than the viewport, so the commit
        // genuinely is below the fold until it is scrolled to — and a census
        // of a frame the button is not in would count zero and pass.
        await scrollSheetTo(
          tester,
          find.byKey(const ValueKey<String>('assign-agent-confirm')),
        );

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'territory detail sheet',
          phase: 'roster',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });
    }
  });

  group('2.0× text and Afrikaans', () {
    testWidgets('the sheet survives 2.0× on a 320dp phone', (tester) async {
      await _openSheet(
        tester,
        users: _roster,
        textScale: 2.0,
        size: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans, at 2.0×, on the evidence pane', (tester) async {
      await _openSheet(
        tester,
        users: _roster,
        locale: const Locale('af'),
        textScale: 2.0,
        size: const Size(320, 900),
      );

      expect(find.text('GEDEK'), findsOneWidget);
      expect(find.text('Ken ’n agent toe'), findsOneWidget);
      // A hardcoded English string inside an Afrikaans screen is a defect.
      expect(find.text('Covered'), findsNothing);
      expect(find.text('Assign an agent'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans on the roster pane', (tester) async {
      await _openSheet(
        tester,
        users: _roster,
        locale: const Locale('af'),
        size: const Size(360, 900),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-assign-ter-1')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Veldagente'.toUpperCase()), findsOneWidget);
      expect(find.text('Kies eers ’n veldagent.'), findsOneWidget);
      expect(find.text('Nie meer aktief nie'), findsOneWidget);
      expect(find.text('Field agents'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
