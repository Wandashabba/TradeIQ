import 'package:flutter/widgets.dart';

/// U+2212 MINUS SIGN.
///
/// A hyphen-minus is a word-joiner that happens to be on the keyboard. It is
/// narrower than a digit, it does not sit on the figure's arithmetic axis, and
/// in a tabular column it makes a negative number look indented rather than
/// negative. Every minus this app prints is this character, and
/// `tiq_number_test.dart` asserts that no formatter can emit the other one.
const String minusSign = '\u2212';

/// U+2014 EM DASH — the one mark that means "we do not know".
///
/// It is not a zero, not an empty string, and not the word "N/A". A tile is
/// never hidden and a grey "Unknown" chip is never shown: the figure keeps its
/// place in the column and says, in one glyph, that nobody measured it.
const String emDash = '\u2014';

/// Digit grouping and the decimal mark, per locale.
///
/// Declared here rather than read from CLDR at runtime. The app ships two
/// locales and a hundred figures; a CLDR version bump that silently moves
/// English from `1,284,990.5` to `1 284 990,5` would change every screen in
/// the product without a single line of the diff being about it. Adding a
/// locale means adding a member here and a test row, which is the point.
@immutable
class TiqNumberSymbols {
  const TiqNumberSymbols({
    required this.languageCode,
    required this.group,
    required this.decimal,
    required this.currencyPrefix,
  });

  final String languageCode;

  /// The thousands separator.
  final String group;

  /// The decimal mark.
  final String decimal;

  /// The currency affix, with its trailing space where it has one. South
  /// African rand is `R ` — a space, because `R1 284` reads as a serial
  /// number and `R 1 284` reads as money.
  final String currencyPrefix;

  /// English. `1,284,990.5` — which is what every screen in the app renders
  /// today, so switching an existing figure onto this formatter is a no-op.
  static const TiqNumberSymbols en = TiqNumberSymbols(
    languageCode: 'en',
    group: ',',
    decimal: '.',
    currencyPrefix: 'R ',
  );

  /// Afrikaans. `1 284 990,5` — a narrow no-break space groups, a comma marks
  /// the decimal. The space is U+00A0 and not U+0020 so a figure never wraps
  /// in the middle of itself at the end of a line.
  static const TiqNumberSymbols af = TiqNumberSymbols(
    languageCode: 'af',
    group: '\u00A0',
    decimal: ',',
    currencyPrefix: 'R\u00A0',
  );

  static const List<TiqNumberSymbols> all = <TiqNumberSymbols>[en, af];

  static TiqNumberSymbols forLanguage(String code) =>
      code == 'af' ? af : en;
}

/// What a figure is a quantity *of*.
///
/// Only the machine units live here — the ones that are a symbol rather than a
/// word. A worded unit ("pts", "stores", "cases") is a translated string and
/// belongs to `l10n`, so it arrives through [TiqUnit.worded] already
/// localised. This class does not own language.
@immutable
class TiqUnit {
  const TiqUnit._({
    this.prefix = '',
    this.suffix = '',
    this.isCurrency = false,
  });

  /// A bare number.
  static const TiqUnit none = TiqUnit._();

  /// `%`, hard against the figure.
  static const TiqUnit percent = TiqUnit._(suffix: '%');

  /// Rand. The prefix comes from the locale, so this is a marker the formatter
  /// resolves rather than a literal.
  static const TiqUnit currency = TiqUnit._(isCurrency: true);

  /// A unit the caller has already localised — `pts`, `winkels`, `cases`.
  /// A leading space is added; pass [tight] for one that hangs off the digits.
  factory TiqUnit.worded(String word, {bool tight = false}) =>
      TiqUnit._(suffix: tight ? word : ' $word');

  final String prefix;
  final String suffix;

  /// Whether the prefix comes from the locale rather than from this object.
  final bool isCurrency;
}

/// How much of a figure is real.
enum FigureState {
  /// A real measurement, including a real zero. A measured zero renders `0`,
  /// keeps its place and is **never** suppressed — an all-zero list is a
  /// finding, not an empty state.
  measured,

  /// Nobody sent a number. Em dash, ink-3, the figure's own role and face, the
  /// unit suppressed, no delta.
  missing,

  /// A number computed from too thin a sample. The figure stays at ink-2, the
  /// fill beside it is outlined instead of filled, and the delta is removed —
  /// for a thin baseline as well as a thin current period.
  lowSample,

  /// A dimension nobody scored. Em dash plus a full-width falling hatch on its
  /// track plus a reason — the reason is the caller's, not this class's.
  notMeasured,

  /// Server-stamped provisional. Console only; the agent app never shows one.
  provisional,
}

/// A figure, split into the three runs it is set in.
///
/// The split is the whole reason this type exists. The digits are JetBrains
/// Mono with tabular figures; the affixes are Onest, because `R` and `pts` are
/// language and Onest is the language face. Handing a widget one string would
/// force it to set the whole thing in one face and lose either the tabular
/// column or the affix.
@immutable
class FormattedFigure {
  const FormattedFigure({
    required this.prefix,
    required this.run,
    required this.suffix,
    required this.state,
    required this.allowsDelta,
  });

  /// Onest. `R ` or empty.
  final String prefix;

  /// JetBrains Mono, tabular. The digits, the group separators, the decimal
  /// mark and the minus — everything a reader compares column to column.
  final String run;

  /// Onest. `%`, ` pts`, or empty.
  final String suffix;

  final FigureState state;

  /// Whether a delta may stand beside this figure.
  ///
  /// False for everything except a plain measurement: a delta never stands
  /// beside nothing, and a delta computed off a thin sample is a number
  /// pretending to be a movement.
  final bool allowsDelta;

  /// The whole thing as one string — for a semantics label, a PDF cell, a
  /// test, or a caller that genuinely has one face. Never for a screen figure.
  String get plain => '$prefix$run$suffix';

  @override
  bool operator ==(Object other) =>
      other is FormattedFigure &&
      other.prefix == prefix &&
      other.run == run &&
      other.suffix == suffix &&
      other.state == state;

  @override
  int get hashCode => Object.hash(prefix, run, suffix, state);

  @override
  String toString() => 'FormattedFigure("$plain", ${state.name})';
}

/// THE ONE FORMATTER.
///
/// Before this there was `NumberFormat('#,##0.#', 'en_US')` in one file and
/// sixty-nine `toStringAsFixed` calls in thirty-three others, which is why the
/// same number could print three ways on three screens and a fourth way in the
/// PDF. Every figure in the app comes through here.
///
/// ```dart
/// final n = TiqNumber.of(context);
/// n.format(1284990.5);                       // 1,284,990.5   (en)
/// n.format(1284990.5);                       // 1 284 990,5   (af)
/// n.format(-31, unit: TiqUnit.percent);      // −31%
/// n.format(1284990, unit: TiqUnit.currency); // R 1,284,990
/// n.format(0);                               // 0      — never suppressed
/// n.format(null);                            // —      — never "0"
/// ```
@immutable
class TiqNumber {
  const TiqNumber(this.symbols);

  final TiqNumberSymbols symbols;

  static const TiqNumber en = TiqNumber(TiqNumberSymbols.en);
  static const TiqNumber af = TiqNumber(TiqNumberSymbols.af);

  /// The formatter for the ambient locale.
  static TiqNumber of(BuildContext context) =>
      forLocale(Localizations.maybeLocaleOf(context));

  static TiqNumber forLocale(Locale? locale) =>
      TiqNumber(TiqNumberSymbols.forLanguage(locale?.languageCode ?? 'en'));

  /// Format [value], split into its runs.
  ///
  /// [decimals] is the server's `decimals` field where there is one: how many
  /// places this *metric* is reported to, which is a property of the metric
  /// and not of the value. When it is null the figure keeps up to one place
  /// and drops a trailing zero, which is what the app does today.
  ///
  /// [signed] puts an explicit `+` on a rise — for a delta, never for a level.
  FormattedFigure split(
    num? value, {
    TiqUnit unit = TiqUnit.none,
    int? decimals,
    bool signed = false,
    FigureState state = FigureState.measured,
  }) {
    final resolved = value == null || !value.isFinite
        ? FigureState.missing
        : state;

    if (resolved == FigureState.missing ||
        resolved == FigureState.notMeasured) {
      // The unit is suppressed with the number. "— %" is a unit measuring
      // nothing, and it reads as a rendering bug.
      return FormattedFigure(
        prefix: '',
        run: emDash,
        suffix: '',
        state: resolved,
        allowsDelta: false,
      );
    }

    final v = value!;
    final magnitude = v.abs();
    final body = _digits(magnitude, decimals);

    // A value that rounds to zero prints unsigned: "−0%" is a movement that
    // did not happen, and a minus in front of it is a claim it did.
    final roundsToZero = _isZeroText(body);
    final sign = v < 0 && !roundsToZero
        ? minusSign
        : (signed && v > 0 && !roundsToZero ? '+' : '');

    return FormattedFigure(
      prefix: unit.isCurrency ? symbols.currencyPrefix : unit.prefix,
      run: '$sign$body',
      suffix: unit.suffix,
      state: resolved,
      allowsDelta: resolved == FigureState.measured,
    );
  }

  /// [split] flattened. Convenient for a semantics label or a table cell.
  String format(
    num? value, {
    TiqUnit unit = TiqUnit.none,
    int? decimals,
    bool signed = false,
    FigureState state = FigureState.measured,
  }) => split(
    value,
    unit: unit,
    decimals: decimals,
    signed: signed,
    state: state,
  ).plain;

  /// The magnitude, grouped, with the locale's decimal mark. No sign.
  String _digits(num magnitude, int? decimals) {
    final places = decimals ?? _naturalPlaces(magnitude);
    final fixed = magnitude.toDouble().toStringAsFixed(places);
    final dot = fixed.indexOf('.');
    final whole = dot == -1 ? fixed : fixed.substring(0, dot);
    var frac = dot == -1 ? '' : fixed.substring(dot + 1);

    if (decimals == null) {
      // Drop a trailing zero only when the caller did not declare a precision.
      // A metric reported to two places prints 4.10, because the second place
      // is information: it says the metric resolves that finely.
      while (frac.isNotEmpty && frac.endsWith('0')) {
        frac = frac.substring(0, frac.length - 1);
      }
    }

    final grouped = _group(whole);
    return frac.isEmpty ? grouped : '$grouped${symbols.decimal}$frac';
  }

  /// Up to one decimal place, which is what the app has always shown.
  int _naturalPlaces(num magnitude) {
    final rounded = (magnitude * 10).roundToDouble() / 10;
    return rounded == rounded.roundToDouble() ? 0 : 1;
  }

  String _group(String whole) {
    if (whole.length <= 3) return whole;
    final buffer = StringBuffer();
    final lead = whole.length % 3 == 0 ? 3 : whole.length % 3;
    buffer.write(whole.substring(0, lead));
    for (var i = lead; i < whole.length; i += 3) {
      buffer
        ..write(symbols.group)
        ..write(whole.substring(i, i + 3));
    }
    return buffer.toString();
  }

  bool _isZeroText(String body) {
    for (final unit in body.split('')) {
      if (unit != '0' && unit != symbols.decimal && unit != symbols.group) {
        return false;
      }
    }
    return true;
  }
}
