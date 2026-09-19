import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/mark/delta.dart';
import 'package:tradeiq_app/features/assistant/answer/answer_notes.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';
import 'package:tradeiq_app/features/assistant/view_specs/trend_chart_card.dart';
import 'package:tradeiq_app/features/assistant/view_specs/view_spec_registry.dart';

import 'ask_harness.dart' show askBlock, askSkins, screenText;

ChatArtifact artifact(String type, {Object? data, Object? params, String? id}) =>
    ChatArtifact(
      id: id ?? 'a1',
      type: type,
      params: params ?? const {'agentId': 'agent-1'},
      data: data ?? const {},
    );

const String persistedId = '2b3f0d0e-1f2a-4c3b-9d4e-5f6a7b8c9d0e';

const Map<String, Object?> scorecard = {
  'agentName': 'tumo@example.com',
  'averageScore': 82.0,
  'teamAverageScore': 71.0,
  'deltaVsTeam': 11.0,
  'visits': 14,
  'outletsVisited': 9,
  'scoredVisits': 12,
};

const Map<String, Object?> stockData = {
  'onShelfAvailabilityPct': 93.1,
  'outletsWithStockout': 3,
  'linesObserved': 360,
  'comparison': {
    'label': 'the month to date before this one',
    'basis': {'kind': 'previous_period'},
    'deltas': {
      'onShelfAvailabilityPct': {'absolute': 5.1, 'pct': 5.8},
      'outletsWithStockout': {'absolute': -2.0, 'pct': -40.0},
    },
  },
};

const Map<String, Object?> mapData = {
  'worstOutlets': [
    {
      'outletId': 'o1',
      'outletName': 'Kasi Spaza',
      'outOfStockLines': 3,
      'lat': -26.2,
      'lng': 28.04,
    },
    {
      'outletId': 'o2',
      'outletName': 'Corner Shop',
      'outOfStockLines': 1,
      'lat': -26.1,
      'lng': 28.1,
    },
  ],
};

Future<void> pumpView(
  WidgetTester tester,
  ChatArtifact a, {
  bool expandable = false,
  TiqSkin? skin,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    askBlock(
      ArtifactView(artifact: a, expandable: expandable),
      skin: skin,
      locale: locale,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ArtifactView', () {
    testWidgets('renders a registered spec', (tester) async {
      await pumpView(tester, artifact('agent_scorecard', data: scorecard));

      expect(tester.takeException(), isNull);
      final text = screenText(tester);
      expect(text, contains('tumo@example.com'));
      expect(text, contains('82.0'));
      expect(text, contains('Team average'));
      expect(text, contains('71.0'));
      // The score above the team's is better by the metric's own definition:
      // the one delta on this card whose sentiment the sign does carry.
      final delta = tester.widget<Delta>(find.byType(Delta));
      expect(delta.data.direction, DeltaDirection.up);
      expect(delta.data.sentiment, TiqSentiment.good);
      expect(text, contains('+11.0'));
    });

    testWidgets('offers Expand only for an artifact the routes can find', (
      tester,
    ) async {
      // A turn that could not persist falls back to a turn-local id like
      // `getAgentScorecard-0`. The card still renders — that is the point of
      // the fallback — but /artifact/getAgentScorecard-0 is a 404, and a
      // control that cannot work is worse than an absent one.
      await pumpView(
        tester,
        artifact(
          'agent_scorecard',
          id: 'getAgentScorecard-0',
          data: const {'averageScore': 82.0},
        ),
        expandable: true,
      );
      expect(screenText(tester), isNot(contains('Open full view')));

      await pumpView(
        tester,
        artifact(
          'agent_scorecard',
          id: persistedId,
          data: const {'averageScore': 82.0},
        ),
        expandable: true,
      );
      expect(tester.takeException(), isNull);
      expect(screenText(tester), contains('Open full view'));
    });

    testWidgets('never offers Expand on stat_tiles or ranked_bars', (
      tester,
    ) async {
      // Neither is persisted: turn-local ids, `params: {}`, no row behind
      // them. Not even a UUID-shaped id changes that.
      for (final type in ['stat_tiles', 'ranked_bars']) {
        for (final id in ['getRateOfSale-$type-1', persistedId]) {
          await pumpView(
            tester,
            ChatArtifact(
              id: id,
              type: type,
              params: const {},
              data: const {
                'tiles': [
                  {'label': 'Sell-in', 'value': 1, 'unit': 'units'},
                ],
                'items': [
                  {'label': 'Spar', 'value': 2},
                ],
              },
            ),
            expandable: true,
          );
          expect(
            screenText(tester),
            isNot(contains('Open full view')),
            reason: '$type $id',
          );
        }
      }
    });

    testWidgets('does not offer Expand where it was not asked for', (
      tester,
    ) async {
      // Expanded mode renders these same cards for the specs it has no
      // purpose-built view for, and a card inside Expanded must not offer a
      // link to itself.
      await pumpView(
        tester,
        artifact(
          'agent_scorecard',
          id: persistedId,
          data: const {'averageScore': 82.0},
        ),
      );
      expect(screenText(tester), isNot(contains('Open full view')));
    });

    testWidgets('falls back to a note for an unknown spec type', (
      tester,
    ) async {
      // Never a blank card. A blank card reads as a bug in the app — the user
      // retries, sees the same nothing, and stops trusting the screen.
      await pumpView(tester, artifact('pie_of_doom'));

      expect(find.byType(UnsupportedArtifactNote), findsOneWidget);
      expect(screenText(tester), contains('cannot draw yet'));
    });

    testWidgets('survives a spec type the server added after this build', (
      tester,
    ) async {
      // Not an error state — a normal consequence of shipping the backend and
      // the app separately.
      await pumpView(tester, artifact('leaderboard'));

      expect(tester.takeException(), isNull);
      expect(find.byType(UnsupportedArtifactNote), findsOneWidget);
    });

    testWidgets('renders when the tool result is missing fields', (
      tester,
    ) async {
      // The spec params are server-validated; the shape of the tool RESULT is
      // not part of that contract. A missing field must not throw.
      await pumpView(tester, artifact('agent_scorecard', data: const {}));

      expect(tester.takeException(), isNull);
      // Omission, not zero: "0 visits" and "visits were never captured" call
      // for opposite responses from a manager.
      final text = screenText(tester);
      expect(text, contains(emDash));
      expect(text, isNot(contains('\n0\n')));
    });

    testWidgets('an unknown figure is spoken as a sentence, not "em dash"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpView(tester, artifact('agent_scorecard', data: const {}));
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(RegExp('Visits, Nothing measured')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('renders when the tool result is not a map at all', (
      tester,
    ) async {
      await pumpView(tester, artifact('agent_scorecard', data: 'unexpected'));

      expect(tester.takeException(), isNull);
    });

    testWidgets('says so when there is no team to compare against', (
      tester,
    ) async {
      // "Team average —" would read as a missing number rather than an absent
      // team, and those mean different things.
      await pumpView(
        tester,
        artifact(
          'agent_scorecard',
          data: const {'averageScore': 64.0, 'teamAverageScore': null},
        ),
      );

      expect(screenText(tester), contains('No other agent'));
      expect(find.byType(Delta), findsNothing);
    });
  });

  group('PillarMetricsCard', () {
    testWidgets('shows each figure with the movement beside it', (
      tester,
    ) async {
      // A figure with nothing to read it against reproduces the export-and-
      // overlay workflow this whole feature exists to kill.
      await pumpView(
        tester,
        artifact(
          'pillar_metrics',
          params: const {'pillar': 'stock'},
          data: stockData,
        ),
      );

      expect(tester.takeException(), isNull);
      final text = screenText(tester);
      expect(text, contains('STOCK'));
      expect(text, contains('93.1%'));
      expect(text, contains('On-shelf availability'));
      expect(text, contains('+5.8%'));
      expect(text, contains('${minusSign}40.0%'));
      expect(find.byType(Delta), findsNWidgets(2));
      // The denominator sorts last: it is context, not performance.
      expect(
        tester.getTopLeft(find.text('Lines observed')).dy,
        greaterThan(tester.getTopLeft(find.text('Outlets with a stockout')).dy),
      );
    });

    testWidgets('names what the movement is measured against', (
      tester,
    ) async {
      // A triangle on its own is a number without a baseline.
      await pumpView(
        tester,
        artifact(
          'pillar_metrics',
          params: const {'pillar': 'stock'},
          data: stockData,
        ),
      );

      expect(
        screenText(tester),
        contains(
          'Change is measured against the month to date before this one.',
        ),
      );
    });

    testWidgets('a fall reads as a fall, and the sign never guesses a verdict', (
      tester,
    ) async {
      await pumpView(
        tester,
        artifact(
          'pillar_metrics',
          params: const {'pillar': 'stock'},
          data: stockData,
        ),
      );

      final deltas = tester
          .widgetList<Delta>(find.byType(Delta))
          .map((d) => d.data)
          .toList();
      expect(
        deltas.map((d) => d.direction),
        containsAll(<DeltaDirection>[DeltaDirection.up, DeltaDirection.down]),
      );
      // More stock-outs is up and bad; more share of shelf is up and good.
      // The tool result carries no sentiment, so none is invented.
      expect(
        deltas.map((d) => d.sentiment).toSet(),
        <TiqSentiment>{TiqSentiment.neutral},
      );
    });

    testWidgets('renders the figures when nothing was compared', (
      tester,
    ) async {
      // Comparison is optional. Without it the card is still the answer.
      await pumpView(
        tester,
        artifact(
          'pillar_metrics',
          params: const {'pillar': 'visibility'},
          data: const {'visibilityCompliancePct': 76.4},
        ),
      );

      final text = screenText(tester);
      expect(text, contains('VISIBILITY'));
      expect(text, contains('76.4%'));
      expect(find.byType(Delta), findsNothing);
    });

    testWidgets('never invents a percentage from a zero baseline', (
      tester,
    ) async {
      // The server sends pct: null when the baseline was zero, because "up
      // from nothing" has no percentage. The card must not fill one in.
      await pumpView(
        tester,
        artifact(
          'pillar_metrics',
          params: const {'pillar': 'stock'},
          data: const {
            'outletsWithStockout': 4,
            'comparison': {
              'label': 'last year',
              'deltas': {
                'outletsWithStockout': {'absolute': 4.0, 'pct': null},
              },
            },
          },
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Delta), findsOneWidget);
      final text = screenText(tester);
      expect(text, contains('+4.0'));
      expect(text, isNot(contains('%')));
      expect(text, isNot(contains('0%')));
    });

    testWidgets('labels a metric it has never heard of instead of hiding it', (
      tester,
    ) async {
      // A backend that grows a figure before this build ships must not
      // silently drop a number the narrative above already mentioned.
      await pumpView(
        tester,
        artifact(
          'pillar_metrics',
          params: const {'pillar': 'sales'},
          data: const {'newFangledRatio': 12},
        ),
      );

      final text = screenText(tester);
      expect(text, contains('New fangled ratio'));
      expect(text, contains('12'));
    });

    testWidgets('says so when the period returned no figures', (tester) async {
      await pumpView(
        tester,
        artifact(
          'pillar_metrics',
          params: const {'pillar': 'stock'},
          data: const {},
        ),
      );

      expect(
        screenText(tester),
        contains('No figures were returned for this period.'),
      );
    });

    testWidgets('in Afrikaans, in the reader\'s own separators', (
      tester,
    ) async {
      await pumpView(
        tester,
        artifact(
          'pillar_metrics',
          params: const {'pillar': 'stock'},
          data: stockData,
        ),
        locale: const Locale('af'),
      );

      final text = screenText(tester);
      expect(text, contains('93,1%'));
      expect(text, contains('+5,8%'));
      expect(text, contains('Beskikbaarheid op die rak'));
      expect(text, isNot(contains('93.1')));
    });
  });

  group('TrendChartCard', () {
    testWidgets('renders a titled chart from the tool result', (tester) async {
      await pumpView(
        tester,
        artifact(
          'trend_chart',
          data: const {
            'metric': 'availability',
            'interval': 'day',
            'points': [
              {'period': '2026-08-01T00:00:00.000Z', 'value': 62.0, 'count': 4},
              {'period': '2026-08-02T00:00:00.000Z', 'value': 71.0, 'count': 6},
            ],
          },
        ),
      );

      expect(tester.takeException(), isNull);
      final legend = tester.widget<ChartLegend>(find.byType(ChartLegend));
      expect(legend.entries.single.label, 'On-shelf availability');
      expect(legend.entries.single.dashed, isFalse);
    });

    testWidgets('draws the comparison inline as a second series', (
      tester,
    ) async {
      // #271 shipped comparison with nowhere to land. A card that renders the
      // current period and drops the window the user explicitly asked to
      // compare against would do the same thing again.
      await pumpView(
        tester,
        artifact(
          'trend_chart',
          data: const {
            'metric': 'execution_score',
            'interval': 'day',
            'points': [
              {'period': '2026-08-01', 'value': 74.0},
              {'period': '2026-08-02', 'value': 78.0},
            ],
            'comparison': {
              'label': 'the month to date before this one',
              'basis': {'kind': 'previous_period'},
              'points': [
                {'period': '2026-07-01', 'value': 70.0},
                {'period': '2026-07-02', 'value': 72.0},
              ],
            },
          },
        ),
      );

      final legend = tester.widget<ChartLegend>(find.byType(ChartLegend));
      expect(legend.entries, hasLength(2));
      expect(legend.entries.first.label, 'Execution score');
      // And the second line is named in words, dashed — never a colour key.
      expect(legend.entries.last.label, 'the month to date before this one');
      expect(legend.entries.last.dashed, isTrue);
    });

    testWidgets('skips unreadable rows instead of plotting them as zero', (
      tester,
    ) async {
      // A fabricated zero IS a data point on a chart — it changes what the
      // line says. One readable point remains, which is below the chart's own
      // two-point minimum, so its honest empty state shows.
      await pumpView(
        tester,
        artifact(
          'trend_chart',
          data: const {
            'metric': 'execution_score',
            'points': [
              {'period': '2026-08-01', 'value': 'not a number'},
              'not even a map',
              {'period': '2026-08-02', 'value': 74.0},
            ],
          },
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        screenText(tester),
        contains('Not enough data to plot — 1 period returned.'),
      );
      expect(find.byType(ChartLegend), findsNothing);
    });

    testWidgets('renders when the tool result is missing everything', (
      tester,
    ) async {
      await pumpView(tester, artifact('trend_chart', data: const {}));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('trend-not-enough')),
        findsOneWidget,
      );
    });

    testWidgets('the title is in the reader\'s language, and a new metric '
        'still has one', (tester) async {
      const points = [
        {'period': '2026-08-01', 'value': 62.0},
        {'period': '2026-08-02', 'value': 71.0},
      ];
      await pumpView(
        tester,
        artifact(
          'trend_chart',
          data: const {'metric': 'availability', 'points': points},
        ),
        locale: const Locale('af'),
      );
      expect(
        tester.widget<ChartLegend>(find.byType(ChartLegend)).entries.first.label,
        'Beskikbaarheid op die rak',
      );

      await pumpView(
        tester,
        artifact(
          'trend_chart',
          data: const {'metric': 'sell_in_cases', 'points': points},
        ),
      );
      expect(
        tester.widget<ChartLegend>(find.byType(ChartLegend)).entries.first.label,
        'Sell in cases',
      );
    });
  });

  group('OutletMapCard', () {
    testWidgets('draws a pin per outlet with the count in its semantics', (
      tester,
    ) async {
      await pumpView(tester, artifact('outlet_map', data: mapData));

      expect(tester.takeException(), isNull);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('stockout-pin-icon-o1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('stockout-pin-icon-o2')),
        findsOneWidget,
      );
      // Asserted on the widget's own property rather than through the
      // compiled semantics tree, which is sensitive to node-merging rules
      // that are not what this test is about.
      final pinSemantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const ValueKey<String>('stockout-pin-icon-o1')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(pinSemantics.properties.label, 'Kasi Spaza, 3 lines out of stock');
      expect(screenText(tester), contains('2 outlets'));
    });

    testWidgets('Veld lists the outlets instead of drawing tiles', (
      tester,
    ) async {
      // Map tiles in direct sun are a grey smear: the same answer, as rows.
      await pumpView(
        tester,
        artifact('outlet_map', data: mapData),
        skin: TiqSkin.veld(),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FlutterMap), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('stockout-row-o1')),
        findsOneWidget,
      );
      final text = screenText(tester);
      expect(text, contains('Kasi Spaza'));
      expect(text, contains('Maps are not drawn in Veld'));
    });

    testWidgets('an outlet whose count is unknown is a dash, never a 0', (
      tester,
    ) async {
      await pumpView(
        tester,
        artifact(
          'outlet_map',
          data: const {
            'worstOutlets': [
              {
                'outletId': 'o1',
                'outletName': 'Kasi Spaza',
                'lat': -26.2,
                'lng': 28.04,
              },
            ],
          },
        ),
        skin: TiqSkin.veld(),
      );

      expect(tester.takeException(), isNull);
      final text = screenText(tester);
      expect(text, contains(emDash));
      expect(text, isNot(contains('\n0')));
    });

    testWidgets('skips rows without a finite coordinate rather than guessing', (
      tester,
    ) async {
      // A pin at (0, 0) is an answer about the Gulf of Guinea, not about
      // stock. The one readable outlet still gets its map.
      await pumpView(
        tester,
        artifact(
          'outlet_map',
          data: const {
            'worstOutlets': [
              {'outletId': 'o1', 'outletName': 'No coords'},
              {
                'outletId': 'o2',
                'outletName': 'Kasi Spaza',
                'outOfStockLines': 2,
                'lat': -26.2,
                'lng': 28.04,
              },
            ],
          },
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('stockout-pin-icon-o2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('stockout-pin-icon-o1')),
        findsNothing,
      );
      expect(screenText(tester), contains('1 outlet'));
    });

    testWidgets('says so when no outlet location can be read', (tester) async {
      // The tool only declares this spec when it has outlets to point at, so
      // an unreadable list means the result shape moved under this build. An
      // empty world map would read as "no problem anywhere".
      await pumpView(
        tester,
        artifact('outlet_map', data: const {'worstOutlets': 'unexpected'}),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FlutterMap), findsNothing);
      expect(screenText(tester), contains('could not be read'));
    });
  });

  // Every card, every skin, at 2.0× text in a 320dp panel: the widest
  // Afrikaans strings and the largest scale the app allows, together.
  for (final skin in askSkins) {
    testWidgets('${skin.mode.name}: every spec lays out at 2.0x in Afrikaans', (
      tester,
    ) async {
      final specs = <ChatArtifact>[
        artifact('agent_scorecard', data: scorecard),
        artifact('agent_scorecard', data: const {}),
        artifact(
          'pillar_metrics',
          params: const {'pillar': 'stock'},
          data: stockData,
        ),
        artifact(
          'trend_chart',
          data: const {
            'metric': 'availability',
            'points': [
              {'period': '2026-08-01', 'value': 62.0},
              {'period': '2026-08-02', 'value': 71.0},
            ],
          },
        ),
        artifact('outlet_map', data: mapData),
        artifact('pie_of_doom'),
      ];
      for (final a in specs) {
        await pumpView(
          tester,
          a,
          skin: skin,
          locale: const Locale('af'),
          textScale: 2.0,
        );
        expect(tester.takeException(), isNull, reason: a.type);
      }
    });
  }
}
