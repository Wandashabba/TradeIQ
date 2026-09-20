import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

// The unpressable-button law lives in one file for the whole suite. The
// territory group wrote it, operations re-exported it, and these screens need
// the same guard — a third copy would be a third thing to drift.
export 'a11y_guard.dart'
    show expectEveryButtonActivatable, semanticsDump, semanticsNodes;

/// Everything the manager's worklists need to stand a screen up without a
/// server.
///
/// The fakes override **repositories**, never the view providers above them,
/// so the merge, the outlet-name resolution, the SLA arithmetic and the
/// ranking are all exercised for real. A test that overrode
/// `alertsViewProvider` would prove only that a widget can render a record.

/// A real, decodable 1×1 transparent PNG, for the evidence thumbnails.
final Uint8List pngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Outlet outlet(String id, String name) =>
    Outlet(id: id, name: name, code: id.toUpperCase(), lat: 0, lng: 0);

AppUser person(String id, String email, {String? name}) => AppUser(
  id: id,
  email: email,
  role: 'field_agent',
  active: true,
  displayName: name,
);

// ── Fakes ─────────────────────────────────────────────────────────────

/// The roster, as GET /users answers it. Every pump installs one — empty by
/// default — so no worklist test ever reaches for the network to name a
/// person.
class FakeUsersRepository implements UsersRepository {
  FakeUsersRepository([this.users = const <AppUser>[]]);

  final List<AppUser> users;

  @override
  Future<PaginatedResponse<AppUser>> listUsers() async =>
      PaginatedResponse(data: users, nextCursor: null);

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
    String? displayName,
  }) async => throw UnimplementedError();

  @override
  Future<AppUser> setActive(String id, bool active) async =>
      throw UnimplementedError();

  @override
  Future<AppUser> updateDisplayName(String id, String? displayName) async =>
      throw UnimplementedError();
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

/// Hands back bytes for any photo id, so a thumbnail in a row is the real
/// widget rather than a stub.
class FakePhotosRepository implements PhotosRepository {
  FakePhotosRepository({this.bytes});

  final Uint8List? bytes;

  int uploadCount = 0;
  String? uploadedVisitId;
  String? uploadedSection;
  String? uploadedDataUrl;
  Map<String, dynamic>? uploadedGpsTag;
  String? uploadedTimestamp;

  /// When set, the next upload throws it.
  Object? uploadFailure;

  @override
  Future<Uint8List> thumbnailBytes(String photoId) async {
    final value = bytes;
    if (value == null) throw StateError('no photo');
    return value;
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
  }) async {
    if (uploadFailure != null) throw uploadFailure!;
    uploadCount++;
    uploadedVisitId = visitId;
    uploadedSection = section;
    uploadedDataUrl = dataUrl;
    uploadedGpsTag = gpsTag;
    uploadedTimestamp = timestamp;
    return const PhotoUploadResult(
      id: 'photo-1',
      url: 'https://cdn.example.com/photo-1.png',
    );
  }

  @override
  Future<String> uploadMessageAttachment(String dataUrl) async =>
      throw UnimplementedError();
}

class FakeAlertsRepository implements AlertsRepository {
  FakeAlertsRepository({
    this.alerts = const <AlertItem>[],
    this.nextCursor,
    this.total,
    this.listFailure,
    this.ackFailure,
    this.listPending = false,
  });

  final List<AlertItem> alerts;
  final String? nextCursor;

  /// The server's count of every matching alert, or null for a server that
  /// does not count.
  final int? total;
  final Object? listFailure;

  /// The list never arrives, so the screen stays in its loading phase.
  final bool listPending;

  /// When set, `acknowledge` throws it.
  final Object? ackFailure;

  final List<String> acknowledged = <String>[];

  @override
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async {
    if (listFailure != null) throw listFailure!;
    if (listPending) return Completer<PaginatedResponse<AlertItem>>().future;
    return PaginatedResponse(
      data: alerts,
      nextCursor: nextCursor,
      total: total,
    );
  }

  @override
  Future<AlertItem> acknowledge(String id) async {
    acknowledged.add(id);
    if (ackFailure != null) throw ackFailure!;
    final item = alerts.firstWhere((a) => a.id == id);
    return AlertItem(
      id: item.id,
      metric: item.metric,
      message: item.message,
      severity: item.severity,
      acknowledged: true,
      visitId: item.visitId,
      outletId: item.outletId,
      evidencePhotoId: item.evidencePhotoId,
      createdAt: item.createdAt,
    );
  }
}

class FakeAlertRulesRepository implements AlertRulesRepository {
  FakeAlertRulesRepository({
    this.rules = const <AlertRule>[],
    this.failure,
    this.pending = false,
  });

  final List<AlertRule> rules;
  final Object? failure;

  /// The list never arrives, so the screen stays in its loading phase.
  final bool pending;

  String? updatedId;
  bool? updatedActive;
  double? updatedThreshold;
  String? updatedSeverity;

  String? createdName;
  String? createdMetric;
  double? createdThreshold;
  String? createdSeverity;
  int createCount = 0;
  int updateCount = 0;

  @override
  Future<List<AlertRule>> listRules() async {
    if (failure != null) throw failure!;
    if (pending) return Completer<List<AlertRule>>().future;
    return rules;
  }

  @override
  Future<AlertRule> createRule({
    required String name,
    required String metric,
    double? threshold,
    String? severity,
  }) async {
    createCount++;
    createdName = name;
    createdMetric = metric;
    createdThreshold = threshold;
    createdSeverity = severity;
    return AlertRule(
      id: 'new',
      name: name,
      metric: metric,
      severity: severity ?? 'normal',
      active: true,
      threshold: threshold,
    );
  }

  @override
  Future<AlertRule> updateRule(
    String id, {
    bool? active,
    double? threshold,
    String? severity,
  }) async {
    updateCount++;
    updatedId = id;
    updatedActive = active;
    updatedThreshold = threshold;
    updatedSeverity = severity;
    final existing = rules.firstWhere((r) => r.id == id);
    return AlertRule(
      id: existing.id,
      name: existing.name,
      metric: existing.metric,
      severity: severity ?? existing.severity,
      active: active ?? existing.active,
      threshold: threshold ?? existing.threshold,
    );
  }
}

class FakeTasksRepository implements TasksAdminRepository {
  FakeTasksRepository({
    this.tasks = const <TaskItem>[],
    this.nextCursor,
    this.total,
    this.listFailure,
    this.closeFailure,
    this.listPending = false,
  });

  final List<TaskItem> tasks;
  final String? nextCursor;

  /// The server's count of every matching task, or null.
  final int? total;
  final Object? listFailure;
  final Object? closeFailure;

  /// The list never arrives, so the screen stays in its loading phase.
  final bool listPending;

  String? closedId;
  String? closedPhotoUrl;
  String? verifiedId;

  @override
  Future<PaginatedResponse<TaskItem>> listTasks({
    String? status,
    String? priority,
    String? outletId,
  }) async {
    if (listFailure != null) throw listFailure!;
    if (listPending) return Completer<PaginatedResponse<TaskItem>>().future;
    return PaginatedResponse(data: tasks, nextCursor: nextCursor, total: total);
  }

  @override
  Future<TaskItem> closeTask({
    required String id,
    required String closurePhotoUrl,
  }) async {
    if (closeFailure != null) throw closeFailure!;
    closedId = id;
    closedPhotoUrl = closurePhotoUrl;
    final existing = tasks.firstWhere((t) => t.id == id);
    return TaskItem(
      id: existing.id,
      findingType: existing.findingType,
      requiredFix: existing.requiredFix,
      priority: existing.priority,
      status: 'closed',
      closurePhotoUrl: closurePhotoUrl,
      closureVerified: false,
      outletId: existing.outletId,
      visitId: existing.visitId,
      slaDueAt: existing.slaDueAt,
      evidencePhotoId: existing.evidencePhotoId,
      createdAt: existing.createdAt,
      ownerId: existing.ownerId,
    );
  }

  @override
  Future<TaskItem> verifyTask(String id) async {
    verifiedId = id;
    final existing = tasks.firstWhere((t) => t.id == id);
    return TaskItem(
      id: existing.id,
      findingType: existing.findingType,
      requiredFix: existing.requiredFix,
      priority: existing.priority,
      status: 'closed',
      closurePhotoUrl: existing.closurePhotoUrl,
      closureVerified: true,
      outletId: existing.outletId,
      visitId: existing.visitId,
      slaDueAt: existing.slaDueAt,
      evidencePhotoId: existing.evidencePhotoId,
      createdAt: existing.createdAt,
      ownerId: existing.ownerId,
    );
  }
}

// ── The pump ──────────────────────────────────────────────────────────

/// Where a `context.push` or `context.go` from a worklist can land. Stubs,
/// because the assertion is that the screen navigated, not what it navigated
/// to — but real routes, because `go_router` throws on a destination that does
/// not exist and that throw is worth keeping.
List<GoRoute> _stubRoutes() => <GoRoute>[
  for (final path in <String>[
    '/dashboard',
    '/alerts',
    '/alert-rules',
    '/tasks',
    '/assistant',
    '/visits/:id',
    '/contests',
    '/leaderboard',
    // Declared before `/leaderboard/:agentId`, exactly as app_router.dart
    // declares it, so `contests` is never matched as an agent id.
    '/leaderboard/contests',
    '/leaderboard/:agentId',
    '/fraud',
    '/incentives',
    '/agents/activity',
    '/reports',
    '/reports/schedules',
    '/webhooks',
    '/audit-templates',
    '/audit-templates/:templateId/preview',
    '/messages',
  ])
    GoRoute(
      path: path,
      builder: (context, state) => Align(
        alignment: Alignment.topLeft,
        child: Text('stub:${state.matchedLocation}'),
      ),
    ),
];

/// A 360×720 console phone, Night × Console, under a real router.
///
/// The whole app sits inside the amber census's repaint boundary, so a census
/// taken after this pump measures the composed frame — chrome included, which
/// is the only way to count the nav's active tab.
Future<void> pumpWorklist(
  WidgetTester tester,
  Widget screen, {
  TiqSkin? skin,
  Size size = const Size(360, 720),
  double textScale = 1.0,
  Locale? locale,
  List<Override> overrides = const <Override>[],
  List<AppUser> users = const <AppUser>[],
  String path = '/screen',
  bool settle = true,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // A leaked sheet count from a previous test would extinguish this one's
  // amber, and the failure would name the wrong component.
  TorchSheets.resetForTest();
  addTearDown(TorchSheets.resetForTest);

  final resolved = skin ?? TiqSkin.night();

  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('amber-golden-boundary'),
      child: ColoredBox(
        color: resolved.palette.ground,
        child: ProviderScope(
          overrides: <Override>[
            usersRepositoryProvider.overrideWithValue(
              FakeUsersRepository(users),
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
            routerConfig: GoRouter(
              initialLocation: path,
              routes: <GoRoute>[
                GoRoute(path: path, builder: (context, state) => screen),
                ..._stubRoutes(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // A phase that never resolves — a skeleton with its travelling rule
    // running — has no settled frame to wait for, and `pumpAndSettle` on a
    // repeating animation never returns.
    await tester.pump();
  }
}

/// Drag the filter rail sideways until [finder] is on screen.
///
/// The rail is a horizontal scroller with a 20dp right bleed so it visibly
/// continues, which means the severity chips genuinely are off the edge of a
/// 360dp phone — as they are for a manager.
Future<void> scrollRailTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find
        .descendant(
          of: find.byType(TorchFilterRail),
          matching: find.byType(Scrollable),
        )
        .first,
    const Offset(-120, 0),
  );
  await tester.pumpAndSettle();
}

/// Scroll inside an open sheet until [finder] is on screen.
///
/// A sheet's body scrolls when it outgrows 88% of the viewport, and at 2.0x
/// on a 360dp phone a form does exactly that — which is the point of the
/// ceiling, and the reason a test cannot assume a commit button is in view.
Future<void> scrollSheetTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find
        .descendant(
          of: find.byType(TorchSheet),
          matching: find.byType(Scrollable),
        )
        .first,
    const Offset(0, -80),
  );
  await tester.pumpAndSettle();
}

/// Let a toast live out its dwell and take its timer with it.
///
/// A toast holds a `Timer`, and flutter_test fails a test whose tree is
/// disposed with one still pending — which presents as a hang two tests later
/// rather than as the toast's own fault.
Future<void> settleToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 20));
  await tester.pumpAndSettle();
}

/// Scroll a worklist until [finder] is built and on screen.
///
/// The body is a lazy `ListView`, which is the point: on a 360dp phone the
/// rows below the filter rail genuinely are past the fold, and a test that
/// pumped a 2000dp viewport to avoid scrolling would be testing a screen
/// nobody has.
Future<void> scrollWorklistTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}
