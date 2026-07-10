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

abstract class TrendsRepository {
  Future<List<TrendPoint>> scorecards();
  Future<List<TrendPoint>> availability();
  Future<List<TrendPoint>> perfectStore();
}

class DioTrendsRepository implements TrendsRepository {
  Future<List<TrendPoint>> _points(String path) async {
    final response = await dio.get(path);
    final points = (response.data as Map<String, dynamic>)['points'] as List;
    return points
        .map((json) => TrendPoint.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<TrendPoint>> scorecards() => _points('/trends/scorecards');

  @override
  Future<List<TrendPoint>> availability() => _points('/trends/availability');

  @override
  Future<List<TrendPoint>> perfectStore() => _points('/trends/perfect-store');
}

final trendsRepositoryProvider =
    Provider<TrendsRepository>((ref) => DioTrendsRepository());

final scorecardsTrendProvider = FutureProvider<List<TrendPoint>>((ref) {
  return ref.read(trendsRepositoryProvider).scorecards();
});

final availabilityTrendProvider = FutureProvider<List<TrendPoint>>((ref) {
  return ref.read(trendsRepositoryProvider).availability();
});

final perfectStoreTrendProvider = FutureProvider<List<TrendPoint>>((ref) {
  return ref.read(trendsRepositoryProvider).perfectStore();
});
