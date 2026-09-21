import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/chart/chart.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';

import '../../core/design/amber_golden.dart';
import '../../core/widgets/torchlight/torch_harness.dart' show torchSkins;
import 'overview_harness.dart';

/// THE EXECUTION OVERVIEW, on Torchlight.
///
/// The four panels The Floor did not absorb, and the laws they are held to:
/// unknown is not zero, a delta never stands beside nothing, colour is never
/// the only signal, every control is operable by a screen reader, every string
/// is translated, and the amber budget holds on every phase in every skin.

Future<FakeDashboardRepository> _pump(
  WidgetTester tester, {
  DashboardKpis? current,
  DashboardKpis? previous,
  List<TerritoryDashboardKpis> byTerritory = const <TerritoryDashboardKpis>[],
  Object? dashboardFailure,
  Object? byTerritoryFailure,
  List<AlertItem> alerts = const <AlertItem>[],
  Object? alertsFailure,
  List<TaskItem> tasks = const <TaskItem>[],
  List<Territory> territories = const <Territory>[],
  List<TrendPoint> trend = const <TrendPoint>[w26, w27],
  Object? trendFailure,
  TiqSkin? skin,
  Size size = const Size(400, 3000),
  double textScale = 1.0,
  Locale? locale,
}) async {
  final repository = FakeDashboardRepository(
    current: current,
    previous: previous,
    byTerritory: byTerritory,
    failure: dashboardFailure,
    byTerritoryFailure: byTerritoryFailure,
  );
  final overrides = overviewOverrides(
    dashboard: repository,
    alerts: alerts,
    alertsFailure: alertsFailure,
    tasks: tasks,
    territories: territories,
    trend: trend,
    trendFailure: trendFailure,
  );
  await pumpOverview(
    tester,
    const DashboardShellScreen(),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    overrides: overrides,
  );
  return repository;
}

/// The territory summary the by-territory endpoint answers with.
TerritoryDashboardKpis _summary(String id, String name, double score) =>
    TerritoryDashboardKpis(
      territoryId: id,
      territoryName: name,
      kpis: kpis(execution: score),
    );

void main() {
  group('the headline figure', () {
    testWidgets('renders the execution score and its supporting line', (
      tester,
    ) async {
      await _pump(tester, current: kpis(execution: 67.8));

      expect(find.byKey(const ValueKey<String>('kpi-execution-score')), findsOneWidget);
      expect(find.text('Execution score'), findsWidgets);
            expect(find.textContaining('target 75'), findsOneWidget);
    });

    testWidgets('a measured zero renders 0, not an em dash', (tester) async {
      // Visits happened and every SKU checked was out of stock. That is a
      // finding, and the figure keeps its place.
      await _pump(tester, current: kpis(execution: 0, osa: 0));

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      expect(tile.value, 0);
      expect(tile.figureState, FigureState.measured);
      expect(tile.noDataReason, isNull);
    });

    testWidgets('a window with no visits is an em dash and a sentence', (
      tester,
    ) async {
      await _pump(tester, current: emptyWindowKpis());

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      expect(tile.value, isNull);
      expect(tile.figureState, FigureState.missing);
      expect(tile.noDataReason, 'No visits in this window');
      // A delta never stands beside nothing.
      expect(tile.delta, isNull);
      expect(find.text('No visits in this window'), findsWidgets);
    });

    testWidgets('a tenant with no outlets gets the first-run state, not zeros', (
      tester,
    ) async {
      await _pump(tester, current: firstRunKpis());

      expect(find.text('Nothing on the books yet'), findsOneWidget);
      // None of the panels render at all — a scoreboard of noughts is the
      // thing this state exists to avoid.
      expect(find.byKey(const ValueKey<String>('kpi-execution-score')), findsNothing);
      expect(find.text('Where are my agents'), findsNothing);
    });
  });

  group('the delta, measured and never invented', () {
    testWidgets('a rise is an up triangle with the good sentiment', (
      tester,
    ) async {
      await _pump(
        tester,
        current: kpis(execution: 78.4),
        previous: kpis(execution: 76.3),
      );

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      expect(tile.delta!.direction, DeltaDirection.up);
      expect(tile.delta!.sentiment, TiqSentiment.good);
      expect(tile.delta!.comparedTo, 'vs the window before');
    });

    testWidgets('a fall is a down triangle with the bad sentiment', (
      tester,
    ) async {
      await _pump(
        tester,
        current: kpis(execution: 70.0),
        previous: kpis(execution: 76.3),
      );

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      expect(tile.delta!.direction, DeltaDirection.down);
      expect(tile.delta!.sentiment, TiqSentiment.bad);
    });

    testWidgets('with no previous window there is no delta at all', (
      tester,
    ) async {
      await _pump(tester, current: kpis(execution: 78.4));

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      expect(tile.delta, isNull);
    });
  });

  group('needs attention', () {
    testWidgets('counts open alerts by severity, and a zero keeps its row', (
      tester,
    ) async {
      await _pump(
        tester,
        alerts: <AlertItem>[
          alert(id: 'a1'),
          alert(id: 'a2'),
          alert(id: 'a3', severity: 'warning'),
          alert(id: 'a4', severity: 'critical', acknowledged: true),
        ],
      );

      final critical = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('attention-critical-alerts')),
      );
      expect(critical.semanticsLabel, contains('Critical alerts open. 2'));
      // Crimson is never the only channel: the word rides with the bar.
      expect(critical.severity, SoftRowSeverity.critical);
      expect(critical.severityLabel, 'Critical');

      final warnings = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('attention-warning-alerts')),
      );
      expect(warnings.semanticsLabel, contains('. 1'));
      expect(warnings.severity, SoftRowSeverity.watch);
    });

    testWidgets('no open alerts is a measured zero with no severity bar', (
      tester,
    ) async {
      await _pump(tester);

      final critical = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('attention-critical-alerts')),
      );
      expect(critical.semanticsLabel, contains('. 0'));
      expect(critical.severity, SoftRowSeverity.none);
      expect(critical.severityLabel, isNull);
      expect(find.text('Nothing outstanding'), findsWidgets);
    });

    testWidgets('reports open tasks rather than an SLA-breach count', (
      tester,
    ) async {
      await _pump(
        tester,
        tasks: <TaskItem>[
          task(id: 't1'),
          task(id: 't2', priority: 'critical'),
          task(id: 't3', status: 'closed'),
        ],
      );

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('attention-open-tasks')),
      );
      expect(row.semanticsLabel, contains('Tasks still open. 2'));
      expect(row.subtitle, '1 at critical priority');
      expect(find.textContaining('SLA'), findsNothing);
    });

    testWidgets('a row opens its worklist', (tester) async {
      await _pump(tester, alerts: <AlertItem>[alert()]);

      await tester.tap(
        find.byKey(const ValueKey<String>('attention-open-tasks')),
      );
      await tester.pumpAndSettle();
      expect(find.text('/tasks'), findsOneWidget);
    });
  });

  group('where we sit against the standard', () {
    testWidgets('every indicator carries a figure, a meter and a word', (
      tester,
    ) async {
      await _pump(tester, current: kpis());

      for (final id in const <String>[
        'osa',
        'perfect',
        'price',
        'visibility',
        'sos',
        'weighted',
        'numeric',
      ]) {
        expect(
          find.byKey(ValueKey<String>('kpi-$id')),
          findsOneWidget,
          reason: 'indicator $id',
        );
      }
      // 93.1 against a floor of 95 is within ten points: watch, in words.
      final osa = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('kpi-osa')),
      );
      expect(osa.semanticsLabel, contains('Close to the standard'));
      expect(osa.semanticsLabel, contains('Target'));
      // 41.2 against 33 is on the standard.
      final sos = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('kpi-sos')),
      );
      expect(sos.semanticsLabel, contains('On the standard'));
    });

    testWidgets('an unmeasured window says so on every indicator', (
      tester,
    ) async {
      await _pump(tester, current: emptyWindowKpis());

      final osa = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('kpi-osa')),
      );
      expect(osa.semanticsLabel, contains('No visits in this window'));
      // Not "0% and below the standard" — the standing is a verdict and there
      // is nothing to pass it on.
      expect(osa.semanticsLabel, isNot(contains('Below the standard')));
    });

    testWidgets('a thin sample drops the delta and greys the figure', (
      tester,
    ) async {
      // A rate needs n >= 5. Two stock lines that both happened to be in
      // stock is arithmetically true and epistemically worthless.
      await _pump(
        tester,
        current: kpis(osa: 100, osaSample: 2),
        previous: kpis(osa: 60, osaSample: 400),
      );

      final osa = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('kpi-osa')),
      );
      expect(osa.semanticsLabel, contains('Small sample'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('kpi-osa')),
          matching: find.byType(DeltaSlot),
        ),
        findsNothing,
      );
    });
  });

  group('the score bands', () {
    testWidgets('one row per band, counted, with the total on the rule', (
      tester,
    ) async {
      await _pump(
        tester,
        current: kpis(
          bands: const <ScoreBand>[
            ScoreBand(label: '80–100', minScore: 80, outlets: 12),
            ScoreBand(label: '70–79', minScore: 70, outlets: 7),
            ScoreBand(label: 'under 70', minScore: 0, outlets: 3),
          ],
        ),
      );

      expect(find.text('Perfect-store distribution'), findsOneWidget);
      final band = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('band-80–100')),
      );
      expect(band.semanticsLabel, '12 outlets scoring 80–100');
    });

    testWidgets(
      'no bands at all hides the panel — five zero bars is not a measurement',
      (tester) async {
        await _pump(tester, current: kpis());
        expect(find.text('Perfect-store distribution'), findsNothing);
      },
    );
  });

  group('the score by territory', () {
    testWidgets('worst first, each against the target', (tester) async {
      await _pump(
        tester,
        territories: const <Territory>[north, west],
        byTerritory: <TerritoryDashboardKpis>[
          _summary('ter-1', 'Gauteng North', 81),
          _summary('ter-2', 'Western Cape', 54),
        ],
      );

      final rows = tester
          .widgetList<SoftRow>(
            find.byWidgetPredicate(
              (w) =>
                  w is SoftRow &&
                  (w.key as ValueKey<String>?)?.value.startsWith(
                        'territory-score-',
                      ) ==
                      true,
            ),
          )
          .toList();
      expect(rows.map((r) => r.title), <String>[
        'Western Cape',
        'Gauteng North',
      ]);
      expect(rows.first.subtitle, 'Below the standard');
      expect(rows.last.subtitle, 'On the standard');
    });

    testWidgets('no territories at all is an answer, never a loader', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('No territories defined'), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
    });

    testWidgets(
      'territories with no summary overlapping them is a settled answer',
      (tester) async {
        await _pump(tester, territories: const <Territory>[north]);
        expect(find.text('No territory scores yet'), findsOneWidget);
      },
    );

    testWidgets('a failed by-territory fetch offers a retry, not a spinner', (
      tester,
    ) async {
      await _pump(
        tester,
        territories: const <Territory>[north],
        byTerritoryFailure: Exception('boom'),
      );
      expect(
        find.byKey(const ValueKey<String>('territory-scores-retry')),
        findsOneWidget,
      );
    });
  });

  group('the charts and their table twins', () {
    testWidgets('the score trend draws a chart with a legend', (tester) async {
      await _pump(tester);
      expect(
        find.byKey(const ValueKey<String>('dashboard-score-chart')),
        findsOneWidget,
      );
      expect(find.byType(ChartLegend), findsWidgets);
    });

    testWidgets('the toggle swaps the chart for its table twin', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('Execution score over time-view-table')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('dashboard-score-table')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('dashboard-score-chart')),
        findsNothing,
      );
      // The twin carries the unabbreviated period, which is what a manager
      // quotes into a spreadsheet.
      expect(find.text('2026-W26'), findsWidgets);
    });

    testWidgets('an empty window draws no plot and says so in words', (
      tester,
    ) async {
      await _pump(tester, trend: const <TrendPoint>[]);
      expect(
        find.byKey(const ValueKey<String>('dashboard-score-chart')),
        findsNothing,
      );
      expect(find.text('No data in range'), findsWidgets);
    });

    testWidgets('a failed trend fetch offers a retry', (tester) async {
      await _pump(tester, trendFailure: Exception('boom'));
      expect(
        find.byKey(const ValueKey<String>('Execution score over time-retry')),
        findsOneWidget,
      );
    });
  });

  group('Veld', () {
    testWidgets('draws no chart and no map — the table and the list instead', (
      tester,
    ) async {
      await _pump(
        tester,
        skin: TiqSkin.veld(),
        territories: const <Territory>[north],
      );

      expect(
        find.byKey(const ValueKey<String>('dashboard-score-chart')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('dashboard-score-table')),
        findsOneWidget,
      );
      // And no toggle either: a control with one working position is worse
      // than none.
      expect(
        find.byKey(const ValueKey<String>('Execution score over time-view-chart')),
        findsNothing,
      );
    });
  });

  group('the filter rail', () {
    testWidgets('a window chip refetches over the window it names', (
      tester,
    ) async {
      final repository = await _pump(tester);
      final before = repository.windows.length;

      await tester.tap(find.byKey(const ValueKey<String>('range-last7')));
      await tester.pumpAndSettle();

      expect(repository.windows.length, greaterThan(before));
      // The 7-day window starts later than the 30-day one it replaced.
      final last = DateTime.parse(repository.windows.last!);
      expect(
        last.isAfter(DateTime.now().subtract(const Duration(days: 20))),
        isTrue,
        reason: 'asked for ${repository.windows.last}',
      );
    });

    testWidgets('all time is offered and honestly shows no delta', (
      tester,
    ) async {
      await _pump(tester, previous: kpis(execution: 10));

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('range-allTime')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('range-allTime')));
      await tester.pumpAndSettle();

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      expect(tile.delta, isNull);
    });

    testWidgets('the territory chip opens a sheet and scopes the console', (
      tester,
    ) async {
      await _pump(tester, territories: const <Territory>[north, west]);

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-territory')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-territory')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('territory-option-ter-1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-ter-1')),
      );
      await tester.pumpAndSettle();

      final chip = tester.widget<TorchFilterChip>(
        find.byKey(const ValueKey<String>('filter-territory')),
      );
      expect(chip.label, 'Gauteng North');
      expect(chip.selected, isTrue);
      // And the header says which territory the figures below are about.
      expect(find.text('Gauteng North'), findsWidgets);
    });

    testWidgets('the sheet can clear the filter again', (tester) async {
      await _pump(tester, territories: const <Territory>[north]);

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-territory')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-territory')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-ter-1')),
      );
      await tester.pumpAndSettle();

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-territory')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-territory')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-all')),
      );
      await tester.pumpAndSettle();

      final chip = tester.widget<TorchFilterChip>(
        find.byKey(const ValueKey<String>('filter-territory')),
      );
      expect(chip.selected, isFalse);
      expect(chip.label, 'All territories');
    });

    testWidgets('a selected option says Selected, not only a tick', (
      tester,
    ) async {
      await _pump(tester, territories: const <Territory>[north]);

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-territory')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-territory')));
      await tester.pumpAndSettle();
      final all = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('territory-option-all')),
      );
      expect(all.semanticsLabel, contains('Selected'));
    });
  });

  group('the refetch', () {
    testWidgets('goes back to the server rather than replaying cache', (
      tester,
    ) async {
      final repository = await _pump(tester, current: kpis(execution: 10));
      expect(find.textContaining('10'), findsWidgets);

      repository.current = kpis(execution: 42);
      await tester.tap(find.byKey(const ValueKey<String>('dashboard-refresh')));
      await tester.pumpAndSettle();

      expect(find.textContaining('42'), findsWidgets);
    });
  });

  group('errors', () {
    testWidgets('a failed KPI fetch offers a retry, not a raw exception', (
      tester,
    ) async {
      await _pump(tester, dashboardFailure: Exception('network down'));
      expect(find.byKey(const ValueKey<String>('kpi-retry')), findsWidgets);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('a failed alerts fetch does not take the screen down', (
      tester,
    ) async {
      await _pump(tester, alertsFailure: Exception('boom'));
      expect(find.byKey(const ValueKey<String>('alerts-retry')), findsOneWidget);
      // The score above it is still there.
      expect(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
        findsOneWidget,
      );
    });
  });

  group('every button is operable by a screen reader', () {
    testWidgets('the rail, the rules, the rows and the refetch', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        territories: const <Territory>[north],
        alerts: <AlertItem>[alert()],
        tasks: <TaskItem>[task()],
      );
      expectEveryButtonActivatable(tester);

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-territory')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-territory')));
      await tester.pumpAndSettle();
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });
  });

  group('the amber census, per phase × skin', () {
    for (final skin in torchSkins) {
      for (final phase in const <String>[
        'loaded',
        'window-empty',
        'first-run',
        'error',
      ]) {
        testWidgets('${skin.mode.name} · $phase', (tester) async {
          await _pump(
            tester,
            skin: skin,
            size: const Size(400, 900),
            current: switch (phase) {
              'window-empty' => emptyWindowKpis(),
              'first-run' => firstRunKpis(),
              _ => kpis(),
            },
            dashboardFailure: phase == 'error' ? Exception('boom') : null,
            territories: const <Territory>[north],
          );

          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'dashboard-overview',
            phase: phase,
          );
          // Nothing on this route is armed, so the nav tab is the whole of
          // Night's spend and Day and Veld paint none.
          expect(
            census.objectCount,
            skin.mode == SkinMode.night ? 1 : 0,
            reason: census.describe(),
          );
        });
      }
    }
  });

  group('2.0× text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0× on a 320dp phone', (tester) async {
      await _pump(
        tester,
        textScale: 2.0,
        size: const Size(320, 6000),
        territories: const <Territory>[north],
        alerts: <AlertItem>[alert()],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the console reads in Afrikaans', (tester) async {
      await _pump(
        tester,
        locale: const Locale('af'),
        territories: const <Territory>[north],
      );

      expect(find.text('Uitvoeringsoorsig'), findsWidgets);
      expect(find.text('Benodig aandag'), findsOneWidget);
      expect(find.text('Waar ons teenoor die standaard staan'), findsOneWidget);
      expect(find.text('Waar is my agente'), findsOneWidget);
      expect(find.text('Laaste 30 dae'), findsWidgets);
      // And none of the English it replaced.
      expect(find.text('Execution overview'), findsNothing);
      expect(find.text('Needs attention'), findsNothing);
    });
  });
}
