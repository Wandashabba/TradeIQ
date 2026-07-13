import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// A single point on an executive trend line returned by the /trends/*
/// endpoints, e.g. one bucket of the scorecard trend over an interval.
class TrendPoint {
  const TrendPoint({
    required this.period,
    required this.value,
  });
  final String period;
  final double value;

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        period: json['period'] as String,
        value: (json['value'] as num).toDouble(),
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

abstract class TrendsRepository {
  Future<List<TrendPoint>> scorecards([TrendQuery query]);
  Future<List<TrendPoint>> availability([TrendQuery query]);
  Future<List<TrendPoint>> perfectStore([TrendQuery query]);
}

class DioTrendsRepository implements TrendsRepository {
  Future<List<TrendPoint>> _points(String path, TrendQuery query) async {
    final response =
        await dio.get(path, queryParameters: query.toQueryParameters());
    final points = (response.data as Map<String, dynamic>)['points'] as List;
    return points
        .map((json) => TrendPoint.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<TrendPoint>> scorecards([TrendQuery query = const TrendQuery()]) =>
      _points('/trends/scorecards', query);

  @override
  Future<List<TrendPoint>> availability([
    TrendQuery query = const TrendQuery(),
  ]) =>
      _points('/trends/availability', query);

  @override
  Future<List<TrendPoint>> perfectStore([
    TrendQuery query = const TrendQuery(),
  ]) =>
      _points('/trends/perfect-store', query);
}

final trendsRepositoryProvider =
    Provider<TrendsRepository>((ref) => DioTrendsRepository());

/// One query drives every trend on the screen, so two charts can never disagree
/// about which slice of time they are showing.
class TrendQueryNotifier extends Notifier<TrendQuery> {
  @override
  TrendQuery build() => const TrendQuery();

  void set(TrendQuery next) => state = next;
}

final trendQueryProvider =
    NotifierProvider<TrendQueryNotifier, TrendQuery>(TrendQueryNotifier.new);

final scorecardsTrendProvider = FutureProvider<List<TrendPoint>>((ref) {
  return ref.read(trendsRepositoryProvider).scorecards(
        ref.watch(trendQueryProvider),
      );
});

final availabilityTrendProvider = FutureProvider<List<TrendPoint>>((ref) {
  return ref.read(trendsRepositoryProvider).availability(
        ref.watch(trendQueryProvider),
      );
});

final perfectStoreTrendProvider = FutureProvider<List<TrendPoint>>((ref) {
  return ref.read(trendsRepositoryProvider).perfectStore(
        ref.watch(trendQueryProvider),
      );
});
