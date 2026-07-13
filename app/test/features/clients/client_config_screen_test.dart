import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/clients/data/clients_repository.dart';
import 'package:tradeiq_app/features/clients/presentation/client_config_screen.dart';

import '../../helpers/routed_app.dart';

const _config = ClientConfig(
  name: 'Acme Beverages',
  scorecardWeights: {
    'availability': 0.3,
    'visibility': 0.2,
  },
  kpiThresholds: {'green': 80.0},
);

class _FakeClientsRepository implements ClientsRepository {
  Map<String, double>? savedWeights;

  @override
  Future<ClientConfig> getConfig() async => _config;

  @override
  Future<ClientConfig> updateWeights(Map<String, double> weights) async {
    savedWeights = weights;
    return ClientConfig(
      name: _config.name,
      scorecardWeights: weights,
      kpiThresholds: _config.kpiThresholds,
    );
  }
}

class _ThrowingClientsRepository implements ClientsRepository {
  @override
  Future<ClientConfig> getConfig() async => throw Exception('boom');

  @override
  Future<ClientConfig> updateWeights(Map<String, double> weights) async =>
      throw Exception('boom');
}

Widget _app(ClientsRepository repo) => routedApp(
      const ClientConfigScreen(),
      overrides: [
        clientsRepositoryProvider.overrideWithValue(repo),
      ],
    );

void main() {
  testWidgets('renders a weight field for each scorecard weight', (tester) async {
    await tester.pumpWidget(_app(_FakeClientsRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('weight-availability')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('weight-visibility')),
        findsOneWidget);
  });

  testWidgets('saving submits the parsed weights map', (tester) async {
    final repo = _FakeClientsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('weight-availability')),
      '0.5',
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-config')));
    await tester.pumpAndSettle();

    expect(repo.savedWeights, {'availability': 0.5, 'visibility': 0.2});
  });

  testWidgets('shows an error message when the config fails to load',
      (tester) async {
    await tester.pumpWidget(_app(_ThrowingClientsRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load config'), findsOneWidget);
  });
}
