import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/outlets/presentation/outlets_list_screen.dart';

class FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'o1', name: 'Test Hypermarket', code: 'TH-001', lat: -26.2041, lng: 28.0473),
      ];
}

void main() {
  testWidgets('renders outlet names once loaded', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outletsRepositoryProvider.overrideWithValue(FakeOutletsRepository()),
        ],
        child: const MaterialApp(home: OutletsListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Hypermarket'), findsOneWidget);
  });
}
