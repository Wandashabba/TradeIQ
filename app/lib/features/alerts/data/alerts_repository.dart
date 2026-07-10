import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// A manager-facing view of one exception alert returned by GET /alerts.
class AlertItem {
  const AlertItem({
    required this.id,
    required this.metric,
    required this.message,
    required this.severity,
    required this.acknowledged,
    this.visitId,
    this.outletId,
  });
  final String id;
  final String metric;
  final String message;
  final String severity;
  final bool acknowledged;
  final String? visitId;
  final String? outletId;

  factory AlertItem.fromJson(Map<String, dynamic> json) => AlertItem(
        id: json['id'] as String,
        metric: json['metric'] as String,
        message: json['message'] as String,
        severity: json['severity'] as String,
        acknowledged: json['acknowledged'] as bool? ?? false,
        visitId: json['visitId'] as String?,
        outletId: json['outletId'] as String?,
      );
}

abstract class AlertsRepository {
  Future<List<AlertItem>> listAlerts({bool? acknowledged, String? severity});
  Future<AlertItem> acknowledge(String id);
}

class DioAlertsRepository implements AlertsRepository {
  @override
  Future<List<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async {
    final query = <String, dynamic>{};
    if (acknowledged != null) query['acknowledged'] = acknowledged ? 'true' : 'false';
    if (severity != null) query['severity'] = severity;
    final response = await dio.get('/alerts', queryParameters: query);
    return (response.data as List)
        .map((json) => AlertItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AlertItem> acknowledge(String id) async {
    final response = await dio.patch('/alerts/$id/ack');
    return AlertItem.fromJson(response.data as Map<String, dynamic>);
  }
}

final alertsRepositoryProvider =
    Provider<AlertsRepository>((ref) => DioAlertsRepository());

final alertsListProvider = FutureProvider<List<AlertItem>>((ref) {
  return ref.read(alertsRepositoryProvider).listAlerts();
});
