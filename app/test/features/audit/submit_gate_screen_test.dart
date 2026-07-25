import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/audit/data/visit_review.dart';
import 'package:tradeiq_app/features/audit/presentation/submit_gate_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

/// Four scored sections done — so the gate reads "4 of 7 sections complete".
const _progress = VisitProgress(
  states: {
    AuditSection.stock: SectionState.done,
    AuditSection.visibility: SectionState.done,
    AuditSection.pricing: SectionState.done,
    AuditSection.capability: SectionState.done,
  },
  details: {},
);

/// A visit that will raise two tasks: one urgent (crit), one routine (warn) —
/// so both indicator tints are on screen to measure.
const _reviewWithTasks = VisitReview(
  skusCounted: 12,
  outOfStock: 1,
  skusPriced: 12,
  competitors: 2,
  photos: 1,
  willRaise: [
    RaisedTask(
      title: 'Fanta Orange 2L is out of stock',
      reason: 'You counted zero on shelf',
      priority: 'high',
    ),
    RaisedTask(
      title: 'Aisle blocked by delivery',
      reason: 'Risk you raised',
      priority: 'normal',
    ),
  ],
);

/// A clean store — nothing to raise.
const _reviewClean = VisitReview(
  skusCounted: 12,
  outOfStock: 0,
  skusPriced: 12,
  competitors: 0,
  photos: 0,
  willRaise: [],
);

/// A single pending capture, so the gate reads as offline.
final _offlineStatus = SyncStatus(
  pending: [
    SyncItem(
      id: 1,
      entityType: 'stock',
      queuedAt: DateTime(2026),
      synced: false,
      attempts: 0,
    ),
  ],
  sent: const [],
  needsAttention: const [],
);

List<Override> _overrides({
  required VisitReview review,
  VisitProgress progress = _progress,
  bool offline = false,
}) => [
  visitReviewProvider.overrideWith((ref, arg) => Stream.value(review)),
  visitProgressProvider.overrideWith((ref, arg) => Stream.value(progress)),
  syncStatusProvider.overrideWith(
    (ref) => Stream.value(offline ? _offlineStatus : SyncStatus.empty),
  ),
];

Widget _gate({
  required VisitReview review,
  VisitProgress progress = _progress,
  bool offline = false,
  VoidCallback? onConfirm,
  ThemeData? theme,
}) => routedApp(
  SubmitGateScreen(
    visitDraftId: 'visit-1',
    outletId: 'o1',
    outletName: 'Test Outlet',
    checkinTs: null,
    onConfirm: onConfirm ?? () {},
  ),
  overrides: _overrides(review: review, progress: progress, offline: offline),
  theme: theme,
);

const _bothThemes = [('light', TiqColors.light), ('dark', TiqColors.dark)];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

/// The decoration of the nearest ancestor Container of [inner] that carries a
/// BoxDecoration colour — the console card / wash the element sits on.
BoxDecoration _cardDecoration(WidgetTester tester, Finder inner) {
  final container = find
      .ancestor(
        of: inner,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color != null,
        ),
      )
      .first;
  return tester.widget<Container>(container).decoration! as BoxDecoration;
}

/// The wash/glyph pair of the [icon] indicator, read off the RENDERED tree — so
/// AA is measured on what actually paints. A critText→crit self-tint (raw crit
/// fails AA in dark) collapses this ratio and fails on its own merits.
(Color bg, Color fg) indicatorColours(WidgetTester tester, IconData icon) {
  final iconFinder = find.byIcon(icon);
  final bg = _cardDecoration(tester, iconFinder).color!;
  final fg = tester.widget<Icon>(iconFinder).color!;
  return (bg, fg);
}

void main() {
  testWidgets('the captured card is a console card with the count + line', (
    tester,
  ) async {
    for (final (name, palette) in _bothThemes) {
      await tester.pumpWidget(
        _gate(review: _reviewWithTasks, theme: _themeFor(name)),
      );
      await tester.pumpAndSettle();

      // The captured summary reads as a console card: surface1 under the line
      // hairline, panel radius — not a bare block of text.
      final count = find.text('4 of 7 sections complete');
      expect(count, findsOneWidget, reason: '$name count');
      // The one-line capture summary is verbatim from the review.
      expect(
        find.text('12 SKUs counted · 2 competitors · 1 photo'),
        findsOneWidget,
        reason: '$name captured line',
      );

      final deco = _cardDecoration(tester, count);
      expect(deco.color, palette.surface1, reason: '$name card surface');
      expect(
        (deco.border! as Border).top.color,
        palette.line,
        reason: '$name card hairline',
      );
    }
  });

  testWidgets(
    'each raised task pairs its colour with the priority WORD, and the '
    'indicator glyph clears AA in both themes',
    (tester) async {
      for (final (name, palette) in _bothThemes) {
        await tester.pumpWidget(
          _gate(review: _reviewWithTasks, theme: _themeFor(name)),
        );
        await tester.pumpAndSettle();

        // Urgency is never colour-alone: the priority is spelled out in words
        // next to the indicator, so a colour-blind agent in bad light can read
        // it.
        expect(
          find.text('Task for the manager · high'),
          findsOneWidget,
          reason: '$name urgent word',
        );
        expect(
          find.text('Task for the manager · normal'),
          findsOneWidget,
          reason: '$name routine word',
        );

        // The urgent indicator carries critText on a crit wash; the routine one
        // warn on a warn wash. Both are glyphs, so both clear 4.5:1 measured on
        // the rendered pair.
        final (critBg, critFg) = indicatorColours(tester, Icons.priority_high);
        expect(critFg, palette.critText, reason: '$name urgent glyph');
        expect(
          contrastRatio(critFg, critBg),
          greaterThanOrEqualTo(4.5),
          reason: '$name urgent indicator AA (rendered pair)',
        );

        final (warnBg, warnFg) = indicatorColours(tester, Icons.adjust);
        expect(warnFg, palette.warn, reason: '$name routine glyph');
        expect(
          contrastRatio(warnFg, warnBg),
          greaterThanOrEqualTo(4.5),
          reason: '$name routine indicator AA (rendered pair)',
        );
      }
    },
  );

  testWidgets('the offline note keeps the "submitting still works" copy', (
    tester,
  ) async {
    for (final (name, _) in _bothThemes) {
      await tester.pumpWidget(
        _gate(review: _reviewWithTasks, offline: true, theme: _themeFor(name)),
      );
      await tester.pumpAndSettle();

      // Offline is the normal state in a shop with no signal — the reassurance
      // that submitting still works must survive the restyle, verbatim.
      expect(
        find.textContaining(
          'No signal? Submitting still works — it saves on the phone and '
          'sends itself.',
        ),
        findsOneWidget,
        reason: '$name offline copy',
      );
    }
  });

  testWidgets('a clean store reads as a good wash, not an empty screen', (
    tester,
  ) async {
    for (final (name, palette) in _bothThemes) {
      await tester.pumpWidget(
        _gate(review: _reviewClean, theme: _themeFor(name)),
      );
      await tester.pumpAndSettle();

      final copy = find.textContaining('Nothing to raise');
      expect(copy, findsOneWidget, reason: '$name clean copy');
      // A clean store is a real result: it wears a good wash, so it does not
      // read as a blank screen.
      final deco = _cardDecoration(tester, copy);
      expect(
        deco.color,
        palette.good.withValues(alpha: 0.10),
        reason: '$name good wash',
      );
    }
  });

  testWidgets('the confirm-submit button invokes onConfirm on tap', (
    tester,
  ) async {
    var confirmed = 0;
    await tester.pumpWidget(
      _gate(review: _reviewWithTasks, onConfirm: () => confirmed++),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('confirm-submit'));
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pump();

    // The gate only confirms — it does not submit. Tapping fires the callback
    // the hub handed in, which is what runs submitVisit.
    expect(confirmed, 1);
  });

  test('no non-geometry AppColors. remain in the submit gate source', () {
    // Geometry (radii) stays on AppColors; every colour reads from the ambient
    // theme via context.colors, so both themes render.
    final src = File(
      'lib/features/audit/presentation/submit_gate_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });
}
