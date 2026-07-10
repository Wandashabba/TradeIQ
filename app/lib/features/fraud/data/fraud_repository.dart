import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// A single risk signal contributing to a flagged visit's score.
class FraudSignal {
  const FraudSignal({
    required this.code,
    required this.detail,
  });
  final String code;
  final String detail;

  factory FraudSignal.fromJson(Map<String, dynamic> json) => FraudSignal(
        code: json['code'] as String,
        detail: json['detail'] as String,
      );
}

/// A visit flagged by the fraud engine, returned by GET /fraud/flagged.
class FlaggedVisit {
  const FlaggedVisit({
    required this.visitId,
    required this.outletId,
    required this.agentId,
    required this.riskScore,
    required this.signals,
  });
  final String visitId;
  final String outletId;
  final String agentId;
  final double riskScore;
  final List<FraudSignal> signals;

  factory FlaggedVisit.fromJson(Map<String, dynamic> json) => FlaggedVisit(
        visitId: json['visitId'] as String,
        outletId: json['outletId'] as String,
        agentId: json['agentId'] as String,
        riskScore: (json['riskScore'] as num).toDouble(),
        signals: (json['signals'] as List?)
                ?.map((s) => FraudSignal.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

abstract class FraudRepository {
  Future<List<FlaggedVisit>> flagged({int? minScore});
}

class DioFraudRepository implements FraudRepository {
  @override
  Future<List<FlaggedVisit>> flagged({int? minScore}) async {
    final query = <String, dynamic>{};
    if (minScore != null) query['minScore'] = minScore;
    final response = await dio.get('/fraud/flagged', queryParameters: query);
    return (response.data as List)
        .map((json) => FlaggedVisit.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final fraudRepositoryProvider =
    Provider<FraudRepository>((ref) => DioFraudRepository());

final flaggedVisitsProvider = FutureProvider<List<FlaggedVisit>>((ref) {
  return ref.read(fraudRepositoryProvider).flagged();
});
