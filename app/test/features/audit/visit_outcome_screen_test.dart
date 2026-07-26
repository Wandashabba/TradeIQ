import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/features/audit/data/scorecards_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outcome_screen.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

const _visit = ServerScorecard(
  visitId: 'remote-1',
  weightedTotal: 72,
  ratingBand: 'amber',
  dimensionScores: {
    'availability': 83,
    'visibility': 80,
    'display': 80,
    'pricing': 61,
    'competitive': 29,
    // salesCapability is ABSENT — no staff on shift to assess. It must never
    // render as a zero.
  },
);

const _previous = ServerScorecard(
  visitId: 'remote-0',
  weightedTotal: 66,
  ratingBand: 'amber',
  dimensionScores: {},
);

/// A scorecard on a chosen rating band — the fake is parametrized by band so
/// the AA floor is checked for green/amber/red, not just the amber fixture.
ServerScorecard _scoreOnBand(String band) => ServerScorecard(
  visitId: 'remote-b',
  weightedTotal: 72,
  ratingBand: band,
  dimensionScores: const {'availability': 83},
);

const _bothThemes = <(String, TiqColors)>[
  ('light', TiqColors.light),
  ('dark', TiqColors.dark),
];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

Widget _app(VisitOutcome outcome, {ThemeData? theme, Key? key}) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);

  return routedApp(
    VisitOutcomeScreen(
      key: key,
      visitDraftId: 'v1',
      outletId: 'o1',
      outletName: 'Sunrise Spaza',
    ),
    theme: theme,
    overrides: [
      localDbProvider.overrideWithValue(db),
      visitOutcomeProvider.overrideWith((ref, arg) async => outcome),
    ],
  );
}

/// The one gradient-washed card on the screen — the score-reveal glass hero.
BoxDecoration _heroBox(WidgetTester tester) {
  final hero = find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).gradient is LinearGradient,
  );
  expect(hero, findsOneWidget);
  return tester.widget<Container>(hero).decoration! as BoxDecoration;
}

void main() {
  testWidgets('shows the score the manager will see', (tester) async {
    await tester.pumpWidget(
      _app(const VisitOutcome(score: _visit, previous: null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('72'), findsOneWidget);
    expect(find.text('Amber'), findsOneWidget);
    expect(find.text('83'), findsOneWidget);
  });

  testWidgets('an unmeasurable dimension is “—”, never a zero', (tester) async {
    await tester.pumpWidget(
      _app(const VisitOutcome(score: _visit, previous: null)),
    );
    await tester.pumpAndSettle();

    // A zero here would read to the agent as "you scored nothing on this", when
    // in truth there was nothing in the store to score. Mirrors the server (#93).
    expect(find.text('Team capability'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.textContaining('not counted against you'), findsOneWidget);
  });

  testWidgets('compares against their own last visit here', (tester) async {
    await tester.pumpWidget(
      _app(const VisitOutcome(score: _visit, previous: _previous)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Up 6 points'), findsOneWidget);
    expect(find.textContaining('(66)'), findsOneWidget);
  });

  testWidgets('held on the phone: no score at all, rather than a guess', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const VisitOutcome(score: null, previous: null)),
    );
    await tester.pumpAndSettle();

    // The app CAN compute a scorecard offline, but it is a proxy — showing it
    // would mean showing a number that quietly changes once the visit reaches
    // the server. An agent whose score moves overnight will not trust the next.
    expect(find.textContaining('safe on this phone'), findsOneWidget);
    expect(find.textContaining('Scored when it sends'), findsOneWidget);
    expect(find.text('/100'), findsNothing);
  });

  testWidgets('a submitted visit cannot be walked back into', (tester) async {
    await tester.pumpWidget(
      _app(const VisitOutcome(score: _visit, previous: null)),
    );
    await tester.pumpAndSettle();

    // Both ways off this screen go forward — to the next store.
    expect(find.byKey(const ValueKey('next-store')), findsOneWidget);
  });

  // ── Premium restyle (sub5c Task 2) ──────────────────────────────────────

  for (final (name, palette) in _bothThemes) {
    testWidgets('the score reveal is a glass hero — $name', (tester) async {
      await tester.pumpWidget(
        _app(
          const VisitOutcome(score: _visit, previous: null),
          theme: _themeFor(name),
          key: ValueKey(name),
        ),
      );
      await tester.pumpAndSettle();

      final box = _heroBox(tester);
      final gradient = box.gradient! as LinearGradient;
      expect(gradient.colors, [
        palette.heroWash,
        palette.surface1,
      ], reason: '$name hero wash → surface1');
      expect(
        (box.border! as Border).top.color,
        palette.heroBorder,
        reason: '$name hero border',
      );

      // The score is the 52px w700 headline figure in ink1; "/100" is ink3.
      final score = tester.widget<Text>(find.text('72'));
      expect(score.style?.fontSize, 52, reason: '$name score 52px');
      expect(score.style?.fontWeight, FontWeight.w700, reason: '$name w700');
      expect(score.style?.color, palette.ink1, reason: '$name score ink1');

      final outOf = tester.widget<Text>(find.text('/100'));
      expect(outOf.style?.color, palette.ink3, reason: '$name /100 ink3');
    });

    // The band is a dot AND a spelled word (never colour-alone), and the word's
    // colour clears AA on BOTH stops of the hero gradient it sits over — red
    // uses critText, the recurring crit→critText lesson.
    for (final (band, word, expected) in <(String, String, Color)>[
      ('green', 'Green', palette.good),
      ('amber', 'Amber', palette.warn),
      ('low', 'Red', palette.critText),
    ]) {
      testWidgets('band $word carries an AA-safe word — $name', (tester) async {
        await tester.pumpWidget(
          _app(
            VisitOutcome(score: _scoreOnBand(band), previous: null),
            theme: _themeFor(name),
            key: ValueKey('$name-$band'),
          ),
        );
        await tester.pumpAndSettle();

        final text = tester.widget<Text>(find.text(word));
        final fg = text.style!.color!;
        expect(fg, expected, reason: '$name $word word colour');

        final stops = (_heroBox(tester).gradient! as LinearGradient).colors;
        for (final ground in stops) {
          expect(
            contrastRatio(fg, ground),
            greaterThanOrEqualTo(4.5),
            reason:
                '$name $word is '
                '${contrastRatio(fg, ground)}:1 on $ground',
          );
        }
      });
    }

    testWidgets('a down delta is a word + arrow in critText, AA-safe — $name', (
      tester,
    ) async {
      // Current 66 vs a previous 72 — down 6. The move down is spelled out and
      // carries an arrow, never colour alone, and its text clears AA.
      const down = ServerScorecard(
        visitId: 'remote-2',
        weightedTotal: 66,
        ratingBand: 'amber',
        dimensionScores: {'availability': 83},
      );
      await tester.pumpWidget(
        _app(
          const VisitOutcome(score: down, previous: _visit),
          theme: _themeFor(name),
          key: ValueKey('$name-down'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      final text = tester.widget<Text>(find.textContaining('Down 6 points'));
      final fg = text.style!.color!;
      expect(fg, palette.critText, reason: '$name down uses critText');

      final stops = (_heroBox(tester).gradient! as LinearGradient).colors;
      for (final ground in stops) {
        expect(
          contrastRatio(fg, ground),
          greaterThanOrEqualTo(4.5),
          reason: '$name down delta ${contrastRatio(fg, ground)}:1 on $ground',
        );
      }
    });

    testWidgets('an up delta is a word + arrow in good, AA-safe — $name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const VisitOutcome(score: _visit, previous: _previous),
          theme: _themeFor(name),
          key: ValueKey('$name-up'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      final text = tester.widget<Text>(find.textContaining('Up 6 points'));
      final fg = text.style!.color!;
      expect(fg, palette.good, reason: '$name up uses good');

      final stops = (_heroBox(tester).gradient! as LinearGradient).colors;
      for (final ground in stops) {
        expect(
          contrastRatio(fg, ground),
          greaterThanOrEqualTo(4.5),
          reason: '$name up delta ${contrastRatio(fg, ground)}:1 on $ground',
        );
      }
    });

    testWidgets('the dimension panel is a console card — $name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const VisitOutcome(score: _visit, previous: null),
          theme: _themeFor(name),
          key: ValueKey('$name-dim'),
        ),
      );
      await tester.pumpAndSettle();

      // The "How it was scored" list is a surface1 + line panel on console
      // tokens; the unmeasured row still shows "—", never a zero (#93).
      final panel = find.ancestor(
        of: find.text('Team capability'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == palette.surface1 &&
              (w.decoration as BoxDecoration).border != null,
        ),
      );
      expect(panel, findsOneWidget, reason: '$name dimension panel');
      expect(find.text('—'), findsOneWidget, reason: '$name unmeasured is —');
      expect(find.text('0'), findsNothing, reason: '$name never a zero');
    });

    testWidgets('held-on-phone is themed and its honesty copy is verbatim — '
        '$name', (tester) async {
      await tester.pumpWidget(
        _app(
          const VisitOutcome(score: null, previous: null),
          theme: _themeFor(name),
          key: ValueKey('$name-held'),
        ),
      );
      await tester.pumpAndSettle();

      // The honesty statement is load-bearing and VERBATIM: an agent shown a
      // phone-side number that later changes stops trusting scores.
      expect(
        find.text('Your visit is safe on this phone'),
        findsOneWidget,
        reason: '$name title verbatim',
      );
      expect(
        find.text(
          'We are not guessing at a score here. You will see the real one — the '
          'same one your manager sees — as soon as this reaches the server.',
        ),
        findsOneWidget,
        reason: '$name no-guess copy verbatim',
      );
      expect(find.text('/100'), findsNothing, reason: '$name no number');

      final title = tester.widget<Text>(
        find.text('Your visit is safe on this phone'),
      );
      expect(title.style?.color, palette.ink1, reason: '$name title ink1');
    });
  }

  test('no non-geometry AppColors. remain in the visit outcome source', () {
    final src = File(
      'lib/features/audit/presentation/visit_outcome_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });
}
