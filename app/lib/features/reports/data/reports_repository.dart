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
  const ReportResult({required this.rowCount, required this.generatedAt});
  final int rowCount;
  final String generatedAt;

  factory ReportResult.fromJson(Map<String, dynamic> json) => ReportResult(
    rowCount: json['rowCount'] as int? ?? 0,
    generatedAt: json['generatedAt'] as String,
  );
}

abstract class ReportsRepository {
  Future<PaginatedResponse<ReportDefinition>> listReports();
  Future<ReportResult> generate(String id);

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
  Future<ReportDefinition> createReport({
    required String name,
    required String type,
    required Map<String, dynamic> filters,
  }) async {
    final response = await dio.post(
      '/reports',
      data: {'name': name, 'type': type, 'filters': filters},
    );
    return ReportDefinition.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteReport(String id) async {
    await dio.delete('/reports/$id');
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => DioReportsRepository(),
);

// The provider exposes the FIRST PAGE as a plain list: the reports screen
// wants the current report definitions, not the whole history, and "load
// more" UI is deliberately out of scope for the pagination sweep (see the
// spec). `nextCursor` is available on the repository for any screen that
// later needs to page; this provider intentionally drops it.
final reportsListProvider = FutureProvider<List<ReportDefinition>>((ref) async {
  final page = await ref.read(reportsRepositoryProvider).listReports();
  return page.data;
});
