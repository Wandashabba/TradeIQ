import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/meter.dart';
import 'package:tradeiq_app/features/assistant/answer/answer_view.dart';
import 'package:tradeiq_app/features/assistant/answer/ask_turn.dart';
import 'package:tradeiq_app/features/assistant/answer/web_sources.dart';
import 'package:tradeiq_app/features/assistant/answer/working_steps.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';
import 'package:tradeiq_app/features/assistant/view_specs/view_spec_registry.dart';

import 'ask_harness.dart';

/// The route with one question asked and its turn left open, so the test can
/// drive the answer event by event. Tall enough that nothing needs scrolling.
Future<(LiveRepository, StepClock)> pumpLive(
  WidgetTester tester, {
  TiqSkin? skin,
  bool disableAnimations = true,
}) async {
  final repository = LiveRepository();
  final clock = StepClock();
  await pumpAsk(
    tester,
    repository: repository,
    clock: clock,
    skin: skin,
    size: const Size(360, 2400),
    disableAnimations: disableAnimations,
    settle: disableAnimations,
  );
  await ask(tester, 'How did Gauteng do?', settle: false);
  return (repository, clock);
}

const _answer = '''Gauteng is **down 12.4%** on last August.

> **What explains it**
> The 500ml was out of stock at **5 outlets**.

#### What I'd do
- Restock the 500ml.
- Ask *Lerato* why.

```followups
Show Soweto outlets on a map
Which agents cover Soweto?
Compare with Western Cape
Something a fourth time
```''';

void main() {
  group('working steps', () {
    testWidgets('running, then done, then failed, then the summary', (
      tester,
    ) async {
      final (repo, clock) = await pumpLive(tester);
      // Before the first lookup the rail stands in the gap under the
      // question, header only, so the send never looks dropped.
      await pumpEvent(tester);
      expect(find.text('Reading your question'), findsOneWidget);

      repo.emit(
        const ToolStartEvent(name: 'getSalesPerformance', pillar: 'sales'),
      );
      await pumpEvent(tester);
      // The running step carries the word, whatever the dot is doing.
      expect(find.text('Sell-in · Live'), findsOneWidget);
      expect(find.text('Looking things up'), findsOneWidget);

      clock.advance(const Duration(milliseconds: 600));
      repo.emit(const ToolEndEvent(name: 'getSalesPerformance', ok: true));
      await pumpEvent(tester);
      expect(find.text('Sell-in'), findsOneWidget);
      expect(screenText(tester), contains('0.6'));

      repo.emit(const ToolStartEvent(name: 'getStockLevels', pillar: 'stock'));
      await pumpEvent(tester);
      clock.advance(const Duration(milliseconds: 1200));
      repo.emit(const ToolEndEvent(name: 'getStockLevels', ok: false));
      await pumpEvent(tester);
      expect(find.text('Stock on shelf — unavailable'), findsOneWidget);
      expect(screenText(tester), contains('1.2'));
      // Every tool is done and no token has come: the header says so.
      expect(find.text('Writing the answer'), findsOneWidget);

      repo.emit(const TokenEvent('Down 12%.'));
      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();

      // Collapsed to one provenance row when the answer lands.
      expect(find.byType(WorkingSteps), findsNothing);
      expect(
        find.text('Checked 1 source · 1 unavailable · 1.8s'),
        findsOneWidget,
      );
    });

    testWidgets('a silent step says so at 12s, and offers Stop at 30s', (
      tester,
    ) async {
      final (repo, clock) = await pumpLive(tester);
      repo.emit(const ToolStartEvent(name: 'getStockLevels', pillar: 'stock'));
      await pumpEvent(tester);
      expect(
        find.byKey(const ValueKey<String>('working-steps-stalled')),
        findsNothing,
      );

      // Wall clock from the last event, measured on the phone.
      clock.advance(const Duration(seconds: 12));
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('This one is taking a while'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('working-steps-stop')),
        findsNothing,
      );

      clock.advance(const Duration(seconds: 18));
      await tester.pump(const Duration(seconds: 18));
      final stop = find.byKey(const ValueKey<String>('working-steps-stop'));
      expect(stop, findsOneWidget);

      await tester.tap(stop);
      await tester.pumpAndSettle();
      // Stop keeps what was written, and is not an error.
      expect(find.byType(WorkingSteps), findsNothing);
      expect(screenText(tester), contains('Stopped.'));
      await repo.close();
      await disposeAsk(tester);
    });

    testWidgets('an event resets the silence', (tester) async {
      final (repo, clock) = await pumpLive(tester);
      repo.emit(const ToolStartEvent(name: 'getStockLevels', pillar: 'stock'));
      await pumpEvent(tester);
      clock.advance(const Duration(seconds: 11));
      await tester.pump(const Duration(seconds: 11));
      repo.emit(const ToolEndEvent(name: 'getStockLevels', ok: true));
      repo.emit(
        const ToolStartEvent(name: 'getSalesPerformance', pillar: 'sales'),
      );
      await pumpEvent(tester);
      clock.advance(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('This one is taking a while'), findsNothing);

      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();
      await disposeAsk(tester);
    });

    testWidgets('the summary of a clean run', (tester) async {
      final (repo, clock) = await pumpLive(tester);
      for (final name in ['getSalesPerformance', 'getStockLevels']) {
        repo.emit(ToolStartEvent(name: name, pillar: 'sales'));
        await pumpEvent(tester);
        clock.advance(const Duration(milliseconds: 1000));
        repo.emit(ToolEndEvent(name: name, ok: true));
        await pumpEvent(tester);
      }
      repo.emit(const TokenEvent('Fine.'));
      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();

      expect(find.text('Checked 2 sources · 2.0s'), findsOneWidget);
    });

    test('labels map known tools and fall back by pillar', () {
      expect(
        stepLabel(
          const ToolActivity(name: 'getSalesPerformance', pillar: 'sales'),
        ),
        'Sell-in',
      );
      expect(
        stepLabel(const ToolActivity(name: 'getNew', pillar: 'stock')),
        'Checking stock',
      );
      expect(
        stepLabel(const ToolActivity(name: 'getNew', pillar: 'x')),
        'Looking that up',
      );
    });

    test('labels the operational tools in manager words, never by name', () {
      const tools = {
        'getPriceCompliance': 'competition',
        'getCampaignPerformance': 'sales',
        'getSellInForecast': 'sales',
        'getContestStandings': 'execution',
        'getTaskSummary': 'execution',
        'getAlerts': 'execution',
        'findTerritories': 'execution',
      };
      for (final entry in tools.entries) {
        final label = stepLabel(
          ToolActivity(name: entry.key, pillar: entry.value),
        );
        expect(toolStepLabels[entry.key], label);
        expect(label, isNot(contains('get')));
      }
      expect(
        stepLabel(
          const ToolActivity(name: 'getPriceCompliance', pillar: 'competition'),
        ),
        'Shelf prices vs RRP',
      );
    });

    test('labels the outside-context tools, by name and by their pillar', () {
      expect(
        stepLabel(
          const ToolActivity(name: 'getCalendarContext', pillar: 'context'),
        ),
        'Holidays & paydays',
      );
      expect(
        stepLabel(
          const ToolActivity(name: 'getWeatherContext', pillar: 'context'),
        ),
        'Weather',
      );
      expect(
        stepLabel(
          const ToolActivity(name: 'getEconomicContext', pillar: 'context'),
        ),
        'Economy',
      );
      expect(
        stepLabel(const ToolActivity(name: 'getNewContext', pillar: 'context')),
        'Checking outside context',
      );
    });

    test('labels the web search, by name and by its pillar', () {
      expect(
        stepLabel(const ToolActivity(name: 'webSearch', pillar: 'web')),
        'Searching the web',
      );
      expect(toolStepLabels['webSearch'], 'Searching the web');
      expect(
        stepLabel(const ToolActivity(name: 'webFetch', pillar: 'web')),
        'Searching the web',
      );
    });
  });

  group('web sources', () {
    testWidgets('a sources event lands under the answer', (tester) async {
      final (repo, _) = await pumpLive(tester);
      repo.emit(const ToolStartEvent(name: 'webSearch', pillar: 'web'));
      await pumpEvent(tester);
      expect(find.text('Searching the web · Live'), findsOneWidget);
      repo.emit(const ToolEndEvent(name: 'webSearch', ok: true));
      repo.emit(const TokenEvent('Shoprite opened three stores.'));
      await pumpEvent(tester);
      expect(find.byType(WebSources), findsNothing);

      repo.emit(
        SourcesEvent([
          WebSource(
            title: 'Shoprite launches new stores',
            url: Uri.parse('https://www.iol.co.za/business/shoprite'),
            domain: 'iol.co.za',
            retrievedAt: DateTime.utc(2026, 9, 17, 10, 12),
          ),
        ]),
      );
      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();

      expect(find.text('Sources'), findsOneWidget);
      expect(find.text('iol.co.za'), findsOneWidget);
      expect(find.text('Shoprite launches new stores'), findsOneWidget);
    });

    testWidgets('outside-context figures cite their publisher and release', (
      tester,
    ) async {
      final (repo, _) = await pumpLive(tester);
      repo.emit(
        const ToolStartEvent(name: 'getEconomicContext', pillar: 'context'),
      );
      await pumpEvent(tester);
      expect(find.text('Economy · Live'), findsOneWidget);
      repo.emit(const ToolEndEvent(name: 'getEconomicContext', ok: true));
      repo.emit(const TokenEvent('Food inflation eased to 0.9%.'));
      repo.emit(
        SourcesEvent([
          WebSource(
            title: 'Stats SA, Consumer Price Index (P0141), time series',
            url: Uri.parse(
              'https://www.statssa.gov.za/publications/P0141/P0141July2026.pdf',
            ),
            domain: 'statssa.gov.za',
            pageAge: 'Released 19 Aug 2026',
            retrievedAt: DateTime.utc(2026, 9, 17, 10, 12),
          ),
        ]),
      );
      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();

      expect(find.text('Sources'), findsOneWidget);
      expect(find.text('statssa.gov.za'), findsOneWidget);
      expect(find.textContaining('Released 19 Aug 2026'), findsOneWidget);
    });

    test('labels competitor retailer-website prices apart from our own', () {
      const tool = ToolActivity(
        name: 'getCompetitorShelfPrices',
        pillar: 'competition',
      );
      expect(stepLabel(tool), 'Competitor shelf prices');
      expect(stepLabel(tool), isNot(contains('get')));
      expect(
        stepLabel(tool),
        isNot(
          stepLabel(
            const ToolActivity(
              name: 'getPriceCompliance',
              pillar: 'competition',
            ),
          ),
        ),
      );
      expect(
        stepLabel(tool),
        isNot(
          stepLabel(
            const ToolActivity(
              name: 'getCompetitorActivity',
              pillar: 'competition',
            ),
          ),
        ),
      );
    });
  });

  group('streaming text', () {
    testWidgets('a caret follows the text while streaming, and goes on done', (
      tester,
    ) async {
      final (repo, _) = await pumpLive(tester);
      repo.emit(const TokenEvent('Gauteng is **down'));
      await pumpEvent(tester);

      expect(find.byType(StreamingCaret), findsOneWidget);
      // The unclosed marker is hidden, never printed.
      expect(screenText(tester), isNot(contains('**')));
      expect(screenText(tester), contains('Gauteng is down'));

      repo.emit(const TokenEvent(' 12.4%** on August.'));
      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();

      expect(find.byType(StreamingCaret), findsNothing);
      expect(screenText(tester), contains('Gauteng is down 12.4% on August.'));
      expect(screenText(tester), isNot(contains('**')));
    });

    testWidgets('an error removes the caret', (tester) async {
      final (repo, _) = await pumpLive(tester);
      repo.emit(const TokenEvent('Gauteng is'));
      await pumpEvent(tester);
      expect(find.byType(StreamingCaret), findsOneWidget);

      repo.emit(const ErrorEvent(code: 'x', message: 'The assistant is busy.'));
      await pumpEvent(tester);
      expect(find.byType(StreamingCaret), findsNothing);
      await repo.close();
      await tester.pumpAndSettle();
    });

    testWidgets('the headline is set larger and heavier than the body', (
      tester,
    ) async {
      final (repo, _) = await pumpLive(tester);
      repo.emit(const TokenEvent(_answer));
      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();

      final views = tester
          .widgetList<AnswerBlockView>(find.byType(AnswerBlockView))
          .toList();
      expect(views.first.headline, isTrue);
      expect(views.skip(1).any((v) => v.headline), isFalse);

      TextStyle styleOf(String start) => tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere((w) => w.text.toPlainText().startsWith(start))
          .text
          .style!;
      final headline = styleOf('Gauteng is');
      final body = styleOf('Restock');
      expect(headline.fontSize!, greaterThan(body.fontSize!));
      expect(headline.fontWeight, FontWeight.w600);
    });
  });

  group('followups', () {
    testWidgets(
      'hidden while the fence is open; chips, capped at 3, once closed',
      (tester) async {
        final (repo, _) = await pumpLive(tester);
        repo.emit(
          const TokenEvent('Down 12%.\n\n```followups\nShow Soweto outlets'),
        );
        await pumpEvent(tester);

        expect(find.byType(FollowUpChips), findsNothing);
        expect(screenText(tester), isNot(contains('`')));
        expect(screenText(tester), isNot(contains('Show Soweto')));

        repo.emit(
          const TokenEvent(
            ' on a map\nWhich agents cover Soweto?\nCompare with Western Cape\n'
            'Something a fourth time\n```',
          ),
        );
        repo.emit(const DoneEvent());
        await repo.close();
        await tester.pumpAndSettle();

        expect(find.byType(FollowUpChips), findsOneWidget);
        expect(
          find.textContaining('Show Soweto outlets on a map'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Compare with Western Cape'),
          findsOneWidget,
        );
        expect(find.textContaining('Something a fourth time'), findsNothing);
        expect(screenText(tester), isNot(contains('`')));
      },
    );

    testWidgets('tapping a chip asks it as the next question', (tester) async {
      final (repo, _) = await pumpLive(tester);
      repo.emit(const TokenEvent(_answer));
      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Which agents cover Soweto?'));
      await tester.pumpAndSettle();

      expect(repo.sent.last, 'Which agents cover Soweto?');
      // It lands in the transcript as the manager's own turn — identical in
      // every way to typing it.
      expect(
        find.descendant(
          of: find.byType(QuestionBubble),
          matching: find.textContaining('Which agents cover Soweto?'),
        ),
        findsOneWidget,
      );
    });
  });

  group('callout', () {
    testWidgets('a blockquote with a bold first line has a kicker', (
      tester,
    ) async {
      final (repo, _) = await pumpLive(tester);
      repo.emit(const TokenEvent(_answer));
      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();

      final callout = find.byType(AskCallout);
      expect(callout, findsOneWidget);
      expect(tester.widget<AskCallout>(callout).kicker, 'What explains it');
      // A section rule in sentence case — never an uppercase eyebrow, and
      // never a warn-washed box that reads as a warning.
      expect(find.text('What explains it'), findsOneWidget);
      expect(find.text('WHAT EXPLAINS IT'), findsNothing);
      expect(
        screenText(tester),
        contains('The 500ml was out of stock at 5 outlets.'),
      );
    });

    testWidgets('a blockquote without one has none', (tester) async {
      final (repo, _) = await pumpLive(tester);
      repo.emit(
        const TokenEvent('Headline.\n\n> Cola ran out at **5** outlets.'),
      );
      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();

      expect(find.byType(AskCallout), findsOneWidget);
      expect(tester.widget<AskCallout>(find.byType(AskCallout)).kicker, isNull);
      // The rule takes its standing name.
      expect(find.text('What explains it'), findsOneWidget);
      expect(screenText(tester), contains('Cola ran out at 5 outlets.'));
    });
  });

  testWidgets('cards are laid out by type: tiles, then bars, then the rest', (
    tester,
  ) async {
    final (repo, _) = await pumpLive(tester);
    // The server's real order: the tool's own card, then its tiles and bars.
    repo.emit(
      const ArtifactEvent(
        id: 'getStockLevels-0',
        type: 'pillar_metrics',
        params: {'pillar': 'stock'},
        data: {'osaPct': 88.0},
      ),
    );
    repo.emit(
      const ArtifactEvent(
        id: 'getStockLevels-ranked_bars-1',
        type: 'ranked_bars',
        params: {},
        data: {
          'title': 'Out-of-stock lines by outlet',
          'unit': 'count',
          'items': [
            {'label': 'Spar Soweto', 'value': 6},
          ],
        },
      ),
    );
    repo.emit(
      const ArtifactEvent(
        id: 'getStockLevels-stat_tiles-1',
        type: 'stat_tiles',
        params: {},
        data: {
          'tiles': [
            {'label': 'On-shelf availability', 'value': 88, 'unit': 'pct'},
          ],
        },
      ),
    );
    repo.emit(const TokenEvent('Stock is **tight**.'));
    repo.emit(const DoneEvent());
    await repo.close();
    await tester.pumpAndSettle();

    final types = tester
        .widgetList<ArtifactView>(find.byType(ArtifactView))
        .map((v) => v.artifact.type)
        .toList();
    // The direction's order: the ranking above everything else, so the
    // headline figures are followed by the list the sentence is about.
    expect(types, ['stat_tiles', 'ranked_bars', 'pillar_metrics']);
    double top(String type) => tester
        .getTopLeft(
          find.byWidgetPredicate(
            (w) => w is ArtifactView && w.artifact.type == type,
          ),
        )
        .dy;
    expect(top('stat_tiles'), lessThan(top('ranked_bars')));
    expect(top('ranked_bars'), lessThan(top('pillar_metrics')));
    expect(find.text('Expand'), findsNothing);
  });

  group('a tool\'s tiles stand in for its own pillar card', () {
    const pillar = {'osaPct': 88.0, 'outletsWithStockout': 17};
    const tiles = {
      'tiles': [
        {'label': 'On-shelf availability', 'value': 88, 'unit': 'pct'},
      ],
    };

    Future<void> run(WidgetTester tester, List<AssistantEvent> events) async {
      final (repo, _) = await pumpLive(tester);
      for (final event in events) {
        repo.emit(event);
        await pumpEvent(tester);
      }
      repo.emit(const TokenEvent('Stock is tight.'));
      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    List<String> shownTypes(WidgetTester tester) => tester
        .widgetList<ArtifactView>(find.byType(ArtifactView))
        .map((v) => v.artifact.type)
        .toList();

    testWidgets('same tool call: the pillar card is hidden', (tester) async {
      await run(tester, const [
        ToolStartEvent(name: 'getStockLevels', pillar: 'stock'),
        ToolEndEvent(name: 'getStockLevels', ok: true),
        ArtifactEvent(
          id: 'p-1',
          type: 'pillar_metrics',
          params: {'pillar': 'stock'},
          data: pillar,
        ),
        ArtifactEvent(
          id: 'getStockLevels-stat_tiles-1',
          type: 'stat_tiles',
          params: {},
          data: tiles,
        ),
      ]);
      expect(shownTypes(tester), ['stat_tiles']);
    });

    testWidgets('a pillar card alone is shown', (tester) async {
      await run(tester, const [
        ToolStartEvent(name: 'getStockLevels', pillar: 'stock'),
        ToolEndEvent(name: 'getStockLevels', ok: true),
        ArtifactEvent(
          id: 'p-1',
          type: 'pillar_metrics',
          params: {'pillar': 'stock'},
          data: pillar,
        ),
      ]);
      expect(shownTypes(tester), ['pillar_metrics']);
    });

    testWidgets('pillar card from tool A, tiles from tool B: both shown', (
      tester,
    ) async {
      await run(tester, const [
        ToolStartEvent(name: 'getStockLevels', pillar: 'stock'),
        ToolEndEvent(name: 'getStockLevels', ok: true),
        ArtifactEvent(
          id: 'p-1',
          type: 'pillar_metrics',
          params: {'pillar': 'stock'},
          data: pillar,
        ),
        ToolStartEvent(name: 'getRateOfSale', pillar: 'sales'),
        ToolEndEvent(name: 'getRateOfSale', ok: true),
        ArtifactEvent(
          id: 'getRateOfSale-stat_tiles-1',
          type: 'stat_tiles',
          params: {},
          data: tiles,
        ),
      ]);
      expect(shownTypes(tester), ['stat_tiles', 'pillar_metrics']);
    });

    testWidgets('other card types are never hidden', (tester) async {
      await run(tester, const [
        ToolStartEvent(name: 'getMetricTrend', pillar: 'stock'),
        ToolEndEvent(name: 'getMetricTrend', ok: true),
        ArtifactEvent(
          id: 't-1',
          type: 'trend_chart',
          params: {},
          data: {
            'metric': 'availability',
            'points': [
              {'period': '2026-08-01', 'value': 90},
              {'period': '2026-08-02', 'value': 91},
            ],
          },
        ),
        ArtifactEvent(
          id: 'getMetricTrend-stat_tiles-1',
          type: 'stat_tiles',
          params: {},
          data: tiles,
        ),
      ]);
      expect(shownTypes(tester), ['stat_tiles', 'trend_chart']);
    });
  });

  testWidgets(
    'an answer with none of the conventions still reads: bold and a list, '
    'no oversized opening, text above the cards',
    (tester) async {
      // The norm until the prompt change lands: the model bolds and lists, but
      // writes no headline sentence, callout or follow-ups.
      final (repo, _) = await pumpLive(tester);
      repo.emit(
        const ArtifactEvent(
          id: 'getStockLevels-stat_tiles-1',
          type: 'stat_tiles',
          params: {},
          data: {
            'tiles': [
              {'label': 'On-shelf availability', 'value': 88, 'unit': 'pct'},
            ],
          },
        ),
      );
      const opening =
          'On-shelf availability across your outlets was **88%** this '
          'month, which is four points below July, mostly because three Soweto '
          'outlets ran out of the 500ml for more than a week.';
      repo.emit(
        const TokenEvent(
          '$opening\n\n- Restock Soweto first.\n- Check the 2L.',
        ),
      );
      repo.emit(const DoneEvent());
      await repo.close();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AskCallout), findsNothing);
      expect(find.byType(FollowUpChips), findsNothing);
      final views = tester.widgetList<AnswerBlockView>(
        find.byType(AnswerBlockView),
      );
      expect(views.any((v) => v.headline), isFalse);
      expect(screenText(tester), isNot(contains('**')));
      final opener = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere(
            (w) =>
                w.text.toPlainText().startsWith('On-shelf availability across'),
          );
      expect(opener.text.style!.fontSize, 14);
      // With no headline, all the prose sits above the cards, as replies always
      // have.
      expect(
        tester.getTopLeft(find.textContaining('Check the 2L')).dy,
        lessThan(tester.getTopLeft(find.byType(ArtifactView)).dy),
      );
    },
  );

  testWidgets('a legacy plain reply renders as one selectable run', (
    tester,
  ) async {
    final (repo, _) = await pumpLive(tester);
    repo.emit(const TokenEvent('Tumo is up 6 points.\n\nThat is good.'));
    repo.emit(const DoneEvent());
    await repo.close();
    await tester.pumpAndSettle();

    // One selectable run, and none of the new layout.
    expect(find.byType(PlainAnswer), findsOneWidget);
    expect(screenText(tester), contains('Tumo is up 6 points.'));
    expect(screenText(tester), contains('That is good.'));
    expect(find.byType(RichAnswer), findsNothing);
    expect(find.byType(WorkingSteps), findsNothing);
    expect(find.byType(FollowUpChips), findsNothing);
  });

  testWidgets('reduced motion renders the final state on the first frame', (
    tester,
  ) async {
    final (repo, _) = await pumpLive(tester, disableAnimations: true);
    repo.emit(
      const ArtifactEvent(
        id: 'stat-1',
        type: 'stat_tiles',
        params: {},
        data: {
          'tiles': [
            {
              'label': 'Sell-in, units',
              'value': 48210,
              'unit': 'units',
              'meter': 81,
            },
          ],
        },
      ),
    );
    repo.emit(const TokenEvent('Gauteng is **down**.\n\n- one'));
    // A single frame: no tween may stand between the data and the screen.
    await pumpEvent(tester);

    expect(screenText(tester), contains('48,210'));
    final meter = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(Meter),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((meter.painter! as MeterPainter).fraction, closeTo(0.81, 1e-9));
    for (final opacity in tester.widgetList<Opacity>(
      find.descendant(
        of: find.byType(RichAnswer),
        matching: find.byType(Opacity),
      ),
    )) {
      // The caret's blink is the only opacity allowed, and it is held on.
      expect(opacity.opacity, 1);
    }

    repo.emit(const DoneEvent());
    await repo.close();
    await tester.pumpAndSettle();
  });
}
