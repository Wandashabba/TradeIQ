import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/download/file_download.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';

import '../worklist_harness.dart';

/// Everything the reporting screens need to stand up without a server.
///
/// The fakes override **repositories**, never the providers above them, so the
/// page envelope, the CSV row count and the delivery summaries are all
/// exercised for real.

const reportA = ReportDefinition(
  id: 'r-a',
  name: 'Coverage by outlet',
  type: 'outlet_coverage',
);

const reportB = ReportDefinition(
  id: 'r-b',
  name: 'Sales by SKU',
  type: 'sales_by_sku',
);

/// A failure that names a host, so a test can prove the host never reaches the
/// screen. An `Error`, not an `Exception` — see [FakeReportsRepository.csvFailure].
StateError get networkFailure =>
    StateError('SocketException: Failed host lookup: api.tradeiq.co.za');

/// A CSV with a header and [rows] data lines.
String csvWith(int rows) {
  final buffer = StringBuffer('outlet,visits\n');
  for (var i = 0; i < rows; i++) {
    buffer.writeln('Outlet $i,${i + 1}');
  }
  return buffer.toString();
}

class FakeReportsRepository implements ReportsRepository {
  FakeReportsRepository({
    this.reports = const <ReportDefinition>[reportA, reportB],
    this.nextCursor,
    this.total,
    this.csvRows = 5,
    this.csvFailure,
    this.listFailure,
    this.listPending = false,
  });

  final List<ReportDefinition> reports;
  final String? nextCursor;
  final int? total;
  final int csvRows;

  /// Thrown by `generateCsv` when set.
  ///
  /// An `Error` rather than an `Exception` in the tests that use it, because
  /// Riverpod 3 **retries** a provider that threw an `Exception` — it reads it
  /// as transient — and a retrying provider is `AsyncLoading`, not
  /// `AsyncError`. A test that threw `Exception('boom')` at a list provider
  /// would sit on the skeleton forever and never reach the error branch it was
  /// written to prove.
  final Object? csvFailure;
  final Object? listFailure;
  final bool listPending;

  String? generatedId;
  String? generatedSlug;
  String? deletedId;
  String? createdName;
  String? createdType;
  Map<String, dynamic>? createdFilters;

  @override
  Future<PaginatedResponse<ReportDefinition>> listReports() async {
    if (listFailure != null) throw listFailure!;
    if (listPending) {
      return Completer<PaginatedResponse<ReportDefinition>>().future;
    }
    return PaginatedResponse<ReportDefinition>(
      data: reports,
      nextCursor: nextCursor,
      total: total,
    );
  }

  @override
  Future<ReportResult> generate(String id) async {
    generatedId = id;
    return ReportResult(
      rowCount: csvRows,
      generatedAt: '2026-09-20T10:00:00.000Z',
    );
  }

  @override
  Future<ReportCsv> generateCsv(String id, {required String slug}) async {
    generatedId = id;
    generatedSlug = slug;
    if (csvFailure != null) throw csvFailure!;
    final body = csvRows == 0 ? '' : csvWith(csvRows);
    return ReportCsv(
      bytes: Uint8List.fromList(utf8.encode(body)),
      filename: '$slug-20260920.csv',
      rows: ReportCsv.countRows(body),
    );
  }

  @override
  Future<ReportDefinition> createReport({
    required String name,
    required String type,
    required Map<String, dynamic> filters,
  }) async {
    createdName = name;
    createdType = type;
    createdFilters = filters;
    return reportA;
  }

  @override
  Future<void> deleteReport(String id) async => deletedId = id;
}

/// What the Run action handed the platform, without a filesystem or a DOM.
class RecordingDownloader implements FileDownloader {
  RecordingDownloader({
    this.fails = false,
    this.location = '/Users/me/Downloads',
  });

  final bool fails;
  final String? location;

  Uint8List? savedBytes;
  String? savedFilename;
  String? savedMimeType;

  @override
  Future<SavedFile> save({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    if (fails) throw const DownloadRefused('The disk would not take it.');
    savedBytes = bytes;
    savedFilename = filename;
    savedMimeType = mimeType;
    return SavedFile(filename: filename, location: location);
  }
}

ReportSchedule schedule({
  String id = 's-1',
  String reportId = 'r-a',
  String? reportName = 'Coverage by outlet',
  String cadence = 'weekly',
  List<String> recipients = const <String>['ops@example.com'],
  bool active = true,
  DateTime? lastRunAt,
  DateTime? nextRunAt,
}) => ReportSchedule(
  id: id,
  reportDefinitionId: reportId,
  reportName: reportName,
  cadence: cadence,
  recipients: recipients,
  active: active,
  lastRunAt: lastRunAt,
  nextRunAt: nextRunAt,
);

/// Pushes [child] the way the console reaches it — over a route that stays
/// underneath — so the screen's own Back has somewhere to land.
///
/// A pushed screen pumped as the *root* route is a screen whose pop kills the
/// router, and the failure arrives as a go_router assertion about an empty
/// stack rather than as anything to do with the screen.
class PushedHost extends StatefulWidget {
  const PushedHost({super.key, required this.child});

  final Widget child;

  @override
  State<PushedHost> createState() => _PushedHostState();
}

class _PushedHostState extends State<PushedHost> {
  bool _pushed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pushed) return;
    _pushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (context) => widget.child));
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Align(alignment: Alignment.topLeft, child: Text('beneath'));
}

/// A 360×720 console phone with the reporting repositories stubbed.
Future<void> pumpReports(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
  TiqSkin? skin,
  double textScale = 1.0,
  bool settle = true,
  Size size = const Size(360, 720),
}) => pumpWorklist(
  tester,
  screen,
  skin: skin,
  textScale: textScale,
  settle: settle,
  size: size,
  overrides: overrides,
);

/// [pumpReports], for a screen the console pushes rather than routes to.
Future<void> pumpPushedReports(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
  TiqSkin? skin,
  double textScale = 1.0,
  Size size = const Size(360, 720),
}) async {
  await pumpReports(
    tester,
    PushedHost(child: screen),
    overrides: overrides,
    skin: skin,
    textScale: textScale,
    size: size,
  );
  await tester.pumpAndSettle();
}
