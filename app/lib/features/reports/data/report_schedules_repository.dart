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

/// A saved report on a recurring cadence, as returned by the
/// `/report-schedules` routes.
///
/// Nothing fires a schedule yet (#66): [cadence] is stored, not acted on.
class ReportSchedule {
  const ReportSchedule({
    required this.id,
    required this.reportDefinitionId,
    required this.cadence,
    required this.recipients,
    required this.active,
    this.reportName,
    this.lastRunAt,
  });

  final String id;
  final String reportDefinitionId;

  /// Only the list endpoint joins the report's name; PATCH and run return the
  /// bare row, so this is null there.
  final String? reportName;
  final String cadence;
  final List<String> recipients;
  final bool active;
  final DateTime? lastRunAt;

  factory ReportSchedule.fromJson(Map<String, dynamic> json) {
    final definition = json['reportDefinition'];
    final rawRecipients = json['recipients'];
    final lastRunAt = json['lastRunAt'] as String?;
    return ReportSchedule(
      id: json['id'] as String,
      reportDefinitionId: json['reportDefinitionId'] as String,
      reportName: definition is Map<String, dynamic>
          ? definition['name'] as String?
          : null,
      cadence: json['cadence'] as String,
      // `recipients` is a JSON column: trust only its string entries.
      recipients: rawRecipients is List
          ? [for (final r in rawRecipients) if (r is String) r]
          : const [],
      active: json['active'] as bool? ?? true,
      lastRunAt: lastRunAt == null ? null : DateTime.parse(lastRunAt),
    );
  }
}

/// What `POST /report-schedules/:id/run` returns: the report was generated
/// and the run recorded. [deliveredTo] echoes the configured recipients — the
/// backend does NOT send anything yet (delivery is #66), so the UI must not
/// read it as proof of delivery.
class ScheduleRunResult {
  const ScheduleRunResult({
    required this.schedule,
    required this.generatedAt,
    required this.rowCount,
    required this.deliveredTo,
  });

  final ReportSchedule schedule;
  final String generatedAt;
  final int rowCount;
  final List<String> deliveredTo;

  factory ScheduleRunResult.fromJson(Map<String, dynamic> json) {
    final raw = json['deliveredTo'];
    return ScheduleRunResult(
      schedule:
          ReportSchedule.fromJson(json['schedule'] as Map<String, dynamic>),
      generatedAt: json['generatedAt'] as String,
      rowCount: json['rowCount'] as int? ?? 0,
      deliveredTo: raw is List
          ? [for (final r in raw) if (r is String) r]
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

  /// POST /report-schedules/:id/run — generate the report now and record the
  /// run.
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
