import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/assistant/data/artifact_repository.dart';
import 'package:tradeiq_app/features/assistant/export/artifact_exporter.dart';
import 'package:tradeiq_app/features/assistant/presentation/artifact_screen.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

export '../a11y_guard.dart'
    show expectEveryButtonActivatable, semanticsDump, semanticsNodes;
export 'package:tradeiq_app/features/assistant/data/artifact_repository.dart';
export 'package:tradeiq_app/features/assistant/export/artifact_exporter.dart';
export 'package:tradeiq_app/features/assistant/presentation/artifact_screen.dart';
export 'package:tradeiq_app/features/territories/data/territories_repository.dart'
    show Territory, territoriesListProvider;

/// Everything the Ask TradeIQ artifact viewer needs to stand up without a
/// server: a scripted repository that records what it was asked for, and an
/// exporter that records what would have been shared.

const String artifactId = '2b3f0d0e-1f2a-4c3b-9d4e-5f6a7b8c9d0e';

/// A repository that answers from a script and records what it was asked for.
class StubArtifactRepository implements ArtifactRepository {
  StubArtifactRepository(this.detail, {this.fetchFailure});

  ArtifactDetail? detail;

  /// Set to make the first `fetch` fail the way the server does.
  final String? fetchFailure;

  /// Set to make the next refine or undo fail the way the server does.
  String? refuseWith;

  final List<Map<String, dynamic>> refinements = <Map<String, dynamic>>[];
  int undos = 0;
  int fetches = 0;

  @override
  Future<ArtifactDetail> fetch(String id, {CancelToken? cancelToken}) async {
    fetches++;
    final failure = fetchFailure;
    if (failure != null && fetches == 1) {
      throw ArtifactRequestException(failure);
    }
    return detail!;
  }

  @override
  Future<ArtifactDetail> refine(
    String id,
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) async {
    refinements.add(params);
    final refusal = refuseWith;
    if (refusal != null) throw ArtifactRequestException(refusal);
    final current = detail!;
    detail = ArtifactDetail(
      id: current.id,
      type: current.type,
      toolName: current.toolName,
      params: params,
      data: current.data,
      canUndo: true,
    );
    return detail!;
  }

  @override
  Future<ArtifactDetail> undo(String id, {CancelToken? cancelToken}) async {
    undos += 1;
    final refusal = refuseWith;
    if (refusal != null) throw ArtifactRequestException(refusal);
    return detail!;
  }
}

ArtifactDetail trendArtifact({
  Map<String, dynamic>? params,
  bool compared = false,
  bool canUndo = false,
  List<Map<String, dynamic>>? points,
}) => ArtifactDetail(
  id: artifactId,
  type: 'trend_chart',
  toolName: 'getMetricTrend',
  params:
      params ??
      <String, dynamic>{
        'metric': 'execution_score',
        'period': <String, dynamic>{'kind': 'mtd'},
        'interval': 'day',
      },
  data: <String, dynamic>{
    'metric': 'execution_score',
    'interval': 'day',
    'points':
        points ??
        <Map<String, dynamic>>[
          <String, dynamic>{'period': '2026-08-01', 'value': 74.0},
          <String, dynamic>{'period': '2026-08-02', 'value': 78.0},
        ],
    if (compared)
      'comparison': <String, dynamic>{
        'label': 'the month to date before this one',
        'basis': <String, dynamic>{'kind': 'previous_period'},
        'points': <Map<String, dynamic>>[
          <String, dynamic>{'period': '2026-07-01', 'value': 70.0},
          <String, dynamic>{'period': '2026-07-02', 'value': 80.0},
        ],
      },
  },
  canUndo: canUndo,
);

/// A pillar view, which is a table and never a chart.
ArtifactDetail pillarArtifact({
  Map<String, dynamic>? params,
  bool compared = true,
  bool canUndo = false,
}) => ArtifactDetail(
  id: artifactId,
  type: 'pillar_metrics',
  toolName: 'getRateOfSale',
  canUndo: canUndo,
  params:
      params ??
      <String, dynamic>{'period': <String, dynamic>{'kind': 'mtd'}},
  // The pillar services answer with the figures at the TOP level and the
  // baseline under `comparison.values`, with the movement pre-computed in
  // `comparison.deltas` — the client never subtracts two numbers the server
  // already compared.
  data: <String, dynamic>{
    'osaPct': 93.1,
    'shareOfShelfPct': 41.2,
    if (compared)
      'comparison': <String, dynamic>{
        'label': 'the month before',
        'values': <String, dynamic>{'osaPct': 88.0, 'shareOfShelfPct': 41.2},
        'deltas': <String, dynamic>{
          'osaPct': <String, dynamic>{'absolute': 5.1, 'pct': 5.8},
          // The server declined to compute a percentage on an unchanged
          // figure rather than inventing one.
          'shareOfShelfPct': <String, dynamic>{'absolute': 0.0},
        },
      },
  },
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

/// Pump the artifact route, in [skin].
///
/// [pushed] drives it through a push from the conversation, which is how a
/// manager actually reaches it — and the only way to exercise the back
/// control's two identities.
Future<void> pumpArtifact(
  WidgetTester tester,
  StubArtifactRepository repository, {
  Size size = const Size(1400, 1600),
  RecordingExporter? exporter,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  bool pushed = false,
  List<Territory> territories = const <Territory>[],
  Object? territoriesFailure,
  List<Override> overrides = const <Override>[],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  TorchSheets.resetForTest();
  addTearDown(TorchSheets.resetForTest);

  final resolved = skin ?? TiqSkin.night();

  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('amber-golden-boundary'),
      child: ColoredBox(
        color: resolved.palette.ground,
        child: ProviderScope(
          // Riverpod 3 retries a failed provider on a backoff, so a repository
          // that always throws leaves a screen in `AsyncLoading` carrying an
          // error. One attempt here, so a designed error state is reachable.
          retry: (int count, Object error) => null,
          overrides: <Override>[
            artifactRepositoryProvider.overrideWithValue(repository),
            if (exporter != null)
              artifactExporterProvider.overrideWithValue(exporter),
            territoriesListProvider.overrideWith((ref) async {
              if (territoriesFailure != null) throw territoriesFailure;
              return territories;
            }),
            ...overrides,
          ],
          child: MaterialApp.router(
            theme: ThemeData(extensions: <ThemeExtension<dynamic>>[resolved]),
            locale: locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            localeListResolutionCallback: resolveAppLocale,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            routerConfig: GoRouter(
              initialLocation: pushed ? '/assistant' : '/artifact/$artifactId',
              routes: <GoRoute>[
                GoRoute(
                  path: '/artifact/:id',
                  builder: (context, state) =>
                      ArtifactScreen(artifactId: state.pathParameters['id']!),
                ),
                GoRoute(
                  path: '/assistant',
                  builder: (context, state) => const _Launcher(),
                ),
                GoRoute(
                  path: '/dashboard',
                  builder: (context, state) => const Text('the floor'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (pushed) {
    await tester.tap(find.byKey(const ValueKey<String>('open-full-view')));
    await tester.pumpAndSettle();
  }
}

/// The conversation a manager opens the full view from.
class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      key: const ValueKey<String>('open-full-view'),
      onPressed: () => context.push('/artifact/$artifactId'),
      child: const Text('the conversation'),
    ),
  );
}

/// Press the filter chip carrying [value], scrolling its rail into reach
/// first.
///
/// The rails bleed past the gutter by design — they are meant to visibly
/// continue — and they build only the chips in view, so in a 300dp control
/// column half the period vocabulary genuinely is off screen until a thumb
/// moves it. A test that widened the window to avoid the drag would be testing
/// a rail nobody has.
Future<void> tapArtifactChip(WidgetTester tester, String value) async {
  final chip = find.byKey(ValueKey<String>('artifact-filter-$value'));
  if (chip.evaluate().isEmpty) {
    final rails = find.byType(TorchFilterRail);
    for (var i = 0; i < rails.evaluate().length; i++) {
      final scrollable = find
          .descendant(of: rails.at(i), matching: find.byType(Scrollable))
          .first;
      for (var step = 0; step < 12 && chip.evaluate().isEmpty; step++) {
        await tester.drag(scrollable, const Offset(-120, 0));
        await tester.pumpAndSettle();
      }
      if (chip.evaluate().isNotEmpty) break;
    }
  }
  expect(
    chip,
    findsOneWidget,
    reason: 'no filter chip "$value" is reachable on this screen',
  );
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}
