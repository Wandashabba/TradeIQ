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
  Iterable<ChartReading> get measured => readings.where((r) => r.value != null);

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

/// The plot's height, by density and viewport. **The one source.**
///
/// unify §1.17: 208 Console phone / 232 Field / 260 at ≥600dp.
/// The assistant surface's 160 lost on its own arithmetic — with a 38dp
/// gutter it leaves about 120dp of plot.
///
/// `TrendChartCard.plotHeightFor` in `features/assistant/view_specs/` held a
/// second copy of these three numbers, with the density arms written the
/// other way round, until 29 September 2026. Two copies of a number are two
/// numbers; it delegates here now.
/// **208 at both densities on a phone since 4 October 2026**; it read
/// `skin.space.density == TiqDensity.console ? 208 : 232` before.
///
/// THIS ONE MOVED NO PIXELS, AND SAYING SO IS THE POINT. `TrendChart` has
/// **no agent call site**: the four in the product are `trends_screen`,
/// `dashboard_shell_screen`, the assistant's `expanded_views` and
/// `trend_chart_card`, and all four are console. The 232 was a **dead arm** —
/// declared, documented in unify §1.17, and unreachable — so this is the one
/// row of the density table whose 24dp is arithmetic rather than a
/// measurement, and the before/after renders are byte-identical because there
/// was nothing to render.
///
/// It is changed anyway, prophylactically: a dead arm that says *an agent's
/// chart is taller than a manager's* is what the next agent screen to grow a
/// chart would silently inherit, and it would inherit it without the
/// before/after this change had. §1.17 gave a reason only for why the
/// assistant's 160 loses — *"with a 38dp gutter it leaves ~120dp of plot"* —
/// and none for why the field arm was 232.
///
/// 260 at ≥600dp is untouched and is not a density branch: it is a **width**
/// branch, it is the same on both surfaces, and it is the arm the desk reads.
double trendChartHeightFor(TiqSkin skin, double width) {
  if (width >= 600) return 260;
  return switch (skin.space.density) {
    TiqDensity.console || TiqDensity.field => 208,
  };
}

/// [trendChartHeightFor], reading the skin and width off a [BuildContext].
double trendChartHeight(BuildContext context) =>
    trendChartHeightFor(context.skin, MediaQuery.sizeOf(context).width);

/// The range a metric can physically take, when it has one.
///
/// A rate cannot be 120%, and an axis that prints 120 is not a rounding
/// choice — it is a reading that does not exist. See [niceScale].
@immutable
class ChartDomain {
  const ChartDomain({this.min, this.max});

  /// Nought to a hundred. Every rate in this product.
  static const ChartDomain rate = ChartDomain(min: 0, max: 100);

  /// No natural bounds: a count, a score out of nothing in particular, rand.
  static const ChartDomain unbounded = ChartDomain();

  final double? min;
  final double? max;
}

/// Rounds a range out to bounds whose ticks land on round numbers.
///
/// The arithmetic came from `charts.dart` and two things have been added to
/// it since, both because the owner looked at a rendered plot and called it
/// unrealistic:
///
/// * **[domain] — the metric's own ceiling and floor.** `GET /trends/
///   availability` answers in percent, the published standard is 95, and a
///   run at 88–97 rounded out to an axis labelled `105`. A percentage cannot
///   be 105, and a gridline that says so is the most confident-looking lie a
///   chart can tell. The padded range is clipped to [ChartDomain] before the
///   ticks are chosen, and 100 is a multiple of every step on the ladder, so
///   the rounding cannot push back through it.
/// * **The step is searched, not computed in one shot.** The old form divided
///   the span by [ticks] and snapped the quotient up the 1-2-5 ladder, which
///   overshoots badly near a ladder boundary: a span of 41 asked for a step of
///   10.25, snapped to 20, and drew a six-reading run inside an eighty-point
///   axis — the "cartoonish" plot, in the owner's word. This walks the ladder
///   from below and stops at the **finest** step whose gridline count is
///   inside the budget, so the run fills the plot it is given.
///
/// [ticks] is the tick budget, not a tick count: the result carries at most
/// `ticks + 2` gridlines and usually fewer.
({double min, double max, double step}) niceScale(
  Iterable<double> values, {
  double? include,
  int ticks = 4,
  ChartDomain domain = ChartDomain.unbounded,
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
  // The padding is air, and air outside the metric's range is not air. Only
  // the padding is clipped — a reading itself is never moved, so a server
  // that sends 103% still draws at 103%.
  final floor = domain.min;
  final ceiling = domain.max;
  final lowest = all.reduce((a, b) => a < b ? a : b);
  final highest = all.reduce((a, b) => a > b ? a : b);
  if (floor != null && lo < floor && lowest >= floor) lo = floor;
  if (ceiling != null && hi > ceiling && highest <= ceiling) hi = ceiling;

  var span = hi - lo;
  if (span <= 0) span = 1;
  // The finest step on the 1-2-5 ladder that keeps the gridlines inside the
  // budget. Starts an order of magnitude under the span, so the loop always
  // approaches from the fine side.
  final budget = ticks + 1;
  var step = _magnitude(span) / 10;
  if (step <= 0) step = 1;
  var niceMin = lo;
  var niceMax = hi;
  for (var guard = 0; guard < 24; guard++) {
    niceMin = (lo / step).floor() * step;
    niceMax = (hi / step).ceil() * step;
    if ((niceMax - niceMin) / step <= budget) break;
    step = _nextStep(step);
  }
  return (min: niceMin, max: niceMax, step: step);
}

/// The next rung up the 1-2-5 ladder. 1 → 2 → 5 → 10 → 20 → 50 → …
double _nextStep(double step) {
  final magnitude = _magnitude(step);
  final normalised = step / magnitude;
  if (normalised < 1.5) return 2 * magnitude;
  if (normalised < 3.5) return 5 * magnitude;
  return 10 * magnitude;
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
