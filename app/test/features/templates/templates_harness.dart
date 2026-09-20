import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';

/// An `Error` rather than an `Exception`: Riverpod 3 retries an Exception and
/// the screen then never leaves its loading phase.
StateError get templatesNetworkFailure =>
    StateError('SocketException: Failed host lookup: api.tradeiq.co.za');

const templateFixtures = <AuditTemplate>[
  AuditTemplate(
    id: 'tpl-1',
    name: 'Grocery Audit',
    industry: 'retail',
    version: 2,
    active: true,
  ),
  AuditTemplate(id: 'tpl-2', name: 'Pharmacy Audit', version: 1, active: false),
  AuditTemplate(id: 'tpl-3', name: 'Promo Check', version: 4, active: true),
];

/// One section, one required text question and one optional yes/no.
const sampleSchema = <String, dynamic>{
  'sections': <dynamic>[
    <String, dynamic>{
      'id': 'availability',
      'title': 'Availability',
      'fields': <dynamic>[
        <String, dynamic>{
          'id': 'onShelf',
          'label': 'On shelf?',
          'type': 'boolean',
          'weight': 10,
        },
        <String, dynamic>{
          'id': 'facing',
          'label': 'Facing count',
          'type': 'number',
          'visibleIf': <String, dynamic>{'field': 'onShelf', 'equals': true},
        },
      ],
    },
    <String, dynamic>{
      'id': 'extras',
      'title': 'Extras',
      'fields': <dynamic>[
        <String, dynamic>{
          'id': 'zone',
          'label': 'Shelf zone',
          'type': 'choice',
          'options': <String>['eye level', 'floor'],
        },
        <String, dynamic>{'id': 'note', 'label': 'Notes', 'type': 'text'},
        <String, dynamic>{
          'id': 'shelfPhoto',
          'label': 'Shelf photo',
          'type': 'photo',
        },
      ],
    },
  ],
};

/// One section, one scorable question and one **weighted photo** question.
///
/// A weighted photo field is legal JSON — `scoring` is a flat id→weight map
/// with no type filter — and the preview can never earn it, because capture
/// lands with the audit-flow integration. So the reachable maximum here is 10,
/// not 16.
const photoWeightedSchema = <String, dynamic>{
  'sections': <dynamic>[
    <String, dynamic>{
      'id': 'availability',
      'title': 'Availability',
      'fields': <dynamic>[
        <String, dynamic>{
          'id': 'onShelf',
          'label': 'On shelf?',
          'type': 'boolean',
        },
        <String, dynamic>{
          'id': 'shelfPhoto',
          'label': 'Shelf photo',
          'type': 'photo',
        },
      ],
    },
  ],
  'scoring': <String, dynamic>{'onShelf': 10, 'shelfPhoto': 6},
};

class FakeTemplatesRepository implements TemplatesRepository {
  FakeTemplatesRepository({
    this.templates = templateFixtures,
    this.selectedId,
    this.listFailure,
    this.detailFailure,
    this.selectFailure,
    this.detailSchema = sampleSchema,
  });

  final List<AuditTemplate> templates;
  String? selectedId;
  final Object? listFailure;
  final Object? detailFailure;
  final Object? selectFailure;
  final Map<String, dynamic> detailSchema;

  final List<String?> selections = <String?>[];

  @override
  Future<PaginatedResponse<AuditTemplate>> listTemplates() async {
    if (listFailure != null) throw listFailure!;
    return PaginatedResponse<AuditTemplate>(
      data: templates,
      nextCursor: null,
    );
  }

  @override
  Future<AuditTemplateDetail> fetchTemplate(String id) async {
    if (detailFailure != null) throw detailFailure!;
    return AuditTemplateDetail(
      template: templates.firstWhere(
        (t) => t.id == id,
        orElse: () => templates.first,
      ),
      schema: detailSchema,
    );
  }

  AuditTemplateDetail? _selected() {
    for (final t in templates) {
      if (t.id == selectedId) {
        return AuditTemplateDetail(template: t, schema: const <String, dynamic>{});
      }
    }
    return null;
  }

  @override
  Future<AuditTemplateDetail?> fetchSelected() async => _selected();

  @override
  Future<AuditTemplateDetail?> selectForAudits(String? templateId) async {
    selections.add(templateId);
    if (selectFailure != null) throw selectFailure!;
    selectedId = templateId;
    return _selected();
  }
}
