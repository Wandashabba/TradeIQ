import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
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
  @override
  Future<List<FlaggedVisit>> flagged({int? minScore}) async =>
      const [_highRiskVisit, _lowRiskVisit];
}

class _ThrowingFraudRepository implements FraudRepository {
  @override
  Future<List<FlaggedVisit>> flagged({int? minScore}) async =>
      throw Exception('boom');
}

Widget _app(FraudRepository repo, {ThemeData? theme}) => routedApp(
      const FraudScreen(),
      theme: theme,
      overrides: [
        fraudRepositoryProvider.overrideWithValue(repo),
      ],
    );

void main() {
  testWidgets('renders under the light theme', (tester) async {
    await tester.pumpWidget(_app(_FakeFraudRepository(), theme: AppTheme.light()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(FraudScreen), findsOneWidget);
  });

  testWidgets('renders risk score and signal codes for flagged visits',
      (tester) async {
    await tester.pumpWidget(_app(_FakeFraudRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Visit v-high-0'), findsOneWidget);
    expect(
      find.text('Risk 82 · gps_mismatch, fast_visit'),
      findsOneWidget,
    );
    expect(find.text('Risk 55 · '), findsOneWidget);
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_ThrowingFraudRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load flagged visits'),
      findsOneWidget,
    );
  });
}
