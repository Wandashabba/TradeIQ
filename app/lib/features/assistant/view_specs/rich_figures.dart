import '../../../core/design/tiq_number.dart';
export '../../../core/design/tiq_number.dart' show minusSign;

/// The data behind `stat_tiles` and `ranked_bars`, read once and shared by
/// the chat cards and the table twin the PDF prints — so a figure cannot be
/// formatted one way on screen and another in the report.
///
/// Pure Dart: the PDF builds on a background isolate. Every read is
/// type-tested, and an entry that cannot be read is skipped rather than drawn
/// as zero.
///
/// ## The formatter
///
/// This file used to hold `NumberFormat('#,##0.#', 'en_US')`, which printed
/// `1,284,990.5` to an Afrikaans manager whose convention is `1 284 990,5`,
/// and a hyphen where a minus belongs. Every figure now goes through
/// [TiqNumber] — the app's one locale formatter — and every figure the Ask
/// screen *draws* goes through `FigureSlot`, which sets it in the two faces
/// and owns the unknown states. The functions here exist for the table twin
/// and the PDF, which are text rather than widgets.

/// The wire's `unit` as the formatter's.
///
/// `pts` is a **word**, and words are `l10n`'s: the caller passes the
/// localised singular and plural through [pointsWord]. Defaulting it to
/// English keeps the pure-Dart callers (the table twin, the PDF) working
/// exactly as they did, and a widget passes `context.l10n`.
TiqUnit unitFor(
  String? unit,
  num magnitude, {
  String Function(num magnitude)? pointsWord,
}) => switch (unit) {
  'pct' => TiqUnit.percent,
  'pts' => TiqUnit.worded(
    pointsWord?.call(magnitude) ?? (magnitude == 1 ? 'pt' : 'pts'),
  ),
  _ => TiqUnit.none,
};

/// `48 210`, `81%`, `4 pts`, `−31%` — in the reader's own locale.
///
/// [decimals] is the metric's declared precision (#410), not the value's: a
/// metric reported to one place prints `4.0`, because the trailing zero says
/// the metric resolves that finely.
String formatAmount(
  num value,
  String? unit, {
  TiqNumber number = TiqNumber.en,
  int? decimals,
  String Function(num magnitude)? pointsWord,
}) => number.format(
  value,
  unit: unitFor(unit, value.abs(), pointsWord: pointsWord),
  decimals: decimals,
);

/// [formatAmount] with an explicit `+` on a rise.
String formatSignedAmount(
  num value,
  String? unit, {
  TiqNumber number = TiqNumber.en,
  int? decimals,
  String Function(num magnitude)? pointsWord,
}) => number.format(
  value,
  unit: unitFor(unit, value.abs(), pointsWord: pointsWord),
  decimals: decimals,
  signed: true,
);

enum DeltaSentiment { good, bad, warn, neutral }

/// Where a figure's number came from (#410).
///
/// `internal` is the tenant's own TradeIQ data. Everything else is **outside
/// data** — public, about the world rather than about this client, and never
/// summable with an internal total. The server refuses a run that mixes the
/// two at all; the client refuses to draw outside data inside the panel.
enum FigureOrigin {
  internal,
  webSearch,
  statsSa,
  weather,
  calendar,
  competitorPrices;

  /// An absent origin is internal, which is what every figure sent before
  /// #410 was.
  static FigureOrigin parse(dynamic raw) => switch (raw) {
    'web_search' => FigureOrigin.webSearch,
    'stats_sa' => FigureOrigin.statsSa,
    'weather' => FigureOrigin.weather,
    'calendar' => FigureOrigin.calendar,
    'competitor_prices' => FigureOrigin.competitorPrices,
    _ => FigureOrigin.internal,
  };

  bool get isOutside => this != FigureOrigin.internal;
}

/// The provenance a figure run carries (#410).
///
/// One per run, because the server rejects a run that mixes origins: the
/// separation is enforced where the numbers are made, not asserted where they
/// are drawn.
class FigureProvenance {
  const FigureProvenance({
    this.origin = FigureOrigin.internal,
    this.publisher,
    this.readAt,
    this.focusIndex,
  });

  final FigureOrigin origin;

  /// Who published it, for outside data. Null where the source does not say.
  final String? publisher;

  /// When we read it. Null when unknown.
  final DateTime? readAt;

  /// Which single figure in the run the answer's sentence is about — the
  /// server's choice, not a client heuristic (#410). Null when the server did
  /// not name one, and then **nothing is lit**: the old build guessed index 0,
  /// which had no way to know which way "worst" runs for the metric in hand.
  final int? focusIndex;

  bool get isOutside => origin.isOutside;

  /// Read from a figure run's data map.
  static FigureProvenance from(dynamic data, {dynamic tile}) {
    if (data is! Map) return const FigureProvenance();
    // `stat_tiles` carries origin per tile and the flag per run; `ranked_bars`
    // carries one origin for the whole list. Reading the tile first and the
    // run second covers both without knowing which shape this is.
    final rawOrigin = (tile is Map ? tile['origin'] : null) ?? data['origin'];
    final rawPublisher =
        (tile is Map ? tile['publisher'] : null) ?? data['publisher'];
    final rawReadAt = (tile is Map ? tile['readAt'] : null) ?? data['readAt'];
    final focus = data['focusIndex'];
    return FigureProvenance(
      origin: FigureOrigin.parse(rawOrigin),
      publisher: rawPublisher is String && rawPublisher.trim().isNotEmpty
          ? rawPublisher.trim()
          : null,
      readAt: rawReadAt is String ? DateTime.tryParse(rawReadAt) : null,
      focusIndex: focus is int && focus >= 0 ? focus : null,
    );
  }
}

class TileDelta {
  const TileDelta({
    required this.value,
    required this.unit,
    required this.up,
    required this.sentiment,
    this.decimals,
  });

  final num value;
  final String? unit;

  /// The direction as the server stated it. It is the glyph, never inferred
  /// from the sign: a delta may be sent as a magnitude.
  final bool? up;
  final DeltaSentiment sentiment;
  final int? decimals;

  /// `−12.4%`, `+9`.
  ///
  /// **No triangle.** The glyph used to be a literal U+25BC, which Onest has
  /// never carried and `package:pdf` draws as nothing at all (#401) — so the
  /// arrow was simply absent from every exported report. The direction is a
  /// drawn shape on screen (`Delta`) and the sign in text; here, where this is
  /// a table cell, the sign is the whole of it.
  String text({TiqNumber number = TiqNumber.en}) => formatSignedAmount(
    up == false ? -value.abs() : value.abs(),
    unit,
    number: number,
    decimals: decimals,
  );

  static TileDelta? tryParse(dynamic raw, {int? decimals}) {
    if (raw is! Map) return null;
    final value = raw['value'];
    if (value is! num || !value.isFinite) return null;
    final unit = raw['unit'];
    final direction = raw['direction'];
    return TileDelta(
      value: value,
      unit: unit is String ? unit : null,
      decimals: decimals,
      up: direction == 'up'
          ? true
          : direction == 'down'
          ? false
          : null,
      sentiment: switch (raw['sentiment']) {
        'good' => DeltaSentiment.good,
        'bad' => DeltaSentiment.bad,
        'warn' => DeltaSentiment.warn,
        _ => DeltaSentiment.neutral,
      },
    );
  }
}

class StatTileData {
  const StatTileData({
    required this.label,
    required this.value,
    this.unit,
    this.delta,
    this.comparedTo,
    this.meter,
    this.decimals,
    this.sampleSize,
    this.baselineSampleSize,
    this.provenance = const FigureProvenance(),
  });

  final String label;
  final num value;
  final String? unit;
  final TileDelta? delta;
  final String? comparedTo;

  /// 0–100, clamped.
  final double? meter;

  /// How many places this metric is reported to (#410). Null means the client
  /// keeps up to one place and drops a trailing zero, which is what it did
  /// before the field existed.
  final int? decimals;

  /// How many rows the figure was measured over, and how many its baseline
  /// was (#410). **Null is not zero**: null means the figure has no
  /// denominator — a total, a count of things — and reading it as zero would
  /// put the low-sample treatment on every headline figure in the product.
  final int? sampleSize;
  final int? baselineSampleSize;

  final FigureProvenance provenance;

  String formatted({TiqNumber number = TiqNumber.en}) =>
      formatAmount(value, unit, number: number, decimals: decimals);

  static List<StatTileData> listFrom(dynamic data) {
    final tiles = data is Map ? data['tiles'] : null;
    if (tiles is! List) return const [];
    final out = <StatTileData>[];
    for (final raw in tiles) {
      if (raw is! Map) continue;
      final label = raw['label'];
      final value = raw['value'];
      if (label is! String || value is! num || !value.isFinite) continue;
      final unit = raw['unit'];
      final comparedTo = raw['comparedTo'];
      final meter = raw['meter'];
      final decimals = raw['decimals'];
      final places = decimals is int ? decimals : null;
      out.add(StatTileData(
        label: label,
        value: value,
        unit: unit is String ? unit : null,
        delta: TileDelta.tryParse(raw['delta']),
        comparedTo:
            comparedTo is String && comparedTo.isNotEmpty ? comparedTo : null,
        meter: meter is num && meter.isFinite
            ? meter.toDouble().clamp(0, 100)
            : null,
        decimals: places,
        sampleSize: _count(raw['sampleSize']),
        baselineSampleSize: _count(raw['baselineSampleSize']),
        provenance: FigureProvenance.from(data, tile: raw),
      ));
    }
    return out;
  }
}

/// A sample count, or null. **Never 0 for "unknown"** — a zero denominator is
/// a claim that the client cannot make on the server's behalf.
int? _count(dynamic raw) => raw is int && raw >= 0 ? raw : null;

class RankedBarItem {
  const RankedBarItem(this.label, this.value, {this.sampleSize});
  final String label;
  final double value;

  /// Rows behind this one bar, when the tool counted them.
  final int? sampleSize;
}

class RankedBarsData {
  const RankedBarsData({
    required this.items,
    this.title,
    this.comparedTo,
    this.unit,
    this.decimals,
    this.provenance = const FigureProvenance(),
  });

  final String? title;
  final String? comparedTo;
  final String? unit;
  final int? decimals;
  final List<RankedBarItem> items;
  final FigureProvenance provenance;

  /// Whether any value is below zero. Only then are the bars drawn diverging
  /// around a centre line; a set of non-negative counts (the common case —
  /// "out-of-stock lines by outlet") grows from a left baseline across the
  /// full track, and is not signed.
  bool get diverging => items.any((item) => item.value < 0);

  /// The largest magnitude, which every bar is scaled against. Zero when there
  /// is nothing to scale.
  double get maxAbs => items.fold(
        0,
        (max, item) => item.value.abs() > max ? item.value.abs() : max,
      );

  /// The one bar the answer is about — **the server's choice** (#410).
  ///
  /// It used to be "the first", which was an inference dressed as a fact: the
  /// sentence above may be about the third outlet, and only the server knows
  /// which way "worst" runs for the metric in hand. Null when the server did
  /// not name one, and then no bar is lit at all. A single item is never a
  /// focus: one bar cannot be ranked.
  int? get focusIndex {
    final index = provenance.focusIndex;
    if (index == null || items.length < 2 || index >= items.length) return null;
    return index;
  }

  /// A value label: signed when the bars diverge, plain when they do not.
  String label(double value, {TiqNumber number = TiqNumber.en}) => diverging
      ? formatSignedAmount(value, unit, number: number, decimals: decimals)
      : formatAmount(value, unit, number: number, decimals: decimals);

  static RankedBarsData from(dynamic data) {
    if (data is! Map) return const RankedBarsData(items: []);
    String? str(String key) {
      final value = data[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final raw = data['items'];
    final items = <RankedBarItem>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final label = entry['label'];
        final value = entry['value'];
        if (label is! String || value is! num || !value.isFinite) continue;
        items.add(RankedBarItem(
          label,
          value.toDouble(),
          sampleSize: _count(entry['sampleSize']),
        ));
      }
    }
    final decimals = data['decimals'];
    return RankedBarsData(
      title: str('title'),
      comparedTo: str('comparedTo'),
      unit: str('unit'),
      decimals: decimals is int ? decimals : null,
      items: items,
      provenance: FigureProvenance.from(data),
    );
  }
}
