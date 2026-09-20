import 'package:flutter/widgets.dart';

import '../../../../theme/torchlight/tiq_skin.dart';

/// ONE READING IN A SERIES.
///
/// [value] is nullable and the nullability is the point. The trends endpoints
/// omit an empty bucket rather than sending a zero, so a caller that filled
/// the gap with `0` would draw a week of load-shedding as a week of total
/// failure. A null reading breaks the line: the stroke stops before it and
/// starts after it, and the legend says how many buckets were not measured.
@immutable
class ChartReading {
  const ChartReading({
    required this.label,
    required this.value,
    this.longLabel,
    this.sampleSize,
  });

  /// The axis form. Short, because an axis has about 40dp per tick — `W26`,
  /// not `2026-W26`.
  final String label;

  /// The unabbreviated form, for the scrub readout and the table twin. Null
  /// falls back to [label].
  final String? longLabel;

  /// Null is **not measured**, never zero.
  final double? value;

  /// Rows behind [value], where the server counts them.
  final int? sampleSize;

  String get readLabel => longLabel ?? label;
}

/// Which of the two roles a series plays.
///
/// There are exactly two, and there is no third: unify §1.13 reserves Truffle
/// for "them, unlit" and nothing else, so a chart cannot grow a third hue
/// without giving Truffle a second meaning. A chart that needs three series
/// needs three charts, or a ranked list.
enum ChartSeriesRole {
  /// The subject. `chartNeutral`, solid, 2dp.
  subject,

  /// What the subject is being read against — the client average, last
  /// period, the target band's own line. Truffle, **dashed**, 1.5dp.
  ///
  /// Dashed and not merely darker: unify §4 requires every hue-coded
  /// distinction to carry a second channel, and the dash is the channel that
  /// survives greyscale, deuteranopia, glare and a printed page.
  comparison,
}

/// A named run of readings.
@immutable
class ChartSeries {
  const ChartSeries({
    required this.name,
    required this.readings,
    this.role = ChartSeriesRole.subject,
  });

  /// What the legend calls it. Localised by the caller — nothing in this
  /// folder hardcodes English.
  final String name;

  /// Oldest first.
  final List<ChartReading> readings;

  final ChartSeriesRole role;

  /// The readings that actually measured something.
  Iterable<ChartReading> get measured =>
      readings.where((r) => r.value != null);

  bool get hasData => measured.isNotEmpty;

  /// How many buckets in this run were not measured.
  int get gaps => readings.length - measured.length;
}

/// A dashed annotation across the plot: a configured target, a threshold, a
/// client average drawn as a level rather than as a run.
///
/// It is dashed because a dash is what a threshold *means* in this system —
/// `charts.dart` said so before Torchlight and unify §1.1 keeps it. It is
/// never amber: a 1dp ink-1 rule measures 15:1 and amber there would displace
/// the focus object for no legibility gain (§1.1, the diverging-axis ruling,
/// which is the same argument).
@immutable
class ChartThreshold {
  const ChartThreshold({required this.value, required this.label});

  final double value;

  /// Named in the legend, always. A rule with no name is a line somebody drew.
  final String label;
}

/// The plot's height, by density and viewport.
///
/// unify §1.17: 208 Console phone / 232 Field / 180 Veld / 260 at ≥600dp.
/// The assistant surface's 160 lost on its own arithmetic — with a 38dp
/// gutter it leaves about 120dp of plot.
double trendChartHeight(BuildContext context) {
  final skin = context.skin;
  if (skin.mode == SkinMode.veld) return 180;
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 600) return 260;
  return skin.space.density == TiqDensity.console ? 208 : 232;
}

/// Rounds a range out to bounds whose ticks land on round numbers.
///
/// Lifted unchanged in behaviour from `charts.dart` — the arithmetic was never
/// the problem with the old chart set, the tokens were — and kept here so the
/// Torchlight charts do not import a deprecated file.
({double min, double max, double step}) niceScale(
  Iterable<double> values, {
  double? include,
  int ticks = 4,
}) {
  final all = <double>[...values, ?include];
  if (all.isEmpty) return (min: 0, max: 1, step: 1);
  var lo = all.reduce((a, b) => a < b ? a : b);
  var hi = all.reduce((a, b) => a > b ? a : b);
  if (lo == hi) {
    // A flat run still needs a band to sit in the middle of. A zero-height
    // scale would put every point on the floor and read as a collapse.
    final pad = lo.abs() < 1 ? 1.0 : lo.abs() * 0.1;
    lo -= pad;
    hi += pad;
  } else {
    final pad = (hi - lo) * 0.18;
    lo -= pad;
    hi += pad;
  }
  if (lo > 0 && lo < (hi - lo)) lo = 0;
  final raw = (hi - lo) / ticks;
  final magnitude = _magnitude(raw);
  final normalised = raw / magnitude;
  final step =
      (normalised <= 1
          ? 1
          : normalised <= 2
          ? 2
          : normalised <= 5
          ? 5
          : 10) *
      magnitude;
  final niceMin = (lo / step).floor() * step;
  final niceMax = (hi / step).ceil() * step;
  return (min: niceMin, max: niceMax, step: step);
}

double _magnitude(double raw) {
  if (raw <= 0) return 1;
  var m = 1.0;
  while (m * 10 <= raw) {
    m *= 10;
  }
  while (m > raw) {
    m /= 10;
  }
  return m;
}
