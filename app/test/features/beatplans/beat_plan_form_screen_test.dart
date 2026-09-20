import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/features/beatplans/data/beatplans_repository.dart';
import 'package:tradeiq_app/features/beatplans/presentation/beat_plan_form_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

import '../../core/design/amber_golden.dart';
import '../operations_harness.dart';

const List<AppUser> _users = <AppUser>[
  AppUser(
    id: 'a1',
    email: 'agent-one@x.com',
    role: 'field_agent',
    active: true,
    displayName: 'Aisha Patel',
  ),
  // An agent with no display name falls back to the address.
  AppUser(
    id: 'a2',
    email: 'agent-two@x.com',
    role: 'field_agent',
    active: true,
  ),
  AppUser(id: 'm1', email: 'manager@x.com', role: 'manager', active: true),
];

const List<Territory> _territories = <Territory>[
  Territory(id: 't1', name: 'Gauteng North', code: 'gauteng-north'),
];

final List<Outlet> _outlets = <Outlet>[
  opsOutlet('o1', 'Shop One', code: 'S1'),
  opsOutlet('o2', 'Shop Two', code: 'S2'),
];

Future<FakeBeatPlansRepository> _pump(
  WidgetTester tester, {
  List<AppUser> users = _users,
  List<Outlet> outlets = const <Outlet>[],
  Object? createFailure,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
}) async {
  final repo = FakeBeatPlansRepository(createFailure: createFailure);
  await pumpOperations(
    tester,
    const BeatPlanFormScreen(),
    skin: skin,
    textScale: textScale,
    locale: locale,
    users: users,
    overrides: <Override>[
      beatPlansRepositoryProvider.overrideWithValue(repo),
      territoriesRepositoryProvider.overrideWithValue(
        FakeTerritoriesRepository(territories: _territories),
      ),
      outletsRepositoryProvider.overrideWithValue(
        FakeOpsOutletsRepository(outlets: outlets.isEmpty ? _outlets : outlets),
      ),
    ],
  );
  return repo;
}

/// Name the plan, pick today, and pick the agent — everything but the stops.
Future<void> _fillDay(WidgetTester tester) async {
  await scrollOpsTo(
    tester,
    find.byKey(const ValueKey<String>('beatplan-name-field')),
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('beatplan-name-field')),
    'North Route',
  );
  await tester.pumpAndSettle();

  await scrollOpsTo(
    tester,
    find.byKey(const ValueKey<String>('beatplan-date-pick')),
  );
  await tester.tap(find.byKey(const ValueKey<String>('beatplan-date-pick')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();

  await pickOption(
    tester,
    const ValueKey<String>('beatplan-agent-field'),
    'Aisha Patel',
  );
}

Future<void> _addStop(WidgetTester tester, String outletId) async {
  final row = find.byKey(ValueKey<String>('stop-available-$outletId'));
  await scrollOpsTo(tester, row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

TorchPrimaryButton _submit(WidgetTester tester) =>
    tester.widget<TorchPrimaryButton>(
      find.byKey(const ValueKey<String>('beatplan-save-button')),
    );

void main() {
  group('who works the day', () {
    testWidgets('only field agents are offered, by name where there is one', (
      tester,
    ) async {
      await _pump(tester);
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('beatplan-agent-field')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('beatplan-agent-field')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aisha Patel'), findsWidgets);
      // A named agent is offered by name; an unnamed one falls back to email.
      expect(find.text('agent-two@x.com'), findsWidgets);
      // The manager must not be offered as a beat-plan assignee.
      expect(find.text('manager@x.com'), findsNothing);
    });
  });

  group('the stops keep their order', () {
    testWidgets('builds and submits an ordered plan', (tester) async {
      final repo = await _pump(tester);
      await _fillDay(tester);

      // o2 first, then o1, to prove order is preserved.
      await _addStop(tester, 'o2');
      await _addStop(tester, 'o1');

      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('beatplan-save-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('beatplan-save-button')),
      );
      await tester.pumpAndSettle();

      expect(repo.createCount, 1);
      expect(repo.createdName, 'North Route');
      expect(repo.createdAgentId, 'a1');
      expect(repo.createdOutletIds, <String>['o2', 'o1']);
    });

    testWidgets('a stop can be moved earlier, and the request follows', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await _fillDay(tester);
      await _addStop(tester, 'o2');
      await _addStop(tester, 'o1');

      final up = find.byKey(const ValueKey<String>('stop-up-o1'));
      await scrollOpsTo(tester, up);
      await tester.tap(up);
      await tester.pumpAndSettle();

      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('beatplan-save-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('beatplan-save-button')),
      );
      await tester.pumpAndSettle();

      expect(repo.createdOutletIds, <String>['o1', 'o2']);
    });

    testWidgets('a stop can be taken off again', (tester) async {
      await _pump(tester);
      await _fillDay(tester);
      await _addStop(tester, 'o2');

      final remove = find.byKey(const ValueKey<String>('stop-remove-o2'));
      await scrollOpsTo(tester, remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();

      // Back in the pool, and the commit is disarmed again.
      expect(
        find.byKey(const ValueKey<String>('stop-available-o2')),
        findsOneWidget,
      );
      expect(_submit(tester).onPressed, isNull);
    });

    testWidgets('every reorder control names the store it acts on', (
      tester,
    ) async {
      await _pump(tester);
      await _fillDay(tester);
      await _addStop(tester, 'o2');
      await _addStop(tester, 'o1');

      final handle = tester.ensureSemantics();
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('stop-up-o1')),
      );
      // The old screen shipped three IconButtons with tooltips and no
      // labels: a reader heard "button" three times per stop.
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey<String>('stop-up-o1')))
            .label,
        contains('Move Shop One earlier'),
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey<String>('stop-remove-o1')))
            .label,
        contains('Take Shop One off the plan'),
      );
      handle.dispose();
    });
  });

  group('the commit', () {
    testWidgets('is disarmed until the plan is complete, and says why', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('beatplan-name-field')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('beatplan-name-field')),
        'No Agent',
      );
      await tester.pumpAndSettle();

      final button = _submit(tester);
      expect(button.onPressed, isNull);
      expect(
        button.blockedReason,
        'Name the plan, pick a date and an agent, and add at least one stop '
        'first.',
      );
      expect(repo.createCount, 0);
    });

    testWidgets('a failure says nothing was saved', (tester) async {
      await _pump(
        tester,
        createFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      await _fillDay(tester);
      await _addStop(tester, 'o1');
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('beatplan-save-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('beatplan-save-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('That plan was not created. Nothing was saved.'),
        findsOneWidget,
      );
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      await settleOpsToasts(tester);
    });
  });

  group('the wire format', () {
    test('a date is sent zero-padded, as a calendar date', () {
      expect(BeatPlanFormScreen.wireDate(DateTime(2026, 7, 4)), '2026-07-04');
      expect(BeatPlanFormScreen.wireDate(DateTime(2026, 11, 30)), '2026-11-30');
    });
  });

  group('Afrikaans and 2.0x', () {
    testWidgets('Afrikaans has no English left on it', (tester) async {
      await _pump(tester, locale: const Locale('af'));
      expect(find.text('Nuwe besoekplan'), findsWidgets);
      expect(find.text('Die dag'), findsOneWidget);
      expect(find.text('Plannaam'), findsOneWidget);
      expect(find.text('The day'), findsNothing);
    });

    testWidgets('2.0x does not overflow', (tester) async {
      await _pump(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });
  });

  group('every button is operable by a screen reader', () {
    // The kit shipped a component family that announced itself and did
    // nothing when a screen reader activated it, and `SectionRuleAction` and
    // `PaginationFooter.action` were still shipping that way when this group
    // was migrated. This is the guard, on this screen, per phase — so no
    // local `Semantics(button: true, excludeSemantics: true)` around a bare
    // GestureDetector can bring it back.
    testWidgets('the empty builder', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });

    testWidgets('with a day and a stop on it', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await _fillDay(tester);
      await _addStop(tester, 'o1');
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      testWidgets('${skin.mode.name}, nothing filled in: 0', (tester) async {
        await _pump(tester, skin: skin);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'beat-plan-form',
          phase: 'form',
        );
        expect(census.objectCount, 0, reason: census.describe());
      });

      testWidgets('${skin.mode.name}, complete: 1', (tester) async {
        await _pump(tester, skin: skin);
        await _fillDay(tester);
        await _addStop(tester, 'o1');
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'beat-plan-form',
          phase: 'ready',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });
    }
  });
}
