import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/figure_slot.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// The one figure primitive: two faces, four unknown states, measured fitting.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    TiqSkin? skin,
    double textScale = 1.0,
    double width = 360,
  }) async {
    final resolved = skin ?? TiqSkin.night();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          theme: ThemeData(extensions: <ThemeExtension<dynamic>>[resolved]),
          home: Scaffold(
            body: Center(
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );
  }

  /// The `RichText` the FigureSlot itself built — not the first one in the
  /// tree, which belongs to the Scaffold's own chrome.
  RichText richOf(WidgetTester tester) => tester.widget<RichText>(
    find.descendant(
      of: find.byType(FigureSlot),
      matching: find.byType(RichText),
    ),
  );

  /// The leaf spans a FigureSlot actually rendered, in order.
  ///
  /// `Text.rich` nests the span it is given inside one of its own, so the
  /// runs are two levels down; walking to the leaves is what makes this
  /// independent of how many wrappers Text adds.
  List<TextSpan> spansOf(WidgetTester tester) {
    final leaves = <TextSpan>[];
    void walk(InlineSpan span) {
      if (span is! TextSpan) return;
      if (span.text != null) leaves.add(span);
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child);
      }
    }

    walk(richOf(tester).text);
    return leaves;
  }

  group('two faces, one figure', () {
    testWidgets('the digits are mono and the affix is Onest', (tester) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        FigureSlot(
          value: 1284990,
          role: skin.text.figureL,
          unit: TiqUnit.currency,
        ),
        skin: skin,
      );
      final spans = spansOf(tester);
      expect(spans.map((s) => s.text), <String>['R ', '1,284,990']);
      expect(
        spans[0].style!.fontFamily,
        TiqFonts.prose,
        reason: 'The R is language, and Onest is the language face.',
      );
      expect(
        spans[1].style!.fontFamily,
        TiqFonts.mono,
        reason:
            'Onest has no slashed zero, proportional digits, and an I and an l '
            'that are the same shape. None of that matters in a sentence and '
            'all of it matters in a column of money.',
      );
    });

    testWidgets('tabular figures are on, and never on the affix', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        FigureSlot(value: 81, role: skin.text.figureM, unit: TiqUnit.percent),
        skin: skin,
      );
      final spans = spansOf(tester);
      expect(
        spans[0].style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(spans[1].text, '%');
      expect(spans[1].style!.fontFeatures, isEmpty);
      expect(
        spans[1].style!.letterSpacing,
        0,
        reason:
            'A mono role declares tracking 0; an affix that inherited a '
            'negative one would kern into the digit beside it.',
      );
    });

    testWidgets('a prose role is refused', (tester) async {
      final skin = TiqSkin.night();
      await pump(tester, FigureSlot(value: 1, role: skin.text.body));
      expect(tester.takeException(), isAssertionError);
    });
  });

  group('unknown versus zero, on screen', () {
    testWidgets('a measured zero keeps its ink and its unit', (tester) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        FigureSlot(value: 0, role: skin.text.figureL, unit: TiqUnit.percent),
        skin: skin,
      );
      final spans = spansOf(tester);
      expect(spans.map((s) => s.text), <String>['0', '%']);
      expect(spans[0].style!.color, skin.palette.ink1);
    });

    testWidgets('a null is an em dash in ink-3, at its own role and face', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        FigureSlot(
          value: null,
          role: skin.text.figureL,
          unit: TiqUnit.percent,
          color: skin.palette.good,
          semanticsLabel: 'No visits in this window',
        ),
        skin: skin,
      );
      final spans = spansOf(tester);
      expect(spans.map((s) => s.text), <String>['—']);
      expect(
        spans[0].style!.color,
        skin.palette.ink3,
        reason:
            'An em dash is ink-3 whatever the caller wanted. Its job is to '
            'read as an absence, and an absence in ink-1 reads as a value.',
      );
      expect(
        spans[0].style!.fontSize,
        skin.text.figureL.size,
        reason: 'At the figure\'s own role — the tile keeps its place.',
      );
      expect(
        spans[0].style!.fontFamily,
        TiqFonts.mono,
        reason: 'And its own face.',
      );
    });

    testWidgets('a low sample keeps the number at ink-2', (tester) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        FigureSlot(
          value: 71.4,
          role: skin.text.figureL,
          unit: TiqUnit.percent,
          state: FigureState.lowSample,
          semanticsLabel: 'Seventy-one point four percent, low sample',
        ),
        skin: skin,
      );
      final spans = spansOf(tester);
      expect(spans[0].text, '71.4');
      expect(spans[0].style!.color, skin.palette.ink2);
    });

    testWidgets('a provisional figure carries a dotted underline', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        FigureSlot(
          value: 71,
          role: skin.text.figureL,
          state: FigureState.provisional,
          semanticsLabel: 'Provisional score 71',
        ),
        skin: skin,
      );
      final style = spansOf(tester)[0].style!;
      expect(style.decoration, TextDecoration.underline);
      expect(style.decorationStyle, TextDecorationStyle.dotted);
    });

    testWidgets('an unknown state without a sentence in words is refused', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pump(tester, FigureSlot(value: null, role: skin.text.figureL));
      expect(
        tester.takeException(),
        isAssertionError,
        reason:
            'An em dash announced as "em dash" is not the sentence in words '
            'the design asks for.',
      );
    });
  });

  group('fitting is measured, never guessed', () {
    testWidgets('a long figure steps down the declared candidates', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        FigureSlot(
          value: 1284990,
          role: skin.text.heroFigure,
          fit: <TiqTypeToken>[
            skin.text.heroFigure,
            skin.text.heroFigureCompact,
            skin.text.figureL,
          ],
          unit: TiqUnit.currency,
        ),
        skin: skin,
        // "R 1,284,990" at JetBrains Mono 72 cannot fit 360dp. That is open
        // question 3(a) in the ruling, and the answer is that the formatter
        // runs first and the fitting rule measures the result.
        width: 320,
      );
      expect(
        spansOf(tester)[1].style!.fontSize,
        lessThan(skin.text.heroFigure.size),
      );
    });

    testWidgets('a short figure keeps the largest candidate', (tester) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        FigureSlot(
          value: 71,
          role: skin.text.heroFigure,
          fit: <TiqTypeToken>[
            skin.text.heroFigure,
            skin.text.heroFigureCompact,
          ],
        ),
        skin: skin,
      );
      expect(spansOf(tester)[0].style!.fontSize, skin.text.heroFigure.size);
    });

    testWidgets('there is no FittedBox anywhere in it', (tester) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        FigureSlot(value: 1284990.5, role: skin.text.heroFigure),
        skin: skin,
        width: 100,
      );
      expect(
        find.byType(FittedBox),
        findsNothing,
        reason:
            'Optically shrinking one figure in a baseline row breaks the row '
            'baseline and puts two numbers at two sizes beside each other — '
            'which is what a tabular column exists to prevent.',
      );
    });
  });

  group('text scaling', () {
    testWidgets('hero.figure caps at 1.6x; everything else reaches 2.0x', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        FigureSlot(value: 71, role: skin.text.heroFigure),
        skin: skin,
        textScale: 2.0,
      );
      final hero = richOf(tester);
      expect(
        hero.textScaler.scale(10),
        closeTo(16, 0.01),
        reason:
            'The one documented exception to the 2.0 clamp: above 1.6 no '
            'fitting rule saves a 72px number on a 360dp screen. The cap lives '
            'on the token, visible to anyone reading the scale.',
      );

      await pump(
        tester,
        FigureSlot(value: 71, role: skin.text.figureM),
        skin: skin,
        textScale: 2.0,
      );
      final normal = richOf(tester);
      expect(normal.textScaler.scale(10), closeTo(20, 0.01));
    });

    testWidgets('the cap is applied through TextScaler, not as a factor', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        FigureSlot(value: 71, role: skin.text.heroFigure),
        skin: skin,
        textScale: 2.0,
      );
      expect(
        spansOf(tester)[0].style!.fontSize,
        skin.text.heroFigure.size,
        reason:
            'The declared size is untouched; the scaler is what is clamped. A '
            'factor multiplied into a font size stops being right the moment '
            'the platform stops being linear.',
      );
    });
  });

  group('locale', () {
    testWidgets('Afrikaans groups on a no-break space', (tester) async {
      final skin = TiqSkin.night();
      await pump(
        tester,
        Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: const Locale('af'),
            child: FigureSlot(value: 1284990.5, role: skin.text.figureL),
          ),
        ),
        skin: skin,
      );
      expect(spansOf(tester)[0].text, '1 284 990,5');
    });
  });

  group('semantics', () {
    testWidgets('the sentence in words replaces the glyphs', (tester) async {
      final skin = TiqSkin.night();
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        FigureSlot(
          value: null,
          role: skin.text.figureL,
          unit: TiqUnit.percent,
          semanticsLabel: 'No visits in this window',
        ),
        skin: skin,
      );
      expect(find.bySemanticsLabel('No visits in this window'), findsOneWidget);
      handle.dispose();
    });
  });
}
