import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/beatplans/data/beatplans_repository.dart';
import 'package:tradeiq_app/features/beatplans/presentation/beat_plan_form_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

class _RecordingBeatPlansRepository implements BeatPlansRepository {
  Map<String, dynamic>? createdArgs;

  @override
  Future<List<BeatPlan>> listBeatPlans() async => const [];

  @override
  Future<BeatPlanDetail> getBeatPlan(String id) async =>
      throw UnimplementedError();

  @override
  Future<void> markStopVisited(String planId, String stopId, bool visited) async {}

  @override
  Future<BeatPlan> createBeatPlan({
    required String agentId,
    required String name,
    required String scheduledDate,
    required List<String> outletIds,
    String? territoryId,
  }) async {
    createdArgs = {
      'agentId': agentId,
      'name': name,
      'scheduledDate': scheduledDate,
      'outletIds': outletIds,
      'territoryId': territoryId,
    };
    return BeatPlan(
        id: 'bp1', name: name, status: 'planned', scheduledDate: scheduledDate);
  }
}

class _FakeUsersRepository implements UsersRepository {
  @override
  Future<List<AppUser>> listUsers() async => const [
        AppUser(id: 'a1', email: 'agent-one@x.com', role: 'field_agent', active: true),
        AppUser(id: 'm1', email: 'manager@x.com', role: 'manager', active: true),
      ];

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
  }) async =>
      throw UnimplementedError();

  @override
  Future<AppUser> setActive(String id, bool active) async =>
      throw UnimplementedError();
}

class _FakeTerritoriesRepository implements TerritoriesRepository {
  @override
  Future<List<Territory>> listTerritories() async => const [
        Territory(id: 't1', name: 'Gauteng North', code: 'GN'),
      ];

  @override
  Future<TerritoryCoverage> getCoverage(String id) async =>
      throw UnimplementedError();
}

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'o1', name: 'Shop One', code: 'S1', lat: 0, lng: 0),
        Outlet(id: 'o2', name: 'Shop Two', code: 'S2', lat: 0, lng: 0),
      ];

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) async =>
      throw UnimplementedError();
}

Widget _app(_RecordingBeatPlansRepository repo) => ProviderScope(
      overrides: [
        beatPlansRepositoryProvider.overrideWithValue(repo),
        usersRepositoryProvider.overrideWithValue(_FakeUsersRepository()),
        territoriesRepositoryProvider
            .overrideWithValue(_FakeTerritoriesRepository()),
        outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      ],
      child: const MaterialApp(home: BeatPlanFormScreen()),
    );

void main() {
  testWidgets('lists only field agents in the agent dropdown', (tester) async {
    await tester.pumpWidget(_app(_RecordingBeatPlansRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('beatplan-agent-field')));
    await tester.pumpAndSettle();

    expect(find.text('agent-one@x.com'), findsWidgets);
    // The manager must not be offered as a beat-plan assignee.
    expect(find.text('manager@x.com'), findsNothing);
  });

  testWidgets('builds and submits an ordered beat plan', (tester) async {
    final repo = _RecordingBeatPlansRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey<String>('beatplan-name-field')), 'North Route');

    await tester.tap(find.byKey(const ValueKey<String>('beatplan-date-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('beatplan-agent-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('agent-one@x.com').last);
    await tester.pumpAndSettle();

    // Add both outlets: o2 first, then o1, to prove order is preserved.
    // The form is taller than the test viewport, so scroll each control into
    // view before interacting with it.
    final o2 = find.byKey(const ValueKey<String>('stop-available-o2'));
    await tester.ensureVisible(o2);
    await tester.tap(o2);
    await tester.pump();
    final o1 = find.byKey(const ValueKey<String>('stop-available-o1'));
    await tester.ensureVisible(o1);
    await tester.tap(o1);
    await tester.pump();

    final save = find.byKey(const ValueKey<String>('beatplan-save-button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repo.createdArgs, isNotNull);
    expect(repo.createdArgs!['name'], 'North Route');
    expect(repo.createdArgs!['agentId'], 'a1');
    expect(repo.createdArgs!['outletIds'], ['o2', 'o1']);
  });

  testWidgets('blocks submit when no agent is selected', (tester) async {
    final repo = _RecordingBeatPlansRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey<String>('beatplan-name-field')), 'No Agent');
    final save = find.byKey(const ValueKey<String>('beatplan-save-button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.textContaining('Select a field agent'), findsOneWidget);
    expect(repo.createdArgs, isNull);
  });
}
