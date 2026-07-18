import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/features/dispatch/data/dispatch_repository.dart';
import 'package:tradeiq_app/features/dispatch/presentation/dispatch_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../helpers/routed_app.dart';

const _outlets = [
  Outlet(id: 'o1', name: 'Corner Shop', code: 'CS1', lat: -26.2, lng: 28.0),
  Outlet(id: 'o2', name: 'Main Street', code: 'MS1', lat: -26.1, lng: 28.1),
];

const _result = DispatchResult(
  recommended: DispatchCandidate(
    agentId: 'a1',
    email: 'near@example.com',
    distanceM: 120,
    inTerritory: true,
  ),
  candidates: [
    DispatchCandidate(
      agentId: 'a1',
      email: 'near@example.com',
      distanceM: 120,
      inTerritory: true,
    ),
    DispatchCandidate(
      agentId: 'a2',
      email: 'far@example.com',
      inTerritory: false,
    ),
  ],
);

class _FakeDispatchRepository implements DispatchRepository {
  @override
  Future<DispatchResult> dispatch(String outletId) async => _result;
}

Widget _app({ThemeData? theme}) => routedApp(
      const DispatchScreen(),
      theme: theme,
      overrides: [
        outletsListProvider.overrideWith((ref) async => _outlets),
        dispatchRepositoryProvider
            .overrideWithValue(_FakeDispatchRepository()),
      ],
    );

void main() {
  testWidgets('renders under the light theme', (tester) async {
    await tester.pumpWidget(_app(theme: AppTheme.light()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DispatchScreen), findsOneWidget);
  });

  testWidgets('renders the outlet dropdown and Dispatch app bar',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Dispatch'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('outlet-select')), findsOneWidget);
  });
}
