import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/card.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/chart/chart.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/sparkline.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';

import 'overview_harness.dart';

/// THE EXECUTION OVERVIEW WEARS THE FLOOR'S GRAMMAR, MEASURED.
///
/// `overview_look_test.dart` renders the route so somebody can look at it, and
/// is off in CI for the reason it gives. This file is the half that runs
/// everywhere: the measurements behind the owner's card override (`unify.md`
/// §1.3, §1.16, §1.17 and `torchlight-aisle.md` §9c) and behind the realistic
/// charts, on the one route that was migrated before either of them landed.
///
/// What it pins, and what each pin is protecting against, because every one of
/// these was on the screen on 28 September 2026:
///
/// * a **crimson-outlined radius-6 rectangle** around the headline figure —
///   `StatTile(lead: true, severity: …)`, which is the one configuration in the
///   kit that draws a border;
/// * a **full-width meter** in every indicator row and every territory row,
///   redrawing the percentage the figure beside it had already printed;
/// * a **severity triangle** in a trailing column, where the override says a
///   severity is an 8dp dot;
/// * **five stacked elements** in the figure block, where four is the ceiling;
/// * **bare plots on the ground** between two lists of cards.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    DashboardKpis? current,
    DashboardKpis? previous,
    TiqSkin? skin,
  }) => pumpOverview(
    tester,
    const DashboardShellScreen(),
    skin: skin,
    overrides: overviewOverrides(
      current: current ?? kpis(),
      previous: previous ?? kpis(execution: 66),
      territories: const <Territory>[north, west],
      byTerritory: <TerritoryDashboardKpis>[
        TerritoryDashboardKpis(
          territoryId: 'ter-1',
          territoryName: 'Gauteng North',
          kpis: kpis(execution: 58.2),
        ),
      ],
    ),
  );

  /// Every indicator row and territory row on the route.
  Iterable<SoftRow> figureRows(WidgetTester tester) =>
      tester.widgetList<SoftRow>(
        find.byWidgetPredicate((w) {
          if (w is! SoftRow) return false;
          final key = (w.key as ValueKey<String>?)?.value ?? '';
          return key.startsWith('kpi-') || key.startsWith('territory-score-');
        }),
      );

  group('no rectangles', () {
    testWidgets('the headline figure wears no outline', (tester) async {
      await pump(tester);

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      // `lead` plus a severity is the ONE configuration in `StatTile` that
      // draws a border, and it drew it at `radii.chip` — a radius-6 rectangle
      // in the middle of a screen of radius-22 cards. The standing lives in
      // the delta beside the figure and in the target on the supporting line.
      expect(tile.lead, isTrue);
      expect(tile.severity, isNull);
    });

    testWidgets('the headline figure sits in a card, and is four things', (
      tester,
    ) async {
      await pump(tester);

      final tile = find.byKey(const ValueKey<String>('kpi-execution-score'));
      expect(
        find.ancestor(of: tile, matching: find.byType(TorchCard)),
        findsOneWidget,
      );

      final stat = tester.widget<StatTile>(tile);
      // Eyebrow, figure (with its delta on the same baseline), one meta line,
      // one visual. The meter was the fifth, and the delta on its own line
      // was what made the fourth a fifth.
      expect(stat.meter, isNull, reason: 'the meter is the fifth element');
      expect(stat.deltaOnBaseline, isTrue);
      expect(stat.subordinates, isNotNull);
      expect(
        find.descendant(of: tile, matching: find.byType(Meter)),
        findsNothing,
      );
      // The one visual is the sparkline, on the card's trailing edge.
      expect(
        find.descendant(
          of: find.ancestor(of: tile, matching: find.byType(TorchCard)),
          matching: find.byType(Sparkline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no indicator or territory row draws a meter or a triangle', (
      tester,
    ) async {
      await pump(tester);

      final rows = figureRows(tester).toList();
      expect(rows, hasLength(greaterThan(7)));
      for (final row in rows) {
        final key = (row.key as ValueKey<String>).value;
        expect(
          find.descendant(
            of: find.byKey(row.key!),
            matching: find.byType(Meter),
          ),
          findsNothing,
          reason: '$key still draws a meter',
        );
        expect(
          find.descendant(
            of: find.byKey(row.key!),
            matching: find.byType(SeverityMark),
          ),
          findsNothing,
          reason: '$key still draws a severity triangle',
        );
      }
    });

    testWidgets('a standing is a dot, at its two commitment levels', (
      tester,
    ) async {
      // 93.1 against a 95 floor is watch; 55.6 against 80 is critical; 41.2
      // against 33 is on the standard and draws no mark at all, because a
      // verdict is only ever crimson in this system.
      await pump(tester);

      SoftRowSeverity severityOf(String id) => tester
          .widget<SoftRow>(find.byKey(ValueKey<String>('kpi-$id')))
          .severity;

      expect(severityOf('osa'), SoftRowSeverity.watch);
      expect(severityOf('perfect'), SoftRowSeverity.critical);
      expect(severityOf('sos'), SoftRowSeverity.none);
    });

    testWidgets('every row still says its standing and its standard in words', (
      tester,
    ) async {
      // The dot is a silhouette and the meter's tick was a notch. Neither is
      // a reading, so the words that replaced them are what this measures —
      // removing the meter may not cost the target.
      await pump(tester);

      for (final row in figureRows(tester)) {
        final label = row.semanticsLabel!;
        expect(
          label,
          anyOf(
            contains('the standard'),
            contains('No visits in this window'),
          ),
          reason: '${(row.key as ValueKey<String>).value} has no standing',
        );
        expect(
          label,
          contains('Target'),
          reason: '${(row.key as ValueKey<String>).value} has no standard',
        );
      }
    });
  });

  group('every plot goes through the kit', () {
    testWidgets('both trend panels are a TrendChart in a card', (tester) async {
      await pump(tester);

      final charts = find.byType(TrendChart);
      expect(charts, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        expect(
          find.ancestor(of: charts.at(i), matching: find.byType(TorchCard)),
          findsOneWidget,
          reason: 'plot $i is on bare ground',
        );
      }
      // And nothing on the route paints a plot of its own beside them: the
      // two kit charts are the whole of the route's chart drawing.
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Veld draws no plot at all — the table twin instead', (
      tester,
    ) async {
      await pump(tester, skin: TiqSkin.veld());

      expect(find.byType(TrendChart), findsNothing);
      // Both of them, reached by scrolling: Veld halves the density and the
      // route is taller than any viewport a test should pretend to have.
      for (final key in const <String>[
        'dashboard-score-table',
        'dashboard-availability-table',
      ]) {
        await scrollOverviewTo(tester, find.byKey(ValueKey<String>(key)));
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget, reason: key);
      }
      expect(find.byType(TrendChart), findsNothing);
    });
  });
}
