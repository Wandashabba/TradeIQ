import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/floor_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

/// Everything The Floor's tests need to stand a screen up without a server.
///
/// The fakes override **repositories**, never the providers above them, so the
/// merge, the ranking, the phase decision and the sample-size plumbing are all
/// exercised for real. A test that overrode `floorViewProvider` would prove
/// only that a widget can render a record.

// ── Fixture builders ──────────────────────────────────────────────────

/// A measured window. `totals` is what makes it measured — not the figures.
DashboardKpis kpis({
  double osa = 61,
  double execution = 72,
  double priceCompliance = 0,
  int? osaSample = 240,
  int? executionSample = 18,
  int visits = 42,
  int outletsVisited = 33,
  int outletsTotal = 42,
}) => DashboardKpis(
  numericDistribution: 0,
  weightedDistribution: 0,
  osaPct: osa,
  executionScore: execution,
  priceCompliancePct: priceCompliance,
  visibilityCompliancePct: 0,
  shareOfShelf: 0,
  perfectStoreRate: 0,
  sampleSizes: DashboardSampleSizes(
    osaPct: osaSample,
    executionScore: executionSample,
  ),
  visits: visits,
  outletsVisited: outletsVisited,
  outletsTotal: outletsTotal,
);

/// A tenant with outlets and no visits in this window. NOT first-run.
DashboardKpis emptyWindowKpis({int outletsTotal = 42}) => DashboardKpis(
  numericDistribution: 0,
  weightedDistribution: 0,
  osaPct: 0,
  executionScore: 0,
  priceCompliancePct: 0,
  visibilityCompliancePct: 0,
  shareOfShelf: 0,
  perfectStoreRate: 0,
  visits: 0,
  outletsVisited: 0,
  outletsTotal: outletsTotal,
);

/// A brand-new tenant: nothing on the books at all.
DashboardKpis firstRunKpis() => emptyWindowKpis(outletsTotal: 0);

AlertItem alert({
  String id = 'a1',
  String severity = 'critical',
  String message = 'Out of stock since Tuesday',
  String outletId = 'o1',
  String? photoId,
  String? visitId,
  DateTime? createdAt,
  bool noTime = false,
}) => AlertItem(
  id: id,
  metric: 'out_of_stock',
  message: message,
  severity: severity,
  acknowledged: false,
  outletId: outletId,
  visitId: visitId,
  evidencePhotoId: photoId,
  createdAt: noTime ? null : (createdAt ?? DateTime.utc(2026, 9, 18, 6, 40)),
);

TaskItem task({
  String id = 't1',
  String priority = 'high',
  String fix = 'Restock the end cap',
  String outletId = 'o2',
  DateTime? createdAt,
}) => TaskItem(
  id: id,
  findingType: 'stockout',
  requiredFix: fix,
  priority: priority,
  status: 'open',
  closureVerified: false,
  outletId: outletId,
  slaDueAt: DateTime.utc(2026, 9, 20),
  createdAt: createdAt ?? DateTime.utc(2026, 9, 18, 9),
);

Outlet outlet(String id, String name) =>
    Outlet(id: id, name: name, code: id.toUpperCase(), lat: 0, lng: 0);

// ── Fakes ─────────────────────────────────────────────────────────────

class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({DashboardKpis? current, this.previous})
    : current = current ?? kpis();

  final DashboardKpis current;
  final DashboardKpis? previous;

  /// The console asks twice — this window and the one before it — and the
  /// second answer is where a thin BASELINE comes from.
  var _calls = 0;

  @override
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  }) async {
    _calls++;
    if (_calls == 1) return current;
    if (previous == null) throw StateError('no previous window');
    return previous!;
  }

  @override
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({
    String? from,
    String? to,
  }) async => const <TerritoryDashboardKpis>[];
}

class FakeAlertsRepository implements AlertsRepository {
  FakeAlertsRepository([this.alerts = const <AlertItem>[]]);

  final List<AlertItem> alerts;

  @override
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async => PaginatedResponse(data: alerts, nextCursor: null);

  @override
  Future<AlertItem> acknowledge(String id) async => throw UnimplementedError();
}

class FakeTasksRepository implements TasksAdminRepository {
  FakeTasksRepository([this.tasks = const <TaskItem>[]]);

  final List<TaskItem> tasks;

  @override
  Future<PaginatedResponse<TaskItem>> listTasks({
    String? status,
    String? priority,
    String? outletId,
  }) async => PaginatedResponse(data: tasks, nextCursor: null);

  @override
  Future<TaskItem> closeTask({
    required String id,
    required String closurePhotoUrl,
  }) async => throw UnimplementedError();

  @override
  Future<TaskItem> verifyTask(String id) async => throw UnimplementedError();
}

class FakeOutletsRepository implements OutletsRepository {
  FakeOutletsRepository([this.outlets = const <Outlet>[]]);

  final List<Outlet> outlets;

  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async => PaginatedResponse(data: outlets, nextCursor: null);

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) async => throw UnimplementedError();
}

class FakeTerritoriesRepository implements TerritoriesRepository {
  FakeTerritoriesRepository([this.territories = const <Territory>[]]);

  final List<Territory> territories;

  @override
  Future<PaginatedResponse<Territory>> listTerritories() async =>
      PaginatedResponse(data: territories, nextCursor: null);

  @override
  Future<TerritoryCoverage> getCoverage(String id) async =>
      throw UnimplementedError();

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async => throw UnimplementedError();

  @override
  Future<void> assignAgent(String territoryId, String userId) async =>
      throw UnimplementedError();
}

/// Hands back bytes for any photo id, or throws — which is how the
/// missing-photo test drives the plate to its fallback through the real code
/// path rather than by passing null.
class FakePhotosRepository implements PhotosRepository {
  FakePhotosRepository({this.bytes, this.fail = false});

  final Uint8List? bytes;
  final bool fail;

  @override
  Future<Uint8List> thumbnailBytes(String photoId) async {
    if (fail || bytes == null) throw StateError('no photo');
    return bytes!;
  }

  @override
  Future<Uint8List> imageBytes(String photoId) => thumbnailBytes(photoId);

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
  }) async => throw UnimplementedError();

  @override
  Future<String> uploadMessageAttachment(String dataUrl) async =>
      throw UnimplementedError();
}

// ── An image a widget test can actually paint ─────────────────────────

/// A real decoded [ui.Image] wrapped as a provider that completes on the first
/// frame, synchronously.
///
/// `Image.memory` in a widget test decodes on the engine's clock, which the
/// fake clock does not drive: the frame the census measures would arrive after
/// the assertion. This resolves in the same frame, so the plate under test is
/// the plate a user meets.
class SyncImage extends ImageProvider<SyncImage> {
  SyncImage(this.image);

  final ui.Image image;

  static Future<SyncImage> solid(
    WidgetTester tester, {
    Color color = const Color(0xFF808080),
    int size = 8,
  }) async {
    final made = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        Paint()..color = color,
      );
      return recorder.endRecording().toImage(size, size);
    });
    return SyncImage(made!);
  }

  /// THE SEEDED DEV DATA'S SHELF PHOTO, rebuilt pixel for pixel.
  ///
  /// `backend/scripts/seed/photos.ts` draws four shelves of randomly sized,
  /// **randomly and fully coloured** product blocks from a mulberry32 PRNG —
  /// the same generator and the same layout are reproduced here, so the
  /// fixture is the photograph the owner was actually looking at when they
  /// said the plate was a rainbow, and not a polite approximation of it.
  ///
  /// It is deliberately the worst case a plate can be handed: unlike a shop
  /// shelf, every block is a fully saturated random colour.
  static Future<SyncImage> seededShelf(
    WidgetTester tester, {
    int seed = 7,
    int width = 160,
    int height = 120,
  }) async {
    var a = (seed * 2654435761) & 0xFFFFFFFF;
    double rnd() {
      a = (a + 0x6d2b79f5) & 0xFFFFFFFF;
      var t = a;
      t = ((t ^ (t >>> 15)) * (t | 1)) & 0xFFFFFFFF;
      t ^= (t + ((t ^ (t >>> 7)) * (t | 61))) & 0xFFFFFFFF;
      return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
    }

    const rows = 4;
    final made = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final rowHeight = height / rows;
      // The seed writes a raw RGB buffer: every pixel opaque, every edge hard.
      // Reproduce that, or the antialiased edges of these rects come back
      // part-transparent, the Night `well` shows through them, and the test
      // would be measuring the ground's own colour cast instead of the plate's.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()
          ..color = const Color(0xFFEBEBE4)
          ..isAntiAlias = false,
      );
      for (var row = 0; row < rows; row++) {
        var x = 0.0;
        while (x < width) {
          final blockWidth = 6 + (rnd() * 22).floor();
          final colour = Color.fromARGB(
            255,
            (rnd() * 256).floor().clamp(0, 255),
            (rnd() * 256).floor().clamp(0, 255),
            (rnd() * 256).floor().clamp(0, 255),
          );
          final top = (row * rowHeight + rnd() * rowHeight * 0.35).floorToDouble();
          final bottom = ((row + 1) * rowHeight).floorToDouble() - 4;
          // The shelf board, the product, and the back of the shelf.
          canvas
            ..drawRect(
              Rect.fromLTRB(
                x,
                (row * rowHeight).floorToDouble(),
                x + blockWidth,
                ((row + 1) * rowHeight).floorToDouble(),
              ),
              Paint()
                ..color = const Color(0xFFEBEBE4)
                ..isAntiAlias = false,
            )
            ..drawRect(
              Rect.fromLTRB(top < bottom ? x : x, top, x + blockWidth - 1, bottom),
              Paint()
                ..color = colour
                ..isAntiAlias = false,
            )
            ..drawRect(
              Rect.fromLTRB(
                x,
                bottom,
                x + blockWidth,
                ((row + 1) * rowHeight).floorToDouble(),
              ),
              Paint()
                ..color = const Color(0xFF463C32)
                ..isAntiAlias = false,
            );
          x += blockWidth;
        }
      }
      return recorder.endRecording().toImage(width, height);
    });
    return SyncImage(made!);
  }

  @override
  Future<SyncImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<SyncImage>(this);

  @override
  ImageStreamCompleter loadImage(SyncImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        SynchronousFuture<ImageInfo>(ImageInfo(image: image)),
      );
}

// ── The pump ──────────────────────────────────────────────────────────

/// The fake world The Floor is stood up in, as a list a second pump can reuse.
///
/// Split out of [pumpFloor] so the router-backed pump below runs against the
/// same repositories rather than a second, subtly different set of them.
List<Override> floorOverrides({
  DashboardKpis? current,
  DashboardKpis? previous,
  List<AlertItem> alerts = const <AlertItem>[],
  List<TaskItem> tasks = const <TaskItem>[],
  List<Outlet> outlets = const <Outlet>[],
  List<Territory> territories = const <Territory>[],
  Uint8List? photoBytes,
  bool photosFail = false,
  ImageProvider<Object>? plateImage,
  DateTime? now,
  List<Override> extraOverrides = const <Override>[],
}) => <Override>[
  dashboardRepositoryProvider.overrideWithValue(
    FakeDashboardRepository(current: current, previous: previous),
  ),
  alertsRepositoryProvider.overrideWithValue(FakeAlertsRepository(alerts)),
  tasksAdminRepositoryProvider.overrideWithValue(FakeTasksRepository(tasks)),
  outletsRepositoryProvider.overrideWithValue(FakeOutletsRepository(outlets)),
  territoriesRepositoryProvider.overrideWithValue(
    FakeTerritoriesRepository(territories),
  ),
  photosRepositoryProvider.overrideWithValue(
    FakePhotosRepository(bytes: photoBytes, fail: photosFail),
  ),
  // The plate's image seam. A decoded frame rather than an HTTP round
  // trip: `Image.memory` decodes on the engine's clock, and the frame the
  // amber census measures would otherwise arrive after the assertion.
  if (plateImage != null)
    plateImageResolverProvider.overrideWithValue((ref, photoId) => plateImage),
  nowProvider.overrideWithValue(() => now ?? DateTime.utc(2026, 9, 18, 18)),
  ...extraOverrides,
];

/// A 360×640 phone, Night × Console, with the clock pinned.
///
/// The regional manager on a phone is the common case, so it is the default
/// here rather than an edge case somebody remembers to add.
Future<void> pumpFloor(
  WidgetTester tester,
  Widget screen, {
  DashboardKpis? current,
  DashboardKpis? previous,
  List<AlertItem> alerts = const <AlertItem>[],
  List<TaskItem> tasks = const <TaskItem>[],
  List<Outlet> outlets = const <Outlet>[],
  List<Territory> territories = const <Territory>[],
  Uint8List? photoBytes,
  bool photosFail = false,
  ImageProvider<Object>? plateImage,
  TiqSkin? skin,
  Size size = const Size(360, 640),
  double textScale = 1.0,
  DateTime? now,
  Locale locale = const Locale('en'),
  List<Override> extraOverrides = const <Override>[],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final resolved = skin ?? TiqSkin.night();

  await tester.pumpWidget(
    ProviderScope(
      overrides: floorOverrides(
        current: current,
        previous: previous,
        alerts: alerts,
        tasks: tasks,
        outlets: outlets,
        territories: territories,
        photoBytes: photoBytes,
        photosFail: photosFail,
        plateImage: plateImage,
        now: now,
        extraOverrides: extraOverrides,
      ),
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          devicePixelRatio: 1.0,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Localizations(
          locale: locale,
          delegates: const <LocalizationsDelegate<dynamic>>[
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Theme(
              data: ThemeData(
                extensions: <ThemeExtension<dynamic>>[resolved],
              ),
              child: RepaintBoundary(
                key: const ValueKey<String>('amber-golden-boundary'),
                child: ColoredBox(
                  color: resolved.palette.ground,
                  child: SizedBox.fromSize(size: size, child: screen),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}


/// THE FLOOR INSIDE A ROUTER, so a press can be asserted on where it went.
///
/// [pumpFloor] stands the screen up on its own, which is right for everything
/// about what it draws and wrong for everything about what it *does*: a nav
/// slot's whole job is to change the route, and a screen with no router around
/// it cannot fail that. The stub destinations are deliberately empty screens —
/// what is under test is The Floor's chrome, not `/tasks`.
Future<GoRouter> pumpFloorRoute(
  WidgetTester tester, {
  DashboardKpis? current,
  DashboardKpis? previous,
  List<AlertItem> alerts = const <AlertItem>[],
  List<TaskItem> tasks = const <TaskItem>[],
  List<Outlet> outlets = const <Outlet>[],
  List<Territory> territories = const <Territory>[],
  Uint8List? photoBytes,
  bool photosFail = false,
  ImageProvider<Object>? plateImage,
  TiqSkin? skin,
  Size size = const Size(360, 640),
  double textScale = 1.0,
  DateTime? now,
  List<Override> extraOverrides = const <Override>[],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final resolved = skin ?? TiqSkin.night();

  Widget stub(String name) => Center(child: Text('STUB $name'));

  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: <RouteBase>[
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const TheFloorScreen(),
      ),
      for (final route in const <String>[
        '/tasks',
        '/assistant',
        '/dispatch',
        '/alerts',
        '/outlets',
        '/account/password',
      ])
        GoRoute(path: route, builder: (context, state) => stub(route)),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: floorOverrides(
        current: current,
        previous: previous,
        alerts: alerts,
        tasks: tasks,
        outlets: outlets,
        territories: territories,
        photoBytes: photoBytes,
        photosFail: photosFail,
        plateImage: plateImage,
        now: now,
        extraOverrides: extraOverrides,
      ),
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: <ThemeExtension<dynamic>>[resolved]),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Where the router currently is. `GoRouter.location` is deprecated and the
/// replacement is three hops deep, so it is spelled once here.
String currentRoute(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

/// One nav slot, by the word it *says* rather than the word it prints.
///
/// In a widget test the fallback font has square glyphs, every nav label
/// measures wider than its slot, and [TorchNavPill] correctly drops the whole
/// bar to icon-only. The printed labels are therefore absent by design, and
/// the spoken ones are the only handle on a slot — which is the right handle
/// anyway: the tab a screen reader announces and the tab a thumb lands on must
/// be the same object. Requires `tester.ensureSemantics()`.
Finder navSlot(String label) =>
    find.bySemanticsLabel(RegExp('^$label, tab [0-9]+ of [0-9]+\$'));

/// The photograph the plate is actually painting, or null when it is drawing
/// the fallback instead.
///
/// The plate paints through `DecorationImage` and not `Image`: only the
/// decoration takes an arbitrary `ColorFilter`, and the plate's tone is a
/// colour matrix. So "is there a photograph" is a question about the
/// decoration, and — usefully — the same object carries the tone, which means
/// one lookup answers both.
DecorationImage? platedImage(WidgetTester tester) {
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(TiqPlate),
      matching: find.byType(DecoratedBox),
    ),
  )) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration && decoration.image != null) {
      return decoration.image;
    }
  }
  return null;
}

/// Scroll The Floor until [finder] is built and on screen.
///
/// The body is a lazy `ListView`, which is the point: on a 360×640 phone the
/// section rule and the rows below it genuinely are past the fold, and a test
/// that pumped a 2000dp viewport to avoid scrolling would be testing a screen
/// nobody has.
Future<void> scrollFloorTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 30,
  );
  await tester.pumpAndSettle();
}
