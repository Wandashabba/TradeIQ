import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/territories/presentation/territories_screen.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

import '../../core/design/amber_golden.dart';
import '../../core/widgets/torchlight/torch_harness.dart' show torchSkins;
import '../territory_harness.dart';

Future<FakeTerritoriesRepository> _pump(
  WidgetTester tester, {
  List<Territory> territories = const <Territory>[north, west],
  Map<String, TerritoryCoverage> coverageFor =
      const <String, TerritoryCoverage>{},
  Object? listFailure,
  Object? coverageFailure,
  bool listPending = false,
  bool coveragePending = false,
  List<AppUser> users = const <AppUser>[],
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  String role = 'manager',
  Size size = const Size(360, 720),
}) async {
  final repository = FakeTerritoriesRepository(
    territories: territories,
    coverageFor: coverageFor,
    listFailure: listFailure,
    coverageFailure: coverageFailure,
    listPending: listPending,
    coveragePending: coveragePending,
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
    settle: !(listPending || coveragePending),
    overrides: <Override>[
      territoriesRepositoryProvider.overrideWithValue(repository),
    ],
  );
  return repository;
}

void main() {
  group('the list', () {
    testWidgets('names every territory and its code', (tester) async {
      await _pump(tester);

      expect(find.text('Gauteng North'), findsOneWidget);
      expect(find.text('Western Cape'), findsOneWidget);
      expect(find.text('GP-N · Gauteng'), findsOneWidget);
      // A territory with no region does not get a dangling separator.
      expect(find.text('WC'), findsOneWidget);
    });

    testWidgets('the row is the whole target, not a verb beside it', (
      tester,
    ) async {
      await _pump(tester);

      final row = tester.widget<SoftRow>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('territory-ter-1')),
          matching: find.byType(SoftRow),
        ),
      );
      expect(row.onTap, isNotNull);
    });

    testWidgets('a territory nobody works carries the flag and the word', (
      tester,
    ) async {
      await _pump(
        tester,
        coverageFor: <String, TerritoryCoverage>{
          'ter-1': coverage(agentCount: 0),
          'ter-2': coverage(agentCount: 2),
        },
      );

      SoftRow rowFor(String id) => tester.widget<SoftRow>(
        find.descendant(
          of: find.byKey(ValueKey<String>('territory-$id')),
          matching: find.byType(SoftRow),
        ),
      );

      // Colour is never the only signal: the crimson channel comes with the
      // word, which is what survives greyscale and a screen reader.
      expect(rowFor('ter-1').severity, SoftRowSeverity.watch);
      expect(rowFor('ter-1').severityLabel, 'Unassigned');
      expect(rowFor('ter-2').severity, SoftRowSeverity.none);
      expect(rowFor('ter-2').severityLabel, isNull);
      // And it is legible without the bar at all: the count says it too.
      expect(find.textContaining('No agents'), findsOneWidget);
    });

    testWidgets('the section rule counts what it is showing', (tester) async {
      await _pump(tester);

      final rule = tester.widget<SectionRule>(find.byType(SectionRule).first);
      expect(rule.count, 2);
    });
  });

  group('coverage — three absences, and one measured zero', () {
    testWidgets('a measured rate prints as a percentage', (tester) async {
      await _pump(tester);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('territory-ter-1')),
          matching: find.text('67%'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a MEASURED nought prints 0% and keeps its place', (
      tester,
    ) async {
      // Three outlets, none visited: a real zero, and it is a finding rather
      // than an absence.
      await _pump(
        tester,
        coverageFor: <String, TerritoryCoverage>{
          'ter-1': coverage(visited: 0, total: 3, rate: 0),
        },
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('territory-ter-1')),
          matching: find.text('0%'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a territory with no outlets is an em dash, never 0%', (
      tester,
    ) async {
      // The wire sends `coverageRate: 0` here — `outletsTotal > 0 ? … : 0` in
      // territories.service.ts — and a nought over an empty denominator is a
      // verdict nobody reached.
      await _pump(
        tester,
        coverageFor: <String, TerritoryCoverage>{'ter-1': emptyCoverage()},
      );

      final row = find.byKey(const ValueKey<String>('territory-ter-1'));
      expect(find.descendant(of: row, matching: find.text('0%')), findsNothing);
      expect(
        find.descendant(of: row, matching: find.text('—')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text('No outlets to cover yet'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a coverage request that failed says so, and is not a zero', (
      tester,
    ) async {
      await _pump(tester, coverageFailure: Exception('boom'));

      expect(find.text('Coverage did not load'), findsWidgets);
      expect(find.text('0%'), findsNothing);
      // One error region per screen: fifteen rows must not offer fifteen
      // Retry buttons.
      expect(find.byType(ErrorState), findsNothing);
    });

    testWidgets('a coverage request in flight is a skeleton, not a zero', (
      tester,
    ) async {
      await _pump(tester, coveragePending: true);
      // Past the skeleton's 600ms appearance delay, without settling — the
      // travelling rule never stops.
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('0%'), findsNothing);
      expect(find.byType(SkeletonLine), findsWidgets);
    });
  });

  group('the phases', () {
    testWidgets('an empty list is a designed state with a way out', (
      tester,
    ) async {
      await _pump(tester, territories: const <Territory>[]);

      expect(find.text('No territories yet'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('territory-create')),
        findsOneWidget,
      );
    });

    testWidgets('a failed list offers one retry and refetches', (tester) async {
      await _pump(tester, listFailure: Exception('boom'));

      expect(find.byType(ErrorState), findsOneWidget);
      final retry = find.byKey(const ValueKey<String>('territories-retry'));
      expect(retry, findsOneWidget);
      // It is operable: a button that announces itself and does nothing when
      // activated is the kit-wide bug this suite exists to stop coming back.
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsOneWidget);
    });

    testWidgets('the loading phase never shows a figure', (tester) async {
      await _pump(tester, listPending: true);
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(SoftRow), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('who may create', () {
    testWidgets('a manager gets the create action', (tester) async {
      await _pump(tester);

      expect(
        find.byKey(const ValueKey<String>('territory-create')),
        findsOneWidget,
      );
    });

    testWidgets('a field agent does not', (tester) async {
      await _pump(tester, role: 'field_agent');

      expect(
        find.byKey(const ValueKey<String>('territory-create')),
        findsNothing,
      );
    });
  });

  group('every button is operable by a screen reader', () {
    // The kit shipped a component family that announced itself and did
    // nothing when activated. This is that guard, on this route, per phase —
    // a screen cannot reintroduce it with a local `Semantics(button: true,
    // excludeSemantics: true)` around a bare GestureDetector.
    for (final phase in const <String>['loaded', 'empty', 'error']) {
      testWidgets(phase, (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          territories: phase == 'empty'
              ? const <Territory>[]
              : const <Territory>[north, west],
          listFailure: phase == 'error' ? Exception('boom') : null,
        );

        expectEveryButtonActivatable(tester);
        handle.dispose();
      });
    }
  });

  group('the amber census, per phase × skin', () {
    for (final skin in torchSkins) {
      for (final phase in const <String>['loaded', 'empty', 'error']) {
        testWidgets('${skin.mode.name} · $phase', (tester) async {
          await _pump(
            tester,
            skin: skin,
            territories: phase == 'empty'
                ? const <Territory>[]
                : const <Territory>[north, west],
            listFailure: phase == 'error' ? Exception('boom') : null,
          );

          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'territories',
            phase: phase,
          );
          // And the exact number, not merely "within budget": this route
          // declines its content grant on every phase, so Night is the nav's
          // active tab alone and the light grounds are dark.
          expect(
            census.objectCount,
            skin.mode == SkinMode.night ? 1 : 0,
            reason: census.describe(),
          );
        });
      }
    }

    testWidgets('night · loading', (tester) async {
      await _pump(tester, skin: TiqSkin.night(), listPending: true);
      await tester.pump(const Duration(milliseconds: 700));

      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });
  });

  group('2.0× text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0× on a 320dp phone', (tester) async {
      await _pump(tester, textScale: 2.0, size: const Size(320, 900));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans renders Afrikaans, at 2.0×', (tester) async {
      await _pump(
        tester,
        locale: const Locale('af'),
        textScale: 2.0,
        size: const Size(320, 900),
      );

      expect(find.text('Gebiede'), findsWidgets);
      expect(find.textContaining('Alle gebiede'.toUpperCase()), findsOneWidget);
      // A hardcoded English string inside an Afrikaans screen is a defect.
      expect(find.text('Territories'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans says the absence in Afrikaans', (tester) async {
      await _pump(
        tester,
        locale: const Locale('af'),
        coverageFor: <String, TerritoryCoverage>{'ter-1': emptyCoverage()},
      );

      expect(find.text('Nog geen winkels om te dek nie'), findsOneWidget);
    });
  });
}
