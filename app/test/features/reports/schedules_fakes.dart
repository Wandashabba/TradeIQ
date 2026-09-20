import 'dart:async';

import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';

/// The schedules a reporting test stands up, and the repository behind them.

final nextRunAt = DateTime(2026, 9, 21, 9, 0);

final activeSchedule = ReportSchedule(
  id: 's-active',
  reportDefinitionId: 'r-a',
  reportName: 'Coverage by outlet',
  cadence: 'weekly',
  recipients: const <String>['ops@acme.test', 'lead@acme.test'],
  active: true,
  nextRunAt: nextRunAt,
);

// Paused: the backend clears nextRunAt.
const pausedSchedule = ReportSchedule(
  id: 's-paused',
  reportDefinitionId: 'r-b',
  reportName: 'Sales by SKU',
  cadence: 'daily',
  recipients: <String>['sales@acme.test'],
  active: false,
);

/// A schedule that delivers to nobody — almost certainly a mistake, and the
/// one state on this screen that carries a severity bar.
const noRecipientsSchedule = ReportSchedule(
  id: 's-nobody',
  reportDefinitionId: 'r-c',
  reportName: 'Orders',
  cadence: 'daily',
  recipients: <String>[],
  active: true,
);

const emailNotConfigured = ReportDeliveryOutcome(
  channel: 'email',
  status: 'not_configured',
  targets: <String>['ops@acme.test', 'lead@acme.test'],
  detail: 'Email delivery not configured',
);

ScheduleRunResult runResultFor({
  int rowCount = 42,
  List<String> deliveredTo = const <String>['https://hooks.acme.test/reports'],
  ReportDeliveryOutcome? webhook,
}) => ScheduleRunResult(
  schedule: activeSchedule,
  runId: 'run-1',
  generatedAt: '2026-09-14T10:05:00.000Z',
  rowCount: rowCount,
  deliveredTo: deliveredTo,
  deliveries: <ReportDeliveryOutcome>[
    webhook ??
        ReportDeliveryOutcome(
          channel: 'webhook',
          status: deliveredTo.isEmpty ? 'no_subscribers' : 'queued',
          targets: deliveredTo,
        ),
    emailNotConfigured,
  ],
);

class FakeSchedulesRepository implements ReportSchedulesRepository {
  FakeSchedulesRepository({
    List<ReportSchedule>? schedules,
    this.listFailure,
    this.runFailure,
    this.updateFailure,
    this.listPending = false,
    this.runs = const <ReportRun>[],
    this.runsNextCursor,
    this.runsTotal,
    this.runsFailure,
    this.moreRunsFailure,
    this.morePage = const <ReportRun>[],
    this.emailDeliveries = const <ReportEmailDelivery>[],
    ScheduleRunResult? runResult,
  }) : schedules = <ReportSchedule>[
         ...(schedules ?? <ReportSchedule>[activeSchedule, pausedSchedule]),
       ],
       runResult = runResult ?? runResultFor();

  /// Mutable, so an update is visible on the next list — like the server.
  final List<ReportSchedule> schedules;

  /// `Error`s rather than `Exception`s: Riverpod 3 retries an Exception and
  /// the screen then never leaves its loading phase.
  final Object? listFailure;
  final Object? runFailure;
  final Object? updateFailure;
  final bool listPending;
  final ScheduleRunResult runResult;

  final List<ReportRun> runs;
  final String? runsNextCursor;
  final int? runsTotal;
  final Object? runsFailure;
  final Object? moreRunsFailure;

  /// What the second page holds.
  final List<ReportRun> morePage;
  final List<ReportEmailDelivery> emailDeliveries;

  String? toggledId;
  bool? toggledValue;
  String? runId;
  String? deletedId;
  String? updatedId;
  String? createdReportId;
  String? createdCadence;
  List<String>? createdRecipients;
  String? updatedCadence;
  List<String>? updatedRecipients;
  int listCalls = 0;
  int runsCalls = 0;
  String? runsCursor;
  String? historyId;

  @override
  Future<PaginatedResponse<ReportSchedule>> listSchedules() async {
    listCalls++;
    if (listFailure != null) throw listFailure!;
    if (listPending)
      return Completer<PaginatedResponse<ReportSchedule>>().future;
    return PaginatedResponse<ReportSchedule>(
      data: <ReportSchedule>[...schedules],
      nextCursor: null,
    );
  }

  @override
  Future<ReportSchedule> updateSchedule(
    String id, {
    String? cadence,
    List<String>? recipients,
  }) async {
    updatedId = id;
    updatedCadence = cadence;
    updatedRecipients = recipients;
    if (updateFailure != null) throw updateFailure!;
    final i = schedules.indexWhere((s) => s.id == id);
    final old = schedules[i];
    final updated = ReportSchedule(
      id: old.id,
      reportDefinitionId: old.reportDefinitionId,
      reportName: old.reportName,
      cadence: cadence ?? old.cadence,
      recipients: recipients ?? old.recipients,
      active: old.active,
      lastRunAt: old.lastRunAt,
      nextRunAt: old.nextRunAt,
    );
    schedules[i] = updated;
    return updated;
  }

  @override
  Future<ReportSchedule> createSchedule({
    required String reportDefinitionId,
    required String cadence,
    required List<String> recipients,
  }) async {
    createdReportId = reportDefinitionId;
    createdCadence = cadence;
    createdRecipients = recipients;
    if (updateFailure != null) throw updateFailure!;
    return activeSchedule;
  }

  @override
  Future<ReportSchedule> setActive(String id, bool active) async {
    toggledId = id;
    toggledValue = active;
    if (updateFailure != null) throw updateFailure!;
    return activeSchedule;
  }

  @override
  Future<void> deleteSchedule(String id) async => deletedId = id;

  @override
  Future<ScheduleRunResult> runNow(String id) async {
    runId = id;
    if (runFailure != null) throw runFailure!;
    return runResult;
  }

  @override
  Future<PaginatedResponse<ReportRun>> listRuns(
    String scheduleId, {
    String? cursor,
    int limit = reportRunsPageSize,
  }) async {
    historyId = scheduleId;
    runsCalls++;
    runsCursor = cursor;
    if (cursor == null && runsFailure != null) throw runsFailure!;
    if (cursor != null && moreRunsFailure != null) throw moreRunsFailure!;
    return PaginatedResponse<ReportRun>(
      // Page two is a DIFFERENT page. Handing back the same rows would append
      // duplicate ids to the list and the failure would arrive as "duplicate
      // keys" rather than as anything to do with paging.
      data: cursor == null ? runs : <ReportRun>[...morePage],
      nextCursor: cursor == null ? runsNextCursor : null,
      total: runsTotal,
    );
  }

  @override
  Future<List<ReportEmailDelivery>> listEmailDeliveries(
    String scheduleId,
    String runId,
  ) async => emailDeliveries;
}
