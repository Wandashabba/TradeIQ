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
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/audit/data/competitive_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s6_competitive_screen.dart';

class _SpyCompetitiveRepository implements CompetitiveRepository {
  String? visitDraftId;
  List<CompetitiveEntry>? entries;

  @override
  Future<void> saveCompetitive({
    required String visitDraftId,
    required List<CompetitiveEntry> entries,
  }) async {
    this.visitDraftId = visitDraftId;
    this.entries = entries;
  }
}

const _bothThemes = ['light', 'dark'];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

Widget _screen(CompetitiveRepository spy, {ThemeData? theme, Key? key}) =>
    ProviderScope(
      overrides: [competitiveRepositoryProvider.overrideWithValue(spy)],
      child: MaterialApp(
        theme: theme,
        // A fresh key per theme pass so State (the competitor list) never
        // carries across pumps in a both-themes loop.
        home: Scaffold(
          body: SingleChildScrollView(
            child: S6CompetitiveScreen(key: key, visitDraftId: 'v1'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('captures competitor entries and calls saveCompetitive on Save — '
      'promoter via AgentToggle', (tester) async {
    for (final name in _bothThemes) {
      final spy = _SpyCompetitiveRepository();
      await tester.pumpWidget(
        _screen(spy, theme: _themeFor(name), key: ValueKey(name)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add competitor'));
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('comp-sku-0')),
        'Rival Cola 500ml',
      );
      await tester.enterText(
        find.byKey(const ValueKey('comp-price-0')),
        '12.50',
      );
      await tester.enterText(
        find.byKey(const ValueKey('comp-posm-0')),
        'poster',
      );
      // Promoter presence is now an AgentToggle — tap the row by its label,
      // not a 20px SwitchListTile.
      await tester.ensureVisible(find.text('Promoter present'));
      await tester.tap(find.text('Promoter present'));
      await tester.pump();

      await tester.ensureVisible(find.text('Save competitive'));
      await tester.tap(find.text('Save competitive'));
      await tester.pumpAndSettle();

      expect(spy.visitDraftId, 'v1', reason: name);
      expect(spy.entries, hasLength(1), reason: name);
      expect(
        spy.entries!.first.competitorSku,
        'Rival Cola 500ml',
        reason: name,
      );
      expect(spy.entries!.first.competitorPrice, 12.50, reason: name);
      expect(spy.entries!.first.competitorPosmType, 'poster', reason: name);
      expect(spy.entries!.first.competitorPromoterPresent, true, reason: name);
      // Facings defaults to 1 — never 0, which would erase the competitor
      // from the share-of-shelf denominator entirely (#93).
      expect(spy.entries!.first.facingsCount, 1, reason: name);
      expect(
        find.text('Competitive intel saved — queued for sync'),
        findsOneWidget,
        reason: name,
      );
    }
  });

  testWidgets('skips rows without a competitor SKU name on Save', (
    tester,
  ) async {
    final spy = _SpyCompetitiveRepository();

    await tester.pumpWidget(_screen(spy));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add competitor'));
    await tester.pump();

    await tester.ensureVisible(find.text('Save competitive'));
    await tester.tap(find.text('Save competitive'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, isEmpty);
  });

  testWidgets('captures competitor facings, so share of shelf is a real ratio', (
    tester,
  ) async {
    final spy = _SpyCompetitiveRepository();
    await tester.pumpWidget(_screen(spy));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add competitor'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('comp-sku-0')),
      'Rival Cola 500ml',
    );
    await tester.enterText(find.byKey(const ValueKey('comp-facings-0')), '18');
    await tester.tap(find.text('Save competitive'));
    await tester.pumpAndSettle();

    // Without this, share of shelf counted each captured ROW as one facing — a
    // competitor holding a whole shelf counted the same as one holding a can.
    expect(spy.entries!.first.facingsCount, 18);
  });

  testWidgets(
    'competitor rows are PanelCards, fields are AgentFields, promoter is an '
    'AgentToggle, add + save are AgentButtons — no raw Card/SwitchListTile/'
    'ElevatedButton/TextButton',
    (tester) async {
      for (final name in _bothThemes) {
        await tester.pumpWidget(
          _screen(
            _SpyCompetitiveRepository(),
            theme: _themeFor(name),
            key: ValueKey(name),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add competitor'));
        await tester.pump();

        expect(find.byType(Card), findsNothing, reason: '$name no Card');
        expect(
          find.byType(SwitchListTile),
          findsNothing,
          reason: '$name no SwitchListTile',
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

        // The competitor row is a console panel; its four inputs are labelled
        // AgentFields; promoter presence is an AgentToggle; add + save are the
        // kit's buttons.
        final glass = tester
            .element(find.byType(S6CompetitiveScreen))
            .colors
            .glass;
        if (glass) {
          // Lumen Glass: the competitor is a no-blur glass tile headed by its
          // sequence number, set in mono in a status tile.
          expect(
            find.byType(PanelCard),
            findsNothing,
            reason: '$name no panel',
          );
          expect(
            find.ancestor(
              of: find.text('Competitor 1'),
              matching: find.byWidgetPredicate(
                (w) => w is GlassPane && w.kind == GlassKind.tile && !w.blur,
              ),
            ),
            findsOneWidget,
            reason: '$name competitor glass tile',
          );
          final number = tester.widget<StatusTile>(find.byType(StatusTile));
          expect(number.glyph, '1', reason: '$name sequence number');
          expect(number.mono, isTrue, reason: '$name number in mono');
          expect(number.status, LumenStatus.none, reason: '$name no status');
        } else {
          expect(find.byType(PanelCard), findsOneWidget, reason: '$name panel');
        }
        expect(
          find.byType(AgentField),
          findsNWidgets(4),
          reason: '$name four AgentFields',
        );
        expect(
          find.widgetWithText(AgentToggle, 'Promoter present'),
          findsOneWidget,
          reason: '$name promoter AgentToggle',
        );
        expect(
          find.widgetWithText(AgentButton, 'Add competitor'),
          findsOneWidget,
          reason: '$name add is AgentButton',
        );
        expect(
          find.widgetWithText(AgentButton, 'Save competitive'),
          findsOneWidget,
          reason: '$name save is AgentButton',
        );
      }
    },
  );

  test('no non-geometry AppColors. remain in the S6 competitive source', () {
    final src = File(
      'lib/features/audit/presentation/sections/s6_competitive_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });
}
