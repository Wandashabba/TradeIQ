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
  // Deliberately partial: only `green` is stored. The other three keys must
  // fall back to what the engine already uses, not to zero.
  kpiThresholds: {'green': 80.0},
);

class _FakeClientsRepository implements ClientsRepository {
  Map<String, double>? savedWeights;
  Map<String, double>? savedThresholds;

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

  @override
  Future<ClientConfig> updateThresholds(Map<String, double> thresholds) async {
    savedThresholds = thresholds;
    return ClientConfig(
      name: _config.name,
      scorecardWeights: _config.scorecardWeights,
      kpiThresholds: thresholds,
    );
  }
}

class _ThrowingClientsRepository implements ClientsRepository {
  @override
  Future<ClientConfig> getConfig() async => throw Exception('boom');

  @override
  Future<ClientConfig> updateWeights(Map<String, double> weights) async =>
      throw Exception('boom');

  @override
  Future<ClientConfig> updateThresholds(Map<String, double> thresholds) async =>
      throw Exception('boom');
}

Widget _app(ClientsRepository repo) => routedApp(
      const ClientConfigScreen(),
      overrides: [
        clientsRepositoryProvider.overrideWithValue(repo),
      ],
    );

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1280, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a weight field for each scorecard weight', (tester) async {
    await _pump(tester, _app(_FakeClientsRepository()));

    expect(find.byKey(const ValueKey<String>('weight-availability')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('weight-visibility')),
        findsOneWidget);
  });

  testWidgets('saving submits the parsed weights map', (tester) async {
    final repo = _FakeClientsRepository();
    await _pump(tester, _app(repo));

    await tester.enterText(
      find.byKey(const ValueKey<String>('weight-availability')),
      '0.5',
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-config')));
    await tester.pumpAndSettle();

    expect(repo.savedWeights, {'availability': 0.5, 'visibility': 0.2});
  });

  testWidgets('exposes exactly the four thresholds the engine reads', (
    tester,
  ) async {
    // The seed used to write excellent/good/needsImprovement, which no code path
    // reads — a UI over those keys would have been controls that do nothing.
    await _pump(tester, _app(_FakeClientsRepository()));

    for (final key in const [
      'green',
      'amber',
      'stockoutUnits',
      'priceDeviationPct',
    ]) {
      expect(
        find.byKey(ValueKey<String>('threshold-$key')),
        findsOneWidget,
        reason: 'missing threshold $key',
      );
    }
  });

  testWidgets('an absent threshold shows the engine default, not zero', (
    tester,
  ) async {
    final repo = _FakeClientsRepository();
    await _pump(tester, _app(repo));

    // Only `green` is stored. Saving must send the engine's real fallbacks for
    // the rest — sending 0 would turn "price deviation over 10%" into "over 0%"
    // and open a task on every single price row.
    await tester.tap(find.byKey(const ValueKey<String>('save-thresholds')));
    await tester.pumpAndSettle();

    expect(repo.savedThresholds, {
      'green': 80.0,
      'amber': 60.0,
      'stockoutUnits': 0.0,
      'priceDeviationPct': 10.0,
    });
  });

  testWidgets('saving submits an edited threshold', (tester) async {
    final repo = _FakeClientsRepository();
    await _pump(tester, _app(repo));

    await tester.enterText(
      find.byKey(const ValueKey<String>('threshold-priceDeviationPct')),
      '5',
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-thresholds')));
    await tester.pumpAndSettle();

    expect(repo.savedThresholds?['priceDeviationPct'], 5.0);
  });

  testWidgets('shows an error message when the config fails to load',
      (tester) async {
    await _pump(tester, _app(_ThrowingClientsRepository()));

    expect(find.textContaining('Failed to load config'), findsOneWidget);
  });
}
