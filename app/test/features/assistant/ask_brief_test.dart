import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/assistant/answer/ask_turn.dart';
import 'package:tradeiq_app/features/assistant/answer/working_steps.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';

import 'ask_harness.dart';

/// THE BRIEF.
///
/// > *"Let's redesign the output of the Ask chat, it doesn't look appetising
/// > nor nice. it is very basic"* — the owner, 6 October 2026, then choosing
/// > **H** from G, H and I.
///
/// On a desk a settled turn is a dated one-page document: an eyebrow naming
/// the scope and a mono stamp, the question muted beneath them, the one figure
/// the turn already carries set at hero size, the panel, the rest of the prose
/// under WHAT THIS MEANS, and a footer with the steps on the left and the
/// follow-ups on the right. The phone's transcript is untouched.
///
/// Every figure in the fixtures is the live assistant's own reply from that
/// morning — 400 outlets across 13 territories — and the tests pin two things
/// above all: that the brief never invents a figure (a turn with none leads
/// with its sentence), and that a figure lifted into the hero is not drawn a
/// second time in the panel.
void main() {
  const phone = Size(360, 640);
  const desk = Size(1440, 900);

  /// The owner's browser window: a maximised Chrome on a laptop. The brief
  /// must land here, because F's first version did not and was reported as
  /// "not changed at all".
  const laptop = Size(1190, 760);

  /// Below `askSplitMinWidth` (837).
  const narrow = Size(800, 900);

  const briefKey = ValueKey<String>('ask-brief');
  const headerKey = ValueKey<String>('brief-header');
  const heroKey = ValueKey<String>('brief-hero');

  group('the phone keeps its transcript', () {
    testWidgets('bubble, prose, panel, steps at 360x640 — and no brief', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(rankedTurn()),
        size: phone,
      );
      await ask(tester, 'Which outlets ran out?');

      expect(find.byType(QuestionBubble), findsOneWidget);
      expect(find.byKey(headerKey), findsNothing);
      expect(find.byKey(briefKey), findsNothing);

      final panel = tester.getRect(
        find.byKey(const ValueKey<String>('instrument-panel')),
      );
      final steps = tester.getRect(find.byType(StepsSummaryRow).first);
      expect(
        steps.top,
        lessThan(panel.top),
        reason:
            'the phone order is unchanged: the steps row is above the panel',
      );
      await disposeAsk(tester);
    });
  });

  group('a desk sets the turn as a brief', () {
    testWidgets(
      'the question becomes the masthead: an eyebrow with the scope, a '
      'dated stamp, and the question muted beneath — no bubble',
      (tester) async {
        await pumpAsk(
          tester,
          repository: ScriptedRepository(briefTurn()),
          size: desk,
          clock: StepClock(),
        );
        await ask(tester, 'How many outlets do we have?');

        expect(find.byType(QuestionBubble), findsNothing);
        expect(find.byKey(headerKey), findsOneWidget);
        expect(find.text('ANSWER · ALL TERRITORIES'), findsOneWidget);
        // StepClock's default is 1 September 2026, 09:00 UTC.
        expect(find.text('1 Sep 2026 · 09:00'), findsOneWidget);
        expect(find.text('How many outlets do we have?'), findsOneWidget);

        // The masthead and the body share one left edge: it is one document.
        final header = tester.getRect(find.byKey(headerKey));
        final brief = tester.getRect(find.byKey(briefKey));
        expect(brief.left, header.left);
        expect(brief.width, lessThanOrEqualTo(760));
        expect(tester.takeException(), isNull);
        await disposeAsk(tester);
      },
    );

    testWidgets(
      "the model's own bold figure leads — 400 / outlets / the rest of the "
      'sentence — and the prose follows under WHAT THIS MEANS',
      (tester) async {
        await pumpAsk(
          tester,
          repository: ScriptedRepository(briefTurn()),
          size: desk,
        );
        await ask(tester, 'How many outlets do we have?');

        expect(find.byKey(heroKey), findsOneWidget);
        expect(find.text('400'), findsOneWidget);
        expect(find.text('outlets'), findsOneWidget);
        expect(
          find.text('across 13 territories in South Africa'),
          findsOneWidget,
          reason:
              'the lead-in "We have" is dropped; the remainder is the '
              'subline, without its full stop',
        );
        expect(find.text('WHAT THIS MEANS'), findsOneWidget);

        final hero = tester.getRect(find.byKey(heroKey));
        final meaning = tester.getRect(find.text('WHAT THIS MEANS'));
        expect(meaning.top, greaterThan(hero.bottom));
        expect(tester.takeException(), isNull);
        await disposeAsk(tester);
      },
    );

    testWidgets(
      'the footer: what ran on the left, what to ask next on the right',
      (tester) async {
        await pumpAsk(
          tester,
          repository: ScriptedRepository(briefTurn()),
          size: desk,
        );
        await ask(tester, 'How many outlets do we have?');

        final steps = tester.getRect(find.byType(StepsSummaryRow).first);
        final chip = tester.getRect(
          find.byKey(const ValueKey<String>('follow-up-By territory')),
        );
        final prose = tester.getRect(
          find.textContaining('Seven in ten of your stores'),
        );
        expect(
          steps.top,
          greaterThan(prose.bottom),
          reason: 'the footer is last',
        );
        expect(
          chip.left,
          greaterThan(steps.left + steps.width / 2),
          reason: 'the follow-ups sit opposite the steps, not under them',
        );
        expect(tester.takeException(), isNull);
        await disposeAsk(tester);
      },
    );

    testWidgets(
      'a turn with no figure to lift leads with its sentence — nothing is '
      'invented — and the panel follows it',
      (tester) async {
        await pumpAsk(
          tester,
          repository: ScriptedRepository(rankedTurn()),
          size: desk,
        );
        await ask(tester, 'Which outlets ran out?');

        expect(find.byKey(heroKey), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('brief-headline')),
          findsOneWidget,
        );
        expect(
          find.text('WHAT THIS MEANS'),
          findsNothing,
          reason: 'a headline-only answer has nothing after it to label',
        );

        final headline = tester.getRect(
          find.byKey(const ValueKey<String>('brief-headline')),
        );
        final panel = tester.getRect(
          find.byKey(const ValueKey<String>('instrument-panel')),
        );
        final steps = tester.getRect(find.byType(StepsSummaryRow).first);
        expect(panel.top, greaterThan(headline.bottom));
        expect(steps.top, greaterThan(panel.bottom));
        expect(tester.takeException(), isNull);
        await disposeAsk(tester);
      },
    );

    testWidgets(
      'one bare tile is the hero, said under the headline, and the panel '
      'does not draw it a second time',
      (tester) async {
        await pumpAsk(
          tester,
          repository: ScriptedRepository(tilesTurn()),
          size: desk,
        );
        await ask(tester, 'How is sell-in?');

        expect(find.byKey(heroKey), findsOneWidget);
        expect(find.text('Sell-in, units'), findsOneWidget);
        expect(find.text('Sell-in held steady'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('instrument-panel')),
          findsNothing,
          reason: 'the one tile became the hero; an empty panel is dropped',
        );
        expect(tester.takeException(), isNull);
        await disposeAsk(tester);
      },
    );

    testWidgets("the owner's 1190-wide laptop window gets the brief", (
      tester,
    ) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(briefTurn()),
        size: laptop,
      );
      await ask(tester, 'How many outlets do we have?');

      expect(find.byKey(briefKey), findsOneWidget);
      expect(find.byKey(heroKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeAsk(tester);
    });

    testWidgets('below the measure the transcript stays a transcript', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(briefTurn()),
        size: narrow,
      );
      await ask(tester, 'How many outlets do we have?');

      expect(find.byType(QuestionBubble), findsOneWidget);
      expect(find.byKey(briefKey), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeAsk(tester);
    });
  });
}

/// The live assistant's reply of 6 October 2026, as the model wrote it: one
/// bold figure at the head of one short sentence, a paragraph, two follow-ups.
List<AssistantEvent> briefTurn() => <AssistantEvent>[
  const ToolStartEvent(name: 'findTerritories', pillar: 'context'),
  const ToolEndEvent(name: 'findTerritories', ok: true),
  TokenEvent(
    'We have **400 outlets** across 13 territories in South Africa.\n\n'
    'Seven in ten of your stores are inland, and the largest territories by '
    'store count are Gauteng, KwaZulu-Natal and Western Cape.\n\n'
    '```followups\nBy territory\nUnvisited this week\n```',
  ),
  const DoneEvent(),
];
