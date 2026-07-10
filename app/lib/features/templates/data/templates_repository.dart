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

abstract class TemplatesRepository {
  Future<List<AuditTemplate>> listTemplates();
}

class DioTemplatesRepository implements TemplatesRepository {
  @override
  Future<List<AuditTemplate>> listTemplates() async {
    final response = await dio.get('/templates');
    return (response.data as List)
        .map((json) => AuditTemplate.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final templatesRepositoryProvider =
    Provider<TemplatesRepository>((ref) => DioTemplatesRepository());

final templatesListProvider = FutureProvider<List<AuditTemplate>>((ref) {
  return ref.read(templatesRepositoryProvider).listTemplates();
});
