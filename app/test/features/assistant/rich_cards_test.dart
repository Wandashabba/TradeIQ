import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/meter.dart';
import 'package:tradeiq_app/core/widgets/torchlight/mark/delta.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';
import 'package:tradeiq_app/features/assistant/view_specs/ranked_bars_card.dart';
import 'package:tradeiq_app/features/assistant/view_specs/rich_figures.dart';
import 'package:tradeiq_app/features/assistant/view_specs/stat_tiles_card.dart';
import 'package:tradeiq_app/features/assistant/view_specs/trend_chart_card.dart';
import 'package:tradeiq_app/features/assistant/view_specs/view_spec_registry.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import 'ask_harness.dart' show askSkins, screenText;

/// One answer block on its own, in a Torchlight skin, at a phone panel's
/// inner width.
Widget wrap(
  Widget child, {
  TiqSkin? skin,
  bool reduce = true,
  Locale locale = const Locale('en'),
}) {
  final resolved = skin ?? TiqSkin.night(density: TiqDensity.console);
  return MaterialApp(
    theme: AppTheme.torchlight(resolved),
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: DefaultTextStyle(
        style: resolved.text.body.style(color: resolved.palette.ink1),
        child: ColoredBox(
          color: resolved.palette.surface,
          child: SingleChildScrollView(
            child: SizedBox(width: 320, child: child),
          ),
        ),
      ),
    ),
  );
}

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
  for (final skin in askSkins) {
    final name = skin.mode.name;

    group('$name: StatTilesCard', () {
      testWidgets('four tiles on a phone, every figure through the formatter', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(ArtifactView(artifact: artifact('stat_tiles', _tiles)), skin: skin),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(StatTilesCard), findsOneWidget);
        final text = screenText(tester);
        expect(text, contains('48,210'));
        expect(text, contains('81%'));
        expect(text, contains('88%'));
        expect(text, contains('17'));
        // Four on a phone, three recommended: the rest belong in the table
        // twin, not in the fold.
        expect(text, isNot(contains('Neutral one')));
      });

      testWidgets('the delta is the server verdict, never inferred', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(ArtifactView(artifact: artifact('stat_tiles', _tiles)), skin: skin),
        );
        await tester.pumpAndSettle();

        final deltas = tester
            .widgetList<Delta>(find.byType(Delta))
            .map((d) => (d.data.direction, d.data.sentiment))
            .toList();
        expect(deltas, <(DeltaDirection, TiqSentiment)>[
          (DeltaDirection.down, TiqSentiment.bad),
          // The wire's `warn` is neutral: there is no amber warning.
          (DeltaDirection.down, TiqSentiment.neutral),
          // A count that went UP but is good: direction is the glyph,
          // sentiment is the ink, and neither is inferred from the other.
          (DeltaDirection.up, TiqSentiment.good),
        ]);
      });

      testWidgets('the meter fills to its share, and only where asked', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(ArtifactView(artifact: artifact('stat_tiles', _tiles)), skin: skin),
        );
        await tester.pumpAndSettle();
        final meters = find.byType(Meter);
        expect(meters, findsOneWidget);
        final paint = tester.widget<CustomPaint>(
          find.descendant(of: meters, matching: find.byType(CustomPaint)),
        );
        expect((paint.painter! as MeterPainter).fraction, closeTo(0.81, 1e-9));
      });
    });

    group('$name: RankedBarsCard', () {
      testWidgets('diverging bars scaled to the largest magnitude', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(ArtifactView(artifact: artifact('ranked_bars', _bars)), skin: skin),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // What is ranked, and against what, in the server's words.
        expect(find.text('Change by territory'), findsOneWidget);
        expect(find.text("vs Aug '25"), findsOneWidget);

        double factor(int i) => tester
            .widget<FractionallySizedBox>(
              find.byKey(ValueKey<String>('ranked-bar-fill-$i')),
            )
            .widthFactor!;
        expect(factor(0), 1.0);
        expect(factor(1), closeTo(9 / 31, 1e-9));
        expect(factor(3), closeTo(7 / 31, 1e-9));
        // A measured zero draws no bar and prints 0.
        expect(
          find.byKey(const ValueKey<String>('ranked-bar-fill-4')),
          findsNothing,
        );

        // A fall sits left of the axis, a rise to its right.
        final fall = tester
            .getCenter(find.byKey(const ValueKey<String>('ranked-bar-fill-0')))
            .dx;
        final rise = tester
            .getCenter(find.byKey(const ValueKey<String>('ranked-bar-fill-3')))
            .dx;
        expect(fall, lessThan(rise));

        // Every value is signed when the bars diverge, with a true minus.
        final text = screenText(tester);
        expect(text, contains('${minusSign}31%'));
        expect(text, contains('+7%'));
      });

      testWidgets('all non-negative: plain bars from one baseline, unsigned', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
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
            skin: skin,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.text("1–17 Sep '26"), findsOneWidget);
        expect(screenText(tester), isNot(contains('+')));

        double factor(int i) => tester
            .widget<FractionallySizedBox>(
              find.byKey(ValueKey<String>('ranked-bar-fill-$i')),
            )
            .widthFactor!;
        expect(factor(1), 1.0);
        expect(factor(0), closeTo(0.5, 1e-9));

        final lefts = <double>[
          for (var i = 0; i < 3; i++)
            tester
                .getTopLeft(find.byKey(ValueKey<String>('ranked-bar-fill-$i')))
                .dx,
        ];
        expect(lefts.toSet(), hasLength(1));

        // Order is the server's, never re-sorted client-side.
        expect(
          tester.getTopLeft(find.text('Spar Soweto')).dy,
          lessThan(tester.getTopLeft(find.text('Shoprite Tembisa')).dy),
        );
        // No focus field: no focus bar. The old build guessed index 0.
        expect(
          find.byKey(const ValueKey<String>('ranked-bars-focus')),
          findsNothing,
        );
      });

      testWidgets('the server names the focus; it keeps marker and weight', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            ArtifactView(
              artifact: artifact('ranked_bars', <String, Object>{
                ..._bars,
                'focusIndex': 1,
              }),
            ),
            skin: skin,
          ),
        );
        await tester.pumpAndSettle();

        final focus = find.byKey(const ValueKey<String>('ranked-bars-focus'));
        expect(focus, findsOneWidget);
        final label = tester.widget<Text>(
          find.descendant(of: focus, matching: find.text('Tembisa')),
        );
        expect(label.style!.fontWeight, skin.text.bodyStrong.weight);
        // Outside a route that claimed the light, the focus is ink.
        expect(
          tester.widget<Text>(find.text('Pretoria East')).style!.fontWeight,
          skin.text.body.weight,
        );
      });
    });

    group('$name: trend_chart', () {
      const points = [
        {'period': '2026-08-01', 'value': 1600},
        {'period': '2026-08-02', 'value': 1700},
        {'period': '2026-08-03', 'value': 1500},
      ];

      testWidgets('with a comparison: a dashed second series, named', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
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
            skin: skin,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final legend = tester.widget<ChartLegend>(find.byType(ChartLegend));
        expect(legend.entries, hasLength(2));
        expect(legend.entries.last.label, 'month to date last year');
        expect(legend.entries.last.dashed, isTrue);
        // A legend is a label: never amber, lit or not.
        expect(legend.entries.first.colour, skin.palette.ink1);
      });

      testWidgets('a comparison that had no data: no line, a quiet note', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            ArtifactView(
              artifact: artifact('trend_chart', const {
                'metric': 'availability',
                'interval': 'day',
                'points': points,
                'comparison': {'label': 'month to date last year', 'points': []},
              }),
            ),
            skin: skin,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final legend = tester.widget<ChartLegend>(find.byType(ChartLegend));
        expect(legend.entries, hasLength(1));
        expect(
          find.text('no data for month to date last year'),
          findsOneWidget,
        );
      });

      testWidgets('fewer than two readable points is not a chart', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            ArtifactView(
              artifact: artifact('trend_chart', const {
                'metric': 'availability',
                'points': [
                  {'period': '2026-08-01', 'value': 90},
                  {'period': '2026-08-02', 'value': 'n/a'},
                ],
              }),
            ),
            skin: skin,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('trend-not-enough')),
          findsOneWidget,
        );
        expect(find.byType(ChartLegend), findsNothing);
      });
    });
  }

  group('Afrikaans', () {
    testWidgets('tiles and bars take the reader\'s separators', (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: <Widget>[
              ArtifactView(artifact: artifact('stat_tiles', _tiles)),
              ArtifactView(artifact: artifact('ranked_bars', _bars)),
            ],
          ),
          locale: const Locale('af'),
        ),
      );
      await tester.pumpAndSettle();
      final text = screenText(tester);
      expect(text, contains('48\u00A0210'));
      expect(text, contains('12,4%'));
      expect(text, contains('${minusSign}31%'));
      expect(text, isNot(contains('48,210')));
    });
  });

  group('motion', () {
    testWidgets('bars grow in, and reduced motion draws them full at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(ArtifactView(artifact: artifact('ranked_bars', _bars)), reduce: false),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final growing = tester
          .widget<FractionallySizedBox>(
            find.byKey(const ValueKey<String>('ranked-bar-fill-0')),
          )
          .widthFactor!;
      expect(growing, lessThan(1));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        wrap(ArtifactView(artifact: artifact('ranked_bars', _bars))),
      );
      expect(
        tester
            .widget<FractionallySizedBox>(
              find.byKey(const ValueKey<String>('ranked-bar-fill-0')),
            )
            .widthFactor,
        1.0,
      );
    });

    testWidgets('more than six rows: six, and a row that shows the rest', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ArtifactView(
            artifact: artifact('ranked_bars', <String, Object>{
              'unit': 'count',
              'items': <Map<String, Object>>[
                for (var i = 0; i < 9; i++) <String, Object>{
                  'label': 'Outlet $i',
                  'value': 20 - i,
                },
              ],
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Outlet 6'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey<String>('ranked-bars-show-all')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Outlet 8'), findsOneWidget);
    });
  });

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

    test('the focus is the server\'s, and absent means nothing is lit', () {
      // The old build guessed index 0. #410 put `focusIndex` on the wire: the
      // server is the only side that knows which way "worst" runs.
      expect(
        RankedBarsData.from(const {
          'items': [
            {'label': 'a', 'value': 3},
            {'label': 'b', 'value': -8},
          ],
          'focusIndex': 1,
        }).focusIndex,
        1,
      );
      expect(
        RankedBarsData.from(const {
          'items': [
            {'label': 'a', 'value': 3},
            {'label': 'b', 'value': -8},
          ],
        }).focusIndex,
        isNull,
      );
      expect(RankedBarsData.from(const {'items': []}).focusIndex, isNull);
    });

    test('a delta is a positive magnitude; its arrow comes from direction', () {
      TileDelta delta(String direction) => TileDelta.tryParse({
            'value': 12.4,
            'unit': 'pct',
            'direction': direction,
            'sentiment': 'bad',
          })!;
      // No U+25BC: Onest never carried it and package:pdf drew it as nothing
      // (#401). The sign is the direction, and the table twin reads it.
      expect(delta('down').text, '${minusSign}12.4%');
      expect(delta('up').text, '+12.4%');
    });

    testWidgets('malformed data renders without throwing', (tester) async {
      for (final data in <Object>['nope', const {}, const {'tiles': 'x'}, const {'items': [1, 2]}]) {
        await tester.pumpWidget(wrap(
          Column(children: [
            ArtifactView(artifact: artifact('stat_tiles', data)),
            ArtifactView(artifact: artifact('ranked_bars', data)),
          ]),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(RankedBarsCard), findsOneWidget);
    });
  });
}
