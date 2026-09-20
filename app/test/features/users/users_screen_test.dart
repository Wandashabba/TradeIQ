import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';
import 'package:tradeiq_app/features/users/presentation/users_screen.dart';

import '../../core/design/amber_golden.dart';
import '../clientadmin_harness.dart';
import 'users_fakes.dart';

Future<FakeUsersRepository> _pump(
  WidgetTester tester, {
  FakeUsersRepository? repo,
  String role = 'admin',
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  bool settle = true,
}) async {
  final fake = repo ?? FakeUsersRepository();
  await pumpConsole(
    tester,
    const UsersScreen(),
    skin: skin,
    textScale: textScale,
    locale: locale,
    settle: settle,
    path: '/users',
    overrides: <Override>[
      usersRepositoryProvider.overrideWithValue(fake),
      sessionAs(role),
    ],
  );
  return fake;
}

/// Dismiss the open sheet.
///
/// There is no visible Close control in Night or Day — the grabber and the
/// scrim are the dismissal — so the test taps the barrier the way a thumb
/// would. Veld's 56dp Close row is the one skin that has a control.
Future<void> _dismissSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(180, 8));
  await tester.pumpAndSettle();
  expect(find.byType(TorchSheet), findsNothing);
}

/// Open one user's sheet.
Future<void> _openSheet(WidgetTester tester, String id) async {
  await scrollConsoleTo(tester, keyed('user-$id'));
  await tester.tap(keyed('user-$id'));
  await tester.pumpAndSettle();
}

void main() {
  group('the roster', () {
    testWidgets('a row names a person, never a database id', (tester) async {
      await _pump(
        tester,
        repo: FakeUsersRepository(
          users: const <AppUser>[namedUser, inactiveUser],
        ),
      );

      expect(find.byType(PersonRow), findsNWidgets(2));
      final handle = tester.ensureSemantics();
      expect(find.text('Sipho Ndlovu'), findsOneWidget);
      // The row middle-truncates what it paints, so the whole line is
      // asserted where a screen reader gets it.
      expect(
        tester.getSemantics(keyed('user-u-named')).label,
        contains('Field agent, agent7@example.com'),
      );
      // An account that was never given a name reads by its address.
      expect(
        tester.getSemantics(keyed('user-u-inactive')).label,
        contains('inactive@example.com'),
      );
      // The id never appears anywhere on the row.
      expect(
        tester.getSemantics(keyed('user-u-named')).label,
        isNot(contains('u-named')),
      );
      expect(find.text('u-named'), findsNothing);
      handle.dispose();
    });

    testWidgets('status is a word and a mark, and both are announced', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        repo: FakeUsersRepository(
          users: const <AppUser>[namedUser, inactiveUser],
        ),
      );

      final chips = tester
          .widgetList<StatusChip>(find.byType(StatusChip))
          .toList();
      expect(chips.map((c) => c.label), <String>['Active', 'Inactive']);
      // Deactivating somebody is a decision, not a fault: Oatmeal and a
      // square, never crimson.
      expect(chips[0].level, StatusLevel.onTarget);
      expect(chips[1].level, StatusLevel.held);

      // The word reaches the row's one semantics node through trailingLabel.
      expect(tester.getSemantics(keyed('user-u-named')).label,
          contains('Active'));
      expect(
        tester.getSemantics(keyed('user-u-inactive')).label,
        contains('Inactive'),
      );
      handle.dispose();
    });

    testWidgets('an inactive user is still reachable', (tester) async {
      await _pump(tester);
      final row = tester.widget<PersonRow>(
        find.descendant(
          of: keyed('user-u-inactive'),
          matching: find.byType(PersonRow),
        ),
      );
      expect(
        row.deactivated,
        isFalse,
        reason:
            'a deactivated PersonRow has no onTap, and an admin has to be '
            'able to switch the account back on',
      );
      await _openSheet(tester, 'u-inactive');
      expect(find.byType(TorchSheet), findsOneWidget);
    });

    testWidgets('the counts are measured zeros, never hidden tiles', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeUsersRepository(users: const <AppUser>[namedUser]),
      );
      expect(find.byType(StatCluster), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('INACTIVE'), findsOneWidget);
      // Nobody deactivated renders 0 and keeps its place.
      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('the section rule counts what it is showing', (tester) async {
      await _pump(tester);
      expect(find.byType(SectionRule), findsOneWidget);
      expect(find.text('2'), findsWidgets);
    });
  });

  group('role gating', () {
    testWidgets('an admin gets Add user and the whole sheet', (tester) async {
      await _pump(tester, role: 'admin');
      await scrollConsoleTo(tester, keyed('user-create'));
      expect(keyed('user-create'), findsOneWidget);

      await _openSheet(tester, 'u-active');
      expect(keyed('active-u-active'), findsOneWidget);
      expect(keyed('edit-name-u-active'), findsOneWidget);
    });

    testWidgets('a manager gets a read-only roster and the note that says so', (
      tester,
    ) async {
      await _pump(tester, role: 'manager');
      expect(
        find.text('Only admins can add or change users.'),
        findsOneWidget,
      );
      expect(keyed('user-create'), findsNothing);

      // A manager may reset a field agent and nobody else — the same rule the
      // server applies, so the console never offers a door that answers 403.
      await _openSheet(tester, 'u-inactive');
      expect(keyed('reset-password-u-inactive'), findsOneWidget);
      expect(keyed('active-u-inactive'), findsNothing);
      expect(keyed('edit-name-u-inactive'), findsNothing);
      await _dismissSheet(tester);

      await _openSheet(tester, 'u-active');
      expect(keyed('reset-password-u-active'), findsNothing);
      expect(keyed('user-read-only'), findsOneWidget);
    });

    testWidgets('an admin may reset anyone', (tester) async {
      await _pump(
        tester,
        role: 'admin',
        repo: FakeUsersRepository(
          users: const <AppUser>[adminUser, activeUser, inactiveUser],
        ),
      );
      for (final id in <String>['u-admin', 'u-active', 'u-inactive']) {
        await _openSheet(tester, id);
        expect(keyed('reset-password-$id'), findsOneWidget);
        await _dismissSheet(tester);
      }
    });
  });

  group('the active toggle', () {
    testWidgets('records setActive, with a mandatory state word', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await _openSheet(tester, 'u-active');

      final toggle = tester.widget<TorchToggle>(keyed('active-u-active'));
      expect(toggle.value, isTrue);
      expect(toggle.onWord, 'Active');
      expect(toggle.offWord, 'Inactive');
      expect(find.text('Active'), findsWidgets);

      await tester.tap(keyed('active-u-active'));
      await tester.pumpAndSettle();
      expect(repo.setActiveId, 'u-active');
      expect(repo.setActiveValue, isFalse);
    });

    testWidgets('a failed save puts the toggle back and says why', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeUsersRepository(setActiveFailure: offline()),
      );
      await _openSheet(tester, 'u-active');

      await tester.tap(keyed('active-u-active'));
      await tester.pumpAndSettle();

      // The switch never lies about the server.
      expect(
        tester.widget<TorchToggle>(keyed('active-u-active')).value,
        isTrue,
      );
      expect(keyed('active-error-u-active'), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });
  });

  group('edit name', () {
    /// The name editor is a PANE of the user sheet, not a second sheet:
    /// `showTorchSheet` asserts on a sheet over a sheet, and unify §1.10's
    /// answer is a cross-fade of this sheet's own content.
    Future<void> openEdit(WidgetTester tester, String id) async {
      await _openSheet(tester, id);
      await tester.tap(keyed('edit-name-$id'));
      await tester.pumpAndSettle();
      expect(find.byType(TorchSheet), findsOneWidget);
      expect(find.byType(TorchSheetSwap), findsOneWidget);
    }

    testWidgets('sets a name on an unnamed user and refreshes the list', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await openEdit(tester, 'u-inactive');

      await tester.enterText(keyed('edit-name-field'), '  Lerato Dube  ');
      await tester.pumpAndSettle();
      await tester.tap(keyed('edit-name-save'));
      await tester.pumpAndSettle();

      expect(repo.updatedId, 'u-inactive');
      expect(repo.updatedDisplayName, 'Lerato Dube');
      expect(find.text('Lerato Dube'), findsOneWidget);
    });

    testWidgets('a blank name clears it and the row falls back to the address',
        (tester) async {
      final repo = await _pump(
        tester,
        repo: FakeUsersRepository(users: const <AppUser>[namedUser]),
      );
      await openEdit(tester, 'u-named');

      await tester.enterText(keyed('edit-name-field'), '   ');
      await tester.pumpAndSettle();
      await tester.tap(keyed('edit-name-save'));
      await tester.pumpAndSettle();

      expect(repo.updatedDisplayName, isNull);
      expect(find.text('Sipho Ndlovu'), findsNothing);
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(keyed('user-u-named')).label,
        contains('agent7@example.com'),
      );
      handle.dispose();
    });

    testWidgets('an unchanged name closes without a request', (tester) async {
      final repo = await _pump(
        tester,
        repo: FakeUsersRepository(users: const <AppUser>[namedUser]),
      );
      await openEdit(tester, 'u-named');

      await tester.tap(keyed('edit-name-save'));
      await tester.pumpAndSettle();
      expect(repo.updateCalls, 0);
      expect(find.byType(TorchSheet), findsNothing);
    });

    testWidgets('over 120 characters is refused before sending', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await openEdit(tester, 'u-inactive');

      await tester.enterText(keyed('edit-name-field'), 'a' * 121);
      await tester.pumpAndSettle();
      await tester.tap(keyed('edit-name-save'));
      await tester.pumpAndSettle();

      expect(find.text('Use 120 characters or fewer.'), findsOneWidget);
      expect(repo.updateCalls, 0);
    });

    testWidgets('a failed save keeps the sheet open with a plain error', (
      tester,
    ) async {
      await _pump(tester, repo: FakeUsersRepository(updateFailure: offline()));
      await openEdit(tester, 'u-inactive');

      await tester.enterText(keyed('edit-name-field'), 'Lerato Dube');
      await tester.pumpAndSettle();
      await tester.tap(keyed('edit-name-save'));
      await tester.pumpAndSettle();

      expect(keyed('edit-name-error'), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      // The typed name is still there.
      expect(find.text('Lerato Dube'), findsOneWidget);
    });
  });

  group('add user', () {
    Future<void> openCreate(WidgetTester tester) async {
      await scrollConsoleTo(tester, keyed('user-create'));
      await tester.tap(keyed('user-create'));
      await tester.pumpAndSettle();
    }

    testWidgets('records the entered arguments, trimmed', (tester) async {
      final repo = await _pump(tester);
      await openCreate(tester);

      await tester.enterText(keyed('new-name'), '  Lerato Dube  ');
      await tester.enterText(keyed('new-email'), 'lerato@example.com');
      await tester.enterText(keyed('new-password'), 'correct horse battery');
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, keyed('create-user'));
      await tester.tap(keyed('create-user'));
      await tester.pumpAndSettle();

      expect(repo.createdEmail, 'lerato@example.com');
      expect(repo.createdPassword, 'correct horse battery');
      expect(repo.createdRole, 'field_agent');
      expect(repo.createdDisplayName, 'Lerato Dube');
    });

    testWidgets('a whitespace-only name is sent as no name', (tester) async {
      final repo = await _pump(tester);
      await openCreate(tester);

      await tester.enterText(keyed('new-name'), '   ');
      await tester.enterText(keyed('new-email'), 'lerato@example.com');
      await tester.enterText(keyed('new-password'), 'correct horse battery');
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, keyed('create-user'));
      await tester.tap(keyed('create-user'));
      await tester.pumpAndSettle();

      expect(repo.createdDisplayName, isNull);
    });

    testWidgets('the password rule is stated before the request, not after', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await openCreate(tester);

      expect(
        find.text('At least 12 characters. Three ordinary words work.'),
        findsOneWidget,
      );

      await tester.enterText(keyed('new-email'), 'lerato@example.com');
      await tester.enterText(keyed('new-password'), 'short');
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, keyed('create-user'));
      await tester.tap(keyed('create-user'));
      await tester.pumpAndSettle();

      expect(repo.createdEmail, isNull);
      expect(
        find.text('At least 12 characters. Three ordinary words work.'),
        findsWidgets,
      );
    });

    testWidgets("a 409 carries the server's own sentence, never the typed "
        'password', (tester) async {
      final repo = await _pump(
        tester,
        repo: FakeUsersRepository(
          createFailure: DioException(
            requestOptions: RequestOptions(path: '/users'),
            response: Response<Object?>(
              requestOptions: RequestOptions(path: '/users'),
              statusCode: 409,
              data: <String, Object?>{
                'error': 'That email address already has an account.',
              },
            ),
          ),
        ),
      );
      await openCreate(tester);

      await tester.enterText(keyed('new-email'), 'lerato@example.com');
      await tester.enterText(keyed('new-password'), 'correct horse battery');
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, keyed('create-user'));
      await tester.tap(keyed('create-user'));
      await tester.pumpAndSettle();

      expect(repo.createdEmail, 'lerato@example.com');
      await scrollSheetTo(tester, keyed('create-user-error'));
      expect(
        find.text('That email address already has an account.'),
        findsOneWidget,
      );
      // The sentence states the rule and never echoes what was typed. The
      // password field still holds it, obscured — that is the field, not the
      // message.
      final message = tester
          .widget<ErrorState>(keyed('create-user-error'))
          .message;
      expect(message.body, isNot(contains('correct horse')));
      expect(message.headline, isNot(contains('correct horse')));
    });
  });

  group('the states', () {
    testWidgets('empty is a designed state, not a centred "No data"', (
      tester,
    ) async {
      await _pump(tester, repo: FakeUsersRepository(users: const <AppUser>[]));
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No users yet.'), findsOneWidget);
      expect(find.byType(PersonRow), findsNothing);
      // And no cluster of nought against nought, which reads as a broken
      // screen rather than as an empty one.
      expect(find.byType(StatCluster), findsNothing);
    });

    testWidgets('loading is a skeleton, and nothing before 600ms', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeUsersRepository(listPending: true),
        settle: false,
      );
      expect(find.byType(SkeletonRows), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('Add user is on the screen in every phase, not only when the '
        'roster loaded', (tester) async {
      // The capability, written as the failure. Before the fix the create
      // control was built inside `_loaded`, so an admin on a bad connection
      // whose GET /users 500s was offered exactly one thing: "Try again".
      // Adding a user is a POST; it has nothing to do with whether the
      // roster arrived, and before the migration it was a FAB on the
      // scaffold that survived every state.
      await _pump(tester, repo: FakeUsersRepository(listFailure: offline()));
      expect(keyed('users-retry'), findsOneWidget);
      await scrollConsoleTo(tester, keyed('user-create'));
      expect(keyed('user-create'), findsOneWidget);
    });

    testWidgets('Add user is there while the roster is still loading', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeUsersRepository(listPending: true),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 700));
      await scrollConsoleTo(tester, keyed('user-create'));
      expect(keyed('user-create'), findsOneWidget);
    });

    testWidgets('Add user is there on an empty roster', (tester) async {
      await _pump(tester, repo: FakeUsersRepository(users: const <AppUser>[]));
      await scrollConsoleTo(tester, keyed('user-create'));
      expect(keyed('user-create'), findsOneWidget);
    });

    testWidgets('a non-admin never sees Add user, in any phase', (
      tester,
    ) async {
      // The gate survives the move. `canEdit` still decides, and a manager
      // who could not add a user when the roster loaded cannot add one when
      // it fails either.
      await _pump(
        tester,
        role: 'manager',
        repo: FakeUsersRepository(listFailure: offline()),
      );
      expect(keyed('users-retry'), findsOneWidget);
      expect(keyed('user-create'), findsNothing);

      await _pump(tester, role: 'manager');
      expect(keyed('user-create'), findsNothing);
    });

    testWidgets('a failure is sanitised and offers one retry', (tester) async {
      await _pump(tester, repo: FakeUsersRepository(listFailure: offline()));
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(keyed('users-retry'), findsOneWidget);
    });
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      final lit = skin.mode == SkinMode.night ? 1 : 0;
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(t, skin: skin),
        'empty': (t) => _pump(
          t,
          skin: skin,
          repo: FakeUsersRepository(users: const <AppUser>[]),
        ),
        'loading': (t) async {
          await _pump(
            t,
            skin: skin,
            repo: FakeUsersRepository(listPending: true),
            settle: false,
          );
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          repo: FakeUsersRepository(listFailure: offline()),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'users',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }

      testWidgets('${skin.mode.name}, the add-user sheet: its commit, and '
          'nothing beneath', (tester) async {
        await _pump(tester, skin: skin);
        await scrollConsoleTo(tester, keyed('user-create'));
        await tester.tap(keyed('user-create'));
        await tester.pumpAndSettle();
        // The commit is at the foot of a sheet that outgrows 88% of a 360dp
        // phone, so it has to be on screen before the pixels are counted.
        await scrollSheetTo(tester, keyed('create-user'));

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'users',
          phase: 'create sheet',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'the sheet owns the frame: the nav tab beneath it drops to its '
              'ink form and the only light is the commit.\n'
              '${census.describe()}',
        );
      });

      testWidgets("${skin.mode.name}, a user's sheet: 0", (tester) async {
        await _pump(tester, skin: skin);
        await _openSheet(tester, 'u-active');
        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              'the verbs sheet has no commit of its own — every action on it '
              'is a ghost or a toggle.\n${census.describe()}',
        );
      });
    }
  });

  group('2.0x text and Afrikaans lengths', () {
    testWidgets('the roster survives and nothing overflows', (tester) async {
      await _pump(
        tester,
        textScale: 2.0,
        locale: const Locale('af'),
        repo: FakeUsersRepository(
          users: const <AppUser>[
            AppUser(
              id: 'u-long',
              email: 'nomsa.dlamini-mkhize@bloemfontein-noord.example.com',
              role: 'field_agent',
              active: true,
              displayName: 'Nomsa Dlamini-Mkhize van der Westhuizen',
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      await scrollConsoleTo(tester, keyed('user-u-long'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the add-user sheet survives at 2.0x', (tester) async {
      await _pump(tester, textScale: 2.0, locale: const Locale('af'));
      await scrollConsoleTo(tester, keyed('user-create'));
      await tester.tap(keyed('user-create'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await scrollSheetTo(tester, keyed('create-user'));
      expect(tester.takeException(), isNull);
    });
  });
}
