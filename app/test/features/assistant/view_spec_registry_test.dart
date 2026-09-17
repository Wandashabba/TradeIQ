import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';
import 'package:tradeiq_app/core/widgets/delta_pill.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';
import 'package:tradeiq_app/features/assistant/view_specs/view_spec_registry.dart';

Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

ChatArtifact artifact(String type, {Object? data, Object? params}) => ChatArtifact(
      id: 'a1',
      type: type,
      params: params ?? const {'agentId': 'agent-1'},
      data: data ?? const {},
    );

void main() {
  group('ArtifactView', () {
    testWidgets('renders a registered spec', (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('agent_scorecard', data: const {
          'agentName': 'tumo@example.com',
          'averageScore': 82.0,
          'teamAverageScore': 71.0,
          'deltaVsTeam': 11.0,
          'visits': 14,
          'outletsVisited': 9,
          'scoredVisits': 12,
        }),
      )));

      expect(find.text('82.0'), findsOneWidget);
      expect(find.text('Team average 71.0'), findsOneWidget);
      expect(find.text('tumo@example.com'), findsOneWidget);
    });

    testWidgets('offers Expand only for an artifact the routes can find',
        (tester) async {
      // A turn that could not persist falls back to a turn-local id like
      // `getAgentScorecard-0`. The card still renders — that is the point of
      // the fallback — but /artifact/getAgentScorecard-0 is a 404, and a
      // control that cannot work is worse than an absent one.
      await tester.pumpWidget(wrap(ArtifactView(
        expandable: true,
        artifact: ChatArtifact(
          id: 'getAgentScorecard-0',
          type: 'agent_scorecard',
          params: const {'agentId': 'agent-1'},
          data: const {'averageScore': 82.0},
        ),
      )));
      expect(find.text('Expand'), findsNothing);

      await tester.pumpWidget(wrap(ArtifactView(
        expandable: true,
        artifact: ChatArtifact(
          id: '2b3f0d0e-1f2a-4c3b-9d4e-5f6a7b8c9d0e',
          type: 'agent_scorecard',
          params: const {'agentId': 'agent-1'},
          data: const {'averageScore': 82.0},
        ),
      )));
      expect(find.text('Expand'), findsOneWidget);
    });

    testWidgets('never offers Expand on stat_tiles or ranked_bars',
        (tester) async {
      // Neither is persisted: turn-local ids, `params: {}`, no row behind
      // them. Not even a UUID-shaped id changes that.
      for (final type in ['stat_tiles', 'ranked_bars']) {
        for (final id in [
          'getRateOfSale-$type-1',
          '2b3f0d0e-1f2a-4c3b-9d4e-5f6a7b8c9d0e',
        ]) {
          await tester.pumpWidget(wrap(ArtifactView(
            expandable: true,
            artifact: ChatArtifact(id: id, type: type, params: const {}, data: const {
              'tiles': [
                {'label': 'Sell-in', 'value': 1, 'unit': 'units'},
              ],
              'items': [
                {'label': 'Spar', 'value': 2},
              ],
            }),
          )));
          await tester.pumpAndSettle();
          expect(find.text('Expand'), findsNothing, reason: '$type $id');
          expect(find.byIcon(Icons.open_in_full), findsNothing);
        }
      }
    });

    testWidgets('does not offer Expand where it was not asked for',
        (tester) async {
      // Expanded mode renders these same cards for the specs it has no
      // purpose-built view for, and a card inside Expanded must not offer a
      // link to itself.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: ChatArtifact(
          id: '2b3f0d0e-1f2a-4c3b-9d4e-5f6a7b8c9d0e',
          type: 'agent_scorecard',
          params: const {'agentId': 'agent-1'},
          data: const {'averageScore': 82.0},
        ),
      )));

      expect(find.text('Expand'), findsNothing);
    });

    testWidgets('falls back to a note for an unknown spec type', (tester) async {
      // Never a blank card. A blank card reads as a bug in the app — the user
      // retries, sees the same nothing, and stops trusting the screen.
      await tester.pumpWidget(wrap(ArtifactView(artifact: artifact('pie_of_doom'))));

      expect(find.byType(UnsupportedArtifactNote), findsOneWidget);
      expect(find.textContaining('cannot draw yet'), findsOneWidget);
    });

    testWidgets('survives a spec type the server added after this build',
        (tester) async {
      // Not an error state — a normal consequence of shipping the backend and
      // the app separately. The fixture was `trend_chart` until this build
      // learned to draw it; `leaderboard` is the plan's next catalog entry
      // (Phase 1), so it plays the newer-server role now.
      await tester.pumpWidget(wrap(ArtifactView(artifact: artifact('leaderboard'))));

      expect(tester.takeException(), isNull);
      expect(find.byType(UnsupportedArtifactNote), findsOneWidget);
    });

    testWidgets('renders when the tool result is missing fields', (tester) async {
      // The spec params are server-validated; the shape of the tool RESULT is
      // not part of that contract. A missing field must not throw.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('agent_scorecard', data: const {}),
      )));

      expect(tester.takeException(), isNull);
      // Omission, not zero: "0 visits" and "visits were never captured" call
      // for opposite responses from a manager.
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('renders when the tool result is not a map at all', (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('agent_scorecard', data: 'unexpected'),
      )));

      expect(tester.takeException(), isNull);
    });

    testWidgets('says so when there is no team to compare against',
        (tester) async {
      // "Team average —" would read as a missing number rather than an absent
      // team, and those mean different things.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('agent_scorecard', data: const {
          'averageScore': 64.0,
          'teamAverageScore': null,
        }),
      )));

      expect(find.textContaining('No other agent'), findsOneWidget);
    });
  });


  group('PillarMetricsCard', () {
    const stockData = {
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

    testWidgets('shows each figure with the movement beside it', (tester) async {
      // A figure with nothing to read it against reproduces the export-and-
      // overlay workflow this whole feature exists to kill.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('pillar_metrics',
            params: const {'pillar': 'stock'}, data: stockData),
      )));

      expect(find.text('Stock'), findsOneWidget);
      expect(find.text('93.1%'), findsOneWidget);
      expect(find.text('On-shelf availability'), findsOneWidget);
      expect(find.text('5.8%'), findsOneWidget);
      expect(find.byType(DeltaPill), findsNWidgets(2));
    });

    testWidgets('names what the movement is measured against', (tester) async {
      // A pill on its own is a number without a baseline.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('pillar_metrics',
            params: const {'pillar': 'stock'}, data: stockData),
      )));

      expect(
        find.text('Change is measured against the month to date before this one.'),
        findsOneWidget,
      );
    });

    testWidgets('a fall reads as a fall', (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('pillar_metrics',
            params: const {'pillar': 'stock'}, data: stockData),
      )));

      final pills = tester.widgetList<DeltaPill>(find.byType(DeltaPill)).toList();
      expect(pills.any((p) => p.tone == DeltaTone.bad), isTrue);
      expect(pills.any((p) => p.tone == DeltaTone.good), isTrue);
    });

    testWidgets('renders the figures when nothing was compared', (tester) async {
      // Comparison is optional. Without it the card is still the answer.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('pillar_metrics',
            params: const {'pillar': 'visibility'},
            data: const {'visibilityCompliancePct': 76.4}),
      )));

      expect(find.text('Visibility'), findsOneWidget);
      expect(find.text('76.4%'), findsOneWidget);
      expect(find.byType(DeltaPill), findsNothing);
    });

    testWidgets('says n/a rather than inventing a percentage from zero', (tester) async {
      // The server sends pct: null when the baseline was zero, because "up from
      // nothing" has no percentage. The card must not fill that in.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('pillar_metrics',
            params: const {'pillar': 'stock'},
            data: const {
              'outletsWithStockout': 4,
              'comparison': {
                'label': 'last year',
                'deltas': {
                  'outletsWithStockout': {'absolute': 4.0, 'pct': null},
                },
              },
            }),
      )));

      expect(find.text('n/a'), findsOneWidget);
    });

    testWidgets('labels a metric it has never heard of instead of hiding it', (tester) async {
      // A backend that grows a figure before this build ships must not silently
      // drop a number the narrative above already mentioned.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('pillar_metrics',
            params: const {'pillar': 'sales'},
            data: const {'newFangledRatio': 12}),
      )));

      expect(find.text('New fangled ratio'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('says so when the period returned no figures', (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('pillar_metrics',
            params: const {'pillar': 'stock'}, data: const {}),
      )));

      expect(find.text('No figures were returned for this period.'), findsOneWidget);
    });
  });

  group('TrendChartCard', () {
    testWidgets('renders a titled line chart from the tool result', (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('trend_chart', data: const {
          'metric': 'availability',
          'interval': 'day',
          'points': [
            {'period': '2026-08-01T00:00:00.000Z', 'value': 62.0, 'count': 4},
            {'period': '2026-08-02T00:00:00.000Z', 'value': 71.0, 'count': 6},
          ],
        }),
      )));

      expect(tester.takeException(), isNull);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('On-shelf availability'), findsOneWidget);
      expect(find.text('By day'), findsOneWidget);
    });

    testWidgets('draws the comparison inline as a second series',
        (tester) async {
      // #271 shipped comparison with nowhere to land. A card that renders the
      // current period and drops the window the user explicitly asked to
      // compare against would do the same thing again.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('trend_chart', data: const {
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
        }),
      )));

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.comparison, hasLength(2));
      expect(chart.comparisonName, 'the month to date before this one');
      // And the header says what the second line is, in words.
      expect(
        find.text('By day · vs the month to date before this one'),
        findsOneWidget,
      );
    });

    testWidgets('skips unreadable rows instead of plotting them as zero',
        (tester) async {
      // A fabricated zero IS a data point on a chart — it changes what the
      // line says. One readable point remains, which is below the chart's own
      // two-point minimum, so its honest empty state shows.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('trend_chart', data: const {
          'metric': 'execution_score',
          'points': [
            {'period': '2026-08-01', 'value': 'not a number'},
            'not even a map',
            {'period': '2026-08-02', 'value': 74.0},
          ],
        }),
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('Not enough data to plot'), findsOneWidget);
    });

    testWidgets('renders when the tool result is missing everything', (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('trend_chart', data: const {}),
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('Trend'), findsOneWidget);
      expect(find.text('Not enough data to plot'), findsOneWidget);
    });
  });

  group('OutletMapCard', () {
    testWidgets('draws a pin per outlet with the count in its semantics',
        (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('outlet_map', data: const {
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
        }),
      )));

      expect(tester.takeException(), isNull);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stockout-pin-icon-o1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stockout-pin-icon-o2')), findsOneWidget);
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
      expect(find.text('2 outlets'), findsOneWidget);
    });

    testWidgets('skips rows without a finite coordinate rather than guessing',
        (tester) async {
      // A pin at (0, 0) is an answer about the Gulf of Guinea, not about
      // stock. The one readable outlet still gets its map.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('outlet_map', data: const {
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
        }),
      )));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('stockout-pin-icon-o2')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stockout-pin-icon-o1')), findsNothing);
      expect(find.text('1 outlet'), findsOneWidget);
    });

    testWidgets('says so when no outlet location can be read', (tester) async {
      // The tool only declares this spec when it has outlets to point at, so
      // an unreadable list means the result shape moved under this build. An
      // empty world map would read as "no problem anywhere".
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('outlet_map', data: const {'worstOutlets': 'unexpected'}),
      )));

      expect(tester.takeException(), isNull);
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.textContaining('could not be read'), findsOneWidget);
    });
  });

  group('Lumen Glass (light)', () {
    const scorecard = {
      'agentName': 'tumo@example.com',
      'averageScore': 82.0,
      'teamAverageScore': 71.0,
      'deltaVsTeam': 11.0,
      'visits': 14,
      'outletsVisited': 9,
      'scoredVisits': 12,
    };

    testWidgets('the scorecard is a glass panel: hero headline, mono metrics',
        (tester) async {
      await tester.pumpWidget(wrap(
        ArtifactView(artifact: artifact('agent_scorecard', data: scorecard)),
        theme: AppTheme.light(),
      ));

      expect(
        find.ancestor(of: find.text('82.0'), matching: find.byType(GlassPane)),
        findsWidgets,
      );
      final headline = tester.widget<Text>(find.text('82.0')).style!;
      expect(headline.fontSize, 34);
      expect(headline.color, LumenPalette.light.ink);
      expect(tester.widget<Text>(find.text('14')).style!.fontFamily,
          LumenGlass.mono);
      // The metric label is a kicker: uppercase mono.
      expect(tester.widget<Text>(find.text('VISITS')).style!.fontFamily,
          LumenGlass.mono);
      expect(find.text('Team average 71.0'), findsOneWidget);
    });

    testWidgets('at night the scorecard is the same glass panel, in night ink',
        (tester) async {
      await tester.pumpWidget(wrap(
        ArtifactView(artifact: artifact('agent_scorecard', data: scorecard)),
      ));

      expect(
        find.ancestor(of: find.text('82.0'), matching: find.byType(GlassPane)),
        findsWidgets,
      );
      final headline = tester.widget<Text>(find.text('82.0')).style!;
      expect(headline.fontSize, 34);
      expect(headline.color, LumenPalette.dark.ink);
      expect(tester.widget<Text>(find.text('14')).style!.fontFamily,
          LumenGlass.mono);
      expect(tester.widget<Text>(find.text('VISITS')).style!.fontFamily,
          LumenGlass.mono);
    });

    testWidgets('pillar figures are mono rows divided by the white rim',
        (tester) async {
      await tester.pumpWidget(wrap(
        ArtifactView(
          artifact: artifact('pillar_metrics',
              params: const {'pillar': 'stock'},
              data: const {
                'onShelfAvailabilityPct': 93.1,
                'outletsWithStockout': 3,
                'comparison': {
                  'label': 'the month to date before this one',
                  'deltas': {
                    'onShelfAvailabilityPct': {'absolute': 5.1, 'pct': 5.8},
                    'outletsWithStockout': {'absolute': -2.0, 'pct': -40.0},
                  },
                },
              }),
        ),
        theme: AppTheme.light(),
      ));

      expect(tester.widget<Text>(find.text('93.1%')).style!.fontFamily,
          LumenGlass.mono);
      expect(tester.widget<Text>(find.text('5.8%')).style!.fontFamily,
          LumenGlass.mono);
      // Movement is still a glyph in a pill, never the colour of a figure.
      expect(find.byType(DeltaPill), findsNWidgets(2));

      // The second row is ruled off from the first by the pane's white rim.
      final rule = tester
          .widgetList<Container>(find.ancestor(
            of: find.text('Outlets with a stockout'),
            matching: find.byType(Container),
          ))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null);
      expect((rule.border! as Border).top.color, LumenPalette.light.white(0xB3));
    });

    testWidgets('an unknown spec explains itself on an unblurred glass tile',
        (tester) async {
      await tester.pumpWidget(wrap(
        ArtifactView(artifact: artifact('pie_of_doom')),
        theme: AppTheme.light(),
      ));

      final pane = tester.widget<GlassPane>(find
          .ancestor(
            of: find.textContaining('cannot draw yet'),
            matching: find.byType(GlassPane),
          )
          .first);
      expect(pane.kind, GlassKind.tile);
      expect(pane.blur, isFalse);
    });

    testWidgets('the trend card and the outlet map render on glass',
        (tester) async {
      await tester.pumpWidget(wrap(
        ArtifactView(
          artifact: artifact('trend_chart', data: const {
            'metric': 'availability',
            'interval': 'day',
            'points': [
              {'period': '2026-08-01', 'value': 62.0},
              {'period': '2026-08-02', 'value': 71.0},
            ],
          }),
        ),
        theme: AppTheme.light(),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(LineChart), findsOneWidget);

      await tester.pumpWidget(wrap(
        ArtifactView(
          artifact: artifact('outlet_map', data: const {
            'worstOutlets': [
              {
                'outletId': 'o1',
                'outletName': 'Kasi Spaza',
                'outOfStockLines': 3,
                'lat': -26.2,
                'lng': 28.04,
              },
            ],
          }),
        ),
        theme: AppTheme.light(),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('stockout-pin-icon-o1')),
          findsOneWidget);
      expect(find.text('1 outlet'), findsOneWidget);
    });
  });
}
