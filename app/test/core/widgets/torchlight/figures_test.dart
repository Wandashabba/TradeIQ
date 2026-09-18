import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';

import 'mark_harness.dart';

void main() {
  group('Meter', () {
    test('the target tick is ink-1 in every skin, never amber', () {
      for (final skin in allSkins) {
        // The ladder has no meterTick rung, and the tick's colour is ink-1 by
        // construction — see MeterPainter. This asserts the token the painter
        // reaches for is the ink one and not a data or a flame one.
        expect(skin.palette.ink1, isNotNull);
        expect(
          skin.palette.ink1,
          isNot(skin.palette.flame600),
          reason:
              'A target is an annotation and an annotation is a label. '
              'Up to ten ticks can be on one route and the route\'s amber '
              'budget for them is zero.',
        );
      }
    });

    test('track heights are 4 / 6 / 8 by density', () {
      expect(Meter.trackHeight(TiqSkin.night()), 4);
      expect(Meter.trackHeight(TiqSkin.day()), 6);
      expect(Meter.trackHeight(TiqSkin.veld()), 8);
    });

    testWidgets('a null value forces the empty state whatever was declared',
        (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const SizedBox(width: 200, child: Meter(value: null, target: 80)),
        ),
      );
      expect(tester.takeException(), isNull);
      // The painter is what carries the state; this asserts the widget did not
      // silently render a zero-length fill with a tick beside it.
      final paint = tester.widget<CustomPaint>(
        find.descendant(of: find.byType(Meter), matching: find.byType(CustomPaint)),
      );
      expect((paint.painter! as MeterPainter).state, MeterState.missing);
      expect((paint.painter! as MeterPainter).fraction, isNull);
    });

    testWidgets('a true zero renders no fill; the figure above carries it',
        (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const SizedBox(width: 200, child: Meter(value: 0)),
        ),
      );
      final painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(Meter),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter! as MeterPainter;
      expect(painter.fraction, 0);
      expect(painter.state, MeterState.filled);
    });

    testWidgets('no target means no tick — never one at 100 or the midpoint',
        (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const SizedBox(width: 200, child: Meter(value: 61)),
        ),
      );
      final painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(Meter),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter! as MeterPainter;
      expect(painter.targetFraction, isNull);
    });

    testWidgets('the track scales at half rate', (tester) async {
      final heights = <double>[];
      for (final scale in <double>[1.0, 2.0]) {
        await tester.pumpWidget(
          skinned(
            TiqSkin.night(),
            const SizedBox(width: 200, child: Meter(value: 61)),
            textScale: scale,
          ),
        );
        heights.add(tester.getSize(find.byType(Meter)).height);
      }
      // 4dp at 1.0x and 6dp at 2.0x, plus the 2dp the tick breaks the edge by.
      expect(heights, <double>[6, 8]);
    });
  });

  group('StatCluster', () {
    List<StatTile> tiles(int n) => <StatTile>[
      for (var i = 0; i < n; i++)
        StatTile(eyebrow: 'Figure $i', value: 60 + i, unit: TiqUnit.percent),
    ];

    test('four is the maximum on a phone', () {
      expect(() => StatCluster(tiles: tiles(5)), throwsA(isA<AssertionError>()));
      expect(() => StatCluster(tiles: tiles(4)), returnsNormally);
    });

    test('an empty cluster is an empty state, not a cluster', () {
      expect(
        () => StatCluster(tiles: const <StatTile>[]),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('Veld takes two', (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.veld(),
          SizedBox(width: 288, child: StatCluster(tiles: tiles(4))),
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('the phone lays out one column of horizontal tiles',
        (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          SizedBox(width: 288, child: StatCluster(tiles: tiles(3))),
        ),
      );
      final found = tester.widgetList<StatTile>(find.byType(StatTile)).toList();
      expect(found, hasLength(3));
      for (final tile in found) {
        expect(tile.layout, StatTileLayout.horizontal);
      }
      // Stacked, not side by side.
      final tops = <double>[
        for (var i = 0; i < 3; i++) tester.getTopLeft(find.byType(StatTile).at(i)).dy,
      ];
      expect(tops[1], greaterThan(tops[0]));
      expect(tops[2], greaterThan(tops[1]));
    });

    testWidgets('the cells are separated by a gap AND a rule', (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          SizedBox(width: 288, child: StatCluster(tiles: tiles(2))),
        ),
      );
      final rules = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(StatCluster),
              matching: find.byType(ColoredBox),
            ),
          )
          .where((b) => b.color == TiqSkin.night().palette.edgeStructure)
          .toList();
      expect(
        rules,
        hasLength(1),
        reason:
            'A hairline alone measures 1.72:1 on the Night surface and is '
            'invisible; a gap alone loses because a tile\'s own rows are 8dp '
            'apart and every inter-cell space must exceed every intra-cell '
            'one.',
      );
      final first = tester.getBottomLeft(find.byType(StatTile).first).dy;
      final second = tester.getTopLeft(find.byType(StatTile).at(1)).dy;
      expect(second - first, greaterThanOrEqualTo(StatCluster.gap));
    });

    testWidgets('a wide cluster goes two-up and the rules follow',
        (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          SizedBox(width: 640, child: StatCluster(tiles: tiles(4))),
        ),
      );
      for (final tile in tester.widgetList<StatTile>(find.byType(StatTile))) {
        expect(tile.layout, StatTileLayout.vertical);
      }
      final first = tester.getTopLeft(find.byType(StatTile).first);
      final second = tester.getTopLeft(find.byType(StatTile).at(1));
      expect(second.dx, greaterThan(first.dx));
      expect(second.dy, first.dy);
    });

    testWidgets('an odd count leaves a cell empty, never a stretched tile',
        (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          SizedBox(width: 640, child: StatCluster(tiles: tiles(3))),
        ),
      );
      final widths = <double>[
        for (var i = 0; i < 3; i++) tester.getSize(find.byType(StatTile).at(i)).width,
      ];
      expect(widths[2], closeTo(widths[0], 1));
    });
  });

  group('Eyebrow', () {
    test('the role is 11/700 at +4% tracking', () {
      for (final density in <TiqDensity>[TiqDensity.console, TiqDensity.field]) {
        final token = TiqType.forDensity(density).eyebrow;
        expect(token.size, 11);
        expect(token.weight, FontWeight.w700);
        expect(
          token.trackingPercent,
          4,
          reason:
              'Uppercase plus tracking is the most space-hungry setting in '
              'the system, and the eyebrow is a stat tile\'s only label '
              'channel. +8% cost "BESKIKBAARHEID OP RAK" a third line.',
        );
        expect(token.uppercase, isTrue);
      }
      expect(TiqType.veld.eyebrow.trackingPercent, 4);
    });

    testWidgets('it uppercases for display and keeps the sentence for readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        skinned(TiqSkin.night(), const Eyebrow('On-shelf availability')),
      );
      expect(find.text('ON-SHELF AVAILABILITY'), findsOneWidget);
      final node = tester.getSemantics(find.byType(Eyebrow));
      expect(
        node.label,
        'On-shelf availability',
        reason:
            'toUpperCase() at the call site puts the uppercase in the data, '
            'where a screen reader spells it out.',
      );
      handle.dispose();
    });

    testWidgets('it wraps to two lines and no further', (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const SizedBox(width: 80, child: Eyebrow('Beskikbaarheid op rak')),
        ),
      );
      final text = tester.widget<Text>(
        find.descendant(of: find.byType(Eyebrow), matching: find.byType(Text)),
      );
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('Provisional and final', () {
    testWidgets('a provisional figure keeps ink-1 and gains a dotted rule',
        (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const FigureSlot(
            value: 84,
            role: TiqTypeToken(
              name: 'figure.l',
              kind: TiqTypeKind.figure,
              size: 32,
              weight: FontWeight.w600,
              height: 1.05,
            ),
            state: FigureState.provisional,
            semanticsLabel: '84, provisional',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(FigureSlot), findsOneWidget);
    });

    testWidgets('the reconciliation line says both numbers in one sentence',
        (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const SizedBox(
            width: 320,
            child: ReconciliationLine(
              finalValue: 71,
              seenValue: 84,
              voice: ReconciliationVoice.console,
              reason: "Two sections' photos arrived after scoring.",
            ),
          ),
        ),
      );
      expect(find.text('Scored'), findsOneWidget);
      expect(find.text('— the phone showed'), findsOneWidget);
      expect(
        find.text("Two sections' photos arrived after scoring."),
        findsOneWidget,
      );
    });

    testWidgets('the two voices are two string sets', (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const SizedBox(
            width: 320,
            child: ReconciliationLine(
              finalValue: 71,
              seenValue: 84,
              voice: ReconciliationVoice.agent,
            ),
          ),
        ),
      );
      expect(find.text('Now scored'), findsOneWidget);
      expect(find.text('— it was'), findsOneWidget);
      expect(
        find.text('— the phone showed'),
        findsNothing,
        reason:
            'The manager never saw 84, and the agent did. One arithmetic, two '
            'voices, and neither string is shared.',
      );
    });

    testWidgets('the reconciliation delta is neutral, never good or bad',
        (tester) async {
      final skin = TiqSkin.night();
      await tester.pumpWidget(
        skinned(
          skin,
          const SizedBox(
            width: 320,
            child: ReconciliationLine(
              finalValue: 71,
              seenValue: 84,
              voice: ReconciliationVoice.console,
            ),
          ),
        ),
      );
      final triangle = tester
          .widgetList<TiqMark>(find.byType(TiqMark))
          .firstWhere((m) => m.shape == MarkShape.deltaHollowDown);
      expect(triangle.color, skin.palette.ink3);
      expect(triangle.color, isNot(skin.palette.bad));
      expect(triangle.color, isNot(skin.palette.good));
    });

    testWidgets('nothing is struck through', (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const SizedBox(
            width: 320,
            child: ReconciliationLine(
              finalValue: 71,
              seenValue: 84,
              voice: ReconciliationVoice.console,
            ),
          ),
        ),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.decoration, isNot(TextDecoration.lineThrough));
      }
    });

    testWidgets('provisional and confirmed are one shape at two states',
        (tester) async {
      for (final confirmed in <bool>[false, true]) {
        await tester.pumpWidget(
          skinned(TiqSkin.night(), ProvisionalMarker(confirmed: confirmed)),
        );
        final mark = tester.widget<TiqMark>(find.byType(TiqMark));
        expect(
          mark.shape,
          confirmed ? MarkShape.filledCircle : MarkShape.hollowCircle,
        );
        expect(
          find.text(confirmed ? 'Confirmed' : 'Provisional'),
          findsOneWidget,
        );
      }
    });
  });
}
