import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';
import 'package:tradeiq_app/features/assistant/view_specs/ranked_bars_card.dart';
import 'package:tradeiq_app/features/assistant/view_specs/rich_figures.dart';
import 'package:tradeiq_app/features/assistant/view_specs/stat_tiles_card.dart';
import 'package:tradeiq_app/features/assistant/view_specs/view_spec_registry.dart';

Widget wrap(Widget child, {required ThemeData theme, bool reduce = false}) =>
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 600, child: child),
          ),
        ),
      ),
    );

ChatArtifact artifact(String type, Object data) =>
    ChatArtifact(id: 'a1', type: type, params: const {}, data: data);

const _tiles = {
  'tiles': [
    {
      'label': 'Sell-in, units',
      'value': 48210,
      'unit': 'units',
      'delta': {'value': 12.4, 'unit': 'pct', 'direction': 'down', 'sentiment': 'bad'},
      'comparedTo': "vs 55,034 · Aug '25",
    },
    {'label': 'Target attainment', 'value': 81, 'unit': 'pct', 'meter': 81},
    {
      'label': 'On-shelf availability',
      'value': 88,
      'unit': 'pct',
      'delta': {'value': 4, 'unit': 'pts', 'direction': 'down', 'sentiment': 'warn'},
    },
    {
      'label': 'Outlets with a stock-out',
      'value': 17,
      'unit': 'count',
      'delta': {'value': 9, 'unit': 'count', 'direction': 'up', 'sentiment': 'good'},
    },
    {
      'label': 'Neutral one',
      'value': 3,
      'unit': 'count',
      'delta': {'value': 0, 'unit': 'count', 'sentiment': 'neutral'},
    },
    {'label': 'Unreadable', 'value': 'n/a'},
  ],
};

const _bars = {
  'title': 'Change by territory',
  'comparedTo': "vs Aug '25",
  'unit': 'pct',
  'items': [
    {'label': 'Soweto', 'value': -31},
    {'label': 'Tembisa', 'value': -9},
    {'label': 'Sandton', 'value': 4},
    {'label': 'Pretoria East', 'value': 7},
    {'label': 'Flat', 'value': 0},
  ],
};

void main() {
  for (final (name, theme, palette, colors) in [
    ('light', AppTheme.light(), LumenPalette.light, TiqColors.light),
    ('night', AppTheme.dark(), LumenPalette.dark, TiqColors.night),
  ]) {
    group('$name: StatTilesCard', () {
      testWidgets('renders every readable tile, counted up to its value',
          (tester) async {
        await tester.pumpWidget(wrap(
          ArtifactView(artifact: artifact('stat_tiles', _tiles)),
          theme: theme,
        ));
        // Mid count-up the figure is on its way, not yet there.
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('48,210'), findsNothing);

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(StatTilesCard), findsOneWidget);
        expect(find.text('48,210'), findsOneWidget);
        expect(find.text('81%'), findsOneWidget);
        expect(find.text('88%'), findsOneWidget);
        expect(find.text('17'), findsOneWidget);
        expect(find.text("vs 55,034 · Aug '25"), findsOneWidget);
        // A tile whose value is not a number is skipped, never drawn as 0.
        expect(find.text('Unreadable'), findsNothing);
      });

      testWidgets('the delta pill is the server verdict, in its colour',
          (tester) async {
        await tester.pumpWidget(wrap(
          ArtifactView(artifact: artifact('stat_tiles', _tiles)),
          theme: theme,
        ));
        await tester.pumpAndSettle();

        Color inkOf(String text) => tester.widget<Text>(find.text(text)).style!.color!;
        expect(inkOf('▼ 12.4%'), palette.critical);
        expect(inkOf('▼ 4 pts'), colors.warn);
        // A count that went UP but is good is green: direction is the glyph,
        // sentiment is the colour, and neither is inferred from the other.
        expect(inkOf('▲ 9'), colors.good);
        expect(inkOf('0'), palette.inkMuted);
      });

      testWidgets('the meter fills to its share', (tester) async {
        await tester.pumpWidget(wrap(
          ArtifactView(artifact: artifact('stat_tiles', _tiles)),
          theme: theme,
        ));
        await tester.pumpAndSettle();
        final fill = tester.widget<FractionallySizedBox>(
            find.byKey(const ValueKey('stat-tile-meter-fill')));
        expect(fill.widthFactor, closeTo(0.81, 1e-9));
        // Only the tile that asked for one has a meter.
        expect(find.byKey(const ValueKey('stat-tile-meter-fill')), findsOneWidget);
      });
    });

    group('$name: RankedBarsCard', () {
      testWidgets('diverging bars scaled to the largest magnitude',
          (tester) async {
        await tester.pumpWidget(wrap(
          ArtifactView(artifact: artifact('ranked_bars', _bars)),
          theme: theme,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.text('Change by territory'), findsOneWidget);
        expect(find.text("vs Aug '25"), findsOneWidget);

        double factor(int i) => tester
            .widget<FractionallySizedBox>(
                find.byKey(ValueKey('ranked-bar-fill-$i')))
            .widthFactor!;
        expect(factor(0), 1.0);
        expect(factor(1), closeTo(9 / 31, 1e-9));
        expect(factor(3), closeTo(7 / 31, 1e-9));
        // Zero draws no bar at all.
        expect(find.byKey(const ValueKey('ranked-bar-fill-4')), findsNothing);

        // A fall sits left of the zero line, a rise to its right.
        final zero = tester.getCenter(find.byKey(const ValueKey('ranked-bar-fill-0'))).dx;
        final rise = tester.getCenter(find.byKey(const ValueKey('ranked-bar-fill-3'))).dx;
        expect(zero, lessThan(rise));

        Color inkOf(String text) => tester.widget<Text>(find.text(text)).style!.color!;
        expect(inkOf('${minusSign}31%'), palette.critical);
        expect(inkOf('+7%'), colors.good);
        expect(
          (tester.widget<Container>(find.descendant(
            of: find.byKey(const ValueKey('ranked-bar-fill-0')),
            matching: find.byType(Container),
          )).decoration! as BoxDecoration).color,
          palette.critical,
        );
      });

      testWidgets('all non-negative: plain bars from a left baseline, unsigned',
          (tester) async {
        // What the backend emits today: worst-first counts.
        await tester.pumpWidget(wrap(
          ArtifactView(
            artifact: artifact('ranked_bars', const {
              'title': 'Out-of-stock lines by outlet',
              'comparedTo': "1–17 Sep '26",
              'unit': 'count',
              'items': [
                {'label': 'Spar Soweto', 'value': 6},
                {'label': 'Shoprite Tembisa', 'value': 12},
                {'label': 'Pick n Pay CBD', 'value': 3},
              ],
            }),
          ),
          theme: theme,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // The period-only comparedTo is shown verbatim.
        expect(find.text("1–17 Sep '26"), findsOneWidget);
        // Counts are not signed.
        expect(find.text('6'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.textContaining('+'), findsNothing);

        double factor(int i) => tester
            .widget<FractionallySizedBox>(
                find.byKey(ValueKey('ranked-bar-fill-$i')))
            .widthFactor!;
        expect(factor(1), 1.0);
        expect(factor(0), closeTo(0.5, 1e-9));

        // Every bar starts at the same left baseline and uses the full track:
        // the longest reaches much further right than a diverging half could.
        final left0 = tester.getTopLeft(find.byKey(const ValueKey('ranked-bar-fill-0'))).dx;
        final left1 = tester.getTopLeft(find.byKey(const ValueKey('ranked-bar-fill-1'))).dx;
        final left2 = tester.getTopLeft(find.byKey(const ValueKey('ranked-bar-fill-2'))).dx;
        expect(left0, left1);
        expect(left1, left2);
        final bar1 = tester.getSize(find.byKey(const ValueKey('ranked-bar-fill-1'))).width;
        final row = tester.getSize(find.byKey(const ValueKey('ranked-bars-row-1'))).width;
        expect(bar1, greaterThan(row * 0.5));

        // A count has no verdict: accent, not good or critical.
        final fill = tester.widget<Container>(find.descendant(
          of: find.byKey(const ValueKey('ranked-bar-fill-1')),
          matching: find.byType(Container),
        ));
        expect((fill.decoration! as BoxDecoration).color, palette.accentSolid);

        // The server's first item leads, even though it is not the largest.
        final leader = find.byKey(const ValueKey('ranked-bars-leader'));
        expect(
          tester.widget<Text>(find.descendant(of: leader, matching: find.text('Spar Soweto')))
              .style!.fontWeight,
          FontWeight.w600,
        );
        // Order is the server's, not re-sorted.
        expect(
          tester.getTopLeft(find.text('Spar Soweto')).dy,
          lessThan(tester.getTopLeft(find.text('Shoprite Tembisa')).dy),
        );
      });

      testWidgets('the first item leads', (tester) async {
        await tester.pumpWidget(wrap(
          ArtifactView(artifact: artifact('ranked_bars', _bars)),
          theme: theme,
        ));
        await tester.pumpAndSettle();

        final leader = find.byKey(const ValueKey('ranked-bars-leader'));
        expect(leader, findsOneWidget);
        final name = tester.widget<Text>(
            find.descendant(of: leader, matching: find.text('Soweto')));
        expect(name.style!.fontWeight, FontWeight.w600);
        expect(
          tester.widget<Text>(find.text('Pretoria East')).style!.fontWeight,
          FontWeight.w400,
        );
      });

      testWidgets('bars grow in, and reduced motion draws them full at once',
          (tester) async {
        await tester.pumpWidget(wrap(
          ArtifactView(artifact: artifact('ranked_bars', _bars)),
          theme: theme,
        ));
        await tester.pump(const Duration(milliseconds: 50));
        final growing = tester
            .widget<FractionallySizedBox>(
                find.byKey(const ValueKey('ranked-bar-fill-0')))
            .widthFactor!;
        expect(growing, lessThan(1));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(wrap(
          ArtifactView(artifact: artifact('ranked_bars', _bars)),
          theme: theme,
          reduce: true,
        ));
        expect(
          tester
              .widget<FractionallySizedBox>(
                  find.byKey(const ValueKey('ranked-bar-fill-0')))
              .widthFactor,
          1.0,
        );
      });
    });

    group('$name: trend_chart comparison', () {
      const points = [
        {'period': '2026-08-01', 'value': 1600},
        {'period': '2026-08-02', 'value': 1700},
        {'period': '2026-08-03', 'value': 1500},
      ];

      testWidgets('with a comparison: a dashed second series, named',
          (tester) async {
        await tester.pumpWidget(wrap(
          ArtifactView(
            artifact: artifact('trend_chart', const {
              'metric': 'sell_in',
              'interval': 'day',
              'points': points,
              'comparison': {
                'label': 'month to date last year',
                'points': [
                  {'period': '2025-08-01', 'value': 1700},
                  {'period': '2025-08-02', 'value': 1800},
                  {'period': '2025-08-03', 'value': 1750},
                ],
              },
            }),
          ),
          theme: theme,
        ));
        await tester.pumpAndSettle();

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.comparison, hasLength(3));
        expect(chart.comparisonName, 'month to date last year');
        expect(chart.dashedComparison, isTrue);
        // The label is the server's text, verbatim, in the legend.
        expect(find.text('month to date last year'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('with a comparison that had no data: no line, a quiet note',
          (tester) async {
        await tester.pumpWidget(wrap(
          ArtifactView(
            artifact: artifact('trend_chart', const {
              'metric': 'availability',
              'interval': 'day',
              'points': points,
              'comparison': {'label': 'month to date last year', 'points': []},
            }),
          ),
          theme: theme,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.comparison, isEmpty);
        expect(find.text('month to date last year'), findsNothing);
        expect(find.text('By day · no data for month to date last year'),
            findsOneWidget);
      });

      testWidgets('without one: exactly as before, one series and no legend',
          (tester) async {
        await tester.pumpWidget(wrap(
          ArtifactView(
            artifact: artifact('trend_chart', const {
              'metric': 'availability',
              'interval': 'day',
              'points': points,
            }),
          ),
          theme: theme,
        ));
        await tester.pumpAndSettle();

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.comparison, isEmpty);
        expect(find.text('Comparison'), findsNothing);
        expect(find.text('On-shelf availability'), findsWidgets);
      });
    });
  }

  group('figures', () {
    test('units format as the design shows them', () {
      expect(formatAmount(48210, 'units'), '48,210');
      expect(formatAmount(81, 'pct'), '81%');
      expect(formatAmount(12.4, 'pct'), '12.4%');
      expect(formatAmount(4, 'pts'), '4 pts');
      expect(formatAmount(1, 'pts'), '1 pt');
      expect(formatAmount(-31, 'pct'), '${minusSign}31%');
      expect(formatSignedAmount(7, 'pct'), '+7%');
      expect(formatSignedAmount(0, 'pct'), '0%');
    });

    test('the leader is the first item, as the server ordered it', () {
      expect(
        RankedBarsData.from(const {
          'items': [
            {'label': 'a', 'value': 3},
            {'label': 'b', 'value': -8},
          ],
        }).leaderIndex,
        0,
      );
      expect(RankedBarsData.from(const {'items': []}).leaderIndex, isNull);
    });

    test('a delta is a positive magnitude; its arrow comes from direction', () {
      TileDelta delta(String direction) => TileDelta.tryParse({
            'value': 12.4,
            'unit': 'pct',
            'direction': direction,
            'sentiment': 'bad',
          })!;
      expect(delta('down').text, '▼ 12.4%');
      expect(delta('up').text, '▲ 12.4%');
      // Never negated by the client.
      expect(delta('down').text, isNot(contains(minusSign)));
    });

    testWidgets('malformed data renders without throwing', (tester) async {
      for (final data in <Object>['nope', const {}, const {'tiles': 'x'}, const {'items': [1, 2]}]) {
        await tester.pumpWidget(wrap(
          Column(children: [
            ArtifactView(artifact: artifact('stat_tiles', data)),
            ArtifactView(artifact: artifact('ranked_bars', data)),
          ]),
          theme: AppTheme.light(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(RankedBarsCard), findsOneWidget);
    });
  });
}
