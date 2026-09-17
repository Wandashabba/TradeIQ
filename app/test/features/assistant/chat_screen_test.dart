import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_repository.dart';
import 'package:tradeiq_app/features/assistant/presentation/chat_screen.dart';
import 'package:tradeiq_app/features/assistant/view_specs/agent_scorecard_card.dart';

import '../../helpers/routed_app.dart';

class StubRepository implements AssistantRepository {
  StubRepository(this.script);

  final List<AssistantEvent> script;
  final List<String> sent = [];

  @override
  Stream<AssistantEvent> chat({
    required String message,
    List<ChatHistoryEntry> history = const [],
    String? conversationId,
    CancelToken? cancelToken,
  }) async* {
    sent.add(message);
    for (final event in script) {
      yield event;
    }
  }
}

Future<void> pumpChat(
  WidgetTester tester,
  StubRepository repository, {
  ThemeData? theme,
}) async {
  // Wide enough for ManagerScaffold's sidebar layout, and tall enough that the
  // composer and the transcript both fit without an overflow.
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(routedApp(
    const AssistantChatScreen(),
    theme: theme ?? AppTheme.dark(),
    overrides: [assistantRepositoryProvider.overrideWithValue(repository)],
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the empty state says what it can and cannot do', (tester) async {
    // An assistant that silently declines the first thing you ask teaches you
    // not to ask again. Phase 0 is read-only, and it says so up front.
    await pumpChat(tester, StubRepository([]));

    expect(find.textContaining('sales, stock, visibility or competition'),
        findsOneWidget);
    expect(find.textContaining('cannot change anything yet'), findsOneWidget);
  });

  testWidgets('a suggestion chip sends its question', (tester) async {
    // A blank chat box is the hardest possible first move.
    final repository = StubRepository([
      const TokenEvent('Here you go.'),
      const DoneEvent(),
    ]);
    await pumpChat(tester, repository);

    await tester.tap(find.textContaining('Which outlets keep running out'));
    await tester.pumpAndSettle();

    expect(repository.sent.single, 'Which outlets keep running out of stock?');
  });

  testWidgets('typing and sending renders both turns', (tester) async {
    final repository = StubRepository([
      const TokenEvent('Tumo is up 6 points.'),
      const DoneEvent(),
    ]);
    await pumpChat(tester, repository);

    await tester.enterText(find.byType(TextField), 'How is Tumo doing?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('How is Tumo doing?'), findsOneWidget);
    expect(find.text('Tumo is up 6 points.'), findsOneWidget);
  });

  testWidgets('a tool shows as a plain-English step, not its function name',
      (tester) async {
    // `getShareOfShelf` is our vocabulary; "Share of shelf" is the manager's.
    final repository = StubRepository([
      const ToolStartEvent(name: 'getShareOfShelf', pillar: 'visibility'),
      const ToolEndEvent(name: 'getShareOfShelf', ok: true),
      const TokenEvent('You hold 34%.'),
      const DoneEvent(),
    ]);
    await pumpChat(tester, repository);

    await tester.enterText(find.byType(TextField), 'share of shelf?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('Share of shelf'), findsOneWidget);
    expect(find.textContaining('getShareOfShelf'), findsNothing);
  });

  testWidgets('a tool this build does not know falls back to its pillar',
      (tester) async {
    final repository = StubRepository([
      const ToolStartEvent(name: 'getShelfHologram', pillar: 'visibility'),
      const ToolEndEvent(name: 'getShelfHologram', ok: true),
      const TokenEvent('Done.'),
      const DoneEvent(),
    ]);
    await pumpChat(tester, repository);

    await tester.enterText(find.byType(TextField), 'q');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('Checking visibility'), findsOneWidget);
    expect(find.textContaining('getShelfHologram'), findsNothing);
  });

  testWidgets('the exit demo: narrative plus the real scorecard widget',
      (tester) async {
    final repository = StubRepository([
      const ToolStartEvent(name: 'getAgentScorecard', pillar: 'execution'),
      const ToolEndEvent(name: 'getAgentScorecard', ok: true),
      const ArtifactEvent(
        id: 'getAgentScorecard-0',
        type: 'agent_scorecard',
        params: {'agentId': 'a1'},
        data: {
          'agentName': 'tumo@example.com',
          'averageScore': 82.0,
          'teamAverageScore': 71.0,
          'deltaVsTeam': 11.0,
          'visits': 14,
          'outletsVisited': 9,
          'scoredVisits': 12,
        },
      ),
      const TokenEvent('Tumo is 11 points ahead of the team this month.'),
      const DoneEvent(),
    ]);
    await pumpChat(tester, repository);

    await tester.enterText(
        find.byType(TextField), 'How has Tumo been performing this month?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('Tumo is 11 points ahead of the team this month.'),
        findsOneWidget);
    expect(find.byType(AgentScorecardCard), findsOneWidget);
    expect(find.text('82.0'), findsOneWidget);
  });

  testWidgets('a server error renders instead of prose', (tester) async {
    // A half-answer followed by an error reads as a bug.
    final repository = StubRepository([
      const ErrorEvent(code: 'rate_limited', message: 'The assistant is busy.'),
    ]);
    await pumpChat(tester, repository);

    await tester.enterText(find.byType(TextField), 'q');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('The assistant is busy.'), findsOneWidget);
  });

  testWidgets('an unknown artifact type does not blank the answer',
      (tester) async {
    final repository = StubRepository([
      const ArtifactEvent(id: 'a1', type: 'hologram', params: {}, data: {}),
      const TokenEvent('Availability is 91%.'),
      const DoneEvent(),
    ]);
    await pumpChat(tester, repository);

    await tester.enterText(find.byType(TextField), 'q');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The narrative still carries the answer.
    expect(find.text('Availability is 91%.'), findsOneWidget);
  });

  testWidgets('the composer clears after sending', (tester) async {
    final repository = StubRepository([const DoneEvent()]);
    await pumpChat(tester, repository);

    await tester.enterText(find.byType(TextField), 'a question');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty);
  });

  testWidgets('sending an empty message does nothing', (tester) async {
    final repository = StubRepository([const DoneEvent()]);
    await pumpChat(tester, repository);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(repository.sent, isEmpty);
  });

  group('Lumen Glass (light)', () {
    GlassPane paneAround(WidgetTester tester, Finder finder) =>
        tester.widget<GlassPane>(
          find.ancestor(of: finder, matching: find.byType(GlassPane)).first,
        );

    Future<void> ask(WidgetTester tester, String question) async {
      await tester.enterText(find.byType(TextField), question);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
    }

    testWidgets('the suggestions are glass pills, and still send',
        (tester) async {
      final repository = StubRepository([
        const TokenEvent('Here you go.'),
        const DoneEvent(),
      ]);
      await pumpChat(tester, repository, theme: AppTheme.light());

      final chip = find.textContaining('Which outlets keep running out');
      expect(paneAround(tester, chip).kind, GlassKind.pill);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(repository.sent.single, 'Which outlets keep running out of stock?');
    });

    testWidgets("the manager's turn is action glass; the answer is a tile",
        (tester) async {
      await pumpChat(
        tester,
        StubRepository([
          const TokenEvent('Tumo is up 6 points.'),
          const DoneEvent(),
        ]),
        theme: AppTheme.light(),
      );
      await ask(tester, 'How is Tumo doing?');

      final question = find.text('How is Tumo doing?');
      expect(paneAround(tester, question).kind, GlassKind.action);
      // Words on the action glass wear the action's own ink.
      expect(tester.widget<Text>(question).style!.color,
          LumenPalette.light.actionInk);

      final answer = paneAround(tester, find.text('Tumo is up 6 points.'));
      expect(answer.kind, GlassKind.tile);
      // A transcript row repeats, so it never pays for a blur.
      expect(answer.blur, isFalse);
    });

    testWidgets('the composer is a glass bar holding the send action',
        (tester) async {
      await pumpChat(tester, StubRepository([]), theme: AppTheme.light());

      final bar = find
          .ancestor(of: find.byType(TextField), matching: find.byType(GlassPane))
          .first;
      expect(tester.widget<GlassPane>(bar).kind, GlassKind.bar);
      expect(
        find.descendant(of: bar, matching: find.byTooltip('Send')),
        findsOneWidget,
      );
    });

    testWidgets('an artifact lands below its bubble, not inside it',
        (tester) async {
      await pumpChat(
        tester,
        StubRepository([
          const ArtifactEvent(
            id: 'getAgentScorecard-0',
            type: 'agent_scorecard',
            params: {'agentId': 'a1'},
            data: {'agentName': 'tumo@example.com', 'averageScore': 82.0},
          ),
          const TokenEvent('Tumo is ahead.'),
          const DoneEvent(),
        ]),
        theme: AppTheme.light(),
      );
      await ask(tester, 'How is Tumo?');

      expect(tester.takeException(), isNull);
      expect(find.text('82.0'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(AgentScorecardCard),
          matching: find.byWidgetPredicate(
            (w) => w is GlassPane && w.kind == GlassKind.tile,
          ),
        ),
        findsNothing,
      );
    });
  });

  testWidgets('dark: the transcript and composer are the same glass, at night',
      (tester) async {
    await pumpChat(
      tester,
      StubRepository([
        const TokenEvent('Tumo is up 6 points.'),
        const DoneEvent(),
      ]),
    );
    await tester.enterText(find.byType(TextField), 'How is Tumo doing?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    GlassPane paneAround(Finder finder) => tester.widget<GlassPane>(
          find.ancestor(of: finder, matching: find.byType(GlassPane)).first,
        );

    final question = find.text('How is Tumo doing?');
    expect(paneAround(question).kind, GlassKind.action);
    // The night action is a bright pane, so its words are the dark action ink.
    expect(tester.widget<Text>(question).style!.color,
        LumenPalette.dark.actionInk);

    final answer = paneAround(find.text('Tumo is up 6 points.'));
    expect(answer.kind, GlassKind.tile);
    expect(answer.blur, isFalse);

    expect(paneAround(find.byType(TextField)).kind, GlassKind.bar);
  });
}
