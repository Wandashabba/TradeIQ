import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_repository.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';

/// A repository that replays scripted events and records what it was sent.
class StubRepository implements AssistantRepository {
  StubRepository(this.script);

  final List<AssistantEvent> script;
  final List<String> messages = [];
  final List<List<ChatHistoryEntry>> histories = [];
  final List<String?> conversationIds = [];
  Object? throwError;

  @override
  Stream<AssistantEvent> chat({
    required String message,
    List<ChatHistoryEntry> history = const [],
    String? conversationId,
    CancelToken? cancelToken,
  }) async* {
    messages.add(message);
    histories.add(history);
    conversationIds.add(conversationId);
    if (throwError != null) throw throwError!;
    for (final event in script) {
      yield event;
    }
  }
}

ProviderContainer containerWith(StubRepository repository) {
  final container = ProviderContainer(
    overrides: [assistantRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ChatController', () {
    test('appends the user turn and a streaming assistant turn', () async {
      final repository = StubRepository([
        const TokenEvent('Tumo is up 6 points.'),
        const DoneEvent(),
      ]);
      final container = containerWith(repository);

      await container
          .read(chatControllerProvider.notifier)
          .send('How is Tumo doing?');

      final messages = container.read(chatControllerProvider).messages;
      expect(messages, hasLength(2));
      expect(messages[0].role, ChatRole.user);
      expect(messages[0].text, 'How is Tumo doing?');
      expect(messages[1].role, ChatRole.assistant);
      expect(messages[1].text, 'Tumo is up 6 points.');
      expect(messages[1].streaming, isFalse);
    });

    test('concatenates streamed tokens in order', () async {
      final repository = StubRepository([
        const TokenEvent('Stock is '),
        const TokenEvent('down '),
        const TokenEvent('4%.'),
        const DoneEvent(),
      ]);
      final container = containerWith(repository);

      await container.read(chatControllerProvider.notifier).send('stock?');

      expect(
        container.read(chatControllerProvider).messages.last.text,
        'Stock is down 4%.',
      );
    });

    test('ignores empty and whitespace-only messages', () async {
      final repository = StubRepository([const DoneEvent()]);
      final container = containerWith(repository);

      await container.read(chatControllerProvider.notifier).send('   ');

      expect(container.read(chatControllerProvider).messages, isEmpty);
      expect(repository.messages, isEmpty);
    });

    test('trims the message before sending', () async {
      final repository = StubRepository([const DoneEvent()]);
      final container = containerWith(repository);

      await container.read(chatControllerProvider.notifier).send('  hi  ');

      expect(repository.messages.single, 'hi');
    });

    group('tool activity', () {
      test('records a tool start and resolves it on end', () async {
        final repository = StubRepository([
          const ToolStartEvent(name: 'getStockLevels', pillar: 'stock'),
          const ToolEndEvent(name: 'getStockLevels', ok: true),
          const TokenEvent('Here you go.'),
          const DoneEvent(),
        ]);
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('stock?');

        final tools = container
            .read(chatControllerProvider)
            .messages
            .last
            .tools;
        expect(tools, hasLength(1));
        expect(tools.single.ok, isTrue);
      });

      test('resolves repeated calls to one tool in start order', () async {
        // `tool_end` carries no call id, so this is FIFO by convention. The
        // first version used `lastIndexWhere` and resolved them backwards —
        // which this test caught, and which no single-call test could have.
        final repository = StubRepository([
          const ToolStartEvent(name: 'getAgentScorecard', pillar: 'execution'),
          const ToolStartEvent(name: 'getAgentScorecard', pillar: 'execution'),
          const ToolEndEvent(name: 'getAgentScorecard', ok: true),
          const ToolEndEvent(name: 'getAgentScorecard', ok: false),
          const DoneEvent(),
        ]);
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('compare');

        final tools = container
            .read(chatControllerProvider)
            .messages
            .last
            .tools;
        expect(tools.map((t) => t.ok).toList(), [true, false]);
      });

      test('carries a failed tool through without failing the turn', () async {
        final repository = StubRepository([
          const ToolStartEvent(name: 'getFraudFlags', pillar: 'execution'),
          const ToolEndEvent(name: 'getFraudFlags', ok: false),
          const TokenEvent('I could not retrieve that.'),
          const DoneEvent(),
        ]);
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('fraud?');

        final message = container.read(chatControllerProvider).messages.last;
        expect(message.tools.single.ok, isFalse);
        expect(message.error, isNull);
        expect(message.text, 'I could not retrieve that.');
      });
    });

    group('artifacts', () {
      test('collects an artifact onto the assistant turn', () async {
        final repository = StubRepository([
          const ArtifactEvent(
            id: 'getAgentScorecard-0',
            type: 'agent_scorecard',
            params: {'agentId': 'a1'},
            data: {'averageScore': 82},
          ),
          const DoneEvent(),
        ]);
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('scorecard');

        final artifacts = container
            .read(chatControllerProvider)
            .messages
            .last
            .artifacts;
        expect(artifacts, hasLength(1));
        expect(artifacts.single.type, 'agent_scorecard');
      });

      test('patches in place when the same id arrives twice', () async {
        // Appending instead is what turns a chat into a graveyard of
        // near-identical cards.
        final repository = StubRepository([
          const ArtifactEvent(
            id: 'a1',
            type: 'agent_scorecard',
            params: {},
            data: {'averageScore': 70},
          ),
          const ArtifactEvent(
            id: 'a1',
            type: 'agent_scorecard',
            params: {},
            data: {'averageScore': 82},
          ),
          const DoneEvent(),
        ]);
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('q');

        final artifacts = container
            .read(chatControllerProvider)
            .messages
            .last
            .artifacts;
        expect(artifacts, hasLength(1));
        expect((artifacts.single.data as Map)['averageScore'], 82);
      });

      test('keeps two artifacts with different ids', () async {
        final repository = StubRepository([
          const ArtifactEvent(
            id: 'a1',
            type: 'agent_scorecard',
            params: {},
            data: {},
          ),
          const ArtifactEvent(
            id: 'a2',
            type: 'agent_scorecard',
            params: {},
            data: {},
          ),
          const DoneEvent(),
        ]);
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('q');

        expect(
          container.read(chatControllerProvider).messages.last.artifacts,
          hasLength(2),
        );
      });
    });

    group('failure', () {
      test('renders a server error instead of prose', () async {
        final repository = StubRepository([
          const ErrorEvent(code: 'rate_limited', message: 'Busy right now.'),
        ]);
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('q');

        final message = container.read(chatControllerProvider).messages.last;
        expect(message.error, 'Busy right now.');
        expect(message.streaming, isFalse);
      });

      test('reports a transport failure in the transcript', () async {
        final repository = StubRepository([])
          ..throwError = Exception('offline');
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('q');

        expect(
          container.read(chatControllerProvider).messages.last.error,
          contains('connection'),
        );
      });

      test('clears streaming when the stream ends with no done frame', () async {
        // A dropped connection. Without this the caret blinks forever on a turn
        // that is never coming back.
        final repository = StubRepository([const TokenEvent('half an ans')]);
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('q');

        final message = container.read(chatControllerProvider).messages.last;
        expect(message.streaming, isFalse);
        expect(message.text, 'half an ans');
      });

      test('explains an empty turn that produced nothing at all', () async {
        final repository = StubRepository([]);
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('q');

        expect(
          container.read(chatControllerProvider).messages.last.error,
          isNotNull,
        );
      });

      test(
        'leaves sending false after a failure so the composer unlocks',
        () async {
          // A stuck `sending` flag disables the input permanently — the user
          // cannot even retry.
          final repository = StubRepository([])..throwError = Exception('boom');
          final container = containerWith(repository);

          await container.read(chatControllerProvider.notifier).send('q');

          expect(container.read(chatControllerProvider).sending, isFalse);
        },
      );
    });

    group('history', () {
      test('sends no history on the first turn', () async {
        final repository = StubRepository([const DoneEvent()]);
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('first');

        expect(repository.histories.single, isEmpty);
      });

      test('replays prior turns on the second', () async {
        final repository = StubRepository([
          const TokenEvent('An answer.'),
          const DoneEvent(),
        ]);
        final container = containerWith(repository);
        final controller = container.read(chatControllerProvider.notifier);

        await controller.send('first');
        await controller.send('second');

        final history = repository.histories.last;
        expect(history.map((e) => e.content).toList(), ['first', 'An answer.']);
        expect(history.map((e) => e.role).toList(), ['user', 'assistant']);
      });

      test('excludes an errored turn from history', () async {
        // Replaying "could not reach the assistant" as though the model said it
        // teaches it that such a reply is in character.
        final repository = StubRepository([
          const ErrorEvent(code: 'x', message: 'Busy.'),
        ]);
        final container = containerWith(repository);
        final controller = container.read(chatControllerProvider.notifier);

        await controller.send('first');
        repository.script
          ..clear()
          ..add(const DoneEvent());
        await controller.send('second');

        expect(repository.histories.last.map((e) => e.content).toList(), [
          'first',
        ]);
      });

      test(
        'caps history so a long conversation forgets rather than fails',
        () async {
          final repository = StubRepository([
            const TokenEvent('ok'),
            const DoneEvent(),
          ]);
          final container = containerWith(repository);
          final controller = container.read(chatControllerProvider.notifier);

          for (var i = 0; i < 20; i++) {
            await controller.send('question $i');
          }

          expect(
            repository.histories.last.length,
            lessThanOrEqualTo(ChatController.historyLimit),
          );
        },
      );
    });

    group('the conversation id', () {
      test(
        'is absent on the first turn and echoed on every one after',
        () async {
          // Without the echo the server opens a new conversation per turn, and
          // both the live-artifact manifest and the params-change note have
          // nothing to report — the backend works and the feature is invisible.
          final repository = StubRepository([
            const ConversationEvent('conv-7'),
            const TokenEvent('ok'),
            const DoneEvent(),
          ]);
          final container = containerWith(repository);
          final controller = container.read(chatControllerProvider.notifier);

          await controller.send('first');
          await controller.send('second');

          expect(repository.conversationIds, [null, 'conv-7']);
        },
      );

      test('is not rendered as a turn', () async {
        final repository = StubRepository([
          const ConversationEvent('conv-7'),
          const DoneEvent(),
        ]);
        final container = containerWith(repository);

        await container.read(chatControllerProvider.notifier).send('q');

        final messages = container.read(chatControllerProvider).messages;
        expect(messages, hasLength(2));
        expect(messages.last.text, isEmpty);
      });

      test('is dropped by clear(), because that is a new conversation', () async {
        // Keeping it would carry the old thread's artifacts into one the user
        // believes is empty, and offer the model views that are no longer there.
        final repository = StubRepository([
          const ConversationEvent('conv-7'),
          const DoneEvent(),
        ]);
        final container = containerWith(repository);
        final controller = container.read(chatControllerProvider.notifier);

        await controller.send('first');
        controller.clear();
        await controller.send('second');

        expect(repository.conversationIds.last, isNull);
      });
    });

    test('a sources event lands on the current assistant message', () async {
      final source = WebSource(
        title: 'Shoprite launches new stores',
        url: Uri.parse('https://www.iol.co.za/business/shoprite'),
        domain: 'iol.co.za',
        retrievedAt: DateTime.utc(2026, 9, 17, 10, 12),
      );
      final repository = StubRepository([
        const ToolStartEvent(name: 'webSearch', pillar: 'web'),
        const ToolEndEvent(name: 'webSearch', ok: true),
        const TokenEvent('Shoprite opened three stores.'),
        SourcesEvent([source]),
        const UsageEvent(
          inputTokens: 1,
          outputTokens: 1,
          cacheReadTokens: 0,
          costCents: 0,
        ),
        const DoneEvent(),
      ]);
      final container = containerWith(repository);

      await container.read(chatControllerProvider.notifier).send('news?');

      final messages = container.read(chatControllerProvider).messages;
      expect(messages.first.sources, isEmpty);
      final answer = messages.last;
      expect(answer.sources, [source]);
      expect(answer.text, 'Shoprite opened three stores.');
      expect(answer.tools.single.name, 'webSearch');
      expect(answer.streaming, isFalse);
    });

    test('clear() empties the transcript', () async {
      final repository = StubRepository([const DoneEvent()]);
      final container = containerWith(repository);
      final controller = container.read(chatControllerProvider.notifier);

      await controller.send('q');
      controller.clear();

      expect(container.read(chatControllerProvider).messages, isEmpty);
    });
  });
}
