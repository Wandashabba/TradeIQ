import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

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

  /// The one gradient-washed card on the screen — the glass hero.
  BoxDecoration heroBox(WidgetTester tester) {
    final hero = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).gradient is LinearGradient,
    );
    expect(hero, findsOneWidget);
    return tester.widget<Container>(hero).decoration! as BoxDecoration;
  }

  testWidgets('the route header is a glass hero — light theme', (tester) async {
    await tester.pumpWidget(_app(_route(), theme: AppTheme.light()));
    await tester.pumpAndSettle();

    final box = heroBox(tester);
    final gradient = box.gradient! as LinearGradient;
    expect(gradient.colors, [
      TiqColors.light.heroWash,
      TiqColors.light.surface1,
    ]);
    expect((box.border! as Border).top.color, TiqColors.light.heroBorder);
  });

  testWidgets('the route header is a glass hero — dark theme', (tester) async {
    await tester.pumpWidget(_app(_route(), theme: AppTheme.dark()));
    await tester.pumpAndSettle();

    final box = heroBox(tester);
    final gradient = box.gradient! as LinearGradient;
    expect(gradient.colors, [TiqColors.dark.heroWash, TiqColors.dark.surface1]);
    expect((box.border! as Border).top.color, TiqColors.dark.heroBorder);
  });

  testWidgets('the done-count is the 30–32px w700 headline figure, in ink1', (
    tester,
  ) async {
    for (final (theme, palette) in [
      (AppTheme.light(), TiqColors.light),
      (AppTheme.dark(), TiqColors.dark),
    ]) {
      await tester.pumpWidget(_app(_route(), theme: theme));
      await tester.pumpAndSettle();

      // doneCount == 1; the sequence badges render a tick (visited) and '2'
      // (next), so '1' is uniquely the headline count.
      final count = tester.widget<Text>(find.text('1'));
      expect(count.style?.fontWeight, FontWeight.w700);
      expect(count.style?.fontSize, inInclusiveRange(30, 32));
      expect(count.style?.color, palette.ink1);
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
    // The word rides on a good-family wash — meaning in words AND colour.
    final pill = find.ancestor(
      of: find.text('Route done'),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color ==
                TiqColors.light.good.withValues(alpha: 0.14),
      ),
    );
    expect(pill, findsOneWidget);
  });

  testWidgets('each stop is a card with a state-coloured left edge', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_route(), theme: AppTheme.light()));
    await tester.pumpAndSettle();

    // Channel 1: a 3px left edge — good (visited), brand (next).
    Finder edge(Color color) => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.color == color &&
          w.constraints == const BoxConstraints.tightFor(width: 3),
    );
    expect(edge(TiqColors.light.good), findsOneWidget);
    expect(edge(TiqColors.light.brand), findsOneWidget);

    // Channels 2+3: the mark/word — never colour alone.
    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
  });
}
