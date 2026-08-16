import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';
import 'package:tradeiq_app/features/assistant/data/artifact_repository.dart';
import 'package:tradeiq_app/features/assistant/export/artifact_exporter.dart';
import 'package:tradeiq_app/features/assistant/presentation/artifact_screen.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    routedApp(
      const ArtifactScreen(artifactId: '2b3f0d0e-1f2a-4c3b-9d4e-5f6a7b8c9d0e'),
      theme: AppTheme.dark(),
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

  testWidgets('stacks the controls above the view on a narrow screen', (
    tester,
  ) async {
    // Side panel on web and tablet; on a phone the same thing full-screen.
    await pumpArtifact(
      tester,
      StubArtifactRepository(trendArtifact()),
      size: const Size(420, 900),
    );

    final filters = tester.getTopLeft(find.text('Filters'));
    final chart = tester.getTopLeft(find.byType(LineChart));
    expect(filters.dy, lessThan(chart.dy));
    expect(tester.takeException(), isNull);
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
