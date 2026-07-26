import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/console.dart';
import 'package:tradeiq_app/features/audit/data/scorecard_service.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s10_scorecard_screen.dart';

// WCAG 2.x contrast ratio — the recurring "coloured band text must clear
// 4.5:1" guard, computed off the rendered colour so a token slip fails loudly.
double _linearize(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _relativeLuminance(Color c) =>
    0.2126 * _linearize(c.r) +
    0.7152 * _linearize(c.g) +
    0.0722 * _linearize(c.b);

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

class _FakeScorecardService extends ScorecardService {
  _FakeScorecardService({
    required super.db,
    required super.syncService,
    this.band = 'red',
  });

  // Parametrized so a test can drive the green/amber/red branch it needs —
  // the band AA + word guards below must cover all three, not just red.
  final String band;

  int computeCalls = 0;
  String? finalizedVisitDraftId;

  @override
  Future<LocalScorecard> computeForVisit(String visitDraftId) async {
    computeCalls++;
    return LocalScorecard(
      dimensionScores: const {
        'availability': 50,
        'visibility': 80,
        'display': 80,
        'pricing': 0,
        'competitive': 0,
        'salesCapability': 70,
      },
      weightedTotal: 54.0,
      // A failing score — shown honestly, never softened.
      ratingBand: band,
    );
  }

  @override
  Future<void> finalizeScorecard(String visitDraftId) async {
    finalizedVisitDraftId = visitDraftId;
  }
}

const _bothThemes = ['light', 'dark'];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

TiqColors _colorsFor(String name) =>
    name == 'light' ? TiqColors.light : TiqColors.dark;

Widget _screen(ScorecardService svc, {ThemeData? theme, Key? key}) =>
    ProviderScope(
      overrides: [scorecardServiceProvider.overrideWithValue(svc)],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: S10ScorecardScreen(key: key, visitDraftId: 'v1'),
          ),
        ),
      ),
    );

_FakeScorecardService _fake({String band = 'red'}) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return _FakeScorecardService(
    db: db,
    syncService: SyncService(db: db, flusher: _NoopFlusher()),
    band: band,
  );
}

void main() {
  testWidgets(
    'renders dimension scores, total and band; refresh recomputes; finalize '
    'queues — both themes',
    (tester) async {
      for (final name in _bothThemes) {
        final fake = _fake();
        await tester.pumpWidget(
          _screen(fake, theme: _themeFor(name), key: ValueKey(name)),
        );
        await tester.pumpAndSettle();

        // No inline screen header — the shared section wrapper titles it.
        // The content itself is what must render:
        for (final key in const [
          'score-availability',
          'score-visibility',
          'score-display',
          'score-pricing',
          'score-competitive',
          'score-salesCapability',
        ]) {
          expect(
            find.byKey(ValueKey(key)),
            findsOneWidget,
            reason: '$name $key',
          );
        }
        expect(find.text('Availability'), findsOneWidget, reason: name);
        expect(find.text('50'), findsOneWidget, reason: name);
        expect(find.text('70'), findsOneWidget, reason: name);

        // The prominent readout: total figure + spelled-out band, both keyed.
        expect(
          find.byKey(const ValueKey('score-total')),
          findsOneWidget,
          reason: name,
        );
        expect(find.text('54.0'), findsOneWidget, reason: name);
        expect(
          find.byKey(const ValueKey('score-band')),
          findsOneWidget,
          reason: name,
        );
        // Band carries a word (never colour alone); 'red' → 'Red'.
        expect(find.text('Red'), findsOneWidget, reason: name);

        // Refresh recomputes — an AgentButton, not a raw TextButton.
        await tester.ensureVisible(find.widgetWithText(AgentButton, 'Refresh'));
        await tester.tap(find.widgetWithText(AgentButton, 'Refresh'));
        await tester.pumpAndSettle();
        expect(fake.computeCalls, 2, reason: name);

        // Finalize queues the marker via finalizeScorecard.
        await tester.ensureVisible(
          find.widgetWithText(AgentButton, 'Finalize scorecard'),
        );
        await tester.tap(
          find.widgetWithText(AgentButton, 'Finalize scorecard'),
        );
        await tester.pumpAndSettle();
        expect(fake.finalizedVisitDraftId, 'v1', reason: name);
        expect(
          find.text('Scorecard queued for sync'),
          findsOneWidget,
          reason: name,
        );
      }
    },
  );

  testWidgets(
    'score is on console cards/rows — no raw Card/ElevatedButton/TextButton',
    (tester) async {
      for (final name in _bothThemes) {
        await tester.pumpWidget(
          _screen(_fake(), theme: _themeFor(name), key: ValueKey(name)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Card), findsNothing, reason: '$name no Card');
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
        // Dimensions and the readout each sit in a console panel.
        expect(find.byType(PanelCard), findsWidgets, reason: '$name panels');
      }
    },
  );

  // Every band, both themes: the word is spelled out (never colour alone) and
  // its rendered colour clears AA text contrast on surface1. Hardwiring the
  // fake to one band would let the other branches rot — a reviewer mutating
  // amber's colour to raw crit (3.76:1 dark) or dropping green/amber's word
  // must fail here.
  const bands = {'green': 'Green', 'amber': 'Amber', 'red': 'Red'};
  for (final MapEntry(key: band, value: word) in bands.entries) {
    testWidgets(
      'the $band band spells out "$word" and clears 4.5:1 on surface1 — '
      'both themes',
      (tester) async {
        for (final name in _bothThemes) {
          final fake = _fake(band: band);
          await tester.pumpWidget(
            _screen(fake, theme: _themeFor(name), key: ValueKey('$band-$name')),
          );
          await tester.pumpAndSettle();

          // (a) never colour alone — the word is present under the band key.
          final bandText = tester.widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('score-band')),
              matching: find.byType(Text),
            ),
          );
          expect(bandText.data, word, reason: '$band/$name word');

          // (b) the colour the tree actually rendered it with clears AA text
          // contrast on surface1.
          final ratio = _contrastRatio(
            bandText.style!.color!,
            _colorsFor(name).surface1,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$band/$name band word is $ratio:1 on surface1 — a coloured '
                'band label must clear AA text contrast (critText for red, '
                'not the crit mark).',
          );
        }
      },
    );
  }

  test('no non-geometry AppColors. remain in the S10 scorecard source', () {
    final src = File(
      'lib/features/audit/presentation/sections/s10_scorecard_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });
}
