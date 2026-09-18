import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/rating_band.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

AppLocalizations _l10n(String locale) => lookupAppLocalizations(Locale(locale));

void main() {
  test('the wire is unchanged — green/amber/red, exactly as the server sends '
      'them', () {
    expect(RatingBand.values.map((b) => b.wire).toList(), [
      'green',
      'amber',
      'red',
    ]);
    for (final wire in ['green', 'amber', 'red']) {
      expect(RatingBand.fromWire(wire)?.wire, wire);
    }
  });

  test('an unknown wire value is not guessed at', () {
    expect(RatingBand.fromWire('Amber'), isNull);
    expect(RatingBand.fromWire('yellow'), isNull);
    expect(RatingBand.fromWire(''), isNull);
    // Screens that must show something read it as the conservative band.
    expect(RatingBand.ofWire('yellow'), RatingBand.gap);
  });

  test('display names in both shipped languages', () {
    final en = _l10n('en');
    expect(RatingBand.healthy.word(en), 'Healthy');
    expect(RatingBand.watch.word(en), 'Watch');
    expect(RatingBand.gap.word(en), 'Gap');

    final af = _l10n('af');
    expect(RatingBand.healthy.word(af), 'Gesond');
    expect(RatingBand.watch.word(af), 'Dophou');
    expect(RatingBand.gap.word(af), 'Gaping');
  });

  test('no display name is a colour name', () {
    for (final locale in ['en', 'af']) {
      final l10n = _l10n(locale);
      for (final band in RatingBand.values) {
        expect(
          band.word(l10n).toLowerCase(),
          isNot(
            isIn(const ['green', 'amber', 'red', 'groen', 'oranje', 'rooi']),
          ),
          reason: '${band.name} in $locale',
        );
      }
    }
  });

  test('every band carries a mark, and no two bands share one', () {
    final marks = RatingBand.values.map((b) => b.mark).toList();
    expect(marks.toSet(), hasLength(marks.length));
    for (final mark in marks) {
      expect(mark, isNotEmpty);
    }
  });

  test('the marked word is the mark and the word, in that order', () {
    final en = _l10n('en');
    expect(RatingBand.watch.markedWord(en), '! Watch');
    expect(RatingBand.healthy.markedWord(en), '✓ Healthy');
    expect(RatingBand.gap.markedWord(en), '✕ Gap');
  });

  // The whole point of the rename: a band never borrows the brand's amber.
  test('no band reaches for the warn/amber slot', () {
    for (final band in RatingBand.values) {
      expect(
        band.status,
        isNot(LumenStatus.warn),
        reason: '${band.name} must take a severity token, never amber',
      );
      expect(band.status, anyOf(LumenStatus.good, LumenStatus.crit));
    }

    for (final colors in [TiqColors.light, TiqColors.dark]) {
      for (final band in RatingBand.values) {
        final ink = band.inkOn(colors);
        expect(ink, isNot(colors.warn), reason: '${band.name} ink');
        expect(ink, isNot(colors.brand), reason: '${band.name} ink');
      }
      expect(RatingBand.healthy.inkOn(colors), colors.good);
      // Watch and Gap share the bad family — told apart by mark and word. A
      // band label is text, so it takes the text grade, not the mark colour.
      expect(RatingBand.watch.inkOn(colors), colors.critText);
      expect(RatingBand.gap.inkOn(colors), colors.critText);
    }

    expect(RatingBand.healthy.glassInk(), LumenGlass.onDarkGood);
    for (final band in [RatingBand.watch, RatingBand.gap]) {
      expect(band.glassInk(), LumenGlass.onDarkCrit);
      expect(band.glassInk(), isNot(LumenGlass.onDarkWarn));
    }
  });
}
