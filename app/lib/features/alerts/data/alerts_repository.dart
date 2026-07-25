import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

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
    this.evidencePhotoId,
  });
  final String id;
  final String metric;
  final String message;
  final String severity;
  final bool acknowledged;
  final String? visitId;
  final String? outletId;

  /// The newest photo of the linked visit (batched server-side), or null when
  /// the alert has no visit or the visit has no photos. Null means the row
  /// shows no thumbnail — never a placeholder (the thumbnail IS the evidence).
  final String? evidencePhotoId;

  factory AlertItem.fromJson(Map<String, dynamic> json) => AlertItem(
    id: json['id'] as String,
    metric: json['metric'] as String,
    message: json['message'] as String,
    severity: json['severity'] as String,
    acknowledged: json['acknowledged'] as bool? ?? false,
    visitId: json['visitId'] as String?,
    outletId: json['outletId'] as String?,
    evidencePhotoId: json['evidencePhotoId'] as String?,
  );
}

abstract class AlertsRepository {
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  });
  Future<AlertItem> acknowledge(String id);
}

class DioAlertsRepository implements AlertsRepository {
  @override
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async {
    final query = <String, dynamic>{};
    if (acknowledged != null) {
      query['acknowledged'] = acknowledged ? 'true' : 'false';
    }
    if (severity != null) query['severity'] = severity;
    final response = await dio.get('/alerts', queryParameters: query);
    return PaginatedResponse<AlertItem>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => AlertItem.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<AlertItem> acknowledge(String id) async {
    final response = await dio.patch('/alerts/$id/ack');
    return AlertItem.fromJson(response.data as Map<String, dynamic>);
  }
}

final alertsRepositoryProvider = Provider<AlertsRepository>(
  (ref) => DioAlertsRepository(),
);

// The provider exposes the FIRST PAGE as a plain list: the "Needs attention"
// panel wants the most recent alerts, not the whole history, and "load more"
// UI is deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
final alertsListProvider = FutureProvider<List<AlertItem>>((ref) async {
  final page = await ref.read(alertsRepositoryProvider).listAlerts();
  return page.data;
});

/// The metrics an [AlertRule] may target. This mirrors the backend's runtime
/// allow-list (`ALERT_METRICS` in alerts.service.ts) exactly — POST /alerts/rules
/// rejects anything else with a 400, so the UI must never offer a fourth.
const alertRuleMetrics = <String>[
  'out_of_stock',
  'price_deviation',
  'low_scorecard',
];

/// One configured rule returned by GET /alerts/rules.
///
/// `threshold` is genuinely optional: the backend falls back to its own default
/// (10% deviation, score 60) when a rule leaves it unset, so null here means
/// "the server decides", not zero.
class AlertRule {
  const AlertRule({
    required this.id,
    required this.name,
    required this.metric,
    required this.severity,
    required this.active,
    this.threshold,
  });

  final String id;
  final String name;
  final String metric;
  final String severity;
  final bool active;
  final double? threshold;

  factory AlertRule.fromJson(Map<String, dynamic> json) => AlertRule(
    id: json['id'] as String,
    name: json['name'] as String,
    metric: json['metric'] as String,
    // The column defaults to 'normal' server-side; the guard is for a rule
    // written before the default existed.
    severity: json['severity'] as String? ?? 'normal',
    active: json['active'] as bool? ?? true,
    threshold: (json['threshold'] as num?)?.toDouble(),
  );
}

abstract class AlertRulesRepository {
  Future<List<AlertRule>> listRules();

  Future<AlertRule> createRule({
    required String name,
    required String metric,
    double? threshold,
    String? severity,
  });

  Future<AlertRule> updateRule(
    String id, {
    bool? active,
    double? threshold,
    String? severity,
  });
}

class DioAlertRulesRepository implements AlertRulesRepository {
  @override
  Future<List<AlertRule>> listRules() async {
    final response = await dio.get('/alerts/rules');
    return (response.data as List)
        .map((json) => AlertRule.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AlertRule> createRule({
    required String name,
    required String metric,
    double? threshold,
    String? severity,
  }) async {
    // Omit rather than send null: the route type-checks each field it receives,
    // so a null threshold would fail validation where an absent one is allowed.
    final body = <String, dynamic>{'name': name, 'metric': metric};
    if (threshold != null) body['threshold'] = threshold;
    if (severity != null) body['severity'] = severity;
    final response = await dio.post('/alerts/rules', data: body);
    return AlertRule.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AlertRule> updateRule(
    String id, {
    bool? active,
    double? threshold,
    String? severity,
  }) async {
    // PATCH is a partial update — an omitted field is left unchanged, and the
    // route 400s when all three are omitted, so callers must send at least one.
    final body = <String, dynamic>{};
    if (active != null) body['active'] = active;
    if (threshold != null) body['threshold'] = threshold;
    if (severity != null) body['severity'] = severity;
    final response = await dio.patch('/alerts/rules/$id', data: body);
    return AlertRule.fromJson(response.data as Map<String, dynamic>);
  }
}

final alertRulesRepositoryProvider = Provider<AlertRulesRepository>(
  (ref) => DioAlertRulesRepository(),
);

/// GET /alerts/rules returns newest-first, and the evaluator lets the newest
/// active rule per metric win. The screen relies on that order, so nothing here
/// re-sorts the list.
final alertRulesListProvider = FutureProvider<List<AlertRule>>((ref) {
  return ref.read(alertRulesRepositoryProvider).listRules();
});
