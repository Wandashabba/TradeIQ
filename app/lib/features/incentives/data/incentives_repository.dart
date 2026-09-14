import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/person_label.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

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
    this.displayName,
  });
  final String schemeName;
  final String email;
  final int rewardPoints;

  /// What people call this agent. Null for agents never given a name.
  final String? displayName;

  /// The name when there is one, otherwise the email.
  String get label => personLabel(displayName, email);

  factory EarnedIncentive.fromJson(Map<String, dynamic> json) => EarnedIncentive(
        schemeName: json['schemeName'] as String,
        email: json['email'] as String,
        rewardPoints: (json['rewardPoints'] as num).toInt(),
        displayName: json['displayName'] as String?,
      );
}

abstract class IncentivesRepository {
  Future<PaginatedResponse<IncentiveScheme>> listSchemes();
  Future<IncentiveScheme> createScheme({
    required String name,
    required String metric,
    required double threshold,
    required int rewardPoints,
  });
  Future<void> deleteScheme(String id);
  Future<List<EarnedIncentive>> earned();

  /// PATCH /incentives/:id — activate or deactivate a scheme without deleting it.
  Future<IncentiveScheme> setActive(String id, bool active);
}

class DioIncentivesRepository implements IncentivesRepository {
  @override
  Future<PaginatedResponse<IncentiveScheme>> listSchemes() async {
    final response = await dio.get('/incentives');
    return PaginatedResponse<IncentiveScheme>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => IncentiveScheme.fromJson(e as Map<String, dynamic>),
    );
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
  Future<IncentiveScheme> setActive(String id, bool active) async {
    final response =
        await dio.patch('/incentives/$id', data: {'active': active});
    return IncentiveScheme.fromJson(response.data as Map<String, dynamic>);
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

// The provider exposes the FIRST PAGE as a plain list: the incentives screen
// wants the current schemes, not the whole history, and "load more" UI is
// deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
final incentivesListProvider = FutureProvider<List<IncentiveScheme>>((ref) async {
  final page = await ref.read(incentivesRepositoryProvider).listSchemes();
  return page.data;
});
