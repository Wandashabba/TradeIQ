import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/app_colors.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outlet_picker_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;

/// Returns a shorter list when narrowed, so a test can tell the two apart —
/// a fake that ignored `mine` would make the scope switch untestable.
class ScopeAwareOutletsRepository implements OutletsRepository {
  final List<bool> calls = [];

  @override
  Future<List<Outlet>> listOutlets({bool mine = false}) async {
    calls.add(mine);
    return mine
        ? const [
            Outlet(
              id: 'o1',
              name: 'My Store',
              code: 'MS-1',
              lat: -26.1,
              lng: 28.0,
            ),
          ]
        : const [
            Outlet(
              id: 'o1',
              name: 'My Store',
              code: 'MS-1',
              lat: -26.1,
              lng: 28.0,
            ),
            Outlet(
              id: 'o2',
              name: 'Other Store',
              code: 'OS-1',
              lat: -26.2,
              lng: 28.1,
            ),
          ];
  }

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) => throw UnimplementedError();
}

class FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets({bool mine = false}) async => const [
    Outlet(
      id: 'o1',
      name: 'Test Outlet',
      code: 'TO-001',
      lat: -26.2041,
      lng: 28.0473,
    ),
  ];

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) => throw UnimplementedError();
}

/// The picker under a real GoRouter (AgentScaffold reads GoRouterState) with an
/// explicit theme, plus the `/audit/:id` destination the row taps through to.
Widget _app(OutletsRepository repo, {ThemeData? theme}) {
  final router = GoRouter(
    initialLocation: '/audit',
    routes: [
      GoRoute(
        path: '/audit',
        builder: (context, state) => const VisitOutletPickerScreen(),
      ),
      GoRoute(
        path: '/audit/:outletId',
        builder: (context, state) =>
            Text('Visit ${state.pathParameters['outletId']}'),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      outletsRepositoryProvider.overrideWithValue(repo),
      // Agent screens carry the sync chip, which watches the outbox over a
      // Drift stream. Drift's watch() reschedules a zero-duration timer on
      // every tick, so pumpAndSettle never settles against a real one — a
      // widget test stubs the provider rather than the database.
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
    ],
    child: MaterialApp.router(theme: theme, routerConfig: router),
  );
}

void main() {
  testWidgets('renders outlets and navigates to the audit shell on row tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(FakeOutletsRepository(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Outlet'), findsOneWidget);

    // The whole card is the start-visit affordance now — no separate button.
    await tester.tap(find.text('Test Outlet'));
    await tester.pumpAndSettle();

    expect(find.text('Visit o1'), findsOneWidget);
  });

  testWidgets('defaults to the agent\'s own territories', (tester) async {
    final repo = ScopeAwareOutletsRepository();
    await tester.pumpWidget(_app(repo, theme: AppTheme.light()));
    await tester.pumpAndSettle();

    // A shorter list of the right shops is the point of having territories.
    expect(repo.calls.first, isTrue);
    expect(find.text('My Store'), findsOneWidget);
    expect(find.text('Other Store'), findsNothing);
    // And it must SAY it is filtered — a narrowed list that looks complete is
    // how somebody concludes a store is missing from the system.
    expect(find.textContaining('your territories'), findsWidgets);
  });

  testWidgets('the agent can always reach every store', (tester) async {
    // The reason this is a filter and not a permission. Territory data is
    // imperfect and field work is not: an agent covering a colleague's patch,
    // or at a shop filed under the wrong territory, must be able to check in
    // without finding an administrator first.
    final repo = ScopeAwareOutletsRepository();
    await tester.pumpWidget(_app(repo, theme: AppTheme.light()));
    await tester.pumpAndSettle();

    // The scope control is a two-segment pill; tapping "All stores" widens it.
    await tester.tap(find.byKey(const ValueKey<String>('scope-all')));
    await tester.pumpAndSettle();

    expect(repo.calls.last, isFalse);
    expect(find.text('Other Store'), findsOneWidget);
  });

  // ── Premium restyle (sub5a Task 3) ──────────────────────────────────────

  testWidgets('no raw Material rows survive the restyle', (tester) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(_app(FakeOutletsRepository(), theme: theme));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    }
  });

  // Read a scope segment's rendered (bg, border, text) off the tree, so a
  // regression to a non-pill treatment fails here rather than being hidden.
  ({Color bg, Color border, Color text}) segment(
    WidgetTester tester,
    String key,
    String label,
  ) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(ValueKey<String>(key)),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final deco = box.decoration! as BoxDecoration;
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey<String>(key)),
        matching: find.text(label),
      ),
    );
    return (
      bg: deco.color!,
      border: (deco.border! as Border).top.color,
      text: text.style!.color!,
    );
  }

  testWidgets('the scope control is a console pill/segment', (tester) async {
    for (final (name, theme, palette) in [
      ('light', AppTheme.light(), TiqColors.light),
      ('dark', AppTheme.dark(), TiqColors.dark),
    ]) {
      await tester.pumpWidget(
        _app(ScopeAwareOutletsRepository(), theme: theme),
      );
      await tester.pumpAndSettle();

      // Defaults narrowed, so "My territories" is the active segment.
      final active = segment(tester, 'scope-mine', 'My territories');
      expect(active.bg, palette.brand, reason: '$name active bg');
      expect(active.border, palette.brand, reason: '$name active border');
      expect(active.text, Colors.white, reason: '$name active text');

      final inactive = segment(tester, 'scope-all', 'All stores');
      expect(inactive.bg, palette.surface1, reason: '$name inactive bg');
      expect(inactive.border, palette.line, reason: '$name inactive border');
      expect(inactive.text, palette.ink2, reason: '$name inactive text');

      // The active state must reach a screen reader, not colour alone.
      final sem = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const ValueKey<String>('scope-mine')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(
        sem.properties.button,
        isTrue,
        reason: '$name segment is a button',
      );
      expect(sem.properties.selected, isTrue, reason: '$name active selected');
    }
  });

  testWidgets('the pill text clears AA in both themes', (tester) async {
    for (final (name, palette) in [
      ('light', TiqColors.light),
      ('dark', TiqColors.dark),
    ]) {
      // Active = white on brand; inactive = ink2 on surface1. Both must clear
      // 4.5:1 — the pill is a self-contained pair (no gradient to composite).
      final white = contrastRatio(Colors.white, palette.brand);
      final ink2 = contrastRatio(palette.ink2, palette.surface1);
      expect(white, greaterThanOrEqualTo(4.5), reason: '$name white-on-brand');
      expect(ink2, greaterThanOrEqualTo(4.5), reason: '$name ink2-on-surface1');
    }
  });

  testWidgets('each outlet renders as a console card', (tester) async {
    for (final (name, theme, palette) in [
      ('light', AppTheme.light(), TiqColors.light),
      ('dark', AppTheme.dark(), TiqColors.dark),
    ]) {
      await tester.pumpWidget(_app(FakeOutletsRepository(), theme: theme));
      await tester.pumpAndSettle();

      // The card: surface1 ground, `line` hairline, panel radius.
      final card = find.ancestor(
        of: find.text('Test Outlet'),
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final deco = w.decoration;
          if (deco is! BoxDecoration) return false;
          return deco.color == palette.surface1 &&
              deco.border == Border.all(color: palette.line) &&
              deco.borderRadius == BorderRadius.circular(AppColors.radiusPanel);
        }),
      );
      expect(card, findsOneWidget, reason: '$name outlet card');

      // The name reads in ink1; the meta line (code · coords) in ink3.
      final title = tester.widget<Text>(find.text('Test Outlet'));
      expect(title.style?.color, palette.ink1, reason: '$name name colour');

      final metaStyle = tester
          .widget<DefaultTextStyle>(
            find
                .ancestor(
                  of: find.textContaining('TO-001'),
                  matching: find.byType(DefaultTextStyle),
                )
                .first,
          )
          .style;
      expect(metaStyle.color, palette.ink3, reason: '$name meta colour');
    }
  });
}
