import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

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
  Future<List<AuditTemplate>> listTemplates();
  Future<AuditTemplateDetail> fetchTemplate(String id);
}

class DioTemplatesRepository implements TemplatesRepository {
  @override
  Future<List<AuditTemplate>> listTemplates() async {
    final response = await dio.get('/templates');
    return (response.data as List)
        .map((json) => AuditTemplate.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AuditTemplateDetail> fetchTemplate(String id) async {
    final response = await dio.get('/templates/$id');
    return AuditTemplateDetail.fromJson(response.data as Map<String, dynamic>);
  }
}

final templatesRepositoryProvider =
    Provider<TemplatesRepository>((ref) => DioTemplatesRepository());

final templatesListProvider = FutureProvider<List<AuditTemplate>>((ref) {
  return ref.read(templatesRepositoryProvider).listTemplates();
});

final templateDetailProvider =
    FutureProvider.family<AuditTemplateDetail, String>((ref, id) {
  return ref.read(templatesRepositoryProvider).fetchTemplate(id);
});
