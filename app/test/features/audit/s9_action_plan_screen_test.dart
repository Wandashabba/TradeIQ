import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/tasks_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s9_action_plan_screen.dart';

class _SpyTasksRepository implements TasksRepository {
  String? visitDraftId;
  String? outletId;
  TaskDraft? task;

  @override
  Future<void> saveTask({
    required String visitDraftId,
    required String outletId,
    required TaskDraft task,
  }) async {
    this.visitDraftId = visitDraftId;
    this.outletId = outletId;
    this.task = task;
  }
}

void main() {
  testWidgets('captures a manual task and calls saveTask on Add task', (tester) async {
    final spy = _SpyTasksRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [tasksRepositoryProvider.overrideWithValue(spy)],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: S9ActionPlanScreen(visitDraftId: 'v1', outletId: 'o1'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('task-type')), 'oos');
    await tester.enterText(find.byKey(const ValueKey('task-fix')), 'Restock shelf');

    await tester.ensureVisible(find.byKey(const ValueKey('task-priority')));
    await tester.tap(find.byKey(const ValueKey('task-priority')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('high').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add task'));
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.outletId, 'o1');
    expect(spy.task!.findingType, 'oos');
    expect(spy.task!.requiredFix, 'Restock shelf');
    expect(spy.task!.priority, 'high');
    expect(find.text('Task queued for sync'), findsOneWidget);

    // The text fields are cleared after queueing.
    expect(find.text('oos'), findsNothing);
    expect(find.text('Restock shelf'), findsNothing);
  });
}
