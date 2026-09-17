import 'package:intl/intl.dart';

/// The data behind `stat_tiles` and `ranked_bars`, read once and shared by
/// the chat cards and the table twin the PDF prints — so a figure cannot be
/// formatted one way on screen and another in the report.
///
/// Pure Dart: the PDF builds on a background isolate. Every read is
/// type-tested, and an entry that cannot be read is skipped rather than drawn
/// as zero.

/// U+2212. A hyphen is a word-joiner; a minus sign is a figure.
const minusSign = '−';

final _number = NumberFormat('#,##0.#', 'en_US');

/// `48,210`, `81%`, `4 pts`, `−31%`.
String formatAmount(num value, String? unit) {
  final magnitude = value.abs();
  final body = _number.format(magnitude);
  // A value that rounds to zero is shown unsigned: "−0%" is a movement that
  // did not happen.
  final sign = value < 0 && body != '0' ? minusSign : '';
  return switch (unit) {
    'pct' => '$sign$body%',
    'pts' => '$sign$body ${magnitude == 1 ? 'pt' : 'pts'}',
    _ => '$sign$body',
  };
}

/// [formatAmount] with an explicit `+` on a rise.
String formatSignedAmount(num value, String? unit) {
  final text = formatAmount(value, unit);
  return value > 0 && text != formatAmount(0, unit) ? '+$text' : text;
}

enum DeltaSentiment { good, bad, warn, neutral }

class TileDelta {
  const TileDelta({
    required this.value,
    required this.unit,
    required this.up,
    required this.sentiment,
  });

  final num value;
  final String? unit;

  /// The direction as the server stated it. It is the glyph, never inferred
  /// from the sign: a delta may be sent as a magnitude.
  final bool? up;
  final DeltaSentiment sentiment;

  /// `▼ 12.4%`, `▲ 9`.
  String get text {
    final glyph = switch (up) {
      true => '▲ ',
      false => '▼ ',
      null => '',
    };
    return '$glyph${formatAmount(value.abs(), unit)}';
  }

  static TileDelta? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final value = raw['value'];
    if (value is! num || !value.isFinite) return null;
    final unit = raw['unit'];
    final direction = raw['direction'];
    return TileDelta(
      value: value,
      unit: unit is String ? unit : null,
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
  });

  final String label;
  final num value;
  final String? unit;
  final TileDelta? delta;
  final String? comparedTo;

  /// 0–100, clamped.
  final double? meter;

  String get formatted => formatAmount(value, unit);

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
      ));
    }
    return out;
  }
}

class RankedBarItem {
  const RankedBarItem(this.label, this.value);
  final String label;
  final double value;
}

class RankedBarsData {
  const RankedBarsData({
    required this.items,
    this.title,
    this.comparedTo,
    this.unit,
  });

  final String? title;
  final String? comparedTo;
  final String? unit;
  final List<RankedBarItem> items;

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

  /// The item to highlight: the **first**. The server sends items already
  /// ordered worst-first, and what "worst" means depends on the metric
  /// (highest first for a bad-when-up count), so the client neither re-sorts
  /// nor second-guesses it by magnitude.
  int? get leaderIndex => items.isEmpty ? null : 0;

  /// A value label: signed when the bars diverge, plain when they do not.
  String label(double value) =>
      diverging ? formatSignedAmount(value, unit) : formatAmount(value, unit);

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
        items.add(RankedBarItem(label, value.toDouble()));
      }
    }
    return RankedBarsData(
      title: str('title'),
      comparedTo: str('comparedTo'),
      unit: str('unit'),
      items: items,
    );
  }
}
