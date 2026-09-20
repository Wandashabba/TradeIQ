// THE ROUTE AS ASSISTIVE TECH SEES IT.
//
// Every assertion here reads the **semantics tree**, never the widget tree.
// That is the whole point of the file. `chat_screen_test.dart` already proves
// each of these capabilities exists — it taps the widget, or sends the gesture
// straight to the `GestureDetector` — and every one of them passed while the
// control was unreachable to TalkBack and VoiceOver, because
// `Semantics(button: true, …, excludeSemantics: true)` around a pressable
// drops the descendant's node and declares a button with no action on it.
//
// A test that reaches a control the way a finger does cannot see that. A test
// that reaches it the way a screen reader does is the law itself.
import 'dart:ui' show SemanticsActionEvent, Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/assistant/answer/ask_turn.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';

import 'ask_harness.dart';

/// The one node whose label is exactly [label], read from the semantics tree.
SemanticsData nodeLabelled(WidgetTester tester, String label) {
  final matches = semanticsNodes(
    tester,
  ).map((n) => n.getSemanticsData()).where((d) => d.label == label).toList();
  expect(
    matches,
    hasLength(1),
    reason:
        'No semantics node labelled "$label". A control that is not in this '
        'tree does not exist to a screen reader, however well it taps.\n\n'
        '${semanticsDump(tester)}',
  );
  return matches.single;
}

/// The node id for [label], so the test can fire the action the platform fires.
int nodeIdLabelled(WidgetTester tester, String label) => semanticsNodes(
  tester,
).firstWhere((n) => n.getSemanticsData().label == label).id;

/// Perform a semantics action exactly as the platform does — through the
/// binding, not by calling the widget's callback.
Future<void> activate(
  WidgetTester tester,
  String label, {
  SemanticsAction action = SemanticsAction.tap,
}) async {
  tester.binding.performSemanticsAction(
    SemanticsActionEvent(
      type: action,
      nodeId: nodeIdLabelled(tester, label),
      viewId: tester.view.viewId,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('every button on the route can be activated', () {
    testWidgets('first run, and after an answer has landed', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAsk(tester, repository: ScriptedRepository(rankedTurn()));

      // The first-run board, the nav, the composer's keys.
      expectEveryButtonActivatable(tester);

      await ask(tester, 'Which outlets ran out?');

      // ...and the landed turn: Copy, Ask again, the steps expander.
      expectEveryButtonActivatable(tester);

      handle.dispose();
      await disposeAsk(tester);
    });

    testWidgets('while an answer is streaming: Stop is real', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = LiveRepository();
      await pumpAsk(tester, repository: repo);
      await ask(tester, 'How did Gauteng do?', settle: false);
      repo.emit(const TokenEvent('Working on it.'));
      await pumpEvent(tester);

      expectEveryButtonActivatable(tester);
      final stop = nodeLabelled(tester, 'Stop the answer');
      expect(
        stop.hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'Stop is the only escape from a running answer.',
      );

      await repo.close();
      handle.dispose();
      await disposeAsk(tester);
    });
  });

  group('the composer', () {
    testWidgets('Send announces, and activating it actually sends', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = ScriptedRepository(tilesTurn());
      await pumpAsk(tester, repository: repo);

      // Nothing typed: a button that says why it is disabled, and is.
      final idle = nodeLabelled(tester, 'Send, unavailable, nothing typed yet');
      expect(idle.flagsCollection.isEnabled, Tristate.isFalse);

      await tester.enterText(composerField, 'Which outlets ran out?');
      await tester.pump();

      final send = nodeLabelled(tester, 'Send this question');
      expect(send.flagsCollection.isButton, isTrue);
      expect(
        send.hasAction(SemanticsAction.tap),
        isTrue,
        reason:
            'The route has one primary action. Announced as a button with no '
            'tap action, it is a label: double-tap and nothing happens.',
      );

      // Fire it the way the platform does, not by calling onPressed.
      await activate(tester, 'Send this question');
      expect(repo.sent, <String>['Which outlets ran out?']);

      handle.dispose();
      await disposeAsk(tester);
    });
  });

  group('the held band', () {
    testWidgets('sessionEnded: the way out is in the tree, and it fires', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAsk(tester, sessionEnded: true);

      // The composer is disabled in this phase, so the band's action is the
      // ONLY exit. Swallowed by an excluded subtree it had no node at all:
      // nothing to focus, nothing to fire, and a manager whose token expired
      // mid-session was stuck on the screen.
      final signIn = nodeLabelled(tester, 'Sign in');
      expect(signIn.flagsCollection.isButton, isTrue);
      expect(signIn.hasAction(SemanticsAction.tap), isTrue);

      // The sentence still arrives as a live region, in its own node.
      final band = semanticsNodes(tester)
          .map((n) => n.getSemanticsData())
          .where((d) => d.label.startsWith('Your session ended.'))
          .toList();
      expect(band, hasLength(1));
      expect(band.single.flagsCollection.isLiveRegion, isTrue);

      await activate(tester, 'Sign in');
      expect(find.text('login'), findsOneWidget);

      handle.dispose();
      await disposeAsk(tester);
    });
  });

  group('a long question', () {
    const question =
        'Which outlets in Soweto ran out of the 500ml line last week, '
        'and how does that compare with the same week last month, and '
        'which agents visited them, and what did they report about the '
        'shelf, and was there a promotion running at the time? '
        'Which outlets in Soweto ran out of the 500ml line last week, '
        'and how does that compare with the same week last month, and '
        'which agents visited them, and what did they report about the '
        'shelf, and was there a promotion running at the time? ';

    testWidgets('the expander and the hold-to-copy both exist to a reader', (
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

      final handle = tester.ensureSemantics();
      await pumpAsk(tester, repository: ScriptedRepository(tilesTurn()));
      await ask(tester, question);

      // The question is clamped at six lines, so the expander is the only way
      // to read the rest of it. It has to be a node, not just a widget.
      expect(find.byType(QuestionBubble), findsOneWidget);
      final expander = nodeLabelled(tester, 'Show the full question');
      expect(expander.hasAction(SemanticsAction.tap), isTrue);

      // Hold-to-copy, as an ACTION on the bubble's own node.
      final bubble = semanticsNodes(tester)
          .map((n) => n.getSemanticsData())
          .where((d) => d.label.startsWith('Your question.'))
          .toList();
      expect(bubble, hasLength(1));
      expect(
        bubble.single.hasAction(SemanticsAction.longPress),
        isTrue,
        reason:
            'The bubble copies on hold. Inside an excluded subtree the gesture '
            'existed and the ACTION did not.',
      );

      await activate(
        tester,
        bubble.single.label,
        action: SemanticsAction.longPress,
      );
      expect(copied, hasLength(1));
      expect(copied.single, question.trim());
      // Let the copy toast's dwell timer run out inside the test body.
      await tester.pump(const Duration(seconds: 4));

      await activate(tester, 'Show the full question');
      expect(
        find.text('Show the full question'),
        findsNothing,
        reason: 'Activating the expander through semantics unclamps it.',
      );

      handle.dispose();
      await disposeAsk(tester);
    });
  });
}
