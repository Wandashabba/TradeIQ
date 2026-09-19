import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/console.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/fraud/data/fraud_repository.dart';
import 'package:tradeiq_app/features/visits/data/visit_detail_repository.dart';
import 'package:tradeiq_app/features/visits/presentation/visit_detail_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;

final _submitted = VisitDetail(
  id: 'v1',
  status: 'submitted',
  outlet: const VisitOutletRef(
    id: 'o1',
    name: 'Spar Rosebank',
    code: 'SPR-001',
    channelType: 'supermarket',
  ),
  agent: const VisitAgentRef(id: 'a1', email: 'thandi@acme.test'),
  checkinTs: DateTime.utc(2026, 9, 14, 7),
  submittedAtClient: DateTime.utc(2026, 9, 14, 7, 14),
  geofencePass: true,
  distanceM: 44.5,
  score: const VisitScore(
    weightedTotal: 55.48,
    ratingBand: 'red',
    target: 85,
    dimensions: [
      ScoreDimension(key: 'availability', score: 90),
      ScoreDimension(key: 'pricing', score: 40),
      ScoreDimension(key: 'competitive', score: null),
    ],
  ),
  sections: const [
    VisitSectionSummary(
      key: 'stock',
      count: 2,
      flagged: 1,
      findings: [
        '1 of 2 SKUs out of stock',
        'Cola 330ml: out of stock, 5 days',
      ],
    ),
    VisitSectionSummary(key: 'visibility', count: 0, flagged: 0, findings: []),
    VisitSectionSummary(
      key: 'pricing',
      count: 3,
      flagged: 0,
      findings: ['0 of 3 prices more than 10% off master'],
    ),
    VisitSectionSummary(key: 'competitive', count: 0, flagged: 0, findings: []),
    VisitSectionSummary(
      key: 'risks',
      count: 1,
      flagged: 1,
      findings: ['critical: expired_stock, Two expired packs'],
    ),
  ],
  photoTotal: 1,
  photos: [
    VisitPhotoRef(
      id: 'p1',
      section: 'visibility',
      timestamp: DateTime.utc(2026, 9, 14, 7, 5),
    ),
  ],
  riskScore: 72,
  signals: const [
    FraudSignal(
      code: 'photo_gps_divergence',
      detail: "A photo's GPS tag is 500m from the check-in location",
    ),
  ],
);

final _draft = VisitDetail(
  id: 'v2',
  status: 'in_progress',
  outlet: const VisitOutletRef(
    id: 'o1',
    name: 'Spar Rosebank',
    code: 'SPR-001',
    channelType: 'supermarket',
  ),
  agent: const VisitAgentRef(id: 'a1', email: 'thandi@acme.test'),
  checkinTs: DateTime.utc(2026, 9, 14, 7),
  submittedAtClient: null,
  geofencePass: false,
  distanceM: 61,
  score: null,
  sections: const [],
  photoTotal: 0,
  photos: const [],
  riskScore: 0,
  signals: const [],
);

class _Repo implements VisitDetailRepository {
  _Repo(this.result);
  final FutureOr<VisitDetail> Function(String id) result;
  int calls = 0;

  @override
  Future<VisitDetail> fetch(String visitId) async {
    calls++;
    return result(visitId);
  }
}

/// A real, decodable image (1×1 transparent PNG) for the thumbnails.
final _pngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _Photos implements PhotosRepository {
  final requested = <String>[];

  @override
  Future<Uint8List> thumbnailBytes(String photoId) async {
    requested.add(photoId);
    return _pngBytes;
  }

  @override
  Future<List<VisitPhoto>> listPhotos(String visitId) async => const [];

  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
    String? source,
  }) => throw UnimplementedError();

  @override
  Future<String> uploadMessageAttachment(String dataUrl) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> imageBytes(String photoId) async =>
      throw UnimplementedError();
}

Widget _app(
  VisitDetailRepository repo, {
  required ThemeData theme,
  PhotosRepository? photos,
  String visitId = 'v1',
}) => ProviderScope(
  overrides: [
    visitDetailRepositoryProvider.overrideWithValue(repo),
    photosRepositoryProvider.overrideWithValue(photos ?? _Photos()),
  ],
  child: MaterialApp.router(
    theme: theme,
    routerConfig: GoRouter(
      initialLocation: '/visits/$visitId',
      routes: [
        GoRoute(
          path: '/visits/:id',
          builder: (context, state) =>
              VisitDetailScreen(visitId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/alerts',
          builder: (context, state) => const Text('alerts list'),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const Text('dashboard'),
        ),
      ],
    ),
  ),
);

/// Big enough that the lazy ListView builds every panel.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final _themes = <String, ThemeData Function()>{
  'light': AppTheme.light,
  'dark': AppTheme.dark,
};

void main() {
  for (final entry in _themes.entries) {
    group('${entry.key} theme', () {
      testWidgets('header, score, sections, photos and fraud render as '
          'glass panels', (tester) async {
        _tallView(tester);
        final photos = _Photos();
        await tester.pumpWidget(
          _app(_Repo((_) => _submitted), theme: entry.value(), photos: photos),
        );
        await tester.pumpAndSettle();

        // Header: outlet, code, agent, when, status.
        expect(find.text('Spar Rosebank'), findsOneWidget);
        expect(find.text('SPR-001'), findsOneWidget);
        expect(find.text('thandi@acme.test'), findsOneWidget);
        expect(find.text('44.5 m'), findsOneWidget);
        expect(find.text('14 min on site'), findsOneWidget);

        // Every block is a pane of glass, in both themes.
        for (final key in [
          'visit-header',
          'visit-score',
          'visit-section-stock',
          'visit-section-risks',
          'visit-photos',
          'visit-fraud',
        ]) {
          final pane = find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(GlassPane),
          );
          final self = find.byKey(ValueKey(key));
          expect(
            tester.widgetList(self).first is GlassPane ||
                pane.evaluate().isNotEmpty,
            isTrue,
            reason: '$key is a glass panel',
          );
        }
        expect(find.byType(PanelCard), findsNWidgets(7)); // 5 sections + 2

        // The score as a mono figure with an explicit ink.
        final figure = tester.widget<Text>(
          find.byKey(const ValueKey('visit-score-figure')),
        );
        expect(figure.data, '55');
        expect(figure.style!.fontFamily, LumenGlass.mono);
        expect(figure.style!.color, isNotNull);

        // Photos are thumbnails fetched by id — the only bytes on the screen.
        expect(find.byKey(const ValueKey('visit-photo-p1')), findsOneWidget);
        expect(photos.requested, ['p1']);
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('every status is a word', (tester) async {
        _tallView(tester);
        await tester.pumpWidget(
          _app(_Repo((_) => _submitted), theme: entry.value()),
        );
        await tester.pumpAndSettle();

        for (final word in [
          'SUBMITTED',
          'INSIDE FENCE',
          '✕ GAP', // the `red` band on the wire, marked and spelled out
          'ON TARGET',
          'BELOW TARGET',
          'NOT MEASURED',
          '1 FLAGGED',
          'NOT CAPTURED',
          'CLEAR',
          'HIGH RISK', // riskScore 72
        ]) {
          expect(find.text(word), findsWidgets, reason: word);
        }
        // A flagged risk is crit; a flagged stock row is warn.
        LumenStatus pillIn(String key) => tester
            .widget<LumenStatusPill>(
              find.descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(LumenStatusPill),
              ),
            )
            .status;
        expect(pillIn('visit-section-risks'), LumenStatus.crit);
        expect(pillIn('visit-section-stock'), LumenStatus.warn);
        expect(pillIn('visit-section-pricing'), LumenStatus.good);
        expect(pillIn('visit-section-visibility'), LumenStatus.none);
      });

      testWidgets('every word clears AA (4.5:1)', (tester) async {
        _tallView(tester);
        final theme = entry.value();
        await tester.pumpWidget(_app(_Repo((_) => _submitted), theme: theme));
        await tester.pumpAndSettle();

        final colors = theme.extension<TiqColors>()!;
        // Status pills: the word on its own wash, over the pane.
        final pills = tester.widgetList<LumenStatusPill>(
          find.byType(LumenStatusPill),
        );
        expect(pills, isNotEmpty);
        for (final pill in pills) {
          final sw = pill.status.swatchOf(colors);
          final ground = Color.alphaBlend(sw.tint, colors.surface1);
          final ratio = contrastRatio(sw.ink, ground);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${pill.label} is $ratio:1',
          );
        }

        // Every other word in the body, on the pane it sits on.
        final body = find.byKey(const ValueKey('visit-header'));
        expect(body, findsOneWidget);
        final texts = tester.widgetList<Text>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Text),
          ),
        );
        var checked = 0;
        for (final t in texts) {
          final color = t.style?.color;
          if (color == null || color.a < 1) continue;
          // Pills are measured above against their own wash.
          if (pills.any((p) => (p.label ?? '').toUpperCase() == t.data)) {
            continue;
          }
          for (final ground in [colors.surface1, colors.surface2]) {
            final ratio = contrastRatio(color, ground);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason: '"${t.data}" is $ratio:1',
            );
          }
          checked++;
        }
        expect(checked, greaterThan(20));
      });
    });
  }

  testWidgets('a draft: in progress, not scored, no fraud panel', (
    tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(
      _app(_Repo((_) => _draft), theme: AppTheme.light(), visitId: 'v2'),
    );
    await tester.pumpAndSettle();

    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('NOT SCORED'), findsOneWidget);
    expect(find.text('OUTSIDE FENCE'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);
    expect(
      find.text('The score is calculated when the visit is submitted.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('visit-fraud')), findsNothing);
    expect(find.text('No photos were captured on this visit.'), findsOneWidget);
  });

  testWidgets('outside the fence because the agent said the pin is wrong '
      '(#386): the reason is beside the failed fence', (tester) async {
    _tallView(tester);
    final flagged = VisitDetail(
      id: 'v4',
      status: 'in_progress',
      outlet: _draft.outlet,
      agent: _draft.agent,
      checkinTs: _draft.checkinTs,
      submittedAtClient: null,
      geofencePass: false,
      distanceM: 8400,
      score: null,
      sections: const [],
      photoTotal: 0,
      photos: const [],
      riskScore: 30,
      signals: const [],
      pinDispute: const VisitPinDispute(
        id: 'd1',
        distanceM: 8400,
        status: 'open',
        note: 'Pinned on the depot',
      ),
    );
    await tester.pumpWidget(
      _app(_Repo((_) => flagged), theme: AppTheme.light(), visitId: 'v4'),
    );
    await tester.pumpAndSettle();

    // Still OUTSIDE FENCE — the claim explains the failure, it never
    // replaces it.
    expect(find.text('OUTSIDE FENCE'), findsOneWidget);
    expect(find.byKey(const ValueKey('visit-pin-dispute')), findsOneWidget);
    expect(find.text('Agent reported it wrong'), findsOneWidget);
    expect(
      find.text('Waiting for review · "Pinned on the depot"'),
      findsOneWidget,
    );
  });

  testWidgets('an ordinary out-of-fence visit carries no claim', (
    tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(
      _app(_Repo((_) => _draft), theme: AppTheme.light(), visitId: 'v2'),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visit-pin-dispute')), findsNothing);
  });

  testWidgets('loading shows a spinner, not a stale or empty screen', (
    tester,
  ) async {
    final pending = Completer<VisitDetail>();
    await tester.pumpWidget(
      _app(_Repo((_) => pending.future), theme: AppTheme.light()),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('visit-header')), findsNothing);

    pending.complete(_submitted);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visit-header')), findsOneWidget);
  });

  for (final entry in _themes.entries) {
    testWidgets('${entry.key}: not found says so, with a way back', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _Repo((id) => throw VisitNotFoundException(id)),
          theme: entry.value(),
          visitId: 'gone',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('visit-not-found')), findsOneWidget);
      expect(find.text('NOT FOUND'), findsOneWidget);
      expect(
        find.text(
          'This visit does not exist, or it belongs to another client.',
        ),
        findsOneWidget,
      );
      // Not the generic error: no Retry for a visit that will not appear.
      expect(find.text('Retry'), findsNothing);
      // A deep link has nothing to pop to, so the console is offered.
      expect(
        find.byKey(const ValueKey('visit-detail-console')),
        findsOneWidget,
      );

      await tester.tap(find.text('Back to alerts'));
      await tester.pumpAndSettle();
      expect(find.text('alerts list'), findsOneWidget);
    });
  }

  testWidgets('an error says so in words and retries', (tester) async {
    var fail = true;
    final repo = _Repo((_) {
      if (fail) throw Exception('boom');
      return _submitted;
    });
    _tallView(tester);
    await tester.pumpWidget(_app(repo, theme: AppTheme.dark()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load visit'), findsOneWidget);
    expect(find.byKey(const ValueKey('visit-not-found')), findsNothing);

    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.text('Spar Rosebank'), findsOneWidget);
  });

  test('formatVisitTime reads as a date and a clock', () {
    final local = DateTime(2026, 9, 4, 8, 5);
    expect(formatVisitTime(local), '4 Sep 2026, 08:05');
  });
}
