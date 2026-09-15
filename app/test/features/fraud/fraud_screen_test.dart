import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/fraud/data/fraud_repository.dart';
import 'package:tradeiq_app/features/fraud/presentation/fraud_screen.dart';

import '../../helpers/routed_app.dart';

const _highRiskVisit = FlaggedVisit(
  visitId: 'v-high-001',
  outletId: 'o1',
  agentId: 'a1',
  riskScore: 82,
  signals: [
    FraudSignal(code: 'gps_mismatch', detail: '500m from outlet'),
    FraudSignal(code: 'fast_visit', detail: 'Under 2 minutes'),
  ],
);

const _lowRiskVisit = FlaggedVisit(
  visitId: 'v-low-002',
  outletId: 'o2',
  agentId: 'a2',
  riskScore: 55,
  signals: [],
);

class _FakeFraudRepository implements FraudRepository {
  _FakeFraudRepository(this.page);
  final FlaggedPage page;

  @override
  Future<FlaggedPage> flagged({int? minScore}) async => page;
}

class _ThrowingFraudRepository implements FraudRepository {
  @override
  Future<FlaggedPage> flagged({int? minScore}) async =>
      throw Exception('boom');
}

Widget _app(FraudRepository repo, {ThemeData? theme}) => routedApp(
      const FraudScreen(),
      theme: theme,
      overrides: [
        fraudRepositoryProvider.overrideWithValue(repo),
      ],
    );

const _riskLine = 'Risk 82 · gps_mismatch, fast_visit';

void main() {
  testWidgets('dark: the risk line keeps the row meta style', (tester) async {
    await tester.pumpWidget(_app(_FakeFraudRepository()));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text(_riskLine)).style, isNull);
  });

  testWidgets('light: rows are glass tiles; the figure and codes are mono', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeFraudRepository(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text(_riskLine)).style!.fontFamily,
      LumenGlass.mono,
    );
    final panes = tester.widgetList<GlassPane>(
      find.ancestor(
        of: find.text('Visit v-high-0'),
        matching: find.byType(GlassPane),
      ),
    );
    expect(panes.any((p) => p.kind == GlassKind.tile && !p.blur), isTrue);
    // Accusation stays a word on glass.
    expect(find.text('HIGH RISK'), findsWidgets);
  });

  testWidgets('renders risk score and signal codes for flagged visits',
      (tester) async {
    await tester.pumpWidget(_app(_FakeFraudRepository(const FlaggedPage(
      data: [_highRiskVisit, _lowRiskVisit],
      nextCursor: null,
    ))));
    await tester.pumpAndSettle();

    expect(find.text('Visit v-high-0'), findsOneWidget);
    expect(
      find.text('Risk 82 · gps_mismatch, fast_visit'),
      findsOneWidget,
    );
    expect(find.text('Risk 55 · '), findsOneWidget);
    expect(find.text('2 flagged visits'), findsOneWidget);
    // Everything was scored: no unscored note.
    expect(find.byKey(const ValueKey('fraud-unscored')), findsNothing);
  });

  testWidgets('says how many visits are not scored yet, rather than hiding them',
      (tester) async {
    await tester.pumpWidget(_app(_FakeFraudRepository(const FlaggedPage(
      data: [_highRiskVisit],
      nextCursor: null,
      unscored: 3,
    ))));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '3 submitted visits have not been scored yet and are not listed here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('titles a partial first page as the top of the list',
      (tester) async {
    await tester.pumpWidget(_app(_FakeFraudRepository(const FlaggedPage(
      data: [_highRiskVisit, _lowRiskVisit],
      nextCursor: 'v-low-002',
    ))));
    await tester.pumpAndSettle();

    expect(find.text('Top 2 flagged visits'), findsOneWidget);
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_ThrowingFraudRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load flagged visits'),
      findsOneWidget,
    );
  });

  testWidgets('View visit on a flagged row opens that visit (#208)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fraudRepositoryProvider.overrideWithValue(_FakeFraudRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/fraud',
            routes: [
              GoRoute(
                path: '/fraud',
                builder: (context, state) => const FraudScreen(),
              ),
              GoRoute(
                path: '/visits/:id',
                builder: (context, state) =>
                    Text('visit detail ${state.pathParameters['id']}'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View visit'), findsNWidgets(2));
    await tester.tap(
      find.byKey(const ValueKey<String>('view-visit-v-high-001')),
    );
    await tester.pumpAndSettle();

    expect(find.text('visit detail v-high-001'), findsOneWidget);
  });
}
