import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// One audit template returned by GET /templates.
class AuditTemplate {
  const AuditTemplate({
    required this.id,
    required this.name,
    required this.version,
    required this.active,
    this.industry,
  });
  final String id;
  final String name;
  final String? industry;
  final int version;
  final bool active;

  factory AuditTemplate.fromJson(Map<String, dynamic> json) => AuditTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        industry: json['industry'] as String?,
        version: json['version'] as int? ?? 1,
        active: json['active'] as bool? ?? true,
      );
}

/// One template fetched by GET /templates/:id, including its free-form
/// dynamic-form `schema` (issue #54 — the renderer consumes this).
class AuditTemplateDetail {
  const AuditTemplateDetail({required this.template, required this.schema});
  final AuditTemplate template;
  final Map<String, dynamic> schema;

  factory AuditTemplateDetail.fromJson(Map<String, dynamic> json) =>
      AuditTemplateDetail(
        template: AuditTemplate.fromJson(json),
        schema: json['schema'] is Map<String, dynamic>
            ? json['schema'] as Map<String, dynamic>
            : const {},
      );
}

abstract class TemplatesRepository {
  Future<PaginatedResponse<AuditTemplate>> listTemplates();
  Future<AuditTemplateDetail> fetchTemplate(String id);
}

class DioTemplatesRepository implements TemplatesRepository {
  @override
  Future<PaginatedResponse<AuditTemplate>> listTemplates() async {
    final response = await dio.get('/templates');
    return PaginatedResponse<AuditTemplate>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => AuditTemplate.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<AuditTemplateDetail> fetchTemplate(String id) async {
    final response = await dio.get('/templates/$id');
    return AuditTemplateDetail.fromJson(response.data as Map<String, dynamic>);
  }
}

final templatesRepositoryProvider =
    Provider<TemplatesRepository>((ref) => DioTemplatesRepository());

// The provider exposes the FIRST PAGE as a plain list: the templates screen
// wants the current templates, not the whole history, and "load more" UI is
// deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
final templatesListProvider = FutureProvider<List<AuditTemplate>>((ref) async {
  final page = await ref.read(templatesRepositoryProvider).listTemplates();
  return page.data;
});

final templateDetailProvider =
    FutureProvider.family<AuditTemplateDetail, String>((ref, id) {
  return ref.read(templatesRepositoryProvider).fetchTemplate(id);
});
