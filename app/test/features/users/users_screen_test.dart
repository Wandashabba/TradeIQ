import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';
import 'package:tradeiq_app/features/users/presentation/users_screen.dart';

import '../../helpers/routed_app.dart';

const _activeUser = AppUser(
  id: 'u-active',
  email: 'active@example.com',
  role: 'manager',
  active: true,
);

const _inactiveUser = AppUser(
  id: 'u-inactive',
  email: 'inactive@example.com',
  role: 'field_agent',
  active: false,
);

class _FakeUsersRepository implements UsersRepository {
  String? setActiveId;
  bool? setActiveValue;
  String? createdEmail;
  String? createdPassword;
  String? createdRole;

  @override
  Future<List<AppUser>> listUsers() async => const [_activeUser, _inactiveUser];

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
  }) async {
    createdEmail = email;
    createdPassword = password;
    createdRole = role;
    return AppUser(id: 'u-new', email: email, role: role, active: true);
  }

  @override
  Future<AppUser> setActive(String id, bool active) async {
    setActiveId = id;
    setActiveValue = active;
    return AppUser(
      id: id,
      email: _activeUser.email,
      role: _activeUser.role,
      active: active,
    );
  }
}

class _ThrowingUsersRepository implements UsersRepository {
  @override
  Future<List<AppUser>> listUsers() async => throw Exception('boom');

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

Widget _app(UsersRepository repo, {ThemeData? theme}) => routedApp(
      const UsersScreen(),
      theme: theme,
      overrides: [
        usersRepositoryProvider.overrideWithValue(repo),
      ],
    );

void main() {
  testWidgets('renders under the light theme', (tester) async {
    await tester.pumpWidget(_app(_FakeUsersRepository(), theme: AppTheme.light()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(UsersScreen), findsOneWidget);
  });

  testWidgets('renders user emails once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeUsersRepository()));
    await tester.pumpAndSettle();

    expect(find.text('active@example.com'), findsOneWidget);
    expect(find.text('inactive@example.com'), findsOneWidget);
  });

  testWidgets('toggling the active switch records setActive', (tester) async {
    final repo = _FakeUsersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('active-u-active')));
    await tester.pumpAndSettle();

    expect(repo.setActiveId, 'u-active');
    expect(repo.setActiveValue, isFalse);
  });

  testWidgets('creating a user records the entered args', (tester) async {
    final repo = _FakeUsersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('new-email')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('new-password')),
      'secret123',
    );
    await tester.tap(find.byKey(const ValueKey<String>('create-user')));
    await tester.pumpAndSettle();

    expect(repo.createdEmail, 'new@example.com');
    expect(repo.createdPassword, 'secret123');
    expect(repo.createdRole, 'field_agent');
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_ThrowingUsersRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load users'),
      findsOneWidget,
    );
  });
}
