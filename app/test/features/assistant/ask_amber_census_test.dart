import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/assistant/answer/ask_phase.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';

import '../../core/design/amber_golden.dart';
import 'ask_harness.dart';

/// THE AMBER CENSUS FOR ASK TRADEIQ — every phase × every skin, counted from
/// pixels.
///
/// `TorchScope` asserts what the route *claims*. This counts what got
/// *painted*, which is the failure a claim cannot see: a card that lit itself
/// without asking, a bloom where no object was declared, three answers each
/// reading one grant as their own.
///
/// | phase | Night | Day | Veld |
/// |---|---|---|---|
/// | first run | 1 | 0 | 0 |
/// | thinking | 2 | 0 | 0 |
/// | writing | 1 | 0 | 0 |
/// | landed, a ranking with a server focus | 2 | 0 | 0 |
/// | landed, a trend and no ranking | 2 | 0 | 0 |
/// | landed, tiles only | 1 | 0 | 0 |
/// | typing a follow-up (keyboard up) | 1 | 1 | 1 |
/// | error, offline, session ended | 1 | 0 | 0 |
///
/// Night's 1 is the nav's active tab; Day and Veld paint the tab as an ink
/// block, so their only amber is Send's block — and only while it is armed.
void main() {
  AskPhase phaseOf(WidgetTester tester) {
    final scope = tester.widget<TorchScope>(find.byType(TorchScope).first);
    return AskPhase.values.byName(scope.phase);
  }

  Future<void> expectCount(
    WidgetTester tester,
    TiqSkin skin, {
    required AskPhase phase,
    required int night,
    required int light,
  }) async {
    expect(phaseOf(tester), phase);
    final census = await amberCensus(tester);
    expectWithinAmberBudget(
      census,
      skin,
      route: 'ask',
      phase: phase.name,
    );
    expect(
      census.objectCount,
      skin.amberIsInk ? light : night,
      reason: '${skin.mode.name} × ${phase.name}\n${census.describe()}',
    );
  }

  for (final skin in askSkins) {
    group(skin.mode.name, () {
      testWidgets('first run: Send is disabled, so nothing is armed', (
        tester,
      ) async {
        await pumpAsk(tester, skin: skin);
        await expectCount(
          tester,
          skin,
          phase: AskPhase.firstRun,
          night: 1,
          light: 0,
        );
        await disposeAsk(tester);
      });

      testWidgets('thinking: the running step is the one live pulse', (
        tester,
      ) async {
        final repo = LiveRepository();
        await pumpAsk(
          tester,
          skin: skin,
          repository: repo,
          // The pulse is a word under reduce-motion. Counting the light
          // needs the light, so motion is on and the frames are fixed.
          disableAnimations: false,
          settle: false,
        );
        await ask(tester, 'Which outlets ran out?', settle: false);
        repo.emit(const ToolStartEvent(name: stockTool, pillar: 'stock'));
        await pumpFrames(tester);

        await expectCount(
          tester,
          skin,
          phase: AskPhase.thinking,
          night: 2,
          light: 0,
        );

        repo.emit(const ToolEndEvent(name: stockTool, ok: true));
        repo.emit(const DoneEvent());
        await repo.close();
        await pumpFrames(tester);
        await disposeAsk(tester);
      });

      testWidgets('writing: the amber goes out when the last tool ends', (
        tester,
      ) async {
        final repo = LiveRepository();
        await pumpAsk(
          tester,
          skin: skin,
          repository: repo,
          disableAnimations: false,
          settle: false,
        );
        await ask(tester, 'Which outlets ran out?', settle: false);
        repo.emit(const ToolStartEvent(name: stockTool, pillar: 'stock'));
        repo.emit(const ToolEndEvent(name: stockTool, ok: true));
        await pumpFrames(tester);

        await expectCount(
          tester,
          skin,
          phase: AskPhase.writing,
          night: 1,
          light: 0,
        );

        repo.emit(const DoneEvent());
        await repo.close();
        await pumpFrames(tester);
        await disposeAsk(tester);
      });

      testWidgets('landed with a ranking: the server-named bar is lit', (
        tester,
      ) async {
        await pumpAsk(
          tester,
          skin: skin,
          repository: ScriptedRepository(rankedTurn()),
        );
        await ask(tester, 'Which outlets ran out?');
        expect(
          find.byKey(const ValueKey<String>('ranked-bars-focus')),
          findsOneWidget,
        );
        await expectCount(
          tester,
          skin,
          phase: AskPhase.landedFocus,
          night: 2,
          light: 0,
        );
        await disposeAsk(tester);
      });

      testWidgets('landed with a trend and no ranking: the series is lit', (
        tester,
      ) async {
        await pumpAsk(
          tester,
          skin: skin,
          repository: ScriptedRepository(chartTurn()),
        );
        await ask(tester, 'How is availability trending?');
        await expectCount(
          tester,
          skin,
          phase: AskPhase.landedFocus,
          night: 2,
          light: 0,
        );
        await disposeAsk(tester);
      });

      testWidgets('landed with tiles only: nothing is lit', (tester) async {
        await pumpAsk(
          tester,
          skin: skin,
          repository: ScriptedRepository(tilesTurn()),
        );
        await ask(tester, 'How is sell-in?');
        await expectCount(
          tester,
          skin,
          phase: AskPhase.landed,
          night: 1,
          light: 0,
        );
        await disposeAsk(tester);
      });

      testWidgets('typing a follow-up: the bar hands off to Send', (
        tester,
      ) async {
        await pumpAsk(
          tester,
          skin: skin,
          repository: ScriptedRepository(rankedTurn()),
          // The keyboard is up: the nav goes, and its grant with it.
          keyboard: 280,
        );
        await ask(tester, 'Which outlets ran out?');
        await tester.enterText(composerField, 'and last month?');
        await tester.pumpAndSettle();

        await expectCount(
          tester,
          skin,
          phase: AskPhase.typing,
          night: 1,
          light: 1,
        );
        await disposeAsk(tester);
      });

      testWidgets('an error is never amber', (tester) async {
        await pumpAsk(
          tester,
          skin: skin,
          repository: ScriptedRepository(const <AssistantEvent>[
            ErrorEvent(code: 'rate_limited', message: 'The assistant is busy.'),
          ]),
        );
        await ask(tester, 'Which outlets ran out?');
        await expectCount(
          tester,
          skin,
          phase: AskPhase.errored,
          night: 1,
          light: 0,
        );
        await disposeAsk(tester);
      });

      testWidgets('offline is held, and Send is not armed', (tester) async {
        await pumpAsk(tester, skin: skin, online: false);
        await expectCount(
          tester,
          skin,
          phase: AskPhase.offline,
          night: 1,
          light: 0,
        );
        await disposeAsk(tester);
      });

      testWidgets('a session that ended is held, not failed', (tester) async {
        await pumpAsk(tester, skin: skin, sessionEnded: true);
        await expectCount(
          tester,
          skin,
          phase: AskPhase.sessionEnded,
          night: 1,
          light: 0,
        );
        await disposeAsk(tester);
      });
    });
  }

  group('one grant, one object', () {
    testWidgets(
      'two landed rankings light one bar: the latest answer holds the light',
      (tester) async {
        final skin = TiqSkin.night(density: TiqDensity.console);
        await pumpAsk(
          tester,
          skin: skin,
          size: const Size(360, 1400),
          repository: ScriptedRepository(
            rankedTurn(text: 'Short.'),
          ),
        );
        await ask(tester, 'Which outlets ran out?');
        await ask(tester, 'And the week before?');

        expect(
          find.byKey(const ValueKey<String>('ranked-bars-focus')),
          findsNWidgets(2),
          reason: 'Both answers keep their focus bar — marker and weight.',
        );
        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          2,
          reason:
              'The nav tab and ONE bar. The earlier answer\'s light went out '
              'when the next question was asked.\n${census.describe()}',
        );
        await disposeAsk(tester);
      },
    );

    testWidgets('tiles, a ranking and a chart in one panel: one bar is lit', (
      tester,
    ) async {
      // The ranking takes the light; the chart's series stays ink, because
      // the ledger lights a trend only when the answer has no ranking.
      final ranked = rankedTurn();
      final tiles = tilesTurn();
      final chart = chartTurn();
      await pumpAsk(
        tester,
        size: const Size(360, 1600),
        repository: ScriptedRepository(<AssistantEvent>[
          ...tiles.sublist(0, 3),
          ...ranked.sublist(0, 4),
          ...chart.sublist(0, 3),
          const TokenEvent('Stock is tight in three outlets.'),
          const DoneEvent(),
        ]),
      );
      await ask(tester, 'How is stock?');
      expect(tester.takeException(), isNull);
      expect(phaseOf(tester), AskPhase.landedFocus);
      final census = await amberCensus(tester);
      expect(census.objectCount, 2, reason: census.describe());
      await disposeAsk(tester);
    });

    testWidgets('a ranking with no server focus lights nothing', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(rankedTurn(focus: null)),
      );
      await ask(tester, 'Which outlets ran out?');
      expect(phaseOf(tester), AskPhase.landed);
      expect(
        find.byKey(const ValueKey<String>('ranked-bars-focus')),
        findsNothing,
        reason: 'No focus field means nothing is lit — never a guess at 0.',
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
      await disposeAsk(tester);
    });

    testWidgets('the focus event names the bar, not its position', (
      tester,
    ) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(rankedTurn(focus: 2)),
      );
      await ask(tester, 'Which outlets ran out?');
      final focus = find.byKey(const ValueKey<String>('ranked-bars-focus'));
      expect(focus, findsOneWidget);
      expect(
        find.descendant(of: focus, matching: find.text('Pick n Pay Rosebank')),
        findsOneWidget,
      );
      await disposeAsk(tester);
    });
  });
}
