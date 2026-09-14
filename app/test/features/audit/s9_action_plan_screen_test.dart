import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/console.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
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

const _bothThemes = ['light', 'dark'];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

Widget _screen(TasksRepository spy, {ThemeData? theme, Key? key}) =>
    ProviderScope(
      overrides: [tasksRepositoryProvider.overrideWithValue(spy)],
      child: MaterialApp(
        theme: theme,
        // A fresh key per theme pass so State never carries across pumps.
        home: Scaffold(
          body: SingleChildScrollView(
            child: S9ActionPlanScreen(
              key: key,
              visitDraftId: 'v1',
              outletId: 'o1',
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'captures a manual task and calls saveTask on Add task — priority via '
    'ChoiceRow',
    (tester) async {
      for (final name in _bothThemes) {
        final spy = _SpyTasksRepository();
        await tester.pumpWidget(
          _screen(spy, theme: _themeFor(name), key: ValueKey(name)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const ValueKey('task-type')), 'oos');
        await tester.enterText(
          find.byKey(const ValueKey('task-fix')),
          'Restock shelf',
        );

        // Priority is now a ChoiceRow — tap the chip label, not a dropdown menu.
        await tester.ensureVisible(find.text('High'));
        await tester.tap(find.text('High'));
        await tester.pump();

        await tester.ensureVisible(find.text('Add task'));
        await tester.tap(find.text('Add task'));
        await tester.pumpAndSettle();

        expect(spy.visitDraftId, 'v1', reason: name);
        expect(spy.outletId, 'o1', reason: name);
        expect(spy.task!.findingType, 'oos', reason: name);
        expect(spy.task!.requiredFix, 'Restock shelf', reason: name);
        expect(spy.task!.priority, 'high', reason: name);
        expect(find.text('Task queued for sync'), findsOneWidget, reason: name);

        // The text fields are cleared after queueing.
        expect(find.text('oos'), findsNothing, reason: name);
        expect(find.text('Restock shelf'), findsNothing, reason: name);
      }
    },
  );

  testWidgets(
    'the task form is a PanelCard, fields are AgentFields, save is an '
    'AgentButton — no raw Card/Dropdown/ElevatedButton',
    (tester) async {
      for (final name in _bothThemes) {
        await tester.pumpWidget(
          _screen(
            _SpyTasksRepository(),
            theme: _themeFor(name),
            key: ValueKey(name),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Card), findsNothing, reason: '$name no Card');
        expect(
          find.byType(DropdownButtonFormField<String>),
          findsNothing,
          reason: '$name no Dropdown',
        );
        expect(
          find.byType(ElevatedButton),
          findsNothing,
          reason: '$name no ElevatedButton',
        );

        final glass = tester
            .element(find.byType(S9ActionPlanScreen))
            .colors
            .glass;
        if (glass) {
          // Lumen Glass: the task being written is one no-blur glass tile.
          expect(
            find.byType(PanelCard),
            findsNothing,
            reason: '$name no panel',
          );
          expect(
            find.ancestor(
              of: find.text('Finding type'),
              matching: find.byWidgetPredicate(
                (w) => w is GlassPane && w.kind == GlassKind.tile && !w.blur,
              ),
            ),
            findsOneWidget,
            reason: '$name task glass tile',
          );
        } else {
          expect(find.byType(PanelCard), findsOneWidget, reason: '$name panel');
        }
        expect(
          find.byType(AgentField),
          findsNWidgets(2),
          reason: '$name two AgentFields',
        );
        expect(
          find.byType(ChoiceRow<String>),
          findsOneWidget,
          reason: '$name priority ChoiceRow',
        );
        expect(
          find.widgetWithText(AgentButton, 'Add task'),
          findsOneWidget,
          reason: '$name save is AgentButton',
        );
      }
    },
  );

  test('no non-geometry AppColors. remain in the S9 action plan source', () {
    final src = File(
      'lib/features/audit/presentation/sections/s9_action_plan_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });
}
