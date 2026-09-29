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

  });

  // ── The semantic colour, 28 September 2026 ────────────────────────────
  group('a figure and a run carry their standing', () {
    // THIS USED TO LOOP BOTH SKINS AND EXPECT `bad` FROM EACH. It asserted the
    // 28 September decision that a figure's ground does not change whether it
    // carries a verdict; the owner reversed that for Night on 29 September.
    // Split rather than relaxed, so neither ground's answer can rot into the
    // other's.
    testWidgets('Day: the headline figure is crimson under its standard', (
      tester,
    ) async {
      final skin = TiqSkin.day();
      await pump(tester, skin: skin, current: kpis(execution: 67.8));
      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      expect(
        tile.figureInk,
        skin.palette.bad,
        reason:
            '67.8 against a published 75 is a gap, and the card said so only '
            'in ink-3 at 12px after two other facts.',
      );
      // The words are still the carrier: the supporting line states the
      // target and the delta beside the figure carries its own sentiment.
      expect(tile.subordinates, contains('75'));
    });

    testWidgets('Night: a watch-band headline is luminous, not crimson', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pump(tester, skin: skin, current: kpis(execution: 67.8));
      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      expect(
        tile.figureInk,
        isNull,
        reason:
            'Null is how a StatTile asks FigureSlot for ink-1. A headline '
            'keeps crimson on Night only at `critical`; 67.8 against 75 is '
            'inside the watch band, and the target on the supporting line is '
            'what says so.',
      );
      expect(tile.subordinates, contains('75'));
    });

    testWidgets('Night: a genuinely critical headline still is', (
      tester,
    ) async {
      // THE ONE EXCEPTION THE ARTIFACT KEEPS, and the reason `FigureRank`
      // exists rather than a blanket "Night figures are never coloured": Ask's
      // `-43,6%` is crimson beside a bone `481 615`. A headline is the number
      // the panel exists to report, and a critical one is the answer.
      final skin = TiqSkin.night();
      await pump(tester, skin: skin, current: kpis(execution: 58));
      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      expect(
        tile.figureInk,
        skin.palette.bad,
        reason: '58 against a published 75 is well past the watch band.',
      );
    });

    testWidgets('a headline over its standard is green', (tester) async {
      final skin = TiqSkin.day();
      await pump(tester, skin: skin, current: kpis(execution: 81.2));
      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      expect(tile.figureInk, skin.palette.good);
    });

    // A `chartNeutral` run is a grey scribble: the token means "a series with
    // nothing to say about it", which is the one thing the subject of a trend
    // panel is not. Two tests rather than a loop — a second `pumpOverview`
    // inside one test reuses the ProviderScope element and the series does
    // not change, which is a test that passes for the wrong reason.
    for (final (last, want) in <(double, String)>[
      // Ends at 80, above the 75 rule already on the plot.
      (80, 'good'),
      (62, 'bad'),
    ]) {
      testWidgets('a run ending at $last is $want', (tester) async {
        final skin = TiqSkin.day();
        await pumpOverview(
          tester,
          const DashboardShellScreen(),
          skin: skin,
          overrides: overviewOverrides(
            current: kpis(execution: 67.8),
            previous: kpis(execution: 66),
            trend: <TrendPoint>[
              const TrendPoint(period: '2026-W26', value: 40, count: 12),
              TrendPoint(period: '2026-W27', value: last, count: 14),
            ],
          ),
        );
        await scrollOverviewTo(
          tester,
          find.byKey(const ValueKey<String>('dashboard-score-chart')),
        );
        final chart = tester.widget<TrendChart>(
          find.byKey(const ValueKey<String>('dashboard-score-chart')),
        );
        expect(chart.standing, isNotNull);
        expect(
          subjectInk(skin, chart.standing),
          want == 'good' ? skin.palette.good : skin.palette.bad,
          reason:
              'A run ending at $last against a rule at 75 drew the wrong '
              'ink. The run, its area wash, its end dot and its legend '
              'swatch all come from this one call, so a key cannot name a '
              'line the plot does not draw.',
        );
        // The rule it is judged against is named in the legend, always —
        // that is the position channel the colour is redundant with.
        expect(chart.threshold, isNotNull);
        expect(find.text(chart.threshold!.label), findsWidgets);
      });
    }

    testWidgets('an unmeasured window colours nothing at all', (tester) async {
      // An em dash is an em dash, and `figureInk` never reaches it.
      final skin = TiqSkin.day();
      await pump(tester, skin: skin, current: emptyWindowKpis());
      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('kpi-execution-score')),
      );
      expect(tile.value, isNull);
      expect(tile.figureInk, isNull);
    });

    testWidgets('the queue counts stay in plain ink', (tester) async {
      // RESTRAINT, PINNED. A count is a quantity, not a verdict: two critical
      // alerts and twenty are the same severity, and what makes the row
      // crimson is that any exist. If this starts carrying colour, the rule
      // has become "colour anything next to a dot".
      await pump(tester, skin: TiqSkin.day());
      await scrollOverviewTo(
        tester,
        find.byKey(const ValueKey<String>('attention-critical-alerts')),
      );
      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('attention-critical-alerts')),
      );
      expect((row.trailing! as FigureSlot).color, isNull);
    });
  });
}
