import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/chart/chart.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/features/assistant/view_specs/expanded_views.dart';

import '../../core/design/amber_golden.dart';
import '../../core/widgets/torchlight/torch_harness.dart' show torchSkins;
import 'artifact_harness.dart';

/// THE ASK TRADEIQ ARTIFACT VIEWER, on Torchlight.
///
/// The full-screen view behind a chat card: the same figures with the controls
/// the inline card deliberately leaves out, the table twin, and the export.

TorchFilterChip _chip(WidgetTester tester, String value) =>
    tester.widget<TorchFilterChip>(
      find.byKey(ValueKey<String>('artifact-filter-$value')),
    );

void main() {
  group('the frame', () {
    testWidgets('opens an artifact by id and names it after its tool', (
      tester,
    ) async {
      await pumpArtifact(tester, StubArtifactRepository(trendArtifact()));

      expect(find.text('Trend'), findsWidgets);
      expect(find.byType(TrendChart), findsOneWidget);
    });

    // Reachable by a link from someone else's conversation, where the reader
    // has none of the context the chat gave. A chart with no visible date
    // range is a support ticket waiting to happen.
    testWidgets('says which filters produced what is on screen', (
      tester,
    ) async {
      await pumpArtifact(tester, StubArtifactRepository(trendArtifact()));
      expect(
        find.textContaining('Month to date · daily buckets.'),
        findsOneWidget,
      );
    });

    testWidgets('a push from the conversation goes back to it', (
      tester,
    ) async {
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        pushed: true,
      );
      await tester.tap(find.byKey(const ValueKey<String>('artifact-back')));
      await tester.pumpAndSettle();
      expect(find.text('the conversation'), findsOneWidget);
    });

    testWidgets('a deep link goes to the console instead', (tester) async {
      await pumpArtifact(tester, StubArtifactRepository(trendArtifact()));

      final back = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('artifact-back')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(back.properties.label, 'Back to The Floor');

      await tester.tap(find.byKey(const ValueKey<String>('artifact-back')));
      await tester.pumpAndSettle();
      expect(find.text('the floor'), findsOneWidget);
    });

    testWidgets('a load failure keeps the server words and offers a retry', (
      tester,
    ) async {
      final repository = StubArtifactRepository(
        trendArtifact(),
        fetchFailure: 'That tool is not enabled for your account.',
      );
      await pumpArtifact(tester, repository);

      expect(find.text('That view could not be opened'), findsOneWidget);
      expect(
        find.text('That tool is not enabled for your account.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('artifact-retry')));
      await tester.pumpAndSettle();
      expect(find.byType(TrendChart), findsOneWidget);
    });
  });

  group('the filters', () {
    testWidgets('a change posts the whole params bag and no model call', (
      tester,
    ) async {
      final repository = StubArtifactRepository(trendArtifact());
      await pumpArtifact(tester, repository);

      await tapArtifactChip(tester, 'ytd');

      expect(repository.refinements, hasLength(1));
      // A whole bag, never a patch: the server validates the bag against the
      // tool's schema, and half of one is not a valid bag.
      expect(repository.refinements.single, <String, dynamic>{
        'metric': 'execution_score',
        'period': <String, dynamic>{'kind': 'ytd'},
        'interval': 'day',
      });
      expect(_chip(tester, 'ytd').selected, isTrue);
    });

    testWidgets('a comparison is a params change, not a question', (
      tester,
    ) async {
      final repository = StubArtifactRepository(trendArtifact());
      await pumpArtifact(tester, repository);

      await tapArtifactChip(tester, 'previous_period');

      expect(
        repository.refinements.single['compareTo'],
        <String, dynamic>{'kind': 'previous_period'},
      );
    });

    testWidgets('choosing None removes the key rather than sending null', (
      tester,
    ) async {
      final repository = StubArtifactRepository(
        trendArtifact(
          params: <String, dynamic>{
            'metric': 'execution_score',
            'period': <String, dynamic>{'kind': 'mtd'},
            'interval': 'day',
            'compareTo': <String, dynamic>{'kind': 'previous_period'},
          },
        ),
      );
      await pumpArtifact(tester, repository);

      await tapArtifactChip(tester, '');

      expect(repository.refinements.single.containsKey('compareTo'), isFalse);
    });

    // A control left sitting on a value the server rejected is a lie about
    // what the figures below it mean.
    testWidgets('a refused change rolls the control back and says why', (
      tester,
    ) async {
      final repository = StubArtifactRepository(trendArtifact())
        ..refuseWith = 'Year to date is longer than this tool will go back.';
      await pumpArtifact(tester, repository);

      await tapArtifactChip(tester, 'ytd');

      expect(
        find.text('Year to date is longer than this tool will go back.'),
        findsOneWidget,
      );
      // Rolled back to what the server actually holds: the header still names
      // the window the figures below it were measured over, and it is the one
      // the server kept rather than the one it refused.
      expect(find.textContaining('Month to date'), findsOneWidget);
      // The refusal's own words are the only place "Year to date" appears —
      // the header is not sitting on a window the server rejected.
      expect(find.textContaining('Year to date'), findsOneWidget);
      // And the refusal did not queue a second attempt.
      expect(repository.refinements, hasLength(1));
    });

    testWidgets('undo is offered only when there is something to undo', (
      tester,
    ) async {
      await pumpArtifact(tester, StubArtifactRepository(trendArtifact()));
      expect(find.byKey(const ValueKey<String>('artifact-undo')), findsNothing);

      final repository = StubArtifactRepository(trendArtifact(canUndo: true));
      await pumpArtifact(tester, repository);
      await tester.tap(find.byKey(const ValueKey<String>('artifact-undo')));
      await tester.pumpAndSettle();
      expect(repository.undos, 1);
    });

    // Offering a control for a param its tool never had would appear to work
    // and silently change nothing — the worst of the three outcomes.
    testWidgets('a trend offers no territory; a pillar view does', (
      tester,
    ) async {
      await pumpArtifact(tester, StubArtifactRepository(trendArtifact()));
      expect(
        find.byKey(const ValueKey<String>('artifact-territory')),
        findsNothing,
      );

      await pumpArtifact(
        tester,
        StubArtifactRepository(pillarArtifact()),
        territories: const <Territory>[
          Territory(id: 't1', name: 'Gauteng North', code: 'GP-N'),
        ],
      );
      expect(
        find.byKey(const ValueKey<String>('artifact-territory')),
        findsOneWidget,
      );
      // Not a granularity control: `getRateOfSale` has no interval.
      expect(
        find.byKey(const ValueKey<String>('artifact-filter-week')),
        findsNothing,
      );
    });

    testWidgets('the territory picker offers names, and scopes the view', (
      tester,
    ) async {
      final repository = StubArtifactRepository(pillarArtifact());
      await pumpArtifact(
        tester,
        repository,
        territories: const <Territory>[
          Territory(id: 't1', name: 'Gauteng North', code: 'GP-N'),
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('artifact-territory')),
      );
      await tester.pumpAndSettle();
      // The name a person says out loud, with the code beneath it. A picker
      // that offers uuids is a picker nobody can use.
      expect(find.text('Gauteng North'), findsWidgets);
      expect(find.text('GP-N'), findsWidgets);
      expect(find.text('t1'), findsNothing);

      await tester.tap(find.text('Gauteng North').last);
      await tester.pumpAndSettle();
      expect(repository.refinements.single['territoryId'], 't1');
    });

    // The artifact still works unscoped, so a failed territory list is a
    // missing control rather than a broken screen.
    testWidgets('a failed territory list leaves the view working', (
      tester,
    ) async {
      await pumpArtifact(
        tester,
        StubArtifactRepository(pillarArtifact()),
        territoriesFailure: Exception('territories down'),
      );

      expect(
        find.text('Territories are unavailable — showing the whole business.'),
        findsOneWidget,
      );
      // The rest of the screen is untouched: the period rail still works and
      // the figures are still there.
      expect(find.byType(TorchFilterChip), findsWidgets);
      expect(find.byType(ArtifactTableView), findsOneWidget);
    });

    testWidgets('says a filter is a re-query, not another question', (
      tester,
    ) async {
      await pumpArtifact(tester, StubArtifactRepository(trendArtifact()));
      expect(
        find.textContaining('It does not ask the assistant again.'),
        findsOneWidget,
      );
    });
  });

  group('the view', () {
    testWidgets('a comparison arrives as a second series with a legend', (
      tester,
    ) async {
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact(compared: true)),
      );

      final chart = tester.widget<TrendChart>(find.byType(TrendChart));
      expect(chart.series, hasLength(2));
      expect(chart.series.last.role, ChartSeriesRole.comparison);
      expect(chart.series.last.name, 'the month to date before this one');
      // The legend is not a parameter — a two-line chart with no key cannot
      // be written.
      expect(find.byType(ChartLegend), findsWidgets);
    });

    // `/trends` omits an empty bucket rather than sending a zero, and
    // interpolating across it draws a trend nobody measured.
    testWidgets('a bucket the server omitted breaks the stroke', (
      tester,
    ) async {
      await pumpArtifact(
        tester,
        StubArtifactRepository(
          trendArtifact(
            points: <Map<String, dynamic>>[
              <String, dynamic>{'period': '2026-08-01', 'value': 74.0},
              <String, dynamic>{'period': '2026-08-02'},
              <String, dynamic>{'period': '2026-08-03', 'value': 78.0},
            ],
          ),
        ),
      );

      final chart = tester.widget<TrendChart>(find.byType(TrendChart));
      expect(chart.series.first.readings, hasLength(3));
      expect(chart.series.first.readings[1].value, isNull);
      expect(chart.series.first.gaps, 1);
    });

    testWidgets('the toggle swaps the chart for its table twin', (
      tester,
    ) async {
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact(compared: true)),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('artifact-view-table')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TrendChart), findsNothing);
      expect(find.byType(ArtifactTableView), findsOneWidget);
    });

    testWidgets('the table twin carries the baseline and the change', (
      tester,
    ) async {
      await pumpArtifact(
        tester,
        StubArtifactRepository(pillarArtifact()),
      );

      expect(find.byType(ArtifactTableView), findsOneWidget);
      // "Up 5.1" and "88.0 → 93.1" answer different questions, and the table
      // is where the second one lives.
      expect(find.textContaining('93'), findsWidgets);
      expect(find.textContaining('88'), findsWidgets);
      expect(find.text('On-shelf availability'), findsOneWidget);
    });

    // A delta never stands beside nothing, and a percentage the server
    // declined to compute is said in words rather than as "n/a".
    testWidgets('an unchanged figure says no baseline rather than n/a', (
      tester,
    ) async {
      await pumpArtifact(tester, StubArtifactRepository(pillarArtifact()));
      // Share of shelf did not move and the server sent no percentage for it.
      expect(find.textContaining('n/a'), findsNothing);
      expect(find.text('no baseline'), findsOneWidget);
    });

    testWidgets('a trend with nothing in it says so and draws no plot', (
      tester,
    ) async {
      await pumpArtifact(
        tester,
        StubArtifactRepository(
          trendArtifact(points: const <Map<String, dynamic>>[]),
        ),
      );
      expect(find.byType(TrendChart), findsNothing);
      expect(find.text('No data in range'), findsOneWidget);
    });

    testWidgets('Veld draws the table, and offers no toggle', (tester) async {
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact(compared: true)),
        skin: TiqSkin.veld(),
      );

      expect(find.byType(TrendChart), findsNothing);
      expect(find.byType(ArtifactTableView), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('artifact-view-chart')),
        findsNothing,
      );
    });
  });

  group('the export', () {
    testWidgets('exports what is on screen, filters and figures included', (
      tester,
    ) async {
      final exporter = RecordingExporter();
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        exporter: exporter,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('artifact-export-pdf')),
      );
      await tester.pumpAndSettle();

      expect(exporter.request, isNotNull);
      // The VIEW's name — the metric it plots — not the tool's. The PDF
      // header and the rule above the chart come from one function so they
      // cannot drift into naming the same thing differently.
      expect(exporter.request!.title, 'Execution score');
      expect(
        exporter.request!.filters,
        contains('Month to date · daily buckets.'),
      );
      expect(exporter.request!.table, isNotNull);
      expect(exporter.filename, startsWith('tradeiq-execution-score-'));
      expect(exporter.filename, endsWith('.pdf'));
    });

    // The params it describes are the ones on screen, not the ones the
    // artifact happened to be created with.
    testWidgets('exports the params the user is actually looking at', (
      tester,
    ) async {
      final exporter = RecordingExporter();
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        exporter: exporter,
      );

      await tapArtifactChip(tester, 'yesterday');
      await tester.tap(
        find.byKey(const ValueKey<String>('artifact-export-pdf')),
      );
      await tester.pumpAndSettle();

      expect(exporter.request!.filters, contains('Yesterday'));
    });

    testWidgets('a failed export says so where every other failure is said', (
      tester,
    ) async {
      final exporter = RecordingExporter()..throwThis = StateError('no');
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        exporter: exporter,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('artifact-export-pdf')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('That view could not be exported. Please try again.'),
        findsOneWidget,
      );
    });

    // It fails identically on every retry, so telling the user to try again
    // sends them round a loop and whoever supports them into an investigation.
    testWidgets('a platform with nothing to share to is not told to retry', (
      tester,
    ) async {
      final exporter = RecordingExporter()
        ..throwThis = MissingPluginException('no printing plugin');
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        exporter: exporter,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('artifact-export-pdf')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('not available in this build'),
        findsOneWidget,
      );
      expect(find.textContaining('Please try again'), findsNothing);
    });

    testWidgets('there is nothing to export while the view will not open', (
      tester,
    ) async {
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact(), fetchFailure: 'gone'),
      );
      expect(find.byType(TorchPrimaryButton), findsNothing);
    });
  });

  group('across breakpoints', () {
    for (final (name, size) in const <(String, Size)>[
      ('a phone', Size(360, 1600)),
      ('at the breakpoint', Size(880, 1400)),
      ('just under it', Size(879, 1400)),
      ('a desktop window', Size(1600, 1200)),
      ('narrower than any phone', Size(240, 1600)),
    ]) {
      testWidgets('$name lays out and does not overflow', (tester) async {
        await pumpArtifact(
          tester,
          StubArtifactRepository(trendArtifact(compared: true)),
          size: size,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(TrendChart), findsOneWidget);
      });
    }
  });

  group('every control is operable by a screen reader', () {
    testWidgets('the rail, the picker, the undo, the export and the retry', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpArtifact(
        tester,
        StubArtifactRepository(pillarArtifact(canUndo: true)),
        territories: const <Territory>[
          Territory(id: 't1', name: 'Gauteng North', code: 'GP-N'),
        ],
      );
      expectEveryButtonActivatable(tester);

      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact(), fetchFailure: 'gone'),
      );
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });
  });

  group('the amber census, per phase × skin', () {
    for (final skin in torchSkins) {
      for (final phase in const <String>['loaded', 'unopenable']) {
        testWidgets('${skin.mode.name} · $phase', (tester) async {
          await pumpArtifact(
            tester,
            StubArtifactRepository(
              trendArtifact(),
              fetchFailure: phase == 'unopenable' ? 'gone' : null,
            ),
            skin: skin,
            size: const Size(400, 900),
          );

          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'artifact',
            phase: phase,
          );
          // The export is the route's one commit and its one light. With
          // nothing to export, no primary is built and every skin paints
          // zero.
          expect(
            census.objectCount,
            phase == 'loaded' ? 1 : 0,
            reason: census.describe(),
          );
        });
      }
    }
  });

  group('2.0× text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0× on a 320dp phone', (tester) async {
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact(compared: true, canUndo: true)),
        textScale: 2.0,
        size: const Size(320, 4000),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the viewer reads in Afrikaans', (tester) async {
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        locale: const Locale('af'),
      );

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Vandag'), findsWidgets);
      expect(find.text('Daagliks'), findsOneWidget);
      expect(find.text('Voer uit as ’n PDF'), findsOneWidget);
      expect(
        find.textContaining('Dit vra nie die assistent weer nie.'),
        findsOneWidget,
      );
      // And none of the English it replaced.
      expect(find.text('Today'), findsNothing);
      expect(find.text('Export as a PDF'), findsNothing);
    });
  });
}
