import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// A single point on an executive trend line returned by the /trends/*
/// endpoints, e.g. one bucket of the scorecard trend over an interval.
class TrendPoint {
  const TrendPoint({required this.period, required this.value, this.count = 0});
  final String period;
  final double value;

  /// Rows behind [value]. The server omits empty buckets rather than sending
  /// a zero, so a point that exists always measured something.
  final int count;

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
    period: json['period'] as String,
    value: (json['value'] as num).toDouble(),
    count: (json['count'] as num?)?.toInt() ?? 0,
  );
}

/// The bucket width the server groups by. Only these two exist — the route
/// rejects anything else with a 400, so the UI offers exactly these.
enum TrendInterval { day, week }

/// The window and bucket width every trend on the screen is read through.
///
/// `from`/`to` are null by default, which means "whatever the server's default
/// lookback is" — not "all time". The screen says so rather than implying a
/// range it did not ask for.
class TrendQuery {
  const TrendQuery({this.interval = TrendInterval.week, this.from, this.to});

  final TrendInterval interval;
  final DateTime? from;
  final DateTime? to;

  bool get isRanged => from != null || to != null;

  Map<String, dynamic> toQueryParameters() => {
    'interval': interval.name,
    if (from != null) 'from': from!.toIso8601String(),
    if (to != null) 'to': to!.toIso8601String(),
  };
}

/// The metrics `GET /trends/benchmark` compares. [name] is the wire value.
enum BenchmarkMetric { scorecards, perfectStore, availability, shareOfShelf }

extension BenchmarkMetricLabels on BenchmarkMetric {
  String get label => switch (this) {
    BenchmarkMetric.scorecards => 'Score',
    BenchmarkMetric.perfectStore => 'Perfect store',
    BenchmarkMetric.availability => 'Availability',
    BenchmarkMetric.shareOfShelf => 'Share of shelf',
  };

  /// `count` rows of this metric in words — "3 scorecards", "1 stock line".
  String samples(int count) {
    final one = count == 1;
    final noun = switch (this) {
      BenchmarkMetric.scorecards ||
      BenchmarkMetric.perfectStore => one ? 'scorecard' : 'scorecards',
      BenchmarkMetric.availability => one ? 'stock line' : 'stock lines',
      BenchmarkMetric.shareOfShelf =>
        one ? 'visit with facings' : 'visits with facings',
    };
    return '$count $noun';
  }
}

/// Where a territory sits against its client's average.
enum BenchmarkPosition { above, below, level }

BenchmarkPosition? _position(Object? raw) => switch (raw) {
  'above' => BenchmarkPosition.above,
  'below' => BenchmarkPosition.below,
  'level' => BenchmarkPosition.level,
  _ => null,
};

double? _nullableDouble(Object? raw) => (raw as num?)?.toDouble();

List<TrendPoint> _points(Object? raw) => [
  for (final json in (raw as List? ?? const []))
    TrendPoint.fromJson(json as Map<String, dynamic>),
];

/// A series plus its period average. [average] is null — never 0 — when
/// nothing in the window was measured.
class BenchmarkSeries {
  const BenchmarkSeries({
    required this.average,
    required this.count,
    required this.points,
  });

  final double? average;
  final int count;
  final List<TrendPoint> points;

  factory BenchmarkSeries.fromJson(Map<String, dynamic> json) =>
      BenchmarkSeries(
        average: _nullableDouble(json['average']),
        count: (json['count'] as num?)?.toInt() ?? 0,
        points: _points(json['points']),
      );
}

class TerritoryBenchmark extends BenchmarkSeries {
  const TerritoryBenchmark({
    required this.territoryId,
    required this.territoryName,
    required this.territoryCode,
    required super.average,
    required super.count,
    required super.points,
    required this.rank,
    required this.deltaFromClient,
    required this.position,
  });

  final String territoryId;
  final String territoryName;
  final String territoryCode;
  final int? rank;
  final double? deltaFromClient;
  final BenchmarkPosition? position;

  factory TerritoryBenchmark.fromJson(Map<String, dynamic> json) =>
      TerritoryBenchmark(
        territoryId: json['territoryId'] as String,
        territoryName: json['territoryName'] as String,
        territoryCode: json['territoryCode'] as String? ?? '',
        average: _nullableDouble(json['average']),
        count: (json['count'] as num?)?.toInt() ?? 0,
        points: _points(json['points']),
        rank: (json['rank'] as num?)?.toInt(),
        deltaFromClient: _nullableDouble(json['deltaFromClient']),
        position: _position(json['position']),
      );
}

/// Every territory of the caller's client against the client-wide line.
class TerritoryBenchmarkReport {
  const TerritoryBenchmarkReport({
    required this.metric,
    required this.isPercent,
    required this.client,
    required this.territories,
    this.target,
    this.targetLabel,
    this.unassignedCount = 0,
  });

  final BenchmarkMetric metric;
  final bool isPercent;
  final BenchmarkSeries client;

  /// Ranked by the server: highest average first, territories without data last.
  final List<TerritoryBenchmark> territories;

  /// The client's configured standard for this metric, when it has one.
  final double? target;
  final String? targetLabel;

  /// Rows from outlets outside every territory — in [client], in no row.
  final int unassignedCount;

  String get suffix => isPercent ? '%' : '';

  factory TerritoryBenchmarkReport.fromJson(Map<String, dynamic> json) {
    final target = json['target'] as Map<String, dynamic>?;
    final metricName = json['metric'] as String?;
    return TerritoryBenchmarkReport(
      metric: BenchmarkMetric.values.firstWhere(
        (m) => m.name == metricName,
        orElse: () => BenchmarkMetric.scorecards,
      ),
      isPercent: json['unit'] == 'percent',
      client: BenchmarkSeries.fromJson(json['client'] as Map<String, dynamic>),
      territories: [
        for (final t in (json['territories'] as List? ?? const []))
          TerritoryBenchmark.fromJson(t as Map<String, dynamic>),
      ],
      target: _nullableDouble(target?['value']),
      targetLabel: target?['label'] as String?,
      unassignedCount:
          ((json['unassigned'] as Map<String, dynamic>?)?['count'] as num?)
              ?.toInt() ??
          0,
    );
  }
}

abstract class TrendsRepository {
  Future<List<TrendPoint>> scorecards([TrendQuery query]);
  Future<List<TrendPoint>> availability([TrendQuery query]);
  Future<List<TrendPoint>> perfectStore([TrendQuery query]);
  Future<TerritoryBenchmarkReport> benchmark(
    BenchmarkMetric metric, [
    TrendQuery query,
  ]);
}

class DioTrendsRepository implements TrendsRepository {
  Future<List<TrendPoint>> _points(String path, TrendQuery query) async {
    final response = await dio.get(
      path,
      queryParameters: query.toQueryParameters(),
    );
    final points = (response.data as Map<String, dynamic>)['points'] as List;
    return points
        .map((json) => TrendPoint.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<TrendPoint>> scorecards([
    TrendQuery query = const TrendQuery(),
  ]) => _points('/trends/scorecards', query);

  @override
  Future<List<TrendPoint>> availability([
    TrendQuery query = const TrendQuery(),
  ]) => _points('/trends/availability', query);

  @override
  Future<List<TrendPoint>> perfectStore([
    TrendQuery query = const TrendQuery(),
  ]) => _points('/trends/perfect-store', query);

  @override
  Future<TerritoryBenchmarkReport> benchmark(
    BenchmarkMetric metric, [
    TrendQuery query = const TrendQuery(),
  ]) async {
    final response = await dio.get(
      '/trends/benchmark',
      queryParameters: {...query.toQueryParameters(), 'metric': metric.name},
    );
    return TerritoryBenchmarkReport.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}

final trendsRepositoryProvider = Provider<TrendsRepository>(
  (ref) => DioTrendsRepository(),
);

/// One query drives every trend on the screen, so two charts can never disagree
/// about which slice of time they are showing.
class TrendQueryNotifier extends Notifier<TrendQuery> {
  @override
  TrendQuery build() => const TrendQuery();

  void set(TrendQuery next) => state = next;
}

final trendQueryProvider = NotifierProvider<TrendQueryNotifier, TrendQuery>(
  TrendQueryNotifier.new,
);

final scorecardsTrendProvider = FutureProvider<List<TrendPoint>>((ref) {
  return ref
      .read(trendsRepositoryProvider)
      .scorecards(ref.watch(trendQueryProvider));
});

final availabilityTrendProvider = FutureProvider<List<TrendPoint>>((ref) {
  return ref
      .read(trendsRepositoryProvider)
      .availability(ref.watch(trendQueryProvider));
});

final perfectStoreTrendProvider = FutureProvider<List<TrendPoint>>((ref) {
  return ref
      .read(trendsRepositoryProvider)
      .perfectStore(ref.watch(trendQueryProvider));
});

/// Which of the screen's two views is showing.
enum TrendsView { overTime, compareTerritories }

class TrendsViewNotifier extends Notifier<TrendsView> {
  @override
  TrendsView build() => TrendsView.overTime;

  void set(TrendsView next) => state = next;
}

final trendsViewProvider = NotifierProvider<TrendsViewNotifier, TrendsView>(
  TrendsViewNotifier.new,
);

class BenchmarkMetricNotifier extends Notifier<BenchmarkMetric> {
  @override
  BenchmarkMetric build() => BenchmarkMetric.scorecards;

  void set(BenchmarkMetric next) => state = next;
}

final benchmarkMetricProvider =
    NotifierProvider<BenchmarkMetricNotifier, BenchmarkMetric>(
      BenchmarkMetricNotifier.new,
    );

/// The territory comparison reads through the same [trendQueryProvider] as
/// every series, so the two views always describe the same window.
final territoryBenchmarkProvider = FutureProvider<TerritoryBenchmarkReport>((
  ref,
) {
  return ref
      .read(trendsRepositoryProvider)
      .benchmark(
        ref.watch(benchmarkMetricProvider),
        ref.watch(trendQueryProvider),
      );
});
