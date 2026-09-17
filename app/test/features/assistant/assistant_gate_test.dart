import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/assistant/presentation/assistant_gate.dart';
import 'package:tradeiq_app/features/assistant/presentation/chat_screen.dart';
import 'package:tradeiq_app/features/clients/data/clients_repository.dart';

import '../../helpers/routed_app.dart';

ClientConfig config({required bool assistantEnabled}) => ClientConfig(
      name: 'Acme',
      scorecardWeights: const {},
      kpiThresholds: const {},
      assistantEnabled: assistantEnabled,
    );

class StubClients implements ClientsRepository {
  StubClients(this.result);

  /// Either a config to return or an error to throw.
  final Object result;

  @override
  Future<ClientConfig> getConfig() async {
    final value = result;
    if (value is ClientConfig) return value;
    throw value;
  }

  @override
  Future<ClientConfig> updateWeights(Map<String, double> weights) async =>
      throw UnimplementedError();

  @override
  Future<ClientConfig> updateThresholds(Map<String, double> thresholds) async =>
      throw UnimplementedError();

  @override
  Future<ClientConfig> updateTimezone(String timezone) async =>
      throw UnimplementedError();

  @override
  Future<ClientConfig> updateWorkingHours({
    required String start,
    required String end,
    required List<int> days,
  }) async => throw UnimplementedError();
}

Future<void> pumpGate(
  WidgetTester tester,
  Object clientsResult, {
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(routedApp(
    const AssistantGate(),
    theme: theme ?? AppTheme.dark(),
    overrides: [
      clientsRepositoryProvider.overrideWithValue(StubClients(clientsResult)),
    ],
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the chat when the tenant is in the rollout', (tester) async {
    await pumpGate(tester, config(assistantEnabled: true));

    expect(find.byType(AssistantChatScreen), findsOneWidget);
  });

  testWidgets('explains itself when the tenant is not in the rollout',
      (tester) async {
    await pumpGate(tester, config(assistantEnabled: false));

    expect(find.byType(AssistantChatScreen), findsNothing);
    expect(find.textContaining('Not switched on'), findsOneWidget);
    // Names who can actually act. "Contact your administrator" sends people to
    // the wrong place — a client admin cannot turn this on, by design.
    expect(find.textContaining('TradeIQ contact'), findsOneWidget);
  });

  testWidgets('fails toward the chat when the config call errors',
      (tester) async {
    // Telling someone their feature is switched off because one unrelated call
    // timed out is the worse way to be wrong — the server refuses the turn with
    // a message anyway if they really are outside the rollout.
    await pumpGate(tester, Exception('network down'));

    expect(find.byType(AssistantChatScreen), findsOneWidget);
  });

  testWidgets('light: the explanation sits in one glass panel', (tester) async {
    await pumpGate(
      tester,
      config(assistantEnabled: false),
      theme: AppTheme.light(),
    );

    final pane = find.ancestor(
      of: find.textContaining('Not switched on'),
      matching: find.byType(GlassPane),
    );
    expect(pane, findsOneWidget);
    expect(tester.widget<GlassPane>(pane).kind, GlassKind.panel);
    // The words that matter survive the restyle.
    expect(find.textContaining('TradeIQ contact'), findsOneWidget);
  });

  testWidgets('dark: the explanation sits in the same glass panel',
      (tester) async {
    await pumpGate(tester, config(assistantEnabled: false));

    final pane = find.ancestor(
      of: find.textContaining('Not switched on'),
      matching: find.byType(GlassPane),
    );
    expect(pane, findsOneWidget);
    expect(tester.widget<GlassPane>(pane).kind, GlassKind.panel);
    expect(find.textContaining('TradeIQ contact'), findsOneWidget);
  });

  test('defaults to off when the server predates the field', () {
    // An older backend returns no `assistantEnabled` key at all. Hiding the
    // entry point is the safe way to be wrong — and the route is gated
    // server-side regardless, so this only decides whether we offer it.
    final parsed = ClientConfig.fromJson(const {
      'name': 'Acme',
      'scorecardWeights': <String, dynamic>{},
      'kpiThresholds': <String, dynamic>{},
    });

    expect(parsed.assistantEnabled, isFalse);
  });
}
