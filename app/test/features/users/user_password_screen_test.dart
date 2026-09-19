import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/password_repository.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';
import 'package:tradeiq_app/features/users/presentation/user_password_screen.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';

class _StaffPasswordRepository implements PasswordRepository {
  Object? issueFailure;
  Object? setFailure;
  final issuedFor = <String>[];
  final setFor = <String, String>{};
  var _next = 48217390;

  @override
  Future<IssuedResetCode> issueResetCode(String userId) async {
    issuedFor.add(userId);
    if (issueFailure != null) throw issueFailure!;
    return IssuedResetCode(
      code: '${_next++}',
      expiresAt: DateTime(2026, 9, 19, 14, 32),
      email: 'agent7@example.com',
    );
  }

  @override
  Future<PasswordChanged> setPasswordFor(
    String userId,
    String newPassword,
  ) async {
    if (setFailure != null) throw setFailure!;
    setFor[userId] = newPassword;
    return const PasswordChanged(otherSessionsEnded: false);
  }

  @override
  Future<PasswordChanged> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<PasswordChanged> redeemResetCode({
    required String email,
    required String code,
    required String newPassword,
  }) => throw UnimplementedError();
}

const _agent = AppUser(
  id: 'u-agent',
  email: 'agent7@example.com',
  role: 'field_agent',
  active: true,
  displayName: 'Sipho Ndlovu',
);

Finder _key(String k) => find.byKey(ValueKey<String>(k));

Future<void> _pump(
  WidgetTester tester,
  _StaffPasswordRepository repo, {
  SkinMode skin = SkinMode.day,
  AppUser? user = _agent,
  List<Override> extra = const <Override>[],
}) => pumpAgentScreen(
  tester,
  UserPasswordScreen(userId: 'u-agent', user: user),
  path: '/users/u-agent/password',
  overrides: <Override>[
    ...agentBaseOverrides(db: agentTestDb(), skin: skin),
    passwordRepositoryProvider.overrideWithValue(repo),
    ...extra,
  ],
  extraRoutes: <GoRoute>[
    GoRoute(path: '/users', builder: (context, state) => const Text('USERS')),
  ],
);

Future<void> _press(WidgetTester tester, String key) async {
  if (_key(key).evaluate().isEmpty) await scrollAgentTo(tester, _key(key));
  await tester.ensureVisible(_key(key));
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await scrollAgentTo(tester, _key(key));
  await tester.enterText(_key(key), text);
  await tester.pumpAndSettle();
}

void main() {
  test('the console offers only what the server allows', () {
    // The server's staffMaySetPasswordFor, mirrored.
    expect(staffMaySetPasswordFor('admin', 'admin'), isTrue);
    expect(staffMaySetPasswordFor('admin', 'manager'), isTrue);
    expect(staffMaySetPasswordFor('admin', 'field_agent'), isTrue);
    expect(staffMaySetPasswordFor('manager', 'field_agent'), isTrue);
    expect(staffMaySetPasswordFor('manager', 'manager'), isFalse);
    expect(staffMaySetPasswordFor('manager', 'admin'), isFalse);
    expect(staffMaySetPasswordFor('field_agent', 'field_agent'), isFalse);
    expect(staffMaySetPasswordFor(null, 'field_agent'), isFalse);
  });

  testWidgets('generates a code, shows it once, reads it digit by digit', (
    tester,
  ) async {
    final repo = _StaffPasswordRepository();
    await _pump(tester, repo);
    expect(find.text('Sipho Ndlovu'), findsOneWidget);
    expect(_key('reset-code'), findsNothing);

    await _press(tester, 'issue-reset-code');
    expect(repo.issuedFor, ['u-agent']);
    // Two groups of four, as it is read out across a counter.
    expect(find.text('4821 7390'), findsOneWidget);
    expect(find.textContaining('For agent7@example.com'), findsOneWidget);
    // A screen reader reads digits, never "forty-eight million".
    final semantics = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(RegExp('Reset code 4 8 2 1 7 3 9 0')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('48217390|4821 7390')),
      findsNothing,
      reason: 'the grouped digits must not also be read as a number',
    );
    semantics.dispose();

    // A new code replaces the old one on screen, as on the server.
    await _press(tester, 'reissue-reset-code');
    expect(repo.issuedFor, ['u-agent', 'u-agent']);
    // Back to the top, where the code block is.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('4821 7390'), findsNothing);
    expect(find.text('4821 7391'), findsOneWidget);

    await _press(tester, 'reset-code-done');
    expect(find.text('USERS'), findsOneWidget);
  });

  testWidgets('a refusal says why, and shows no code', (tester) async {
    final repo = _StaffPasswordRepository()
      ..issueFailure = const PasswordRefused(PasswordRefusal.notPermitted);
    await _pump(tester, repo);
    await _press(tester, 'issue-reset-code');
    expect(_key('reset-code'), findsNothing);
    expect(find.textContaining('You can reset field agents only'), findsOne);
  });

  testWidgets('another organisation\'s user is simply not found', (
    tester,
  ) async {
    final repo = _StaffPasswordRepository()
      ..issueFailure = const PasswordRefused(PasswordRefusal.notFound);
    await _pump(tester, repo, user: null);
    await _press(tester, 'issue-reset-code');
    expect(find.text('That user is not in your organisation.'), findsOne);
  });

  testWidgets('sets a password in person, and says what it cannot end', (
    tester,
  ) async {
    final repo = _StaffPasswordRepository();
    await _pump(tester, repo);
    await scrollAgentTo(tester, _key('set-password'));
    expect(
      tester.widget<TorchSecondaryButton>(_key('set-password')).blockedReason,
      'Type a password for them first',
    );

    await _enter(tester, 'set-password-field', 'blue truck monday');
    await _enter(tester, 'set-password-confirm', 'blue truck monday');
    await _press(tester, 'set-password');

    expect(repo.setFor, {'u-agent': 'blue truck monday'});
    await scrollAgentTo(tester, _key('set-password-done'));
    expect(
      find.textContaining('stay signed in until they expire'),
      findsOneWidget,
    );
  });

  testWidgets('the email is not a password', (tester) async {
    final repo = _StaffPasswordRepository();
    await _pump(tester, repo);
    await _enter(tester, 'set-password-field', 'agent7@example.com');
    await _enter(tester, 'set-password-confirm', 'agent7@example.com');
    await _press(tester, 'set-password');
    expect(repo.setFor, isEmpty);
    expect(
      find.text('Your password cannot be your email address.'),
      findsOneWidget,
    );
  });

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      testWidgets('ready, ${skin.name}: 1 — "Generate reset code"', (
        tester,
      ) async {
        await _pump(tester, _StaffPasswordRepository(), skin: skin);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'user-password',
          phase: 'ready',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('code shown, ${skin.name}: 1 — "Done"; the code is ink', (
        tester,
      ) async {
        await _pump(tester, _StaffPasswordRepository(), skin: skin);
        await _press(tester, 'issue-reset-code');
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'user-password',
          phase: 'code-shown',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });
    }
  });
}
