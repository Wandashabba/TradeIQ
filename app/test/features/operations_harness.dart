import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/location/geolocator_gateway.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/beatplans/data/beatplans_repository.dart';
import 'package:tradeiq_app/features/orders/data/orders_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

/// EVERYTHING THE OPERATIONS SCREENS NEED TO STAND UP WITHOUT A SERVER.
///
/// Stores, orders, beat plans and sales targets. The fakes override
/// **repositories**, never the providers above them, so the paging walk, the
/// sorting, the attainment arithmetic and the CSV round trip are all exercised
/// for real. A test that overrode `outletsListProvider` would prove only that
/// a widget can render a record.

/// A real, decodable 1×1 transparent PNG, for the evidence thumbnails.
final Uint8List opsPngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Outlet opsOutlet(
  String id,
  String name, {
  String? code,
  double lat = -26.2041,
  double lng = 28.0473,
  String channelType = 'spaza',
  String status = 'active',
}) => Outlet(
  id: id,
  name: name,
  code: code ?? id.toUpperCase(),
  lat: lat,
  lng: lng,
  channelType: channelType,
  status: status,
);

// ── Fakes ─────────────────────────────────────────────────────────────

class FakeOpsOutletsRepository implements OutletsRepository {
  FakeOpsOutletsRepository({
    this.outlets = const <Outlet>[],
    this.listFailure,
    this.listPending = false,
    this.createFailure,
  });

  final List<Outlet> outlets;
  final Object? listFailure;
  final bool listPending;
  final Object? createFailure;

  int createCount = 0;
  String? createdName;
  String? createdCode;
  String? createdChannel;
  double? createdLat;
  double? createdLng;
  String? createdTerritoryId;

  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async {
    if (listFailure != null) throw listFailure!;
    if (listPending) return Completer<PaginatedResponse<Outlet>>().future;
    return PaginatedResponse(data: outlets, nextCursor: null);
  }

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) async {
    if (createFailure != null) throw createFailure!;
    createCount++;
    createdName = name;
    createdCode = code;
    createdChannel = channelType;
    createdLat = lat;
    createdLng = lng;
    createdTerritoryId = territoryId;
    return opsOutlet('new', name, code: code, lat: lat, lng: lng);
  }
}

class FakeOutletAdminRepository implements OutletAdminRepository {
  FakeOutletAdminRepository({
    this.detail,
    this.disputes = const <PinDispute>[],
    this.detailFailure,
    this.detailPending = false,
    this.updateFailure,
  });

  final OutletDetail? detail;
  final List<PinDispute> disputes;
  final Object? detailFailure;
  final bool detailPending;
  final Object? updateFailure;

  int updateCount = 0;
  String? updatedId;
  String? updatedName;
  double? updatedLat;
  double? updatedLng;
  String? updatedStatus;
  String? updatedFromAttemptId;
  String? updatedDisputeId;

  @override
  Future<OutletDetail> getOutlet(String id) async {
    if (detailFailure != null) throw detailFailure!;
    if (detailPending) return Completer<OutletDetail>().future;
    return detail!;
  }

  @override
  Future<Outlet> updateOutlet({
    required String id,
    String? name,
    double? lat,
    double? lng,
    String? status,
    String? fromAttemptId,
    String? disputeId,
    String? resolutionNote,
  }) async {
    updateCount++;
    updatedId = id;
    updatedName = name;
    updatedLat = lat;
    updatedLng = lng;
    updatedStatus = status;
    updatedFromAttemptId = fromAttemptId;
    updatedDisputeId = disputeId;
    if (updateFailure != null) throw updateFailure!;
    return detail!.outlet;
  }

  @override
  Future<PaginatedResponse<PinDispute>> listPinDisputes({
    String? status,
    String? outletId,
    int? limit,
    String? cursor,
  }) async => PaginatedResponse(data: disputes, nextCursor: null);
}

class FakeTerritoriesRepository implements TerritoriesRepository {
  FakeTerritoriesRepository({
    this.territories = const <Territory>[],
    this.failure,
    this.pending = false,
  });

  final List<Territory> territories;
  final Object? failure;
  final bool pending;

  @override
  Future<PaginatedResponse<Territory>> listTerritories() async {
    if (failure != null) throw failure!;
    if (pending) return Completer<PaginatedResponse<Territory>>().future;
    return PaginatedResponse(data: territories, nextCursor: null);
  }

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

class FakeOrdersRepository implements OrdersRepository {
  FakeOrdersRepository({
    this.orders = const <OrderItem>[],
    this.listFailure,
    this.listPending = false,
    this.createFailure,
  });

  final List<OrderItem> orders;
  final Object? listFailure;
  final bool listPending;
  final Object? createFailure;

  int createCount = 0;
  String? createdOutletId;
  List<OrderLine>? createdLines;

  @override
  Future<PaginatedResponse<OrderItem>> listOrders({
    String? status,
    String? outletId,
  }) async {
    if (listFailure != null) throw listFailure!;
    if (listPending) return Completer<PaginatedResponse<OrderItem>>().future;
    return PaginatedResponse(data: orders, nextCursor: null);
  }

  @override
  Future<void> createOrder({
    required String outletId,
    required List<OrderLine> lines,
  }) async {
    if (createFailure != null) throw createFailure!;
    createCount++;
    createdOutletId = outletId;
    createdLines = lines;
  }
}

class FakeBeatPlansRepository implements BeatPlansRepository {
  FakeBeatPlansRepository({
    this.plans = const <BeatPlan>[],
    this.detail,
    this.listFailure,
    this.listPending = false,
    this.detailFailure,
    this.createFailure,
    this.markFailure,
  });

  final List<BeatPlan> plans;
  final BeatPlanDetail? detail;
  final Object? listFailure;
  final bool listPending;
  final Object? detailFailure;
  final Object? createFailure;
  final Object? markFailure;

  String? visitedPlanId;
  String? visitedStopId;
  bool? visitedValue;

  int createCount = 0;
  String? createdAgentId;
  String? createdName;
  String? createdDate;
  List<String>? createdOutletIds;
  String? createdTerritoryId;

  @override
  Future<PaginatedResponse<BeatPlan>> listBeatPlans() async {
    if (listFailure != null) throw listFailure!;
    if (listPending) return Completer<PaginatedResponse<BeatPlan>>().future;
    return PaginatedResponse(data: plans, nextCursor: null);
  }

  @override
  Future<BeatPlanDetail> getBeatPlan(String id) async {
    if (detailFailure != null) throw detailFailure!;
    return detail!;
  }

  @override
  Future<void> markStopVisited(
    String planId,
    String stopId,
    bool visited,
  ) async {
    if (markFailure != null) throw markFailure!;
    visitedPlanId = planId;
    visitedStopId = stopId;
    visitedValue = visited;
  }

  @override
  Future<BeatPlan> createBeatPlan({
    required String agentId,
    required String name,
    required String scheduledDate,
    required List<String> outletIds,
    String? territoryId,
  }) async {
    if (createFailure != null) throw createFailure!;
    createCount++;
    createdAgentId = agentId;
    createdName = name;
    createdDate = scheduledDate;
    createdOutletIds = outletIds;
    createdTerritoryId = territoryId;
    return BeatPlan(
      id: 'new',
      name: name,
      status: 'scheduled',
      scheduledDate: scheduledDate,
    );
  }
}

class FakeSkusRepository implements SkusRepository {
  FakeSkusRepository({
    this.skus = const <Sku>[],
    this.failure,
    this.pending = false,
  });

  final List<Sku> skus;
  final Object? failure;
  final bool pending;

  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async {
    if (failure != null) throw failure!;
    if (pending) return Completer<PaginatedResponse<Sku>>().future;
    return PaginatedResponse(data: skus, nextCursor: null);
  }
}

class FakeOpsUsersRepository implements UsersRepository {
  FakeOpsUsersRepository([this.users = const <AppUser>[]]);

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

class FakeOpsPhotosRepository implements PhotosRepository {
  FakeOpsPhotosRepository({this.bytes});

  final Uint8List? bytes;

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
  }) async => throw UnimplementedError();

  @override
  Future<String> uploadMessageAttachment(String dataUrl) async =>
      throw UnimplementedError();
}

/// A device position that never touches a platform channel.
///
/// The gateway is faked rather than the service, so the service's own
/// permission walk, timeouts and error mapping stay in the test.
class FakeGeolocatorGateway implements GeolocatorGateway {
  FakeGeolocatorGateway({
    this.permission = LocationPermission.whileInUse,
    this.enabled = true,
    this.lat = -26.089,
    this.lng = 28.023,
    this.accuracy = 5,
  });

  final LocationPermission permission;
  final bool enabled;
  final double lat;
  final double lng;
  final double accuracy;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<Position> getCurrentPosition() async => Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.utc(2026, 9, 20),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

/// The location service over [FakeGeolocatorGateway].
LocationService fakeLocationService({
  LocationPermission permission = LocationPermission.whileInUse,
  bool enabled = true,
  double lat = -26.089,
  double lng = 28.023,
}) => LocationService(
  gateway: FakeGeolocatorGateway(
    permission: permission,
    enabled: enabled,
    lat: lat,
    lng: lng,
  ),
);

// ── The pump ──────────────────────────────────────────────────────────

/// Every destination an operations screen can navigate to. Stubs, because the
/// assertion is that the screen navigated — but real routes, because
/// `go_router` throws on a destination that does not exist and that throw is
/// worth keeping.
List<GoRoute> _opsStubRoutes() => <GoRoute>[
  for (final path in <String>[
    '/dashboard',
    '/alerts',
    '/tasks',
    '/assistant',
    '/outlets',
    '/outlets/create',
    '/outlets/:id',
    '/orders',
    '/beatplans',
    '/sales-targets',
    '/territories',
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
Future<void> pumpOperations(
  WidgetTester tester,
  Widget screen, {
  TiqSkin? skin,
  Size size = const Size(360, 720),
  double textScale = 1.0,
  Locale? locale,
  List<Override> overrides = const <Override>[],
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
            usersRepositoryProvider.overrideWithValue(FakeOpsUsersRepository()),
            photosRepositoryProvider.overrideWithValue(
              FakeOpsPhotosRepository(bytes: opsPngBytes),
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
                ..._opsStubRoutes(),
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

/// Scroll the route's body until [finder] is built and on screen.
///
/// The body is a lazy `ListView`, which is the point: on a 360dp phone the
/// rows below the fold genuinely are past it, and a test that pumped a 2000dp
/// viewport to avoid scrolling would be testing a screen nobody has.
Future<void> scrollOpsTo(
  WidgetTester tester,
  Finder finder, {
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 60,
  );
  await tester.pumpAndSettle();
}

/// The same, back up the page. `scrollUntilVisible` only ever moves one way,
/// and a form field above the evidence list is not reachable by scrolling
/// further down.
Future<void> scrollOpsBackTo(WidgetTester tester, Finder finder) =>
    scrollOpsTo(tester, finder, delta: -200);

/// Scroll inside an open sheet until [finder] is on screen.
Future<void> scrollOpsSheetTo(WidgetTester tester, Finder finder) async {
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

/// Open a [TorchPickerField] and choose the option whose label is [label].
///
/// It scrolls the field into the viewport first: at Veld's densities and at
/// 2.0x a form is taller than the fold, and a tap that lands on whatever the
/// route happens to be painting at those coordinates is not a test of
/// anything.
Future<void> pickOption(WidgetTester tester, Key fieldKey, String label) async {
  final field = find.byKey(fieldKey);
  await scrollOpsTo(tester, field);
  await tester.tap(field);
  await tester.pumpAndSettle();

  // In Veld the sheet is a full-screen route rather than a `TorchSheet`, so
  // the option is found by its words and not by its container.
  final option = find.text(label);
  if (option.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      option,
      find.byType(Scrollable).last,
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(option.last);
  await tester.pumpAndSettle();
}

/// Let a toast live out its dwell and take its timer with it.
///
/// A toast holds a `Timer`, and flutter_test fails a test whose tree is
/// disposed with one still pending — which presents as a hang two tests later
/// rather than as the toast's own fault.
Future<void> settleOpsToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 20));
  await tester.pumpAndSettle();
}
