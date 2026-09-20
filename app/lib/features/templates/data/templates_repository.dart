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

  /// `GET /templates/selected`: the template this client uses in audits —
  /// its questions become an extra section after S1–S10 (#122) — or null.
  Future<AuditTemplateDetail?> fetchSelected();

  /// `PUT /templates/selected` (manager/admin): use [templateId] in audits,
  /// or stop using one with null. Returns the template now in use.
  Future<AuditTemplateDetail?> selectForAudits(String? templateId);
}

AuditTemplateDetail? _selectedFrom(Object? data) {
  final template = data is Map<String, dynamic> ? data['template'] : null;
  return template is Map<String, dynamic>
      ? AuditTemplateDetail.fromJson(template)
      : null;
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

  @override
  Future<AuditTemplateDetail?> fetchSelected() async {
    final response = await dio.get('/templates/selected');
    return _selectedFrom(response.data);
  }

  @override
  Future<AuditTemplateDetail?> selectForAudits(String? templateId) async {
    final response = await dio.put(
      '/templates/selected',
      data: {'templateId': templateId},
    );
    return _selectedFrom(response.data);
  }
}

final templatesRepositoryProvider = Provider<TemplatesRepository>(
  (ref) => DioTemplatesRepository(),
);

// The provider exposes the FIRST PAGE as a plain list: the templates screen
// wants the current templates, not the whole history, and "load more" UI is
// deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
final templatesListProvider = FutureProvider<List<AuditTemplate>>((ref) async {
  final page = await ref.read(templatesRepositoryProvider).listTemplates();
  return page.data;
});

/// The template this client uses in audits, or null (#122). Manager console:
/// the agent app reads it through the visit's pinned copy instead, so the
/// audit works without signal.
final selectedTemplateProvider = FutureProvider<AuditTemplateDetail?>(
  (ref) => ref.read(templatesRepositoryProvider).fetchSelected(),
);

final templateDetailProvider =
    FutureProvider.family<AuditTemplateDetail, String>((ref, id) {
      return ref.read(templatesRepositoryProvider).fetchTemplate(id);
    });
