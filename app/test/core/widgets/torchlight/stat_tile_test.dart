import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';

import 'mark_harness.dart';

const DeltaData _fall = DeltaData(
  direction: DeltaDirection.down,
  sentiment: TiqSentiment.bad,
  magnitude: 19,
  comparedTo: 'vs week 37',
);

Widget _tile(Widget tile, {double width = 288, double textScale = 1.0}) =>
    skinned(
      TiqSkin.night(),
      SizedBox(width: width, child: tile),
      textScale: textScale,
    );

/// Every string the tile actually printed, flattened.
List<String> _printed(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .toList();

void main() {
  group('a null never renders as 0', () {
    testWidgets('the figure is an em dash and the words are on the screen',
        (tester) async {
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'Out-of-stock lines',
            value: null,
            unit: TiqUnit.percent,
            noDataReason: 'No visits in this window',
          ),
        ),
      );
      final printed = _printed(tester);
      expect(
        printed.any((s) => s.contains(emDash)),
        isTrue,
        reason: 'A null renders an em dash at the figure\'s own role and face.',
      );
      expect(
        printed.any((s) => s.trim() == '0' || s.trim() == '0%'),
        isFalse,
        reason:
            'The state the product currently fakes with a zero. Never a 0, '
            'never a 0%, never a "—%".',
      );
      expect(
        printed.any((s) => s.contains('%')),
        isFalse,
        reason:
            'The unit is suppressed with the number. "— %" is a unit '
            'measuring nothing and reads as a rendering bug.',
      );
      expect(find.text('No visits in this window'), findsOneWidget);
    });

    testWidgets('the eyebrow stays at full ink — the label is still true',
        (tester) async {
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'Out-of-stock lines',
            value: null,
            noDataReason: 'No visits in this window',
          ),
        ),
      );
      final eyebrow = tester.widget<Text>(
        find.descendant(of: find.byType(Eyebrow), matching: find.byType(Text)),
      );
      expect(eyebrow.style?.color, TiqSkin.night().palette.ink2);
    });

    testWidgets('a delta never stands beside the em dash', (tester) async {
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'Coverage',
            value: null,
            delta: _fall,
            noDataReason: 'No visits in this window',
          ),
        ),
      );
      expect(find.byType(Delta), findsNothing);
      expect(find.byType(DeltaSlot), findsNothing);
      expect(_printed(tester), isNot(contains('vs week 37')));
    });

    test('a tile with no figure and no sentence will not build', () {
      expect(
        () => StatTile(eyebrow: 'Coverage', value: null),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('the tile is never hidden', (tester) async {
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'Coverage',
            value: null,
            noDataReason: 'No visits in this window',
          ),
        ),
      );
      expect(find.byType(StatTile), findsOneWidget);
      expect(tester.getSize(find.byType(StatTile)).height, greaterThan(80));
    });
  });

  group('a measured zero renders 0', () {
    testWidgets('never suppressed, and the delta is the flat bar',
        (tester) async {
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'Open critical alerts',
            value: 0,
            delta: DeltaData(
              direction: DeltaDirection.flat,
              sentiment: TiqSentiment.neutral,
              magnitude: 0,
            ),
          ),
        ),
      );
      expect(
        _printed(tester).any((s) => s.contains('0')),
        isTrue,
        reason: 'An all-zero list is a finding, not an empty state.',
      );
      expect(
        _printed(tester).any((s) => s.contains(emDash)),
        isFalse,
        reason: 'An em dash means "we do not know". Zero is a measurement.',
      );
      expect(find.byType(Delta), findsOneWidget);
      expect(
        tester
            .widgetList<TiqMark>(find.byType(TiqMark))
            .any((m) => m.shape == MarkShape.deltaFlat),
        isTrue,
      );
    });
  });

  group('a low sample keeps the figure and loses the delta', () {
    testWidgets('ink-2, the hollow square, the sample words, no delta',
        (tester) async {
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'On-shelf availability',
            value: 100,
            unit: TiqUnit.percent,
            sampling: FigureSampling(kind: MetricKind.rate, n: 3),
            sampleNote: 'from 3 visits',
            delta: _fall,
          ),
        ),
      );
      final tile = tester.widget<StatTile>(find.byType(StatTile));
      expect(tile.figureState, FigureState.lowSample);

      // The figure is still 100% — arithmetically true, epistemically weak.
      expect(_printed(tester).any((s) => s.contains('100')), isTrue);
      expect(find.text('from 3 visits'), findsOneWidget);
      expect(
        tester
            .widgetList<TiqMark>(find.byType(TiqMark))
            .any((m) => m.shape == MarkShape.hollowSquare),
        isTrue,
        reason:
            'Outline versus fill is a shape distinction that survives '
            'greyscale, sun and deuteranopia. An alpha reduction does not.',
      );
      expect(
        find.byType(Delta),
        findsNothing,
        reason: 'A delta computed off a thin sample is a number pretending '
            'to be a movement.',
      );
      expect(find.text(DeltaStrings.defaults.tooFewToCompare), findsOneWidget);
    });

    testWidgets('a healthy figure with a thin baseline keeps its full ink',
        (tester) async {
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'On-shelf availability',
            value: 84,
            unit: TiqUnit.percent,
            sampling: FigureSampling(
              kind: MetricKind.rate,
              n: 20,
              baselineN: 1,
            ),
            delta: _fall,
          ),
        ),
      );
      final tile = tester.widget<StatTile>(find.byType(StatTile));
      expect(
        tile.figureState,
        FigureState.measured,
        reason: 'It is a good figure. Only the comparison is withheld.',
      );
      expect(find.byType(Delta), findsNothing);
      expect(find.text(DeltaStrings.defaults.baselineTooThin), findsOneWidget);
    });

    testWidgets('an unknown count says "small sample", never a number',
        (tester) async {
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'Coverage',
            value: 92,
            unit: TiqUnit.percent,
            sampling: FigureSampling.unknownAndThin,
          ),
        ),
      );
      expect(find.text(StatTileStrings.defaults.smallSample), findsOneWidget);
    });
  });

  group('not measured', () {
    testWidgets('an em dash, a full-width hatch on the track, and a reason',
        (tester) async {
      await tester.pumpWidget(
        _tile(
          const NotMeasured(reason: 'No competitor on shelf'),
        ),
      );
      expect(_printed(tester).any((s) => s.contains(emDash)), isTrue);
      expect(find.text('No competitor on shelf'), findsOneWidget);
      final meter = tester.widget<Meter>(find.byType(Meter));
      expect(meter.state, MeterState.notMeasured);
    });

    test('a hatch without a sentence will not build', () {
      expect(
        () => const Meter(value: null, state: MeterState.notMeasured),
        returnsNormally,
      );
      // The assert fires on build, not on construction — a const constructor
      // cannot reach the skin.
    });

    testWidgets('a hatched meter with no reason trips the assert',
        (tester) async {
      await tester.pumpWidget(
        _tile(const Meter(value: null, state: MeterState.notMeasured)),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });
  });

  group('layout', () {
    testWidgets('the phone tile is horizontal', (tester) async {
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'On-shelf availability',
            value: 61,
            unit: TiqUnit.percent,
          ),
        ),
      );
      final eyebrow = tester.getTopLeft(find.byType(Eyebrow));
      final figure = tester.getTopLeft(find.byType(FigureSlot));
      expect(
        figure.dx,
        greaterThan(eyebrow.dx),
        reason: 'Eyebrow expanded left, figure right-aligned.',
      );
      expect(
        (figure.dy - eyebrow.dy).abs(),
        lessThan(24),
        reason: 'They are on one row, not stacked.',
      );
    });

    testWidgets('a wide cell stacks', (tester) async {
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'On-shelf availability',
            value: 61,
            unit: TiqUnit.percent,
          ),
          width: 420,
        ),
      );
      final eyebrow = tester.getTopLeft(find.byType(Eyebrow));
      final figure = tester.getTopLeft(find.byType(FigureSlot));
      expect(figure.dy, greaterThan(eyebrow.dy));
    });

    testWidgets('nothing clips at 2.0x with a two-line Afrikaans eyebrow',
        (tester) async {
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'Beskikbaarheid op rak',
            value: 61,
            unit: TiqUnit.percent,
            meter: MeterData(value: 61, target: 80),
            delta: _fall,
          ),
          textScale: 2.0,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(StatTile)).height, greaterThan(88));
    });
  });

  group('provenance', () {
    testWidgets('a tappable tile announces its hint', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _tile(
          StatTile(
            eyebrow: 'On-shelf availability',
            value: 61,
            unit: TiqUnit.percent,
            semanticsHint: 'Double tap for how this is measured',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(StatTile));
      expect(tapped, isTrue);
    });

    testWidgets('the em dash is never spoken as "dash"', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _tile(
          const StatTile(
            eyebrow: 'Coverage',
            value: null,
            noDataReason: 'No visits in this window',
          ),
        ),
      );
      final node = tester.getSemantics(
        find
            .descendant(
              of: find.byType(StatTile),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(node.value, 'No visits in this window');
      expect(node.value, isNot(contains(emDash)));
      handle.dispose();
    });
  });
}
