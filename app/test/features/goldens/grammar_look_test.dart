import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/tasks/presentation/tasks_screen.dart';
import 'package:tradeiq_app/features/visits/data/visit_detail_repository.dart';

import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';

import '../agent_harness.dart';
import '../worklist_harness.dart';

/// THE GRAMMAR, RENDERED, SO SOMEBODY CAN LOOK AT IT.
///
/// The Floor's own images live in `dashboard/floor_look_test.dart`; these are
/// the screens the card grammar was rolled out *to*, so the two sets can be
/// held side by side. The marker is what this batch changed: `NEEDS A
/// DECISION` on the ground, with no line across the screen and no count chip.
///
/// ## Why it does not run in CI
///
/// The same reason `floor_look_test.dart` gives: CI rasterises anti-aliased
/// Onest on `ubuntu-latest` and this repository is developed on macOS, so a
/// pixel comparison fails on the day it lands and gets skipped within a week.
/// The images are an artefact to *look at*; the pins are the measurements in
/// the screens' own tests, which do run everywhere.
///
/// Regenerate with:
///
/// ```sh
/// GRAMMAR_LOOK=1 flutter test \
///   test/features/goldens/grammar_look_test.dart --update-goldens
/// ```
void main() {
  final looking = Platform.environment['GRAMMAR_LOOK'] == '1';

  setUpAll(loadAgentFonts);

  Outlet outlet(String id, String name) =>
      Outlet(id: id, name: name, code: id.toUpperCase(), lat: 0, lng: 0);

  final outlets = <Outlet>[
    outlet('o1', 'SaveMor Glenwood'),
    outlet('o2', 'Shoprite Klipspruit Mall'),
    outlet('o3', 'Kasi Corner Spaza'),
    outlet('o4', 'Pick n Pay Rosebank'),
  ];

  testWidgets('Today — the agent’s home, Night × Field', (tester) async {
    await pumpAgentScreen(
      tester,
      const TodayScreen(),
      size: const Size(390, 844),
      overrides: <Override>[
        ...agentBaseOverrides(db: agentTestDb()),
        todayRouteProvider.overrideWith((ref) async => _today()),
      ],
    );

    await expectLater(
      find.byKey(agentBoundaryKey),
      matchesGoldenFile('goldens/grammar_today_390x844.png'),
    );
  }, skip: !looking);

  testWidgets('Alerts — the manager’s worklist, Night × Console', (
    tester,
  ) async {
    await pumpWorklist(
      tester,
      const AlertsScreen(),
      size: const Size(390, 844),
      overrides: <Override>[
        alertsRepositoryProvider.overrideWithValue(
          _Alerts(<AlertItem>[
            _alert('a1', 'critical', 'SKU 4412 is out of stock', 'o1'),
            _alert('a2', 'warning', 'SKU 9001 price deviates 18%', 'o2'),
            _alert('a3', 'critical', 'Scorecard 54 is below threshold 70', 'o3'),
            _alert('a4', 'warning', 'SKU 1180 is out of stock', 'o4'),
          ]),
        ),
        outletsRepositoryProvider.overrideWithValue(_Outlets(outlets)),
        photosRepositoryProvider.overrideWithValue(_NoPhotos()),
        visitDetailRepositoryProvider.overrideWithValue(_NoVisits()),
      ],
    );

    await expectLater(
      find.byKey(const ValueKey<String>('amber-golden-boundary')),
      matchesGoldenFile('goldens/grammar_alerts_390x844.png'),
    );
  }, skip: !looking);

  testWidgets('Tasks — the manager’s worklist, Night × Console', (
    tester,
  ) async {
    await pumpWorklist(
      tester,
      const TasksScreen(),
      size: const Size(390, 844),
      overrides: <Override>[
        tasksAdminRepositoryProvider.overrideWithValue(
          _Tasks(<TaskItem>[
            _task('t1', 'critical', 'Restock the end cap', 'o1'),
            _task('t2', 'high', 'Rebuild the promotional display', 'o2'),
            _task('t3', 'normal', 'Replace the shelf talker', 'o3'),
          ]),
        ),
        outletsRepositoryProvider.overrideWithValue(_Outlets(outlets)),
      ],
    );

    await expectLater(
      find.byKey(const ValueKey<String>('amber-golden-boundary')),
      matchesGoldenFile('goldens/grammar_tasks_390x844.png'),
    );
  }, skip: !looking);
}

/// A real day: nine stores, four done, the fifth up next.
TodayRoute _today() => TodayRoute(
  planName: 'Tembisa run',
  hasLocation: true,
  stops: <RouteStop>[
    for (var i = 0; i < 4; i++)
      RouteStop(
        sequence: 1 + i,
        outlet: Outlet(
          id: 'done$i',
          name: 'Khumalo Superette $i',
          code: 'KS-01$i',
          lat: 0,
          lng: 0,
        ),
        visited: true,
        distanceMeters: 900.0 + i * 300,
      ),
    RouteStop(
      sequence: 5,
      outlet: Outlet(
        id: 'kasi',
        name: 'Kasi Corner Spaza',
        code: 'KC-0412',
        lat: 0,
        lng: 0,
      ),
      visited: false,
      distanceMeters: 420,
    ),
    for (var i = 0; i < 4; i++)
      RouteStop(
        sequence: 6 + i,
        outlet: Outlet(
          id: 'rest$i',
          name: 'Pick n Pay Vosloorus $i',
          code: 'PP-02$i',
          lat: 0,
          lng: 0,
        ),
        visited: false,
        distanceMeters: 2100.0 + i * 400,
      ),
  ],
);

AlertItem _alert(String id, String severity, String message, String outletId) =>
    AlertItem(
      id: id,
      metric: 'out_of_stock',
      message: message,
      severity: severity,
      acknowledged: false,
      outletId: outletId,
      createdAt: DateTime.utc(2026, 9, 17, 6),
    );

TaskItem _task(String id, String priority, String fix, String outletId) =>
    TaskItem(
      id: id,
      findingType: 'stockout',
      requiredFix: fix,
      priority: priority,
      status: 'open',
      closureVerified: false,
      outletId: outletId,
      slaDueAt: DateTime.utc(2026, 9, 20),
      createdAt: DateTime.utc(2026, 9, 17, 9),
    );

class _Alerts implements AlertsRepository {
  _Alerts(this.alerts);
  final List<AlertItem> alerts;
  @override
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async => PaginatedResponse(data: alerts, nextCursor: null);
  @override
  Future<AlertItem> acknowledge(String id) async => throw UnimplementedError();
}

class _Tasks implements TasksAdminRepository {
  _Tasks(this.tasks);
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

class _Outlets implements OutletsRepository {
  _Outlets(this.outlets);
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

class _NoPhotos implements PhotosRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoVisits implements VisitDetailRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
