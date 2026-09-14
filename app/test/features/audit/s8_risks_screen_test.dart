import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/console.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/audit/data/risks_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s8_risks_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;

class _SpyRisksRepository implements RisksRepository {
  String? visitDraftId;
  List<RiskEntry>? entries;

  @override
  Future<void> saveRisks({
    required String visitDraftId,
    required List<RiskEntry> entries,
  }) async {
    this.visitDraftId = visitDraftId;
    this.entries = entries;
  }
}

const _bothThemes = ['light', 'dark'];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

Widget _screen(RisksRepository spy, {ThemeData? theme, Key? key}) =>
    ProviderScope(
      overrides: [risksRepositoryProvider.overrideWithValue(spy)],
      child: MaterialApp(
        theme: theme,
        // A fresh key per theme pass so State (the risk list) never carries
        // across pumps in a both-themes loop.
        home: Scaffold(
          body: SingleChildScrollView(
            child: S8RisksScreen(key: key, visitDraftId: 'v1'),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'captures risk entries and calls saveRisks on Save — severity via ChoiceRow',
    (tester) async {
      for (final name in _bothThemes) {
        final spy = _SpyRisksRepository();
        await tester.pumpWidget(
          _screen(spy, theme: _themeFor(name), key: ValueKey(name)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Flag a risk'));
        await tester.pump();

        await tester.enterText(
          find.byKey(const ValueKey('risk-type-0')),
          'expiredStock',
        );
        // Severity is now a ChoiceRow — tap the chip label, not a dropdown menu.
        await tester.ensureVisible(find.text('Critical'));
        await tester.tap(find.text('Critical'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('risk-note-0')),
          'Two cases past date',
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Save risks'));
        await tester.tap(find.text('Save risks'));
        await tester.pumpAndSettle();

        expect(spy.visitDraftId, 'v1', reason: name);
        expect(spy.entries, hasLength(1), reason: name);
        expect(spy.entries!.first.flagType, 'expiredStock', reason: name);
        expect(spy.entries!.first.severity, 'critical', reason: name);
        expect(spy.entries!.first.note, 'Two cases past date', reason: name);
        expect(
          find.text(
            'Risks saved — queued for sync; follow-up tasks will be auto-created',
          ),
          findsOneWidget,
          reason: name,
        );
      }
    },
  );

  testWidgets('skips rows without a flag type on Save', (tester) async {
    final spy = _SpyRisksRepository();

    await tester.pumpWidget(_screen(spy));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flag a risk'));
    await tester.pump();

    await tester.ensureVisible(find.text('Save risks'));
    await tester.tap(find.text('Save risks'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, isEmpty);
  });

  testWidgets(
    'risk rows are PanelCards, fields are AgentFields, add + save are '
    'AgentButtons — no raw Card/Dropdown/ElevatedButton/TextButton',
    (tester) async {
      for (final name in _bothThemes) {
        await tester.pumpWidget(
          _screen(
            _SpyRisksRepository(),
            theme: _themeFor(name),
            key: ValueKey(name),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Flag a risk'));
        await tester.pump();

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
        expect(
          find.byType(TextButton),
          findsNothing,
          reason: '$name no TextButton',
        );

        // The risk row is a console panel; its inputs are labelled AgentFields;
        // severity is a segmented ChoiceRow; add + save are the kit's buttons.
        final glass = tester.element(find.byType(S8RisksScreen)).colors.glass;
        if (glass) {
          // Lumen Glass: the risk is a no-blur glass tile, not a console panel.
          expect(
            find.byType(PanelCard),
            findsNothing,
            reason: '$name no panel',
          );
          expect(
            find.ancestor(
              of: find.text('Risk 1'),
              matching: find.byWidgetPredicate(
                (w) => w is GlassPane && w.kind == GlassKind.tile && !w.blur,
              ),
            ),
            findsOneWidget,
            reason: '$name risk glass tile',
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
          reason: '$name severity ChoiceRow',
        );
        expect(
          find.widgetWithText(AgentButton, 'Flag a risk'),
          findsOneWidget,
          reason: '$name add is AgentButton',
        );
        expect(
          find.widgetWithText(AgentButton, 'Save risks'),
          findsOneWidget,
          reason: '$name save is AgentButton',
        );
      }
    },
  );

  testWidgets(
    'Lumen Glass: a critical or high risk turns its tile rim to the status and '
    'spells the severity out on an opaque, AA-safe note',
    (tester) async {
      const palette = TiqColors.light;
      await tester.pumpWidget(
        _screen(_SpyRisksRepository(), theme: AppTheme.light()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Flag a risk'));
      await tester.pumpAndSettle();

      final tile = find.ancestor(
        of: find.text('Risk 1'),
        matching: find.byWidgetPredicate(
          (w) => w is GlassPane && w.kind == GlassKind.tile && !w.blur,
        ),
      );
      // Normal is not a finding: the tile keeps its own rim and has no note.
      expect(tester.widget<GlassPane>(tile).rimColor, isNull);
      expect(
        find.textContaining('saving it raises a follow-up task'),
        findsNothing,
      );

      for (final (chip, status) in [
        ('Critical', LumenStatus.crit),
        ('High', LumenStatus.warn),
      ]) {
        await tester.ensureVisible(find.text(chip));
        await tester.tap(find.text(chip));
        await tester.pumpAndSettle();

        final sw = status.swatchOf(palette);
        expect(
          tester.widget<GlassPane>(tile).rimColor,
          sw.rim,
          reason: '$chip rim',
        );

        // Never colour alone: the severity is spelled out in the note.
        final note = find.text('$chip risk — saving it raises a follow-up task');
        expect(note, findsOneWidget, reason: '$chip note');
        final fg = tester.widget<Text>(note).style!.color!;
        expect(fg, sw.ink, reason: '$chip note ink');

        final wash =
            tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: note,
                            matching: find.byWidgetPredicate(
                              (w) =>
                                  w is Container &&
                                  w.decoration is BoxDecoration &&
                                  (w.decoration! as BoxDecoration).color !=
                                      null,
                            ),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        // OPAQUE: composited over the pane, so AA holds on its own.
        expect(
          wash.color,
          Color.alphaBlend(sw.tint, palette.surface1),
          reason: '$chip opaque wash',
        );
        expect(
          contrastRatio(fg, wash.color!),
          greaterThanOrEqualTo(4.5),
          reason: '$chip note AA (rendered pair)',
        );
      }

      // Back to normal: the finding clears.
      await tester.ensureVisible(find.text('Normal'));
      await tester.tap(find.text('Normal'));
      await tester.pumpAndSettle();
      expect(tester.widget<GlassPane>(tile).rimColor, isNull);
    },
  );

  test('no non-geometry AppColors. remain in the S8 risks source', () {
    final src = File(
      'lib/features/audit/presentation/sections/s8_risks_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });
}
