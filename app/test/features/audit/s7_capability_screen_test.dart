import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/features/audit/data/capability_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s7_capability_screen.dart';

class _SpyCapabilityRepository implements CapabilityRepository {
  String? visitDraftId;
  CapabilityCapture? capture;

  @override
  Future<void> saveCapability({
    required String visitDraftId,
    required CapabilityCapture capture,
  }) async {
    this.visitDraftId = visitDraftId;
    this.capture = capture;
  }
}

const _bothThemes = ['light', 'dark'];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

Widget _screen(CapabilityRepository spy, {ThemeData? theme, Key? key}) =>
    ProviderScope(
      overrides: [capabilityRepositoryProvider.overrideWithValue(spy)],
      child: MaterialApp(
        theme: theme,
        // A fresh key per theme pass so State (the training checkboxes) never
        // carries across pumps in a both-themes loop.
        home: Scaffold(
          body: SingleChildScrollView(
            child: S7CapabilityScreen(key: key, visitDraftId: 'v1'),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'captures capability and calls saveCapability on Save — training via '
    'AgentCheck',
    (tester) async {
      for (final name in _bothThemes) {
        final spy = _SpyCapabilityRepository();
        await tester.pumpWidget(
          _screen(spy, theme: _themeFor(name), key: ValueKey(name)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const ValueKey('headcount')), '5');
        // Training topics are now AgentChecks — the topic keys are preserved so
        // each check drives its own map entry.
        await tester.tap(
          find.byKey(const ValueKey('training-productKnowledge')),
        );
        await tester.tap(find.byKey(const ValueKey('training-posSystems')));
        await tester.enterText(find.byKey(const ValueKey('quiz')), '85');
        await tester.pump();

        await tester.ensureVisible(find.text('Save capability'));
        await tester.tap(find.text('Save capability'));
        await tester.pumpAndSettle();

        expect(spy.visitDraftId, 'v1', reason: name);
        expect(spy.capture!.staffHeadcountConfirmed, 5, reason: name);
        expect(
          spy.capture!.repTrainingStatus['productKnowledge'],
          true,
          reason: name,
        );
        expect(
          spy.capture!.repTrainingStatus['merchandising'],
          false,
          reason: name,
        );
        expect(
          spy.capture!.repTrainingStatus['posSystems'],
          true,
          reason: name,
        );
        expect(spy.capture!.quizScore, 85, reason: name);
        expect(
          find.text('Capability saved — queued for sync'),
          findsOneWidget,
          reason: name,
        );
      }
    },
  );

  testWidgets(
    'training topics are AgentChecks, fields are AgentFields, save is an '
    'AgentButton — no raw CheckboxListTile/ElevatedButton',
    (tester) async {
      for (final name in _bothThemes) {
        await tester.pumpWidget(
          _screen(
            _SpyCapabilityRepository(),
            theme: _themeFor(name),
            key: ValueKey(name),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(CheckboxListTile),
          findsNothing,
          reason: '$name no CheckboxListTile',
        );
        expect(
          find.byType(ElevatedButton),
          findsNothing,
          reason: '$name no ElevatedButton',
        );

        // Headcount and quiz are labelled AgentFields; the three training
        // topics are AgentChecks; save is the kit's button.
        expect(
          find.byType(AgentField),
          findsNWidgets(2),
          reason: '$name two AgentFields',
        );
        expect(
          find.byType(AgentCheck),
          findsNWidgets(3),
          reason: '$name three AgentChecks',
        );
        expect(
          find.widgetWithText(AgentButton, 'Save capability'),
          findsOneWidget,
          reason: '$name save is AgentButton',
        );
      }
    },
  );

  test('no non-geometry AppColors. remain in the S7 capability source', () {
    final src = File(
      'lib/features/audit/presentation/sections/s7_capability_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });
}
