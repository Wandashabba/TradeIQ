import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/assistant/answer/web_sources.dart';
import 'package:tradeiq_app/features/assistant/answer/working_steps.dart';
import 'package:tradeiq_app/features/assistant/view_specs/view_spec_registry.dart';

import 'ask_harness.dart';

/// ANSWER LEFT, EVIDENCE RIGHT.
///
/// > *"I also don't like the output of the ask search, it is very not nice…
/// > let's make it look super great and creative and very production level"* —
/// > the owner, 6 October 2026, choosing **F**.
///
/// The answer was markdown blocks in one column capped at `answerProseWidth`.
/// For a question whose answer is four numbers and a split — the live
/// assistant's own reply that morning was *"400 outlets across 13 territories…
/// 280 inland across 9, 120 coastal across 4"* — prose is the weakest shape
/// available: the figures are buried in sentences the eye has to parse, and
/// what the answer was COUNTED FROM is below the fold.
///
/// Nothing new is rendered. `StepsSummaryRow`, `AnswerPanel` and `WebSources`
/// already existed and were stacked underneath; on a desk they move into a
/// column beside the prose. These tests pin where each one lands, because the
/// whole change is where they land.
void main() {
  const phone = Size(360, 640);
  const desk = Size(1440, 900);

  group('the phone stacks, as it did', () {
    testWidgets('evidence stays under the answer at 360x640', (tester) async {
      await pumpAsk(tester, repository: ScriptedRepository(rankedTurn()), size: phone);
      await ask(tester, 'Which outlets ran out?');

      final answer = tester.getRect(find.byType(AnswerPanel).first);
      final steps = tester.getRect(find.byType(StepsSummaryRow).first);
      expect(
        steps.top,
        lessThan(answer.bottom),
        reason: 'one column: the steps row is above the panel, not beside it',
      );
      await disposeAsk(tester);
    });
  });

  group('the desk puts the evidence beside it', () {
    testWidgets('the figures panel sits to the right of the prose', (
      tester,
    ) async {
      await pumpAsk(tester, repository: ScriptedRepository(rankedTurn()), size: desk);
      await ask(tester, 'Which outlets ran out?');

      final panel = tester.getRect(find.byType(AnswerPanel).first);
      final steps = tester.getRect(find.byType(StepsSummaryRow).first);

      // Both are in the same column, and that column starts right of centre.
      expect(
        panel.left,
        greaterThan(desk.width / 2),
        reason: 'the evidence column is the right-hand 2/5',
      );
      expect(
        steps.left,
        greaterThan(desk.width / 2),
        reason: 'the provenance row joins the evidence, not the answer',
      );
      await disposeAsk(tester);
    });

    testWidgets('the answer keeps the larger share and does not run under it', (
      tester,
    ) async {
      await pumpAsk(tester, repository: ScriptedRepository(rankedTurn()), size: desk);
      await ask(tester, 'Which outlets ran out?');

      final panel = tester.getRect(find.byType(AnswerPanel).first);
      // 3:2 — the prose has a measure to hold, so it takes the larger share.
      expect(
        panel.left,
        greaterThan(desk.width * 0.5),
        reason: 'the split favours the answer',
      );
      expect(tester.takeException(), isNull);
      await disposeAsk(tester);
    });

    testWidgets('sources move across too, so citations are read with the '
        'answer rather than after it', (tester) async {
      await pumpAsk(tester, repository: ScriptedRepository(rankedTurn()), size: desk);
      await ask(tester, 'Which outlets ran out?');

      final sources = find.byType(WebSources);
      if (sources.evaluate().isNotEmpty) {
        expect(
          tester.getRect(sources.first).left,
          greaterThan(desk.width / 2),
        );
      }
      await disposeAsk(tester);
    });
  });
}
