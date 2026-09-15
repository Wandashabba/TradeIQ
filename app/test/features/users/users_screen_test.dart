import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
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
  _FakeUsersRepository({
    List<AppUser> users = const [_activeUser, _inactiveUser],
    this.failUpdate = false,
  }) : users = [...users];

  /// Mutable so a successful update shows up on the next list.
  final List<AppUser> users;
  final bool failUpdate;
  int listCalls = 0;
  String? setActiveId;
  bool? setActiveValue;
  String? createdEmail;
  String? createdPassword;
  String? createdRole;
  String? createdDisplayName;
  int updateCalls = 0;
  String? updatedId;
  String? updatedDisplayName;

  @override
  Future<PaginatedResponse<AppUser>> listUsers() async {
    listCalls++;
    return PaginatedResponse(data: List.of(users), nextCursor: null);
  }

  @override
  Future<AppUser> updateDisplayName(String id, String? displayName) async {
    updateCalls++;
    updatedId = id;
    updatedDisplayName = displayName;
    if (failUpdate) {
      throw DioException(
        requestOptions: RequestOptions(path: '/users/$id'),
        type: DioExceptionType.connectionError,
      );
    }
    final i = users.indexWhere((u) => u.id == id);
    final old = users[i];
    final updated = AppUser(
      id: old.id,
      email: old.email,
      role: old.role,
      active: old.active,
      displayName: displayName,
    );
    users[i] = updated;
    return updated;
  }

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

  @override
  Future<AppUser> updateDisplayName(String id, String? displayName) async =>
      throw UnimplementedError();
}

Future<void> _openEditName(WidgetTester tester, String userId) async {
  await tester.tap(find.byKey(ValueKey<String>('edit-name-$userId')));
  await tester.pumpAndSettle();
}

String _nameFieldText(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('edit-name-field')),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

Future<void> _saveName(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('edit-name-save')));
  await tester.pumpAndSettle();
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

  group('edit name', () {
    testWidgets('sets a name on an unnamed user and refreshes the list',
        (tester) async {
      final repo = _FakeUsersRepository();
      await tester.pumpWidget(_app(repo, theme: AppTheme.light()));
      await tester.pumpAndSettle();
      final listsBefore = repo.listCalls;

      await _openEditName(tester, 'u-active');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_nameFieldText(tester), isEmpty);
      expect(
        find.text('Leave blank to clear the name; the email is shown instead.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('edit-name-field')),
        '  Thandi Zulu ',
      );
      await _saveName(tester);

      expect(repo.updatedId, 'u-active');
      expect(repo.updatedDisplayName, 'Thandi Zulu');
      expect(find.byType(AlertDialog), findsNothing);
      // The list was re-fetched and now titles the row by the new name.
      expect(repo.listCalls, greaterThan(listsBefore));
      expect(find.text('Thandi Zulu'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('email-u-active')),
        findsOneWidget,
      );
    });

    testWidgets('prefills and changes an existing name', (tester) async {
      final repo = _FakeUsersRepository(users: const [_namedUser]);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await _openEditName(tester, 'u-named');
      expect(_nameFieldText(tester), 'Sipho Ndlovu');

      await tester.enterText(
        find.byKey(const ValueKey<String>('edit-name-field')),
        'Sipho M. Ndlovu',
      );
      await _saveName(tester);

      expect(repo.updatedId, 'u-named');
      expect(repo.updatedDisplayName, 'Sipho M. Ndlovu');
      expect(find.text('Sipho M. Ndlovu'), findsOneWidget);
      expect(find.text('Sipho Ndlovu'), findsNothing);
    });

    testWidgets('a blank name clears it and the row falls back to the email',
        (tester) async {
      final repo = _FakeUsersRepository(users: const [_namedUser]);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await _openEditName(tester, 'u-named');
      await tester.enterText(
        find.byKey(const ValueKey<String>('edit-name-field')),
        '   ',
      );
      await _saveName(tester);

      expect(repo.updateCalls, 1);
      expect(repo.updatedId, 'u-named');
      expect(repo.updatedDisplayName, isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Sipho Ndlovu'), findsNothing);
      expect(find.text('agent7@example.com'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('email-u-named')),
        findsNothing,
      );
    });

    testWidgets('an unchanged name closes without a request', (tester) async {
      final repo = _FakeUsersRepository(users: const [_namedUser]);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await _openEditName(tester, 'u-named');
      await _saveName(tester);

      expect(repo.updateCalls, 0);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('over 120 characters is rejected before sending',
        (tester) async {
      final repo = _FakeUsersRepository();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await _openEditName(tester, 'u-active');
      await tester.enterText(
        find.byKey(const ValueKey<String>('edit-name-field')),
        'a' * 121,
      );
      await _saveName(tester);

      expect(find.text('Use 120 characters or fewer.'), findsOneWidget);
      expect(repo.updateCalls, 0);
      expect(find.byType(AlertDialog), findsOneWidget);

      // Exactly 120 is fine, and surrounding spaces don't count (the server
      // trims before it measures).
      await tester.enterText(
        find.byKey(const ValueKey<String>('edit-name-field')),
        ' ${'a' * 120} ',
      );
      await _saveName(tester);

      expect(find.text('Use 120 characters or fewer.'), findsNothing);
      expect(repo.updatedDisplayName, 'a' * 120);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a failed save keeps the dialog open with a plain error',
        (tester) async {
      final repo = _FakeUsersRepository(failUpdate: true);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      final listsBefore = repo.listCalls;

      await _openEditName(tester, 'u-active');
      await tester.enterText(
        find.byKey(const ValueKey<String>('edit-name-field')),
        'Thandi Zulu',
      );
      await _saveName(tester);

      expect(repo.updateCalls, 1);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text(
          'Could not save the name. Could not reach the server. '
          'Check your connection and try again.',
        ),
        findsOneWidget,
      );
      // The typed name is kept, nothing was refreshed, and Save still works.
      expect(_nameFieldText(tester), 'Thandi Zulu');
      expect(repo.listCalls, listsBefore);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('edit-name-save')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const ValueKey<String>('edit-name-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    for (final (label, theme) in [
      ('light', AppTheme.light()),
      ('night', AppTheme.dark()),
    ]) {
      testWidgets('$label: the edit dialog is a glass pane from the theme',
          (tester) async {
        await tester.pumpWidget(
          _app(
            _FakeUsersRepository(users: const [_namedUser]),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();

        await _openEditName(tester, 'u-named');

        final dialogContext = tester.element(find.byType(AlertDialog));
        final colors = dialogContext.colors;
        expect(colors.glass, isTrue);
        final pane = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(pane.color, colors.surface1);
        final shape = pane.shape! as RoundedRectangleBorder;
        expect(shape.side.color, dialogContext.lumen.panelRim);
        expect(find.text('Edit name'), findsOneWidget);
        expect(_nameFieldText(tester), 'Sipho Ndlovu');
      });
    }
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
