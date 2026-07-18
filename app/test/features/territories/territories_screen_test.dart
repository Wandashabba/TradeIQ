import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/territories/presentation/territories_screen.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

import '../../helpers/routed_app.dart';

const _north = Territory(
  id: 'ter-1',
  name: 'Gauteng North',
  code: 'GP-N',
  region: 'Gauteng',
);

const _south = Territory(
  id: 'ter-2',
  name: 'Western Cape',
  code: 'WC',
);

class _FakeTerritoriesRepository implements TerritoriesRepository {
  String? assignedTerritoryId;
  String? assignedUserId;

  @override
  Future<List<Territory>> listTerritories() async => const [_north, _south];

  @override
  Future<TerritoryCoverage> getCoverage(String id) async => const TerritoryCoverage(
        outletCount: 3,
        agentCount: 2,
        outletsVisited: 2,
        outletsTotal: 3,
        coverageRate: 66.67,
      );

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async =>
      _north;

  @override
  Future<void> assignAgent(String territoryId, String userId) async {
    assignedTerritoryId = territoryId;
    assignedUserId = userId;
  }
}

class _FailingTerritoriesRepository implements TerritoriesRepository {
  @override
  Future<List<Territory>> listTerritories() async => throw Exception('boom');

  @override
  Future<TerritoryCoverage> getCoverage(String id) async =>
      throw Exception('boom');

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async =>
      throw Exception('boom');

  @override
  Future<void> assignAgent(String territoryId, String userId) async =>
      throw Exception('boom');
}

class _FakeUsersRepository implements UsersRepository {
  @override
  Future<List<AppUser>> listUsers() async => const [
        AppUser(id: 'a1', email: 'agent@x.com', role: 'field_agent', active: true),
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

/// A session fixed to the given role, so role-gated UI is deterministic.
class _RoleSession extends SessionController {
  _RoleSession(this.role);
  final String? role;

  @override
  Future<SessionState> build() async => SessionState(role: role, token: 't');
}

Widget _app(
  TerritoriesRepository repo, {
  String? role,
  ThemeData? theme,
}) =>
    routedApp(
      const TerritoriesScreen(),
      theme: theme,
      overrides: [
        territoriesRepositoryProvider.overrideWithValue(repo),
        usersRepositoryProvider.overrideWithValue(_FakeUsersRepository()),
        sessionControllerProvider.overrideWith(() => _RoleSession(role)),
      ],
    );

void main() {
  testWidgets('renders under the light theme', (tester) async {
    await tester.pumpWidget(_app(_FakeTerritoriesRepository(), theme: AppTheme.light()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TerritoriesScreen), findsOneWidget);
  });

  testWidgets('renders territory names once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeTerritoriesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Gauteng North'), findsOneWidget);
    expect(find.text('Western Cape'), findsOneWidget);
  });

  testWidgets('shows an error state when loading fails', (tester) async {
    await tester.pumpWidget(_app(_FailingTerritoriesRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load territories'),
      findsOneWidget,
    );
  });

  testWidgets('hides create/assign controls from a field agent', (tester) async {
    await tester.pumpWidget(_app(_FakeTerritoriesRepository(), role: 'field_agent'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('territory-create-fab')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('territory-assign-ter-1')),
      findsNothing,
    );
  });

  testWidgets('manager assigns a field agent to a territory', (tester) async {
    final repo = _FakeTerritoriesRepository();
    await tester.pumpWidget(_app(repo, role: 'manager'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('territory-assign-ter-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('assign-agent-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('agent@x.com').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('assign-agent-confirm')));
    await tester.pumpAndSettle();

    expect(repo.assignedTerritoryId, 'ter-1');
    expect(repo.assignedUserId, 'a1');
  });

  testWidgets('shows the coverage rate in the row figures', (tester) async {
    await tester.pumpWidget(_app(_FakeTerritoriesRepository()));
    await tester.pumpAndSettle();

    // The fake repo returns the same coverage for every territory id, so
    // both rows show "67% covered" — scope to one row to assert unambiguously.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('territory-ter-1')),
        matching: find.textContaining('67% covered'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the "Map" action opens the territory map screen', (tester) async {
    await tester.pumpWidget(_app(_FakeTerritoriesRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('territory-map-ter-1')));
    // A screen containing FlutterMap: pump a bounded number of frames rather
    // than pumpAndSettle, which never settles while flutter_map's TileLayer
    // keeps retrying its (test-environment-blocked) network tile fetch.
    await tester.pump();
    await tester.pump();

    expect(find.text('Gauteng North — Map'), findsOneWidget);
  });
}
