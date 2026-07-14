import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
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

/// Loads fine, refuses to save — the 403 an admin-only endpoint returns to a
/// caller who is not one.
class _RejectingClientsRepository implements ClientsRepository {
  @override
  Future<ClientConfig> getConfig() async => _config;

  @override
  Future<ClientConfig> updateWeights(Map<String, double> weights) async =>
      throw DioException(
        requestOptions: RequestOptions(path: '/clients/me'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/clients/me'),
          statusCode: 403,
        ),
      );

  @override
  Future<ClientConfig> updateThresholds(Map<String, double> thresholds) async =>
      throw Exception('boom');
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

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._role);
  final String _role;

  @override
  Future<SessionState> build() async => SessionState(role: _role);
}

/// Defaults to an admin: PATCH /clients/me is admin-only, so that is the role
/// the editing tests are about.
Widget _app(ClientsRepository repo, {String role = 'admin'}) => routedApp(
      const ClientConfigScreen(),
      overrides: [
        clientsRepositoryProvider.overrideWithValue(repo),
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(role),
        ),
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

  testWidgets('a manager sees the config, but cannot save it', (tester) async {
    // PATCH /clients/me is admin-only. Showing a manager an editable form and a
    // Save button meant they filled it in and got a 403 — which arrived as an
    // UNHANDLED exception and crashed the screen.
    await _pump(tester, _app(_FakeClientsRepository(), role: 'manager'));

    expect(find.byKey(const ValueKey<String>('read-only-notice')), findsWidgets);
    expect(find.byKey(const ValueKey<String>('save-config')), findsNothing);
    expect(find.byKey(const ValueKey<String>('save-thresholds')), findsNothing);

    // And the fields they cannot save are not typeable either.
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('weight-availability')),
    );
    expect(field.enabled, isFalse);
  });

  testWidgets('a 403 is reported in words, not thrown as an exception', (
    tester,
  ) async {
    await _pump(tester, _app(_RejectingClientsRepository()));

    // Before, this escaped as an unhandled DioException and crashed the screen.
    await tester.tap(find.byKey(const ValueKey<String>('save-config')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Only an administrator can change scoring config.'),
      findsOneWidget,
    );
  });
}
