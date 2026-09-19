import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/tasks_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s9_action_plan_screen.dart';

import '../agent_harness.dart';
import 'section_harness.dart';

class _SpyTasks implements TasksRepository {
  final calls = <(String, String, TaskDraft)>[];

  @override
  Future<void> saveTask({
    required String visitDraftId,
    required String outletId,
    required TaskDraft task,
  }) async => calls.add((visitDraftId, outletId, task));
}

List<Override> _overrides(TasksRepository spy) => <Override>[
  tasksRepositoryProvider.overrideWithValue(spy),
];

const _screen = S9ActionPlanScreen(visitDraftId: 'v1', outletId: 'o1');

Finder _key(String k) => find.byKey(ValueKey<String>(k));

void main() {
  testWidgets(
    'Add task queues one task with its priority, clears the form, and '
    'lists it as a row',
    (tester) async {
      final spy = _SpyTasks();
      await pumpSection(tester, _screen, overrides: _overrides(spy));

      expect(find.text('No extra tasks yet.'), findsOneWidget);
      await typeInSection(tester, _key('task-type'), 'Planogram gap');
      await typeInSection(tester, _key('task-fix'), 'Re-face the top shelf');
      await tapInSection(
        tester,
        find.descendant(of: _key('task-priority'), matching: find.text('High')),
      );
      expect(sectionSave, findsOneWidget);
      expect(find.text('Add task'), findsOneWidget);
      await saveSection(tester);

      final (visit, outlet, task) = spy.calls.single;
      expect(visit, 'v1');
      expect(outlet, 'o1');
      expect(task.findingType, 'Planogram gap');
      expect(task.requiredFix, 'Re-face the top shelf');
      expect(task.priority, 'high');

      // The form is cleared for the next one, and the raised task is a row.
      await scrollAgentTo(tester, _key('task-raised-0'));
      expect(
        find.descendant(
          of: _key('task-raised-0'),
          matching: find.text('Planogram gap'),
        ),
        findsOneWidget,
      );
      expect(find.text('1 task queued for sync'), findsOneWidget);
      await disposeAgentScreen(tester);
    },
  );

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      testWidgets('an empty form is zero, a filled one is one — ${skin.name}', (
        tester,
      ) async {
        await pumpSection(
          tester,
          _screen,
          overrides: _overrides(_SpyTasks()),
          skin: skin,
        );
        await expectAmber(
          tester,
          skin: skin,
          route: 'action plan',
          phase: 'untouched',
          expected: 0,
        );
        await typeInSection(tester, _key('task-type'), 'Dirty shelf');
        await scrollAgentTo(tester, sectionSave);
        await expectAmber(
          tester,
          skin: skin,
          route: 'action plan',
          phase: 'dirty',
          expected: 1,
        );
        await disposeAgentScreen(tester);
      });
    }
  });
}
