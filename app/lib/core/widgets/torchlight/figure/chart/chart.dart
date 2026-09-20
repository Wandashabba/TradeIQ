/// THE CHART KIT — the barrel every screen with a chart imports.
///
/// ```dart
/// import 'package:tradeiq_app/core/widgets/torchlight/figure/chart/chart.dart';
/// ```
///
/// `TrendChart` draws the run and builds its own `ChartLegend`; `ScrubReadout`
/// is what the thumb reveals; `TableTwin` is the same data as rows, which is
/// what a screen reader, a printer and the Veld skin all get.
///
/// Nothing in this folder names an amber token — the chart-focus rung exists
/// on the ladder and this kit declines it. See `trend_chart.dart`.
library;

export 'chart_legend.dart';
export 'chart_series.dart';
export 'scrub_readout.dart';
export 'table_twin.dart';
export 'trend_chart.dart';
