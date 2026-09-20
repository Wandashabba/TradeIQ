import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// A saved report definition returned by GET /reports.
class ReportDefinition {
  const ReportDefinition({
    required this.id,
    required this.name,
    required this.type,
  });
  final String id;
  final String name;
  final String type;

  factory ReportDefinition.fromJson(Map<String, dynamic> json) =>
      ReportDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
      );
}

/// The outcome of GET /reports/:id/generate.
class ReportResult {
  const ReportResult({
    required this.rowCount,
    required this.generatedAt,
  });
  final int rowCount;
  final String generatedAt;

  factory ReportResult.fromJson(Map<String, dynamic> json) => ReportResult(
        rowCount: json['rowCount'] as int? ?? 0,
        generatedAt: json['generatedAt'] as String,
      );
}

/// The file `GET /reports/:id/generate?format=csv` returns.
///
/// The server already writes this CSV — header row, one line per row, cells
/// escaped — and the app used to ask for the JSON instead and keep only
/// `rowCount` from it, throwing every row away (#390). What the manager ran
/// the report for was discarded in the parse.
class ReportCsv {
  const ReportCsv({
    required this.bytes,
    required this.filename,
    required this.rows,
  });

  final Uint8List bytes;

  /// The name the file is saved under.
  final String filename;

  /// Data rows, excluding the header line — what "1 284 rows" counts.
  ///
  /// Counted from the bytes rather than taken from a second request: one run,
  /// one answer. A report with no rows at all sends no header either, and the
  /// count is a measured **zero**, not an unknown.
  final int rows;

  /// How many data lines a CSV body holds. The first line is the header, and
  /// a quoted cell may contain newlines, so lines are counted **outside**
  /// quotes — a naive `split('\n').length` over-counts every address column
  /// the reports ship with.
  static int countRows(String body) {
    if (body.isEmpty) return 0;
    var lines = 0;
    var quoted = false;
    var sawContent = false;
    for (var i = 0; i < body.length; i++) {
      final ch = body[i];
      if (ch == '"') {
        // A doubled quote inside a quoted cell is an escaped quote, not a
        // close — skipping it keeps the parity right.
        if (quoted && i + 1 < body.length && body[i + 1] == '"') {
          i++;
          continue;
        }
        quoted = !quoted;
        sawContent = true;
        continue;
      }
      if (ch == '\n' && !quoted) {
        lines++;
        sawContent = false;
        continue;
      }
      if (ch != '\r') sawContent = true;
    }
    if (sawContent) lines++;
    // Line one is the header.
    return lines <= 1 ? 0 : lines - 1;
  }
}

abstract class ReportsRepository {
  Future<PaginatedResponse<ReportDefinition>> listReports();
  Future<ReportResult> generate(String id);

  /// Runs the report and returns the CSV the server produced.
  Future<ReportCsv> generateCsv(String id, {required String slug});

  /// POST /reports (manager/admin). [type] is one of
  /// visits|scorecards|tasks|orders; [filters] honours from/to/outletId/status.
  Future<ReportDefinition> createReport({
    required String name,
    required String type,
    required Map<String, dynamic> filters,
  });

  /// DELETE /reports/:id.
  Future<void> deleteReport(String id);
}

class DioReportsRepository implements ReportsRepository {
  @override
  Future<PaginatedResponse<ReportDefinition>> listReports() async {
    final response = await dio.get('/reports');
    return PaginatedResponse<ReportDefinition>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => ReportDefinition.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<ReportResult> generate(String id) async {
    final response = await dio.get('/reports/$id/generate');
    return ReportResult.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportCsv> generateCsv(String id, {required String slug}) async {
    final response = await dio.get<String>(
      '/reports/$id/generate',
      queryParameters: const <String, dynamic>{'format': 'csv'},
      // Plain, not JSON: the body is a CSV and Dio's default transformer would
      // try to decode it and fail on the first comma.
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '';
    return ReportCsv(
      bytes: Uint8List.fromList(utf8.encode(body)),
      filename: _filenameFor(slug),
      rows: ReportCsv.countRows(body),
    );
  }

  /// The server sends `attachment; filename="report.csv"`. That is the same
  /// name for every report, so a manager who runs three of them ends up with
  /// report.csv, report (2).csv and report (3).csv and no way to tell which is
  /// which — the slug and the day go in the name here.
  static String _filenameFor(String slug) {
    final stamp = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final safe = slug.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return '${safe.isEmpty ? 'report' : safe}-'
        '${stamp.year}${two(stamp.month)}${two(stamp.day)}.csv';
  }

  @override
  Future<ReportDefinition> createReport({
    required String name,
    required String type,
    required Map<String, dynamic> filters,
  }) async {
    final response = await dio.post('/reports', data: {
      'name': name,
      'type': type,
      'filters': filters,
    });
    return ReportDefinition.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteReport(String id) async {
    await dio.delete('/reports/$id');
  }
}

final reportsRepositoryProvider =
    Provider<ReportsRepository>((ref) => DioReportsRepository());

/// The FIRST PAGE of saved definitions, cursor and all.
///
/// The cursor is kept rather than dropped so the screen can say the list was
/// cut. A first page that renders as the whole truth is what a pagination
/// footer exists to stop, and a screen cannot draw one from a bare list.
final reportsPageProvider =
    FutureProvider<PaginatedResponse<ReportDefinition>>((ref) async {
  return ref.read(reportsRepositoryProvider).listReports();
});

/// The definitions themselves, for the screens that only need the rows.
final reportsListProvider = FutureProvider<List<ReportDefinition>>((ref) async {
  final page = await ref.watch(reportsPageProvider.future);
  return page.data;
});
