import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// The cadences a schedule may be saved with — the backend's runtime
/// allow-list (`CADENCES` in reportschedules.service.ts), in its order.
const reportCadences = <String>['daily', 'weekly'];

/// A cadence slug as a person reads it.
String cadenceLabel(String cadence) => switch (cadence) {
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      _ => cadence,
    };

/// The webhook event a schedule's runs are announced as (#66).
const reportGeneratedEvent = 'report.generated';

DateTime? _date(Object? raw) => raw is String ? DateTime.parse(raw) : null;

List<String> _strings(Object? raw) =>
    raw is List ? [for (final r in raw) if (r is String) r] : const [];

/// A saved report on a recurring cadence, as returned by the
/// `/report-schedules` routes.
///
/// The backend fires active schedules on their cadence (#66): [nextRunAt] is
/// when it next will, null while paused.
class ReportSchedule {
  const ReportSchedule({
    required this.id,
    required this.reportDefinitionId,
    required this.cadence,
    required this.recipients,
    required this.active,
    this.reportName,
    this.lastRunAt,
    this.nextRunAt,
  });

  final String id;
  final String reportDefinitionId;

  /// Only the list endpoint joins the report's name; PATCH and run return the
  /// bare row, so this is null there.
  final String? reportName;
  final String cadence;
  final List<String> recipients;
  final bool active;

  /// The latest run, scheduled or manual.
  final DateTime? lastRunAt;

  /// When the backend next fires this schedule. Null while paused.
  final DateTime? nextRunAt;

  factory ReportSchedule.fromJson(Map<String, dynamic> json) {
    final definition = json['reportDefinition'];
    return ReportSchedule(
      id: json['id'] as String,
      reportDefinitionId: json['reportDefinitionId'] as String,
      reportName: definition is Map<String, dynamic>
          ? definition['name'] as String?
          : null,
      cadence: json['cadence'] as String,
      // `recipients` is a JSON column: trust only its string entries.
      recipients: _strings(json['recipients']),
      active: json['active'] as bool? ?? true,
      lastRunAt: _date(json['lastRunAt']),
      nextRunAt: _date(json['nextRunAt']),
    );
  }
}

/// What one delivery channel did with a run (#66): `webhook` queued to the
/// subscribed endpoints, `email` not configured, and so on.
class ReportDeliveryOutcome {
  const ReportDeliveryOutcome({
    required this.channel,
    required this.status,
    this.targets = const [],
    this.detail,
  });

  final String channel;

  /// `queued`, `no_subscribers`, `not_configured` or `failed`.
  final String status;
  final List<String> targets;
  final String? detail;

  factory ReportDeliveryOutcome.fromJson(Map<String, dynamic> json) =>
      ReportDeliveryOutcome(
        channel: json['channel'] as String? ?? '',
        status: json['status'] as String? ?? '',
        targets: _strings(json['targets']),
        detail: json['detail'] as String?,
      );
}

/// What `POST /report-schedules/:id/run` returns: the report was generated,
/// the run recorded, and it was handed to every delivery channel.
///
/// [deliveredTo] lists every target a delivery was queued for — webhook URLs,
/// then email addresses — and is empty when nothing was sent. Queued is not
/// yet received; the Webhooks screen shows each webhook delivery's outcome.
class ScheduleRunResult {
  const ScheduleRunResult({
    required this.schedule,
    required this.generatedAt,
    required this.rowCount,
    required this.deliveredTo,
    this.runId,
    this.deliveries = const [],
  });

  final ReportSchedule schedule;
  final String? runId;
  final String generatedAt;
  final int rowCount;
  final List<String> deliveredTo;
  final List<ReportDeliveryOutcome> deliveries;

  /// The outcome for [channel], if the backend reported one.
  ReportDeliveryOutcome? outcomeFor(String channel) {
    for (final d in deliveries) {
      if (d.channel == channel) return d;
    }
    return null;
  }

  factory ScheduleRunResult.fromJson(Map<String, dynamic> json) {
    final rawDeliveries = json['deliveries'];
    return ScheduleRunResult(
      schedule:
          ReportSchedule.fromJson(json['schedule'] as Map<String, dynamic>),
      runId: json['runId'] as String?,
      generatedAt: json['generatedAt'] as String,
      rowCount: json['rowCount'] as int? ?? 0,
      deliveredTo: _strings(json['deliveredTo']),
      deliveries: rawDeliveries is List
          ? [
              for (final d in rawDeliveries)
                if (d is Map<String, dynamic>) ReportDeliveryOutcome.fromJson(d),
            ]
          : const [],
    );
  }
}

abstract class ReportSchedulesRepository {
  /// GET /report-schedules (manager/admin).
  Future<PaginatedResponse<ReportSchedule>> listSchedules();

  /// POST /report-schedules. [cadence] is one of [reportCadences];
  /// [recipients] must be non-empty.
  Future<ReportSchedule> createSchedule({
    required String reportDefinitionId,
    required String cadence,
    required List<String> recipients,
  });

  /// PATCH /report-schedules/:id — pause or resume without deleting.
  Future<ReportSchedule> setActive(String id, bool active);

  /// PATCH /report-schedules/:id — change how often and to whom. Only the
  /// fields given are sent; at least one is required, as the backend demands.
  /// The linked report is not updatable (the route accepts only `active`,
  /// `cadence` and `recipients`).
  Future<ReportSchedule> updateSchedule(
    String id, {
    String? cadence,
    List<String>? recipients,
  });

  /// DELETE /report-schedules/:id.
  Future<void> deleteSchedule(String id);

  /// POST /report-schedules/:id/run — generate the report now, record the run
  /// and deliver it. Does not move the next scheduled run.
  Future<ScheduleRunResult> runNow(String id);
}

class DioReportSchedulesRepository implements ReportSchedulesRepository {
  @override
  Future<PaginatedResponse<ReportSchedule>> listSchedules() async {
    final response = await dio.get('/report-schedules');
    return PaginatedResponse<ReportSchedule>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => ReportSchedule.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<ReportSchedule> createSchedule({
    required String reportDefinitionId,
    required String cadence,
    required List<String> recipients,
  }) async {
    final response = await dio.post('/report-schedules', data: {
      'reportDefinitionId': reportDefinitionId,
      'cadence': cadence,
      'recipients': recipients,
    });
    return ReportSchedule.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportSchedule> setActive(String id, bool active) async {
    final response =
        await dio.patch('/report-schedules/$id', data: {'active': active});
    return ReportSchedule.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportSchedule> updateSchedule(
    String id, {
    String? cadence,
    List<String>? recipients,
  }) async {
    assert(
      cadence != null || recipients != null,
      'updateSchedule needs a cadence or recipients',
    );
    final response = await dio.patch('/report-schedules/$id', data: {
      'cadence': ?cadence,
      'recipients': ?recipients,
    });
    return ReportSchedule.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteSchedule(String id) async {
    await dio.delete('/report-schedules/$id');
  }

  @override
  Future<ScheduleRunResult> runNow(String id) async {
    final response = await dio.post('/report-schedules/$id/run');
    return ScheduleRunResult.fromJson(response.data as Map<String, dynamic>);
  }
}

final reportSchedulesRepositoryProvider = Provider<ReportSchedulesRepository>(
  (ref) => DioReportSchedulesRepository(),
);

// First page only, as a plain list — the same deliberate scope as
// `reportsListProvider`: no "load more" UI in the console yet.
final reportSchedulesListProvider =
    FutureProvider<List<ReportSchedule>>((ref) async {
  final page =
      await ref.read(reportSchedulesRepositoryProvider).listSchedules();
  return page.data;
});
