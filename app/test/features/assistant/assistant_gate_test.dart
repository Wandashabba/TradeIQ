import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state/skeleton.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_repository.dart';
import 'package:tradeiq_app/features/assistant/presentation/assistant_gate.dart';
import 'package:tradeiq_app/features/assistant/presentation/chat_screen.dart';
import 'package:tradeiq_app/features/clients/data/clients_repository.dart';

import '../../core/design/amber_golden.dart';
import '../../helpers/routed_app.dart';
import 'ask_harness.dart'
    show ScriptedRepository, askBoundaryKey, askSkins, screenText;

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
    if (value is Future<ClientConfig>) return value;
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
  TiqSkin? skin,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  bool settle = true,
}) async {
  tester.view
    ..physicalSize = const Size(360, 640)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final resolved = skin ?? TiqSkin.night(density: TiqDensity.console);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 640),
        devicePixelRatio: 1.0,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: routedApp(
        const RepaintBoundary(key: askBoundaryKey, child: AssistantGate()),
        theme: AppTheme.torchlight(resolved),
        locale: locale,
        overrides: <Override>[
          clientsRepositoryProvider.overrideWithValue(
            StubClients(clientsResult),
          ),
          askOnlineProvider.overrideWithValue(true),
          askSessionEndedProvider.overrideWithValue(false),
          assistantRepositoryProvider.overrideWithValue(
            ScriptedRepository(const <AssistantEvent>[]),
          ),
        ],
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
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

  for (final skin in askSkins) {
    testWidgets('${skin.mode.name}: the explanation wears the route\'s chrome '
        'and arms nothing', (tester) async {
      await pumpGate(tester, config(assistantEnabled: false), skin: skin);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('ask-not-enabled')), findsOneWidget);
      // The header is the route's, so it does not appear to arrive late.
      expect(find.byType(TorchAppHeader), findsOneWidget);
      final text = screenText(tester);
      expect(text, contains('Ask TradeIQ'));
      expect(text, contains('Not switched on'));
      // Names who can actually act. "Contact your administrator" sends people
      // to the wrong place — a client admin cannot turn this on, by design.
      expect(text, contains('TradeIQ contact'));

      // Nothing is armed here, in any skin: there is nothing to do on this
      // screen, so there is nothing for the light to point at.
      final scope = tester.widget<TorchScope>(find.byType(TorchScope).first);
      expect(scope.phase, 'gate');
      expect(scope.allocation.granted, isEmpty);
      final census = await amberCensus(tester);
      expect(census.objectCount, 0, reason: census.describe());
    });
  }

  testWidgets('while the flag is in flight, the shape of a transcript', (
    tester,
  ) async {
    // Not a centred spinner: the geometry a manager is about to read, held
    // still, so the screen does not jump when the answer's frame arrives.
    final completer = Completer<ClientConfig>();
    await pumpGate(tester, completer.future, settle: false);
    await tester.pump();

    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(AssistantChatScreen), findsNothing);
    expect(find.byType(TorchAppHeader), findsOneWidget);

    completer.complete(config(assistantEnabled: true));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantChatScreen), findsOneWidget);
  });

  testWidgets('in Afrikaans, at 2.0x', (tester) async {
    await pumpGate(
      tester,
      config(assistantEnabled: false),
      locale: const Locale('af'),
      textScale: 2.0,
    );

    expect(tester.takeException(), isNull);
    expect(screenText(tester), isNot(contains('Not switched on')));
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
