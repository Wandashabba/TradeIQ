import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

const _khumalo = Outlet(
  id: 'o1',
  name: 'Khumalo Superette',
  code: 'KS-014',
  lat: -26.2,
  lng: 28.0,
);
const _sunrise = Outlet(
  id: 'o2',
  name: 'Sunrise Spaza',
  code: 'SS-221',
  lat: -26.3,
  lng: 28.1,
);

Widget _app(TodayRoute? route, {ThemeData? theme}) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);

  return routedApp(
    const TodayScreen(),
    theme: theme,
    overrides: [
      localDbProvider.overrideWithValue(db),
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
      todayRouteProvider.overrideWith((ref) async => route),
    ],
  );
}

TodayRoute _route({bool located = true, bool complete = false}) => TodayRoute(
  planName: 'Naledi · Soweto East',
  hasLocation: located,
  stops: [
    RouteStop(
      sequence: 1,
      outlet: _khumalo,
      visited: true,
      distanceMeters: located ? 1200 : null,
    ),
    RouteStop(
      sequence: 2,
      outlet: _sunrise,
      visited: complete,
      distanceMeters: located ? 42 : null,
    ),
  ],
);

void main() {
  testWidgets('the day is the first thing an agent sees', (tester) async {
    await tester.pumpWidget(_app(_route()));
    await tester.pumpAndSettle();

    // Not "which of 400 outlets would you like to audit" — where am I going, and
    // how much is left.
    expect(find.text('Khumalo Superette'), findsOneWidget);
    expect(find.text('Sunrise Spaza'), findsOneWidget);
    expect(find.textContaining('of 2 stores'), findsOneWidget);
    expect(find.text('1 left'), findsOneWidget);
  });

  testWidgets('the next store is marked, and the visited one recedes', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_route()));
    await tester.pumpAndSettle();

    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
  });

  testWidgets('distance is a walk or a drive, not a number of metres', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_route()));
    await tester.pumpAndSettle();

    expect(find.text('42 m away'), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
  });

  testWidgets('no location means no distances — not made-up ones', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_route(located: false)));
    await tester.pumpAndSettle();

    expect(find.textContaining('m away'), findsNothing);
    expect(find.textContaining('will not say where it is'), findsOneWidget);
  });

  testWidgets('no plan is an answer, not a dead end', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();

    // A manager who has not built a beat plan has not built one. The screen says
    // so, rather than inventing a route out of the outlet list — and it still
    // lets the agent work.
    expect(find.text('No route planned for today'), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-a-store')), findsOneWidget);
  });

  testWidgets('the plan is not a cage — an unplanned store is one tap away', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_route()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('visit-another')), findsOneWidget);
  });

  // ── Premium restyle (sub5a Task 2) ──────────────────────────────────────

  testWidgets('light: the day sits on the dark glass pane', (tester) async {
    await tester.pumpWidget(_app(_route(), theme: AppTheme.light()));
    await tester.pumpAndSettle();

    // Lumen Glass puts the day on the product's one heavy pane.
    final pane = tester.widget<GlassPane>(
      find
          .ancestor(
            of: find.text('Naledi · Soweto East'),
            matching: find.byType(GlassPane),
          )
          .first,
    );
    expect(pane.kind, GlassKind.dark);
  });

  testWidgets('light: the next store is its own card, with the check-in on it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_route(), theme: AppTheme.light()));
    await tester.pumpAndSettle();

    final next = find.byKey(const ValueKey('next-stop'));
    expect(next, findsOneWidget);
    expect(
      find.descendant(of: next, matching: find.text('Sunrise Spaza')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: next, matching: find.text('Check in here')),
      findsOneWidget,
    );
  });

  testWidgets('dark: the day sits on the same dark glass pane', (tester) async {
    await tester.pumpWidget(_app(_route(), theme: AppTheme.dark()));
    await tester.pumpAndSettle();

    // At night the day keeps its heavy pane — no gradient-washed flat hero.
    final pane = tester.widget<GlassPane>(
      find
          .ancestor(
            of: find.text('Naledi · Soweto East'),
            matching: find.byType(GlassPane),
          )
          .first,
    );
    expect(pane.kind, GlassKind.dark);
  });

  testWidgets('the done-count is the 30–32px w600 white figure on the dark pane', (
    tester,
  ) async {
    for (final (theme, palette) in [
      (AppTheme.light(), TiqColors.light),
      (AppTheme.dark(), TiqColors.night),
    ]) {
      await tester.pumpWidget(_app(_route(), theme: theme));
      await tester.pumpAndSettle();

      // doneCount == 1; the sequence badges render a tick (visited) and '2'
      // (next), so '1' is uniquely the headline count.
      final count = tester.widget<Text>(find.text('1'));
      // Both themes are glass: white and w600 on the dark pane.
      expect(palette.glass, isTrue);
      expect(count.style?.fontWeight, FontWeight.w600);
      expect(count.style?.fontSize, inInclusiveRange(30, 32));
      expect(count.style?.color, Colors.white);
    }
  });

  testWidgets('the status is a pill with a word — good wash when complete', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_route(complete: true), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Route done'), findsOneWidget);
    // The word rides on the house good/positive wash — meaning in words AND
    // colour, and a fixed self-contained pair (DeltaPill's good tone) rather
    // than a self-tint that cannot clear AA. Contrast itself is pinned by the
    // AA test below.
    final pill = find.ancestor(
      of: find.text('Route done'),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            // Glass: an opaque green pill on the dark pane (white 5.3:1).
            (w.decoration! as BoxDecoration).color == const Color(0xFF1F7A4D),
      ),
    );
    expect(pill, findsOneWidget);
  });

  testWidgets('dark: the next store is its own card; a visited stop is a tile '
      'with its status word', (
    tester,
  ) async {
    // The flat theme's edge-bar cards are gone at night too: the next store is
    // its own card with the check-in, and the rest are status-tiled rows.
    await tester.pumpWidget(_app(_route(), theme: AppTheme.dark()));
    await tester.pumpAndSettle();

    final next = find.byKey(const ValueKey('next-stop'));
    expect(next, findsOneWidget);
    expect(
      find.descendant(of: next, matching: find.text('Sunrise Spaza')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: next, matching: find.text('Check in here')),
      findsOneWidget,
    );

    // The visited store is an unblurred tile — a repeated row never pays for
    // a blur — and its state is a word in the night good ink.
    final row = tester.widget<GlassPane>(
      find
          .ancestor(
            of: find.text('Khumalo Superette'),
            matching: find.byType(GlassPane),
          )
          .first,
    );
    expect(row.kind, GlassKind.tile);
    expect(row.blur, isFalse);
    expect(
      tester.widget<Text>(find.text('DONE')).style?.color,
      LumenStatus.good.swatchOf(TiqColors.night).ink,
    );
    expect(find.text('NEXT'), findsOneWidget);
  });

  // The wash/text of the pill labelled [label], read off the rendered tree —
  // so a regression to a self-tint (translucent token over its own token,
  // ratio ≈ 1:1) fails here rather than being papered over by a copied const.
  (Color bg, Color fg) pillColours(WidgetTester tester, String label) {
    final text = find.text(label);
    expect(text, findsOneWidget);
    final container = find
        .ancestor(
          of: text,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color != null,
          ),
        )
        .first;
    final bg =
        (tester.widget<Container>(container).decoration! as BoxDecoration)
            .color!;
    final fg = tester.widget<Text>(text).style!.color!;
    return (bg, fg);
  }

  // Never-colour-alone (the word) and the AA contrast floor are INDEPENDENT
  // rules — spec §Screens 1 requires every new pill's text to clear 4.5:1 on
  // its own ground in BOTH themes. The complete-state pill now carries an
  // opaque wash, so its own background IS the text's real ground (no gradient
  // compositing to reason about).
  void expectAA(WidgetTester tester, String label, String name) {
    final (bg, fg) = pillColours(tester, label);
    final ratio = contrastRatio(fg, bg);
    expect(
      ratio,
      greaterThanOrEqualTo(4.5),
      reason: '$label ($name) is $ratio:1 on its wash',
    );
  }

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('the in-progress Today pills clear AA — $name', (tester) async {
      await tester.pumpWidget(_app(_route(), theme: theme));
      await tester.pumpAndSettle();

      for (final label in ['DONE', 'NEXT', '1 left']) {
        expectAA(tester, label, name);
      }
    });

    testWidgets('the complete "Route done" pill clears AA — $name', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_route(complete: true), theme: theme));
      await tester.pumpAndSettle();

      // The pill's own opaque wash IS the text's ground — no gradient below it
      // to composite through.
      expectAA(tester, 'Route done', name);
    });
  }
}
