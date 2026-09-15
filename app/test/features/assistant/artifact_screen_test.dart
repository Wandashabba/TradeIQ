import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/assistant/data/artifact_repository.dart';
import 'package:tradeiq_app/features/assistant/export/artifact_exporter.dart';
import 'package:tradeiq_app/features/assistant/presentation/artifact_screen.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

/// A repository that answers from a script and records what it was asked for.
class StubArtifactRepository implements ArtifactRepository {
  StubArtifactRepository(this.detail);

  ArtifactDetail detail;

  /// Set to make the next refine or undo fail the way the server does.
  String? refuseWith;

  final List<Map<String, dynamic>> refinements = [];
  int undos = 0;

  @override
  Future<ArtifactDetail> fetch(String id, {CancelToken? cancelToken}) async =>
      detail;

  @override
  Future<ArtifactDetail> refine(
    String id,
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) async {
    refinements.add(params);
    final refusal = refuseWith;
    if (refusal != null) throw ArtifactRequestException(refusal);
    detail = ArtifactDetail(
      id: detail.id,
      type: detail.type,
      toolName: detail.toolName,
      params: params,
      data: detail.data,
      canUndo: true,
    );
    return detail;
  }

  @override
  Future<ArtifactDetail> undo(String id, {CancelToken? cancelToken}) async {
    undos += 1;
    final refusal = refuseWith;
    if (refusal != null) throw ArtifactRequestException(refusal);
    return detail;
  }
}

ArtifactDetail trendArtifact({
  Map<String, dynamic>? params,
  bool compared = false,
  bool canUndo = false,
}) => ArtifactDetail(
  id: '2b3f0d0e-1f2a-4c3b-9d4e-5f6a7b8c9d0e',
  type: 'trend_chart',
  toolName: 'getMetricTrend',
  params:
      params ??
      {
        'metric': 'execution_score',
        'period': {'kind': 'mtd'},
        'interval': 'day',
      },
  data: {
    'metric': 'execution_score',
    'interval': 'day',
    'points': [
      {'period': '2026-08-01', 'value': 74.0},
      {'period': '2026-08-02', 'value': 78.0},
    ],
    if (compared)
      'comparison': {
        'label': 'the month to date before this one',
        'basis': {'kind': 'previous_period'},
        'points': [
          {'period': '2026-07-01', 'value': 70.0},
          {'period': '2026-07-02', 'value': 80.0},
        ],
      },
  },
  canUndo: canUndo,
);

/// Records what would have been shared, instead of reaching for the platform's
/// share sheet — which does not exist in a test binding.
class RecordingExporter implements ArtifactExporter {
  ArtifactExportRequest? request;
  String? filename;
  Object? throwThis;

  @override
  Future<void> export(
    ArtifactExportRequest request, {
    required String filename,
  }) async {
    this.request = request;
    this.filename = filename;
    if (throwThis != null) throw throwThis!;
  }
}

Future<void> pumpArtifact(
  WidgetTester tester,
  StubArtifactRepository repository, {
  Size size = const Size(1400, 1600),
  RecordingExporter? exporter,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    routedApp(
      const ArtifactScreen(artifactId: '2b3f0d0e-1f2a-4c3b-9d4e-5f6a7b8c9d0e'),
      theme: theme ?? AppTheme.dark(),
      overrides: [
        artifactRepositoryProvider.overrideWithValue(repository),
        if (exporter != null)
          artifactExporterProvider.overrideWithValue(exporter),
        // The territory control is not what these tests are about, and the real
        // provider would reach for the network.
        territoriesListProvider.overrideWith((ref) async => <Territory>[]),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens an artifact by id and draws it full size', (tester) async {
    await pumpArtifact(tester, StubArtifactRepository(trendArtifact()));

    expect(find.text('Execution score'), findsWidgets);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('says which filters produced what is on screen', (tester) async {
    // Reachable by link, so the reader may not have seen the question that
    // produced it. A chart with no visible date range is a support ticket.
    await pumpArtifact(tester, StubArtifactRepository(trendArtifact()));

    expect(
      find.textContaining('Month to date · daily buckets'),
      findsOneWidget,
    );
  });

  testWidgets('a filter change posts the whole params bag and no model call', (
    tester,
  ) async {
    // `refine` validates the bag against the tool's own schema — the same
    // contract the model writes through — so a partial patch is not a valid
    // params bag.
    final repository = StubArtifactRepository(trendArtifact());
    await pumpArtifact(tester, repository);

    await tester.tap(find.byKey(const ValueKey('artifact-filter-ytd')));
    await tester.pumpAndSettle();

    expect(repository.refinements, hasLength(1));
    expect(repository.refinements.single, {
      'metric': 'execution_score',
      'period': {'kind': 'ytd'},
      'interval': 'day',
    });
  });

  testWidgets('a comparison is asked for as a params change, not a question', (
    tester,
  ) async {
    final repository = StubArtifactRepository(trendArtifact());
    await pumpArtifact(tester, repository);

    await tester.tap(
      find.byKey(const ValueKey('artifact-filter-previous_period')),
    );
    await tester.pumpAndSettle();

    expect(repository.refinements.single['compareTo'], {
      'kind': 'previous_period',
    });
  });

  testWidgets('a refused change rolls the control back and says why', (
    tester,
  ) async {
    // The control must not sit on a value the server rejected: the figures
    // below it were computed with the old params, and leaving the two
    // disagreeing is a lie about what is on screen.
    final repository = StubArtifactRepository(trendArtifact())
      ..refuseWith = 'Those parameters are not valid for this view.';
    await pumpArtifact(tester, repository);

    await tester.tap(find.byKey(const ValueKey('artifact-filter-ytd')));
    await tester.pumpAndSettle();

    expect(
      find.text('Those parameters are not valid for this view.'),
      findsOneWidget,
    );
    // Still the period it was loaded with: the applied-filters sentence reads
    // what the FIGURES were computed with, not what the user tried.
    expect(find.text('Month to date · daily buckets.'), findsOneWidget);
    expect(find.textContaining('Year to date ·'), findsNothing);
  });

  testWidgets('undo is offered only when there is something to undo', (
    tester,
  ) async {
    await pumpArtifact(tester, StubArtifactRepository(trendArtifact()));
    expect(find.text('Undo'), findsNothing);

    await pumpArtifact(
      tester,
      StubArtifactRepository(trendArtifact(canUndo: true)),
    );
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
  });

  testWidgets('the comparison arrives as a second series, not a note', (
    tester,
  ) async {
    await pumpArtifact(
      tester,
      StubArtifactRepository(trendArtifact(compared: true)),
    );

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.comparison, hasLength(2));
    expect(chart.comparisonName, 'the month to date before this one');
  });

  testWidgets('the table twin carries a delta column, absolute and percent', (
    tester,
  ) async {
    // The rule charts.dart already states: no value may be reachable only by
    // hovering. The delta column is what the practitioner was building by hand
    // in Excel.
    await pumpArtifact(
      tester,
      StubArtifactRepository(trendArtifact(compared: true)),
    );

    await tester.tap(find.byKey(const ValueKey('artifact-view-table')));
    await tester.pumpAndSettle();

    // SectionLabel renders its header uppercase.
    expect(find.text('CHANGE'), findsOneWidget);
    // 74.0 against 70.0 — up 4, which is 5.7%.
    expect(find.text('5.7%'), findsOneWidget);
    // And the compared bucket is named, because the two series are aligned by
    // position rather than by date.
    expect(find.textContaining('1 Jul'), findsOneWidget);
  });

  testWidgets('a load failure explains itself and offers a retry', (
    tester,
  ) async {
    final repository = _FailingRepository();
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      routedApp(
        const ArtifactScreen(artifactId: 'gone'),
        theme: AppTheme.dark(),
        overrides: [artifactRepositoryProvider.overrideWithValue(repository)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('That view is no longer available.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  /// The Phase 2 gate's second item: real breakpoints, at real device sizes.
  ///
  /// One narrow case used to stand in for this whole group. It proved the
  /// stacked branch existed; it could not prove where the switch happens, that
  /// the other branch works, or that nothing overflows at either extreme —
  /// which are the three ways a responsive layout actually fails.
  ///
  /// The screen's own rule is one line: `constraints.maxWidth >= 880` puts the
  /// controls in a 300px side panel, below that they stack above the view.
  /// Everything here is stated against that number rather than against a
  /// vibe about what "tablet" means.
  group('across breakpoints', () {
    /// Side by side: the controls sit to the RIGHT of the view, tops aligned.
    void expectSidePanel(WidgetTester tester) {
      final filters = tester.getTopLeft(find.text('Filters'));
      final chart = tester.getTopLeft(find.byType(LineChart));
      expect(
        filters.dx,
        greaterThan(chart.dx),
        reason: 'controls should be in the right-hand panel',
      );
    }

    /// Stacked: the controls sit ABOVE the view. This is the phone's
    /// full-screen sheet in all but name.
    Future<void> expectStacked(WidgetTester tester) async {
      final chart = find.byType(LineChart);
      if (chart.evaluate().isEmpty) {
        // A short viewport puts the chart below the fold, and a ListView does
        // not build what it cannot show — so the chart genuinely does not
        // exist yet. Having to scroll DOWN from the top to reach it is itself
        // the proof that it sits below the controls, which is the claim.
        await tester.scrollUntilVisible(chart, 200);
        expect(chart, findsOneWidget);
        return;
      }
      expect(
        tester.getTopLeft(find.text('Filters')).dy,
        lessThan(tester.getTopLeft(chart).dy),
        reason: 'controls should stack above the view',
      );
    }

    /// What the artifact screen actually gets to lay out in.
    ///
    /// **Not the screen width.** `ManagerScaffold` puts a 232px nav rail and a
    /// 1px divider beside the body above 1080, so the `LayoutBuilder` inside
    /// this screen measures `screenWidth - 233` on desktop. Two breakpoints in
    /// two files compose, and only the product of them is visible to a user.
    double bodyWidthFor(double screenWidth) =>
        screenWidth >= 1080 ? screenWidth - 233 : screenWidth;

    // Real devices, not round numbers. A layout that works at 400 and 1200 and
    // breaks at 834 is a layout nobody tested on an iPad.
    const sizes = <String, Size>{
      'phone portrait (iPhone 14)': Size(390, 844),
      'phone landscape': Size(844, 390),
      // An iPad in portrait is 834 wide — below the 880 line, so stacked.
      'tablet portrait (iPad Air)': Size(834, 1112),
      // 1112 wide, and still stacked: the rail and divider take 233, leaving
      // 879. One pixel under. See the regression-window test below.
      'tablet landscape (iPad Air)': Size(1112, 834),
      'desktop': Size(1440, 900),
    };

    sizes.forEach((name, size) {
      testWidgets('$name lays out and does not overflow', (tester) async {
        await pumpArtifact(
          tester,
          StubArtifactRepository(trendArtifact(compared: true)),
          size: size,
        );

        // Derived from the composition rule rather than hand-written per row,
        // so the expectation cannot quietly drift from what the screen does.
        if (bodyWidthFor(size.width) >= 880) {
          expectSidePanel(tester);
        } else {
          await expectStacked(tester);
        }

        // The controls are reachable at every size — a layout that renders but
        // strands the export button has not worked.
        expect(find.text('Filters'), findsOneWidget);
        expect(find.byKey(const ValueKey('artifact-export-pdf')), findsOneWidget);

        // The assertion that catches the real bug. A RenderFlex overflow is an
        // exception here and a yellow-and-black stripe in front of a customer.
        // It found one: the chart legend, 113px over at phone portrait.
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('the nav rail can take the side panel away as the window WIDENS', (
      tester,
    ) async {
      // A known defect, pinned rather than asserted-as-correct, because the
      // shape of it is not obvious from either file alone.
      //
      // The artifact screen switches at 880 of BODY width. `ManagerScaffold`
      // claims 233px for its rail and divider above 1080 of SCREEN width. So:
      //
      //   1000 screen → 1000 body → side panel
      //   1080 screen →  847 body → STACKED   ← widened, and lost the panel
      //   1113 screen →  880 body → side panel again
      //
      // Widening a window must never remove a panel. Neither breakpoint is
      // wrong on its own, which is exactly why nothing caught it: the bug is
      // in the composition. Fixing it means moving one of the two numbers and
      // that is a design call, not a test fix — filed rather than guessed at.
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        size: const Size(1000, 900),
      );
      expectSidePanel(tester);

      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        size: const Size(1080, 900),
      );
      await expectStacked(tester);

      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        size: const Size(1113, 900),
      );
      expectSidePanel(tester);
    });

    testWidgets('switches layout exactly at 880, not near it', (tester) async {
      // Off-by-one at a breakpoint is the classic responsive bug, and it is
      // invisible unless a test sits on the boundary itself. `>= 880` means
      // 880 is wide and 879 is not.
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        size: const Size(879, 900),
      );
      await expectStacked(tester);

      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        size: const Size(880, 900),
      );
      expectSidePanel(tester);
    });

    testWidgets('survives a width narrower than any phone', (tester) async {
      // 320 is the floor the console's own design rules assume. Nothing has to
      // look good here; it has to not throw, because an overflow at the
      // narrowest supported width is the one users photograph.
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact(compared: true)),
        size: const Size(320, 700),
      );

      expect(find.text('Filters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PDF export', () {
    testWidgets('exports what is on screen, filters and figures included', (
      tester,
    ) async {
      final exporter = RecordingExporter();
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact(compared: true)),
        exporter: exporter,
      );

      await tester.tap(find.byKey(const ValueKey('artifact-export-pdf')));
      await tester.pumpAndSettle();

      final request = exporter.request!;
      expect(request.title, 'Execution score');
      // The applied filters travel with the report. A chart in a shared file
      // with no visible date range is a support ticket waiting to happen.
      expect(request.filters, contains('Month to date'));
      // The table twin's rows are the report's rows — one derivation, two
      // renderers, so the PDF cannot disagree with the screen it came from.
      expect(request.table!.rows, hasLength(2));
      expect(request.table!.compared, isTrue);
      expect(exporter.filename, startsWith('tradeiq-execution-score-'));
      expect(exporter.filename, endsWith('.pdf'));
    });

    testWidgets('exports the params the user is actually looking at', (
      tester,
    ) async {
      // Not the ones the artifact was created with: a report of a filter the
      // user changed two minutes ago would be a quiet lie.
      final exporter = RecordingExporter();
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        exporter: exporter,
      );

      await tester.tap(find.byKey(const ValueKey('artifact-filter-ytd')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('artifact-export-pdf')));
      await tester.pumpAndSettle();

      expect(exporter.request!.filters, contains('Year to date'));
    });

    testWidgets('a failed export says so where every other failure is said', (
      tester,
    ) async {
      final exporter = RecordingExporter()..throwThis = Exception('no printer');
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        exporter: exporter,
      );

      await tester.tap(find.byKey(const ValueKey('artifact-export-pdf')));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be exported'), findsOneWidget);
    });

    testWidgets('a platform with nothing to share to is not told to retry', (
      tester,
    ) async {
      // The failure that actually shipped: a stale web build registered every
      // plugin but `printing`, so `sharePdf` reached a method channel with
      // nothing behind it. Retrying that never once succeeds, so offering a
      // retry sends the user round a loop — the message has to say the build
      // is the problem.
      final exporter = RecordingExporter()
        ..throwThis = MissingPluginException('No implementation found');
      await pumpArtifact(
        tester,
        StubArtifactRepository(trendArtifact()),
        exporter: exporter,
      );

      await tester.tap(find.byKey(const ValueKey('artifact-export-pdf')));
      await tester.pumpAndSettle();

      expect(find.textContaining('not available in this build'), findsOneWidget);
      expect(find.textContaining('Please try again'), findsNothing);
    });
  });

  group('Lumen Glass (light)', () {
    Future<void> pumpLight(
      WidgetTester tester,
      StubArtifactRepository repository, {
      Size size = const Size(1400, 1600),
      RecordingExporter? exporter,
    }) => pumpArtifact(
      tester,
      repository,
      size: size,
      exporter: exporter,
      theme: AppTheme.light(),
    );

    GlassPane paneIn(WidgetTester tester, String key) =>
        tester.widget<GlassPane>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(GlassPane),
          ),
        );

    testWidgets('the period in force is the bright, accent-rimmed pill', (
      tester,
    ) async {
      await pumpLight(tester, StubArtifactRepository(trendArtifact()));

      final on = paneIn(tester, 'artifact-filter-mtd');
      final off = paneIn(tester, 'artifact-filter-ytd');
      expect(on.kind, GlassKind.pill);
      expect(on.rimColor, LumenPalette.light.accent);
      expect(on.shadow, isTrue);
      expect(off.rimColor, LumenPalette.light.pillRim);
      expect(off.shadow, isFalse);

      // Never the fill alone: the weight changes, and the state is announced.
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('artifact-filter-mtd')),
          matching: find.byType(Text),
        ),
      );
      expect(label.style!.fontWeight, FontWeight.w600);
      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('artifact-filter-mtd')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.selected, isTrue);
    });

    testWidgets('a pill still posts the whole params bag', (tester) async {
      final repository = StubArtifactRepository(trendArtifact());
      await pumpLight(tester, repository);

      await tester.tap(find.byKey(const ValueKey('artifact-filter-ytd')));
      await tester.pumpAndSettle();

      expect(repository.refinements.single['period'], {'kind': 'ytd'});
    });

    testWidgets('export is the glass primary action, and still exports', (
      tester,
    ) async {
      final exporter = RecordingExporter();
      await pumpLight(
        tester,
        StubArtifactRepository(trendArtifact(compared: true)),
        exporter: exporter,
      );

      final export = find.byKey(const ValueKey('artifact-export-pdf'));
      expect(tester.widget(export), isA<GlassPrimaryButton>());
      expect(find.text('Export PDF'), findsOneWidget);

      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(exporter.request!.title, 'Execution score');
    });

    testWidgets('the table twin: mono figures over white-rim dividers', (
      tester,
    ) async {
      await pumpLight(
        tester,
        StubArtifactRepository(trendArtifact(compared: true)),
      );

      await tester.tap(find.byKey(const ValueKey('artifact-view-table')));
      await tester.pumpAndSettle();

      // The view in force is the raised pill in the toggle.
      final segment = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('artifact-view-table')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (segment.decoration! as BoxDecoration).color,
        LumenPalette.light.pillFill,
      );

      expect(
        tester.widget<Text>(find.text('74')).style!.fontFamily,
        LumenGlass.mono,
      );
      expect(
        tester.widget<Text>(find.text('5.7%')).style!.fontFamily,
        LumenGlass.mono,
      );
      final row = tester.widget<Container>(
        find.ancestor(of: find.text('74'), matching: find.byType(Container)).first,
      );
      expect(
        ((row.decoration! as BoxDecoration).border! as Border).top.color,
        LumenPalette.light.white(0xB3),
      );
    });

    testWidgets('a refusal is words on an opaque crit wash that clears AA', (
      tester,
    ) async {
      final repository = StubArtifactRepository(trendArtifact())
        ..refuseWith = 'Those parameters are not valid for this view.';
      await pumpLight(tester, repository);

      await tester.tap(find.byKey(const ValueKey('artifact-filter-ytd')));
      await tester.pumpAndSettle();

      final words = find.text('Those parameters are not valid for this view.');
      final ink = tester.widget<Text>(words).style!.color!;
      final wash = (tester
                  .widget<Container>(
                    find
                        .ancestor(of: words, matching: find.byType(Container))
                        .first,
                  )
                  .decoration!
              as BoxDecoration)
          .color!;
      // Contrast is only honest measured against an opaque ground.
      expect(wash.a, 1.0);
      expect(contrastRatio(wash, ink), greaterThanOrEqualTo(4.5));
      // And the state carries a glyph, not only a colour.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('the applied filters read as a pill headed by a kicker', (
      tester,
    ) async {
      await pumpLight(tester, StubArtifactRepository(trendArtifact()));

      final sentence = find.text('Month to date · daily buckets.');
      expect(sentence, findsOneWidget);
      expect(
        tester
            .widget<GlassPane>(
              find.ancestor(of: sentence, matching: find.byType(GlassPane)).first,
            )
            .kind,
        GlassKind.pill,
      );
      expect(find.byType(Kicker), findsWidgets);
      expect(find.text('SHOWING'), findsOneWidget);
    });

    for (final size in const [Size(390, 844), Size(1440, 900)]) {
      testWidgets('lays out at ${size.width.toInt()} wide without overflow', (
        tester,
      ) async {
        await pumpLight(
          tester,
          StubArtifactRepository(trendArtifact(compared: true)),
          size: size,
        );

        expect(find.text('Filters'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a load failure explains itself on a glass panel', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        routedApp(
          const ArtifactScreen(artifactId: 'gone'),
          theme: AppTheme.light(),
          overrides: [
            artifactRepositoryProvider.overrideWithValue(_FailingRepository()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final message = find.text('That view is no longer available.');
      expect(
        tester
            .widget<GlassPane>(
              find.ancestor(of: message, matching: find.byType(GlassPane)).first,
            )
            .kind,
        GlassKind.panel,
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}

class _FailingRepository implements ArtifactRepository {
  @override
  Future<ArtifactDetail> fetch(String id, {CancelToken? cancelToken}) async =>
      throw const ArtifactRequestException('That view is no longer available.');

  @override
  Future<ArtifactDetail> refine(
    String id,
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) async =>
      throw const ArtifactRequestException('That view is no longer available.');

  @override
  Future<ArtifactDetail> undo(String id, {CancelToken? cancelToken}) async =>
      throw const ArtifactRequestException('That view is no longer available.');
}
