import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';

/// The one formatter, in both locales, in every state a figure can be in.
void main() {
  group('grouping and the decimal mark', () {
    test('English groups on a comma and marks on a point', () {
      expect(TiqNumber.en.format(1284990.5), '1,284,990.5');
      expect(TiqNumber.en.format(48210), '48,210');
      expect(TiqNumber.en.format(999), '999');
      expect(TiqNumber.en.format(1000), '1,000');
      expect(TiqNumber.en.format(100000), '100,000');
    });

    test('Afrikaans groups on a no-break space and marks on a comma', () {
      expect(TiqNumber.af.format(1284990.5), '1 284 990,5');
      expect(TiqNumber.af.format(48210), '48 210');
      expect(TiqNumber.af.format(4.2), '4,2');
    });

    test('the Afrikaans group separator does not break a line', () {
      expect(
        TiqNumberSymbols.af.group,
        ' ',
        reason:
            'A plain space lets "1 284" wrap to "1" and "284" at the end of a '
            'line, which is two numbers.',
      );
      expect(TiqNumberSymbols.af.group, isNot(' '));
    });

    test('English is byte-identical to what the app renders today', () {
      // The screens currently on NumberFormat('#,##0.#', 'en_US') must not
      // move when they are repointed at this. If this row ever changes, a
      // hundred screens change with it.
      for (final MapEntry(key: value, value: expected) in <num, String>{
        0: '0',
        1: '1',
        1.0: '1',
        1.05: '1.1',
        48210: '48,210',
        1284990.5: '1,284,990.5',
      }.entries) {
        expect(TiqNumber.en.format(value), expected, reason: 'value $value');
      }
    });
  });

  group('the minus sign', () {
    test('is U+2212 and never a hyphen', () {
      final out = TiqNumber.en.format(-31, unit: TiqUnit.percent);
      expect(out, '−31%');
      expect(out.contains('-'), isFalse, reason: 'That is a hyphen-minus.');
      expect(minusSign, '−');
    });

    test('never appears on a value that rounds to zero', () {
      // "−0%" is a movement that did not happen and a minus in front of it is
      // a claim that it did.
      expect(TiqNumber.en.format(-0.01, unit: TiqUnit.percent), '0%');
      expect(TiqNumber.en.format(-0.0), '0');
      expect(TiqNumber.af.format(-0.04), '0');
    });

    test('a signed rise gets an explicit plus, a signed zero does not', () {
      expect(TiqNumber.en.format(4.2, signed: true, unit: TiqUnit.percent),
          '+4.2%');
      expect(TiqNumber.en.format(0, signed: true), '0');
      expect(TiqNumber.en.format(-4.2, signed: true), '−4.2');
    });

    test('no locale can emit a hyphen as a minus', () {
      for (final symbols in TiqNumberSymbols.all) {
        final n = TiqNumber(symbols);
        for (final v in <num>[-1, -1000, -0.5, -1284990.5]) {
          expect(
            n.format(v).contains('-'),
            isFalse,
            reason: '${symbols.languageCode} format($v) used a hyphen.',
          );
        }
      }
    });
  });

  group('units', () {
    test('rand is a prefix with a space in it', () {
      expect(TiqNumber.en.format(1284990, unit: TiqUnit.currency),
          'R 1,284,990');
      expect(
        TiqNumber.af.format(1284990, unit: TiqUnit.currency),
        'R 1 284 990',
      );
      final split = TiqNumber.en.split(1284990, unit: TiqUnit.currency);
      expect(
        split.prefix,
        'R ',
        reason:
            'The R is the Onest run and the digits are the mono run. They are '
            'split so a widget can set them in two faces.',
      );
      expect(split.run, '1,284,990');
    });

    test('percent is hard against the digits; a word is not', () {
      expect(TiqNumber.en.split(81, unit: TiqUnit.percent).suffix, '%');
      expect(
        TiqNumber.en.split(4, unit: TiqUnit.worded('pts')).suffix,
        ' pts',
      );
      expect(
        TiqNumber.en.split(4, unit: TiqUnit.worded('x', tight: true)).suffix,
        'x',
      );
    });

    test('a worded unit is the caller\'s string, already translated', () {
      // This class does not own language. A plural is a translated string and
      // it arrives here finished.
      expect(
        TiqNumber.af.format(4, unit: TiqUnit.worded('winkels')),
        '4 winkels',
      );
    });
  });

  group('unknown versus zero', () {
    test('a measured zero renders 0 and is never suppressed', () {
      final zero = TiqNumber.en.split(0, unit: TiqUnit.percent);
      expect(zero.run, '0');
      expect(zero.suffix, '%', reason: 'A real zero keeps its unit.');
      expect(zero.state, FigureState.measured);
      expect(
        zero.allowsDelta,
        isTrue,
        reason: 'A measured zero gets a flat delta bar, not no delta.',
      );
    });

    test('a null renders an em dash with the unit suppressed', () {
      final missing = TiqNumber.en.split(null, unit: TiqUnit.percent);
      expect(missing.run, '—');
      expect(missing.prefix, isEmpty);
      expect(
        missing.suffix,
        isEmpty,
        reason: '"— %" is a unit measuring nothing and reads as a bug.',
      );
      expect(missing.state, FigureState.missing);
      expect(
        missing.allowsDelta,
        isFalse,
        reason: 'A delta never stands beside nothing.',
      );
    });

    test('a null is not a zero, in either direction', () {
      expect(TiqNumber.en.format(null), isNot(TiqNumber.en.format(0)));
      expect(TiqNumber.en.format(0), isNot(emDash));
    });

    test('a non-finite number is missing, not a crash and not "NaN"', () {
      expect(TiqNumber.en.format(double.nan), emDash);
      expect(TiqNumber.en.format(double.infinity), emDash);
      expect(TiqNumber.en.split(double.nan).state, FigureState.missing);
    });

    test('not-measured is an em dash too, and keeps its own state', () {
      final nm = TiqNumber.en.split(
        42,
        unit: TiqUnit.percent,
        state: FigureState.notMeasured,
      );
      expect(nm.run, emDash);
      expect(
        nm.state,
        FigureState.notMeasured,
        reason:
            'A dimension nobody scored looks like a missing figure and is '
            'labelled differently: it carries a falling hatch on its track and '
            'a reason.',
      );
      expect(nm.allowsDelta, isFalse);
    });

    test('low sample keeps the number and loses the delta', () {
      final low = TiqNumber.en.split(
        71.4,
        unit: TiqUnit.percent,
        state: FigureState.lowSample,
      );
      expect(low.run, '71.4', reason: 'The figure is real; the sample is thin.');
      expect(low.suffix, '%');
      expect(
        low.allowsDelta,
        isFalse,
        reason:
            'A delta off a thin sample is a number pretending to be a '
            'movement — and this holds for a thin baseline too.',
      );
    });

    test('provisional keeps its figure and its delta rules', () {
      final p = TiqNumber.en.split(71, state: FigureState.provisional);
      expect(p.run, '71');
      expect(p.state, FigureState.provisional);
      expect(p.allowsDelta, isFalse);
    });
  });

  group('precision', () {
    test('no declared precision keeps one place and drops a trailing zero', () {
      expect(TiqNumber.en.format(4.0), '4');
      expect(TiqNumber.en.format(4.25), '4.3');
      expect(TiqNumber.en.format(4.20), '4.2');
    });

    test('a declared precision is kept, trailing zeros and all', () {
      // The server's `decimals` is a property of the METRIC, not of the value:
      // a metric reported to two places prints 4.10, because the second place
      // says the metric resolves that finely.
      expect(TiqNumber.en.format(4.1, decimals: 2), '4.10');
      expect(TiqNumber.en.format(4, decimals: 2), '4.00');
      expect(TiqNumber.en.format(4.567, decimals: 0), '5');
      expect(TiqNumber.af.format(4.1, decimals: 2), '4,10');
    });
  });

  group('locale resolution', () {
    testWidgets('reads the ambient locale', (tester) async {
      late TiqNumber resolved;
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('af'),
          delegates: const <LocalizationsDelegate<dynamic>>[
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Builder(
            builder: (context) {
              resolved = TiqNumber.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved.symbols.languageCode, 'af');
      expect(resolved.format(1284990.5), '1 284 990,5');
    });

    test('an unknown language falls back to English rather than throwing', () {
      expect(TiqNumber.forLocale(const Locale('zu')).symbols.languageCode, 'en');
      expect(TiqNumber.forLocale(null).symbols.languageCode, 'en');
    });
  });
}
