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

void main() {
  group('a delta never stands beside nothing', () {
    test('a missing figure removes the delta', () {
      expect(
        DeltaRule.resolve(figureState: FigureState.missing, delta: _fall),
        DeltaSuppression.nullFigure,
      );
    });

    test('a not-measured figure removes the delta', () {
      expect(
        DeltaRule.resolve(figureState: FigureState.notMeasured, delta: _fall),
        DeltaSuppression.nullFigure,
      );
    });

    testWidgets('the slot renders nothing at all beside a null', (
      tester,
    ) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const DeltaSlot(data: _fall, figureState: FigureState.missing),
        ),
      );
      expect(
        find.byType(Delta),
        findsNothing,
        reason:
            'Ticket #392: never an arrow next to nothing. The slot is removed '
            'and not greyed — a greyed delta is still a delta, and the reader '
            'still reads the arrow.',
      );
      expect(find.byType(Text), findsNothing);
    });
  });

  group('a low sample loses its delta', () {
    test('the current window below threshold suppresses it', () {
      expect(
        DeltaRule.resolve(
          figureState: FigureState.lowSample,
          delta: _fall,
          sampling: const FigureSampling(kind: MetricKind.rate, n: 3),
        ),
        DeltaSuppression.lowSample,
      );
    });

    test('exactly at the threshold is the normal treatment', () {
      expect(
        DeltaRule.resolve(
          figureState: FigureState.measured,
          delta: _fall,
          sampling: const FigureSampling(
            kind: MetricKind.rate,
            n: 5,
            baselineN: 5,
          ),
        ),
        DeltaSuppression.none,
        reason: 'The boundary is not a gradient.',
      );
    });

    test('a thin BASELINE suppresses it even when the figure is healthy', () {
      // Gauteng North loses week 37 to a strike, gets one visit at 100%, then
      // twenty visits at 84% in week 38. The figure is good; the comparison is
      // a verdict computed against a single visit.
      expect(
        DeltaRule.resolve(
          figureState: FigureState.measured,
          delta: _fall,
          sampling: const FigureSampling(
            kind: MetricKind.rate,
            n: 20,
            baselineN: 1,
          ),
        ),
        DeltaSuppression.thinBaseline,
      );
    });

    testWidgets('a suppressed delta is replaced by words, never by a gap', (
      tester,
    ) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const DeltaSlot(
            data: _fall,
            figureState: FigureState.measured,
            sampling: FigureSampling(
              kind: MetricKind.rate,
              n: 20,
              baselineN: 1,
            ),
          ),
        ),
      );
      expect(find.byType(Delta), findsNothing);
      expect(
        find.text(DeltaStrings.defaults.baselineTooThin),
        findsOneWidget,
        reason:
            'The reader has to know the comparison was withheld rather than '
            'that it was zero.',
      );
    });

    test(
      'a thin sample with no count still suppresses, without inventing one',
      () {
        expect(FigureSampling.unknownAndThin.isLowSample, isTrue);
        expect(FigureSampling.unknownAndThin.n, isNull);
      },
    );

    test('no sampling information is not a low sample', () {
      expect(FigureSampling.unknown.isLowSample, isFalse);
      expect(
        DeltaRule.resolve(figureState: FigureState.measured, delta: _fall),
        DeltaSuppression.none,
      );
    });
  });

  group('the triangle is drawn, not typed', () {
    testWidgets('no delta renders U+25B2 or U+25BC', (tester) async {
      for (final direction in DeltaDirection.values) {
        await tester.pumpWidget(
          skinned(
            TiqSkin.night(),
            Delta(
              data: DeltaData(
                direction: direction,
                sentiment: TiqSentiment.good,
                magnitude: 4,
              ),
            ),
          ),
        );
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          expect(
            text.data ?? '',
            isNot(anyOf(contains('▲'), contains('▼'))),
            reason:
                'Onest does not carry U+25B2/U+25BC once pyftsubset has run, '
                'and the PDF exporter rendered them as nothing at all (#401). '
                'Every triangle in this system is a path.',
          );
        }
        expect(find.byType(TiqMark), findsOneWidget);
      }
    });

    test('direction and sentiment are two independent fields', () {
      // A stock-out count going up is bad; a spoilage count going down is
      // good. Neither can be derived from the other.
      const badRise = DeltaData(
        direction: DeltaDirection.up,
        sentiment: TiqSentiment.bad,
        magnitude: 12,
      );
      const goodFall = DeltaData(
        direction: DeltaDirection.down,
        sentiment: TiqSentiment.good,
        magnitude: 12,
      );
      expect(badRise.direction, DeltaDirection.up);
      expect(badRise.sentiment, TiqSentiment.bad);
      expect(goodFall.direction, DeltaDirection.down);
      expect(goodFall.sentiment, TiqSentiment.good);
    });

    test("the wire's warn level renders neutral, never amber", () {
      expect(TiqSentiment.fromWire('warn'), TiqSentiment.neutral);
      expect(TiqSentiment.fromWire('anything else'), TiqSentiment.neutral);
      expect(TiqSentiment.fromWire('good'), TiqSentiment.good);
      expect(TiqSentiment.fromWire('bad'), TiqSentiment.bad);
      final skin = TiqSkin.night();
      expect(TiqSentiment.neutral.inkOn(skin), skin.palette.ink3);
    });
  });

  group('no baseline is words, never infinity', () {
    testWidgets('a null magnitude renders "up from none"', (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const Delta(
            data: DeltaData(
              direction: DeltaDirection.up,
              sentiment: TiqSentiment.good,
            ),
          ),
        ),
      );
      expect(find.text(DeltaStrings.defaults.upFromNone), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(contains('∞')));
        expect(text.data ?? '', isNot(contains('n/a')));
      }
    });

    testWidgets('a measured zero movement is the flat bar and a word', (
      tester,
    ) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const Delta(
            data: DeltaData(
              direction: DeltaDirection.flat,
              sentiment: TiqSentiment.neutral,
              magnitude: 0,
            ),
          ),
        ),
      );
      final mark = tester.widget<TiqMark>(find.byType(TiqMark));
      expect(mark.shape, MarkShape.deltaFlat);
      expect(find.text(DeltaStrings.defaults.noChange), findsOneWidget);
    });
  });
}
