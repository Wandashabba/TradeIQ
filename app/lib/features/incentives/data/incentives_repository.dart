import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// An incentive scheme returned by GET /incentives.
class IncentiveScheme {
  const IncentiveScheme({
    required this.id,
    required this.name,
    required this.metric,
    required this.threshold,
    required this.rewardPoints,
    required this.active,
  });
  final String id;
  final String name;
  final String metric;
  final double threshold;
  final int rewardPoints;
  final bool active;

  factory IncentiveScheme.fromJson(Map<String, dynamic> json) => IncentiveScheme(
        id: json['id'] as String,
        name: json['name'] as String,
        metric: json['metric'] as String,
        threshold: (json['threshold'] as num).toDouble(),
        rewardPoints: (json['rewardPoints'] as num).toInt(),
        active: json['active'] as bool? ?? false,
      );
}

/// An earned incentive returned by GET /incentives/earned.
class EarnedIncentive {
  const EarnedIncentive({
    required this.schemeName,
    required this.email,
    required this.rewardPoints,
  });
  final String schemeName;
  final String email;
  final int rewardPoints;

  factory EarnedIncentive.fromJson(Map<String, dynamic> json) => EarnedIncentive(
        schemeName: json['schemeName'] as String,
        email: json['email'] as String,
        rewardPoints: (json['rewardPoints'] as num).toInt(),
      );
}

abstract class IncentivesRepository {
  Future<List<IncentiveScheme>> listSchemes();
  Future<IncentiveScheme> createScheme({
    required String name,
    required String metric,
    required double threshold,
    required int rewardPoints,
  });
  Future<void> deleteScheme(String id);
  Future<List<EarnedIncentive>> earned();
}

class DioIncentivesRepository implements IncentivesRepository {
  @override
  Future<List<IncentiveScheme>> listSchemes() async {
    final response = await dio.get('/incentives');
    return (response.data as List)
        .map((json) => IncentiveScheme.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<IncentiveScheme> createScheme({
    required String name,
    required String metric,
    required double threshold,
    required int rewardPoints,
  }) async {
    final response = await dio.post('/incentives', data: {
      'name': name,
      'metric': metric,
      'threshold': threshold,
      'rewardPoints': rewardPoints,
    });
    return IncentiveScheme.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteScheme(String id) async {
    await dio.delete('/incentives/$id');
  }

  @override
  Future<List<EarnedIncentive>> earned() async {
    final response = await dio.get('/incentives/earned');
    return (response.data as List)
        .map((json) => EarnedIncentive.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final incentivesRepositoryProvider =
    Provider<IncentivesRepository>((ref) => DioIncentivesRepository());

final incentivesListProvider = FutureProvider<List<IncentiveScheme>>((ref) {
  return ref.read(incentivesRepositoryProvider).listSchemes();
});
