import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/fraud/data/fraud_repository.dart';
import 'package:tradeiq_app/features/visits/data/visit_detail_repository.dart';
import 'package:tradeiq_app/features/visits/presentation/visit_detail_screen.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

export '../a11y_guard.dart'
    show expectEveryButtonActivatable, semanticsDump, semanticsNodes;
export 'package:tradeiq_app/features/fraud/data/fraud_repository.dart'
    show FraudSignal;
export 'package:tradeiq_app/features/visits/data/visit_detail_repository.dart';
export 'package:tradeiq_app/features/visits/presentation/visit_detail_screen.dart';

/// Everything the manager's visit review needs to stand up without a server.
///
/// The fake is the **repository**, never the view provider above it, so the
/// not-found branch, the draft/submitted split and the score's own nullability
/// are all exercised for real.

// ── Fixtures ──────────────────────────────────────────────────────────

VisitDetail submittedVisit({
  VisitScore? score = const VisitScore(
    weightedTotal: 55.48,
    ratingBand: 'red',
    target: 85,
    dimensions: <ScoreDimension>[
      ScoreDimension(key: 'availability', score: 90),
      ScoreDimension(key: 'pricing', score: 40),
      ScoreDimension(key: 'competitive', score: null),
    ],
  ),
  bool geofencePass = true,
  double? distanceM = 44.5,
  VisitPinDispute? pinDispute,
  List<VisitSectionSummary> sections = const <VisitSectionSummary>[
    VisitSectionSummary(
      key: 'stock',
      count: 2,
      flagged: 1,
      findings: <String>[
        '1 of 2 SKUs out of stock',
        'Cola 330ml: out of stock, 5 days',
      ],
    ),
    VisitSectionSummary(
      key: 'visibility',
      count: 0,
      flagged: 0,
      findings: <String>[],
    ),
    VisitSectionSummary(
      key: 'pricing',
      count: 3,
      flagged: 0,
      findings: <String>['0 of 3 prices more than 10% off master'],
    ),
    VisitSectionSummary(
      key: 'competitive',
      count: 0,
      flagged: 0,
      findings: <String>[],
    ),
    VisitSectionSummary(
      key: 'risks',
      count: 1,
      flagged: 1,
      findings: <String>['critical: expired_stock, Two expired packs'],
    ),
  ],
  int photoTotal = 1,
  List<VisitPhotoRef>? photos,
  double riskScore = 72,
  List<FraudSignal> signals = const <FraudSignal>[
    FraudSignal(
      code: 'photo_gps_divergence',
      detail: "A photo's GPS tag is 500m from the check-in location",
    ),
  ],
  List<VisitTemplateAnswers> templateResponses =
      const <VisitTemplateAnswers>[],
}) => VisitDetail(
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
  geofencePass: geofencePass,
  distanceM: distanceM,
  pinDispute: pinDispute,
  score: score,
  sections: sections,
  photoTotal: photoTotal,
  photos:
      photos ??
      <VisitPhotoRef>[
        VisitPhotoRef(
          id: 'p1',
          section: 'visibility',
          timestamp: DateTime.utc(2026, 9, 14, 7, 5),
        ),
      ],
  riskScore: riskScore,
  signals: signals,
  templateResponses: templateResponses,
);

/// A visit still open on the agent's phone: no score, no sections, no photos.
VisitDetail draftVisit() => VisitDetail(
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
  sections: const <VisitSectionSummary>[],
  photoTotal: 0,
  photos: const <VisitPhotoRef>[],
  riskScore: 0,
  signals: const <FraudSignal>[],
);

// ── Fakes ─────────────────────────────────────────────────────────────

class FakeVisitDetailRepository implements VisitDetailRepository {
  FakeVisitDetailRepository({this.detail, this.failure, this.pending = false});

  final VisitDetail? detail;
  final Object? failure;
  final bool pending;
  int calls = 0;

  @override
  Future<VisitDetail> fetch(String visitId) async {
    calls++;
    if (pending) return Completer<VisitDetail>().future;
    if (failure != null) throw failure!;
    return detail!;
  }
}

/// A real, decodable 1×1 transparent PNG, so an evidence thumb renders bytes
/// rather than its empty outline.
final Uint8List pngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class FakePhotosRepository implements PhotosRepository {
  final List<String> requested = <String>[];

  @override
  Future<Uint8List> thumbnailBytes(String photoId) async {
    requested.add(photoId);
    return pngBytes;
  }

  @override
  Future<List<VisitPhoto>> listPhotos(String visitId) async =>
      const <VisitPhoto>[];

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

// ── The pump ──────────────────────────────────────────────────────────

/// Pump the visit review at [visitId], in [skin].
///
/// [pushed] drives the route through a push from a list, which is how a
/// manager actually reaches it — and the only way to exercise the back
/// control's two identities.
Future<void> pumpVisit(
  WidgetTester tester, {
  VisitDetail? detail,
  Object? failure,
  bool pending = false,
  String visitId = 'v1',
  TiqSkin? skin,
  Size size = const Size(400, 2400),
  double textScale = 1.0,
  Locale? locale,
  bool pushed = false,
  PhotosRepository? photos,
  List<Override> overrides = const <Override>[],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  TorchSheets.resetForTest();
  addTearDown(TorchSheets.resetForTest);

  final resolved = skin ?? TiqSkin.night();
  final router = GoRouter(
    initialLocation: pushed ? '/alerts' : '/visits/$visitId',
    routes: <GoRoute>[
      GoRoute(
        path: '/visits/:id',
        builder: (context, state) =>
            VisitDetailScreenFinder(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/alerts',
        builder: (context, state) => _Launcher(visitId: visitId),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const Text('the floor'),
      ),
    ],
  );

  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('amber-golden-boundary'),
      child: ColoredBox(
        color: resolved.palette.ground,
        child: ProviderScope(
          // Riverpod 3 retries a failed provider on a backoff, so a repository
          // that always throws leaves the screen in `AsyncLoading` carrying an
          // error — a skeleton, for ever. One attempt here, so the designed
          // error state is what a failed fetch renders.
          retry: (int count, Object error) => null,
          overrides: <Override>[
            visitDetailRepositoryProvider.overrideWithValue(
              FakeVisitDetailRepository(
                detail: detail,
                failure: failure,
                pending: pending,
              ),
            ),
            photosRepositoryProvider.overrideWithValue(
              photos ?? FakePhotosRepository(),
            ),
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
            routerConfig: router,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (pushed) {
    await tester.tap(find.byKey(const ValueKey<String>('open-the-visit')));
    await tester.pumpAndSettle();
  }
}

/// The list a manager pushes the visit from.
class _Launcher extends StatelessWidget {
  const _Launcher({required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      key: const ValueKey<String>('open-the-visit'),
      onPressed: () => context.push('/visits/$visitId'),
      child: const Text('the alerts list'),
    ),
  );
}

/// A thin wrapper so the harness can name the screen without every test file
/// importing the screen's own library twice.
class VisitDetailScreenFinder extends StatelessWidget {
  const VisitDetailScreenFinder({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => VisitDetailScreen(visitId: id);
}
