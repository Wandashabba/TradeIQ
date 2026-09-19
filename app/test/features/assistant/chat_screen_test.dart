import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/features/assistant/answer/ask_turn.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';
import 'package:tradeiq_app/features/assistant/view_specs/agent_scorecard_card.dart';

import 'ask_harness.dart';

/// Ask TradeIQ, end to end through a scripted repository: what a manager can
/// do on the route, which the Torchlight migration changed the look of and
/// must not have changed the capability of.
void main() {
  group('first run', () {
    testWidgets('says what it reads and that it cannot change anything', (
      tester,
    ) async {
      // An assistant that silently declines the first thing you ask teaches
      // you not to ask again. It is read-only, and it says so up front.
      await pumpAsk(tester);

      expect(find.text('Ask about your territory.'), findsOneWidget);
      expect(find.textContaining('I cannot change anything'), findsOneWidget);
      await disposeAsk(tester);
    });

    testWidgets('a suggestion row sends its exact question', (tester) async {
      // A blank chat box is the hardest possible first move.
      final repository = ScriptedRepository(const <AssistantEvent>[
        TokenEvent('Here you go.'),
        DoneEvent(),
      ]);
      await pumpAsk(tester, repository: repository);

      final row = find.byKey(const ValueKey<String>('ask-suggestion-1'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(repository.sent.single, 'Which outlets keep running out of stock?');
      await disposeAsk(tester);
    });

    testWidgets('Send is disabled and says why when nothing is typed', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpAsk(tester);

      expect(
        find.bySemanticsLabel('Send, unavailable, nothing typed yet'),
        findsOneWidget,
      );
      await tester.enterText(composerField, 'How is Tumo doing?');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Send this question'), findsOneWidget);
      semantics.dispose();
      await disposeAsk(tester);
    });
  });

  group('a turn', () {
    testWidgets('typing and sending renders both turns', (tester) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(const <AssistantEvent>[
          TokenEvent('Tumo is up 6 points.'),
          DoneEvent(),
        ]),
      );
      await ask(tester, 'How is Tumo doing?');

      expect(find.byType(QuestionBubble), findsOneWidget);
      expect(screenText(tester), contains('How is Tumo doing?'));
      expect(screenText(tester), contains('Tumo is up 6 points.'));
      await disposeAsk(tester);
    });

    testWidgets('the question is the only right-aligned thing on the route', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(const <AssistantEvent>[
          TokenEvent('Tumo is up 6 points.'),
          DoneEvent(),
        ]),
      );
      await ask(tester, 'How is Tumo?');

      final bubble = tester.getRect(
        find
            .descendant(
              of: find.byType(QuestionBubble),
              matching: find.textContaining('How is Tumo?'),
            )
            .first,
      );
      final answer = tester.getRect(
        find.textContaining('Tumo is up 6 points.').first,
      );
      expect(bubble.right, greaterThan(answer.right - 1));
      expect(bubble.left, greaterThan(answer.left));
      await disposeAsk(tester);
    });

    testWidgets('a tool shows as a plain-English step, not its function name', (
      tester,
    ) async {
      // `getShareOfShelf` is our vocabulary; "Share of shelf" is the manager's.
      await pumpAsk(
        tester,
        repository: ScriptedRepository(const <AssistantEvent>[
          ToolStartEvent(name: 'getShareOfShelf', pillar: 'visibility'),
          ToolEndEvent(name: 'getShareOfShelf', ok: true),
          TokenEvent('You hold 34%.'),
          DoneEvent(),
        ]),
      );
      await ask(tester, 'share of shelf?');

      // Settled, the rail is one provenance row; opened, it is the steps.
      await tester.tap(find.textContaining('Checked 1 source'));
      await tester.pumpAndSettle();
      expect(find.text('Share of shelf'), findsOneWidget);
      expect(find.textContaining('getShareOfShelf'), findsNothing);
      await disposeAsk(tester);
    });

    testWidgets('a tool this build does not know falls back to its pillar', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(const <AssistantEvent>[
          ToolStartEvent(name: 'getShelfHologram', pillar: 'visibility'),
          ToolEndEvent(name: 'getShelfHologram', ok: true),
          TokenEvent('Done.'),
          DoneEvent(),
        ]),
      );
      await ask(tester, 'q');

      await tester.tap(find.textContaining('Checked 1 source'));
      await tester.pumpAndSettle();
      expect(find.text('Checking visibility'), findsOneWidget);
      expect(find.textContaining('getShelfHologram'), findsNothing);
      await disposeAsk(tester);
    });

    testWidgets('the exit demo: narrative plus the real scorecard widget', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        size: const Size(360, 1200),
        repository: ScriptedRepository(const <AssistantEvent>[
          ToolStartEvent(name: 'getAgentScorecard', pillar: 'execution'),
          ToolEndEvent(name: 'getAgentScorecard', ok: true),
          ArtifactEvent(
            id: 'getAgentScorecard-0',
            type: 'agent_scorecard',
            params: <String, dynamic>{'agentId': 'a1'},
            data: <String, dynamic>{
              'agentName': 'tumo@example.com',
              'averageScore': 82.0,
              'teamAverageScore': 71.0,
              'deltaVsTeam': 11.0,
              'visits': 14,
              'outletsVisited': 9,
              'scoredVisits': 12,
            },
          ),
          TokenEvent('Tumo is 11 points ahead of the team this month.'),
          DoneEvent(),
        ]),
      );
      await ask(tester, 'How has Tumo been performing this month?');

      expect(
        screenText(tester),
        contains('Tumo is 11 points ahead of the team this month.'),
      );
      expect(find.byType(AgentScorecardCard), findsOneWidget);
      expect(screenText(tester), contains('82.0'));
      await disposeAsk(tester);
    });

    testWidgets('an unknown artifact type does not blank the answer', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(const <AssistantEvent>[
          ArtifactEvent(
            id: 'a1',
            type: 'hologram',
            params: <String, dynamic>{},
            data: <String, dynamic>{},
          ),
          TokenEvent('Availability is 91%.'),
          DoneEvent(),
        ]),
      );
      await ask(tester, 'q');

      expect(tester.takeException(), isNull);
      // The narrative still carries the answer.
      expect(screenText(tester), contains('Availability is 91%.'));
      expect(screenText(tester), contains('cannot draw yet'));
      await disposeAsk(tester);
    });

    testWidgets('the composer clears after sending', (tester) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(const <AssistantEvent>[DoneEvent()]),
      );
      await ask(tester, 'a question');

      expect(tester.widget<EditableText>(composerField).controller.text, '');
      await disposeAsk(tester);
    });

    testWidgets('sending an empty message does nothing', (tester) async {
      final repository = ScriptedRepository(const <AssistantEvent>[DoneEvent()]);
      await pumpAsk(tester, repository: repository);

      await ask(tester, '   ');

      expect(repository.sent, isEmpty);
      await disposeAsk(tester);
    });

    testWidgets('an errored turn is not replayed to the model', (tester) async {
      final repository = ScriptedRepository(const <AssistantEvent>[
        ErrorEvent(code: 'rate_limited', message: 'The assistant is busy.'),
      ]);
      await pumpAsk(tester, repository: repository);
      await ask(tester, 'first');
      await ask(tester, 'second');

      // Replaying "The assistant is busy." as though the model had said it
      // teaches it that such a reply is in character.
      expect(
        repository.histories.last.map((h) => h.content),
        isNot(contains('The assistant is busy.')),
      );
      await disposeAsk(tester);
    });
  });

  group('errors', () {
    testWidgets('a server error renders instead of prose, with its code', (
      tester,
    ) async {
      // A half-answer followed by an error reads as a bug.
      await pumpAsk(
        tester,
        repository: ScriptedRepository(const <AssistantEvent>[
          ErrorEvent(code: 'rate_limited', message: 'The assistant is busy.'),
        ]),
      );
      await ask(tester, 'q');

      expect(find.byType(AnswerErrorBlock), findsOneWidget);
      expect(screenText(tester), contains('The assistant is busy.'));
      expect(screenText(tester), contains('rate_limited'));
      // The trough's label says what to do next.
      expect(screenText(tester), contains('Ask again, or rephrase'));
      await disposeAsk(tester);
    });

    testWidgets('a raw exception never reaches the screen', (tester) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(const <AssistantEvent>[
          ErrorEvent(
            code: 'internal',
            message: 'TypeError: Cannot read properties of undefined '
                '(reading "rows") at Object.run (/srv/app/tools.js:12:9)',
          ),
        ]),
      );
      await ask(tester, 'q');

      expect(screenText(tester), isNot(contains('/srv/app')));
      expect(screenText(tester), contains('Something went wrong on our side.'));
      await disposeAsk(tester);
    });

    testWidgets('Try again re-sends the identical question as a new turn', (
      tester,
    ) async {
      final repository = ScriptedRepository(const <AssistantEvent>[
        ErrorEvent(code: 'rate_limited', message: 'The assistant is busy.'),
      ]);
      await pumpAsk(tester, repository: repository);
      await ask(tester, 'Which outlets ran out?');

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(repository.sent, <String>[
        'Which outlets ran out?',
        'Which outlets ran out?',
      ]);
      // The failed turn stays in the transcript; the second says so.
      expect(find.byType(AnswerErrorBlock), findsNWidgets(2));
      expect(screenText(tester), contains('This has failed twice.'));
      await disposeAsk(tester);
    });

    testWidgets('a dropped connection says so, and keeps the question', (
      tester,
    ) async {
      final repo = LiveRepository();
      await pumpAsk(tester, repository: repo);
      await ask(tester, 'How did Gauteng do?', settle: false);
      repo.fail(DioException(requestOptions: RequestOptions()));
      await tester.pumpAndSettle();

      expect(screenText(tester), contains('How did Gauteng do?'));
      expect(screenText(tester), contains('Could not reach the assistant'));
      await disposeAsk(tester);
    });
  });

  group('the answer actions row', () {
    testWidgets('a settled answer can be copied and asked again', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              (call.arguments as Map<Object?, Object?>)['text']! as String,
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final repo = ScriptedRepository(tilesTurn());
      await pumpAsk(tester, repository: repo);
      await ask(tester, 'How did sell-in do?');

      final copy = find.byKey(const ValueKey<String>('answer-copy'));
      expect(copy, findsOneWidget);
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // What she pastes is what she read: the prose and the figures, in her
      // own separators.
      expect(copied.single, contains('Sell-in held steady.'));
      expect(copied.single, contains('1,284,990.5'));

      final again = find.byKey(const ValueKey<String>('answer-ask-again'));
      await tester.ensureVisible(again);
      await tester.tap(again);
      await tester.pumpAndSettle();
      expect(repo.sent, <String>['How did sell-in do?', 'How did sell-in do?']);
      await tester.pump(const Duration(seconds: 4));
      await disposeAsk(tester);
    });

    testWidgets('absent while a turn streams, and on a turn that failed', (
      tester,
    ) async {
      final repo = LiveRepository();
      await pumpAsk(tester, repository: repo);
      await ask(tester, 'How did Gauteng do?', settle: false);
      repo.emit(const TokenEvent('Gauteng is down'));
      await pumpEvent(tester);
      expect(
        find.byKey(const ValueKey<String>('answer-actions')),
        findsNothing,
      );

      repo.fail(DioException(requestOptions: RequestOptions()));
      await tester.pumpAndSettle();
      // A failed turn offers Try again inside the error block; it does not
      // offer to copy an answer that does not exist.
      expect(
        find.byKey(const ValueKey<String>('answer-actions')),
        findsNothing,
      );
      await disposeAsk(tester);
    });
  });

  group('Stop', () {
    testWidgets('keeps the partial answer and says it was stopped', (
      tester,
    ) async {
      final repo = LiveRepository();
      await pumpAsk(tester, repository: repo);
      await ask(tester, 'How did Gauteng do?', settle: false);
      repo.emit(const TokenEvent('Gauteng is down 12.4% on'));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Stop the answer'));
      await tester.pumpAndSettle();

      expect(screenText(tester), contains('Gauteng is down 12.4% on'));
      expect(find.byType(StoppedLine), findsOneWidget);
      expect(find.byType(AnswerErrorBlock), findsNothing);
      await repo.close();
      await disposeAsk(tester);
    });

    testWidgets('a stream that dies after prose is stopped, not finished', (
      tester,
    ) async {
      final repo = LiveRepository();
      await pumpAsk(tester, repository: repo);
      await ask(tester, 'How did Gauteng do?', settle: false);
      repo.emit(const TokenEvent('Gauteng is down'));
      await tester.pump();
      await repo.close();
      await tester.pumpAndSettle();

      expect(screenText(tester), contains('Gauteng is down'));
      expect(find.byType(StoppedLine), findsOneWidget);
      await disposeAsk(tester);
    });

    testWidgets('a stream that dies before any prose is an error', (
      tester,
    ) async {
      final repo = LiveRepository();
      await pumpAsk(tester, repository: repo);
      await ask(tester, 'How did Gauteng do?', settle: false);
      await repo.close();
      await tester.pumpAndSettle();

      expect(screenText(tester), contains('The assistant stopped responding.'));
      await disposeAsk(tester);
    });
  });

  group('held states', () {
    testWidgets('offline: Send is disabled, says why, and nothing is queued', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final repository = ScriptedRepository(const <AssistantEvent>[DoneEvent()]);
      await pumpAsk(tester, repository: repository, online: false);

      expect(screenText(tester), contains('No connection'));
      expect(
        find.bySemanticsLabel('Send, unavailable, needs a connection'),
        findsOneWidget,
      );
      final row = find.byKey(const ValueKey<String>('ask-suggestion-0'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repository.sent, isEmpty);
      semantics.dispose();
      await disposeAsk(tester);
    });

    testWidgets('session ended: held, with a way back in', (tester) async {
      await pumpAsk(tester, sessionEnded: true);

      expect(screenText(tester), contains('Your session ended.'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('login'), findsOneWidget);
      await disposeAsk(tester);
    });
  });

  group('the conversation', () {
    testWidgets('history appears once there is something to look back at', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(const <AssistantEvent>[
          TokenEvent('Here.'),
          DoneEvent(),
        ]),
      );
      expect(
        find.byKey(const ValueKey<String>('ask-history-chip')),
        findsNothing,
      );
      await ask(tester, 'first question');
      expect(
        find.byKey(const ValueKey<String>('ask-history-chip')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('ask-history-chip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('ask-history-0')), findsOneWidget);
      await disposeAsk(tester);
    });

    testWidgets('start over asks first, then clears the transcript', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(const <AssistantEvent>[
          TokenEvent('Here.'),
          DoneEvent(),
        ]),
      );
      await ask(tester, 'first question');
      await tester.tap(find.byKey(const ValueKey<String>('ask-history-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('ask-start-over-row')));
      await tester.pumpAndSettle();

      // A decision, not an instant wipe.
      expect(find.text('Start a new conversation?'), findsOneWidget);
      await tester.tap(find.text('Start over'));
      await tester.pumpAndSettle();

      expect(find.byType(QuestionBubble), findsNothing);
      expect(find.text('Ask about your territory.'), findsOneWidget);
      await disposeAsk(tester);
    });
  });

  group('Afrikaans', () {
    testWidgets('the nav and the composer are in the reader\'s language', (
      tester,
    ) async {
      await pumpAsk(tester, locale: const Locale('af'));

      // The pill may go icon-only as a whole when a label does not fit; the
      // labels it measured, and speaks, are the reader's.
      final pill = tester.widget<TorchNavPill>(find.byType(TorchNavPill));
      expect(
        pill.slots.map((s) => s.label),
        <String>['Vloer', 'Werk', 'Vra', 'Kieslys'],
      );
      expect(screenText(tester), contains('Vra oor jou gebied.'));
      await disposeAsk(tester);
    });
  });

  group('figures', () {
    testWidgets('take the reader\'s locale: 1 284 990,5 in Afrikaans', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        locale: const Locale('af'),
        repository: ScriptedRepository(tilesTurn()),
      );
      await ask(tester, 'Hoe lyk verkope?');

      // The old build hard-coded NumberFormat('#,##0.#', 'en_US') and printed
      // "1,284,990.5" to a reader whose convention is the opposite.
      expect(screenText(tester), contains('1\u00A0284\u00A0990,5'));
      expect(screenText(tester), isNot(contains('1,284,990.5')));
      await disposeAsk(tester);
    });

    testWidgets('and 1,284,990.5 in English', (tester) async {
      await pumpAsk(tester, repository: ScriptedRepository(tilesTurn()));
      await ask(tester, 'How is sell-in?');
      expect(screenText(tester), contains('1,284,990.5'));
      await disposeAsk(tester);
    });

    testWidgets('an unknown figure keeps its tile, as a dash and a sentence', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(tilesTurn(value: null)),
      );
      await ask(tester, 'How is sell-in?');

      expect(screenText(tester), contains('SELL-IN, UNITS'));
      expect(screenText(tester), contains('—'));
      expect(screenText(tester), contains('Nothing measured in this window'));
      expect(
        tester
            .widgetList<RichText>(find.byType(RichText))
            .any((t) => t.text.toPlainText().trim() == '0'),
        isFalse,
        reason: 'an unknown is never drawn as a zero',
      );
      await disposeAsk(tester);
    });

    testWidgets('a measured zero is a zero', (tester) async {
      await pumpAsk(tester, repository: ScriptedRepository(tilesTurn(value: 0)));
      await ask(tester, 'How is sell-in?');
      expect(screenText(tester), isNot(contains('Nothing measured')));
      expect(
        tester
            .widgetList<RichText>(find.byType(RichText))
            .any((t) => t.text.toPlainText().trim() == '0'),
        isTrue,
      );
      await disposeAsk(tester);
    });
  });

  group('2.0× text', () {
    testWidgets('the first run and a landed answer lay out without overflow', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        textScale: 2.0,
        repository: ScriptedRepository(rankedTurn()),
      );
      expect(tester.takeException(), isNull);
      await ask(tester, 'Which outlets ran out?');
      expect(tester.takeException(), isNull);
      await disposeAsk(tester);
    });

    testWidgets('and in Afrikaans', (tester) async {
      await pumpAsk(
        tester,
        textScale: 2.0,
        locale: const Locale('af'),
        repository: ScriptedRepository(tilesTurn()),
      );
      expect(tester.takeException(), isNull);
      await ask(tester, 'Hoe lyk verkope?');
      expect(tester.takeException(), isNull);
      await disposeAsk(tester);
    });
  });
}
