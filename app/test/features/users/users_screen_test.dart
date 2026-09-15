import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
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

const _namedUser = AppUser(
  id: 'u-named',
  email: 'agent7@example.com',
  role: 'field_agent',
  active: true,
  displayName: 'Sipho Ndlovu',
);

class _FakeUsersRepository implements UsersRepository {
  _FakeUsersRepository({this.users = const [_activeUser, _inactiveUser]});

  final List<AppUser> users;
  String? setActiveId;
  bool? setActiveValue;
  String? createdEmail;
  String? createdPassword;
  String? createdRole;
  String? createdDisplayName;

  @override
  Future<PaginatedResponse<AppUser>> listUsers() async =>
      PaginatedResponse(data: users, nextCursor: null);

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
    String? displayName,
  }) async {
    createdEmail = email;
    createdPassword = password;
    createdRole = role;
    createdDisplayName = displayName;
    return AppUser(
      id: 'u-new',
      email: email,
      role: role,
      active: true,
      displayName: displayName,
    );
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
  Future<PaginatedResponse<AppUser>> listUsers() async => throw Exception('boom');

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
    String? displayName,
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

Future<void> _openCreateDialog(WidgetTester tester) async {
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
}

void main() {
  testWidgets('light: users are glass tiles; inactive still says so', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeUsersRepository(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    for (final email in ['active@example.com', 'inactive@example.com']) {
      final panes = tester.widgetList<GlassPane>(
        find.ancestor(of: find.text(email), matching: find.byType(GlassPane)),
      );
      expect(panes.any((p) => p.kind == GlassKind.tile && !p.blur), isTrue);
    }
    // One in the triage strip, one on the row — a word, not a fade alone.
    expect(find.text('INACTIVE'), findsNWidgets(2));
  });

  testWidgets('renders user emails once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeUsersRepository()));
    await tester.pumpAndSettle();

    expect(find.text('active@example.com'), findsOneWidget);
    expect(find.text('inactive@example.com'), findsOneWidget);
  });

  for (final theme in [AppTheme.light(), null]) {
    final label = theme == null ? 'dark' : 'light';
    testWidgets(
        '$label: a named user is titled by name, with the email kept as '
        'the supporting line', (tester) async {
      await tester.pumpWidget(
        _app(
          _FakeUsersRepository(users: const [_namedUser, _activeUser]),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sipho Ndlovu'), findsOneWidget);
      // Still on the page — it is what they sign in with — but not the title.
      expect(
        find.byKey(const ValueKey<String>('email-u-named')),
        findsOneWidget,
      );
      expect(find.text('agent7@example.com'), findsOneWidget);
      // An unnamed user falls back to the email as the title, and does not
      // repeat it on the supporting line.
      expect(find.text('active@example.com'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('email-u-active')),
        findsNothing,
      );
    });
  }

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

    await _openCreateDialog(tester);
    await tester.tap(find.byKey(const ValueKey<String>('create-user')));
    await tester.pumpAndSettle();

    expect(repo.createdEmail, 'new@example.com');
    expect(repo.createdPassword, 'secret123');
    expect(repo.createdRole, 'field_agent');
    // Name is optional; left blank, none is sent.
    expect(repo.createdDisplayName, isNull);
  });

  testWidgets('the create dialog has an optional Name field', (tester) async {
    await tester.pumpWidget(_app(_FakeUsersRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('new-name')), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Optional. Shown instead of the email.'), findsOneWidget);
  });

  testWidgets('creating a user sends the trimmed Name as displayName',
      (tester) async {
    final repo = _FakeUsersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openCreateDialog(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('new-name')),
      '  Lerato Mahlangu ',
    );
    await tester.tap(find.byKey(const ValueKey<String>('create-user')));
    await tester.pumpAndSettle();

    expect(repo.createdEmail, 'new@example.com');
    expect(repo.createdDisplayName, 'Lerato Mahlangu');
  });

  testWidgets('a whitespace-only Name is sent as no name', (tester) async {
    final repo = _FakeUsersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openCreateDialog(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('new-name')),
      '   ',
    );
    await tester.tap(find.byKey(const ValueKey<String>('create-user')));
    await tester.pumpAndSettle();

    expect(repo.createdEmail, 'new@example.com');
    expect(repo.createdDisplayName, isNull);
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
