import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';
import '../../webhooks/data/webhooks_repository.dart' show DeliveryStatus;

export '../../webhooks/data/webhooks_repository.dart' show DeliveryStatus;

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

List<String> _strings(Object? raw) => raw is List
    ? [
        for (final r in raw)
          if (r is String) r,
      ]
    : const [];

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
      schedule: ReportSchedule.fromJson(
        json['schedule'] as Map<String, dynamic>,
      ),
      runId: json['runId'] as String?,
      generatedAt: json['generatedAt'] as String,
      rowCount: json['rowCount'] as int? ?? 0,
      deliveredTo: _strings(json['deliveredTo']),
      deliveries: rawDeliveries is List
          ? [
              for (final d in rawDeliveries)
                if (d is Map<String, dynamic>)
                  ReportDeliveryOutcome.fromJson(d),
            ]
          : const [],
    );
  }
}

// ── Run history (#66) ───────────────────────────────────────────────────────

DateTime? _instant(Object? raw) =>
    raw is String ? DateTime.tryParse(raw) : null;

int _int(Object? raw) => raw is int ? raw : 0;

/// How many runs the history screen asks for at a time.
const reportRunsPageSize = 20;

/// Where a run's delivery stands across every channel, as the backend derives
/// it (`RunStatus` in reportschedules.runs.ts).
enum ReportRunStatus {
  /// A webhook or email delivery is still queued or retrying.
  delivering,

  /// Something was delivered and nothing failed.
  delivered,

  /// Some deliveries succeeded and some failed.
  partial,

  /// Deliveries or a channel failed, and nothing succeeded.
  failed,

  /// Nothing was queued anywhere; the run's reason says why.
  notSent,

  /// A status this app does not know yet.
  unknown;

  static ReportRunStatus parse(String? raw) => switch (raw) {
    'delivering' => ReportRunStatus.delivering,
    'delivered' => ReportRunStatus.delivered,
    'partial' => ReportRunStatus.partial,
    'failed' => ReportRunStatus.failed,
    'not_sent' => ReportRunStatus.notSent,
    _ => ReportRunStatus.unknown,
  };
}

/// A run's webhook deliveries, counted.
class RunWebhookSummary {
  const RunWebhookSummary({
    this.status,
    this.delivered = 0,
    this.failed = 0,
    this.pending = 0,
  });

  /// The channel's outcome when the run was handed over (`queued`,
  /// `no_subscribers`, `failed`), or null if none was recorded.
  final String? status;
  final int delivered;

  /// Gave up after every retry.
  final int failed;

  /// Queued or retrying.
  final int pending;

  factory RunWebhookSummary.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return const RunWebhookSummary();
    return RunWebhookSummary(
      status: raw['status'] as String?,
      delivered: _int(raw['delivered']),
      failed: _int(raw['failed']),
      pending: _int(raw['pending']),
    );
  }
}

/// A run's emails, counted.
class RunEmailSummary {
  const RunEmailSummary({
    this.status,
    this.sent = 0,
    this.failed = 0,
    this.pending = 0,
    this.notConfigured = 0,
  });

  /// `queued`, `no_subscribers`, `not_configured` or `failed`; null if none.
  final String? status;
  final int sent;
  final int failed;
  final int pending;

  /// Recipients not emailed because email was not set up for the run.
  final int notConfigured;

  factory RunEmailSummary.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return const RunEmailSummary();
    return RunEmailSummary(
      status: raw['status'] as String?,
      sent: _int(raw['sent']),
      failed: _int(raw['failed']),
      pending: _int(raw['pending']),
      notConfigured: _int(raw['notConfigured']),
    );
  }
}

/// One webhook delivery of a run, as it stands now.
class RunWebhookResult {
  const RunWebhookResult({
    required this.id,
    required this.url,
    required this.status,
    this.attempts = 0,
    this.lastStatusCode,
    this.lastError,
  });

  final String id;
  final String url;
  final DeliveryStatus status;
  final int attempts;
  final int? lastStatusCode;
  final String? lastError;

  factory RunWebhookResult.fromJson(Map<String, dynamic> json) =>
      RunWebhookResult(
        id: json['id'] as String,
        url: json['url'] as String? ?? '',
        status:
            DeliveryStatus.parse(json['status'] as String?) ??
            DeliveryStatus.pending,
        attempts: _int(json['attempts']),
        lastStatusCode: json['lastStatusCode'] as int?,
        lastError: json['lastError'] as String?,
      );
}

/// One run of a schedule, from `GET /report-schedules/:id/runs`.
class ReportRun {
  const ReportRun({
    required this.id,
    required this.trigger,
    required this.status,
    required this.generatedAt,
    required this.rowCount,
    this.dueAt,
    this.reason,
    this.webhook = const RunWebhookSummary(),
    this.email = const RunEmailSummary(),
    this.deliveries = const [],
    this.webhookDeliveries = const [],
    this.csvDownloadUrl,
    this.csvDownloadExpiresAt,
  });

  final String id;

  /// `scheduled` or `manual`.
  final String trigger;
  final ReportRunStatus status;

  /// The due time a scheduled run fired for; null for Run now.
  final DateTime? dueAt;
  final DateTime generatedAt;
  final int rowCount;

  /// Why something was not sent or failed; null when there is nothing to say.
  final String? reason;
  final RunWebhookSummary webhook;
  final RunEmailSummary email;
  final List<ReportDeliveryOutcome> deliveries;
  final List<RunWebhookResult> webhookDeliveries;

  /// The signed link to the run's CSV. Null when the server has no signed
  /// links set up, or once the link has expired.
  final String? csvDownloadUrl;
  final DateTime? csvDownloadExpiresAt;

  bool get scheduled => trigger == 'scheduled';

  /// The outcome for [channel], if the run recorded one.
  ReportDeliveryOutcome? outcomeFor(String channel) {
    for (final d in deliveries) {
      if (d.channel == channel) return d;
    }
    return null;
  }

  factory ReportRun.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    final rawDeliveries = json['deliveries'];
    final rawWebhooks = json['webhookDeliveries'];
    return ReportRun(
      id: json['id'] as String,
      trigger: json['trigger'] as String? ?? 'manual',
      status: ReportRunStatus.parse(json['status'] as String?),
      dueAt: _instant(json['dueAt']),
      generatedAt: _instant(json['generatedAt']) ?? DateTime.now(),
      rowCount: _int(json['rowCount']),
      reason: json['reason'] as String?,
      webhook: RunWebhookSummary.fromJson(
        summary is Map<String, dynamic> ? summary['webhook'] : null,
      ),
      email: RunEmailSummary.fromJson(
        summary is Map<String, dynamic> ? summary['email'] : null,
      ),
      deliveries: rawDeliveries is List
          ? [
              for (final d in rawDeliveries)
                if (d is Map<String, dynamic>)
                  ReportDeliveryOutcome.fromJson(d),
            ]
          : const [],
      webhookDeliveries: rawWebhooks is List
          ? [
              for (final w in rawWebhooks)
                if (w is Map<String, dynamic>) RunWebhookResult.fromJson(w),
            ]
          : const [],
      csvDownloadUrl: json['csvDownloadUrl'] as String?,
      csvDownloadExpiresAt: _instant(json['csvDownloadExpiresAt']),
    );
  }
}

/// One recipient a run was emailed to, from
/// `GET /report-schedules/:id/runs/:runId/email-deliveries`.
class ReportEmailDelivery {
  const ReportEmailDelivery({
    required this.id,
    required this.recipient,
    required this.status,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String recipient;
  final DeliveryStatus status;
  final int attempts;
  final String? lastError;

  factory ReportEmailDelivery.fromJson(Map<String, dynamic> json) =>
      ReportEmailDelivery(
        id: json['id'] as String,
        recipient: json['recipient'] as String? ?? '',
        status:
            DeliveryStatus.parse(json['status'] as String?) ??
            DeliveryStatus.pending,
        attempts: _int(json['attempts']),
        lastError: json['lastError'] as String?,
      );
}

abstract class ReportSchedulesRepository {
  /// GET /report-schedules/:id/runs — one page of the schedule's runs, newest
  /// first. Pass the previous page's `nextCursor` as [cursor] for the next.
  Future<PaginatedResponse<ReportRun>> listRuns(
    String scheduleId, {
    String? cursor,
    int limit = reportRunsPageSize,
  });

  /// GET /report-schedules/:id/runs/:runId/email-deliveries — every recipient
  /// the run was emailed to (a schedule holds at most 50).
  Future<List<ReportEmailDelivery>> listEmailDeliveries(
    String scheduleId,
    String runId,
  );

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
  Future<PaginatedResponse<ReportRun>> listRuns(
    String scheduleId, {
    String? cursor,
    int limit = reportRunsPageSize,
  }) async {
    final response = await dio.get(
      '/report-schedules/$scheduleId/runs',
      queryParameters: {'limit': limit, 'cursor': ?cursor},
    );
    return PaginatedResponse<ReportRun>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => ReportRun.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<List<ReportEmailDelivery>> listEmailDeliveries(
    String scheduleId,
    String runId,
  ) async {
    final response = await dio.get(
      '/report-schedules/$scheduleId/runs/$runId/email-deliveries',
      queryParameters: {'limit': 50},
    );
    return PaginatedResponse<ReportEmailDelivery>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => ReportEmailDelivery.fromJson(e as Map<String, dynamic>),
    ).data;
  }

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
    final response = await dio.post(
      '/report-schedules',
      data: {
        'reportDefinitionId': reportDefinitionId,
        'cadence': cadence,
        'recipients': recipients,
      },
    );
    return ReportSchedule.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportSchedule> setActive(String id, bool active) async {
    final response = await dio.patch(
      '/report-schedules/$id',
      data: {'active': active},
    );
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
    final response = await dio.patch(
      '/report-schedules/$id',
      data: {'cadence': ?cadence, 'recipients': ?recipients},
    );
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
final reportSchedulesListProvider = FutureProvider<List<ReportSchedule>>((
  ref,
) async {
  final page = await ref
      .read(reportSchedulesRepositoryProvider)
      .listSchedules();
  return page.data;
});

/// One run's email deliveries, keyed by (schedule id, run id). Fetched only
/// when the run's detail is opened; the history screen's refresh invalidates
/// every entry.
final reportRunEmailDeliveriesProvider =
    FutureProvider.family<List<ReportEmailDelivery>, (String, String)>(
      (ref, key) => ref
          .read(reportSchedulesRepositoryProvider)
          .listEmailDeliveries(key.$1, key.$2),
    );
