/// Parsed dynamic-form definition of an AuditTemplate's `schema` (issue #54).
///
/// The backend stores the schema verbatim as free-form JSON, so parsing here
/// is tolerant: malformed sections/fields and unknown field types are skipped
/// rather than crashing the renderer.
///
/// Recognised shape:
/// ```json
/// {
///   "sections": [
///     {
///       "id": "availability",
///       "title": "Availability",
///       "fields": [
///         {
///           "id": "onShelf",
///           "label": "On shelf?",
///           "type": "boolean",
///           "weight": 10,
///           "visibleIf": {"field": "otherFieldId", "equals": true},
///           "options": ["a", "b"]
///         }
///       ]
///     }
///   ],
///   "scoring": {"onShelf": 10}
/// }
/// ```
/// A field's weight comes from its own `weight`, falling back to the
/// top-level `scoring` map keyed by field id.
library;

enum TemplateFieldType { number, choice, boolean, photo, text }

/// Shows a field only when another field's answer equals a fixed value.
class TemplateFieldCondition {
  const TemplateFieldCondition({required this.fieldId, required this.equals});
  final String fieldId;
  final Object? equals;
}

class TemplateField {
  const TemplateField({
    required this.id,
    required this.label,
    required this.type,
    this.options = const [],
    this.weight,
    this.visibleIf,
  });

  final String id;
  final String label;
  final TemplateFieldType type;
  final List<String> options;
  final double? weight;
  final TemplateFieldCondition? visibleIf;

  bool isVisible(Map<String, Object?> answers) {
    final condition = visibleIf;
    return condition == null || answers[condition.fieldId] == condition.equals;
  }
}

class TemplateSection {
  const TemplateSection({
    required this.id,
    required this.title,
    required this.fields,
  });

  final String id;
  final String title;
  final List<TemplateField> fields;
}

class TemplateSchema {
  const TemplateSchema({required this.sections});

  final List<TemplateSection> sections;

  /// Sum of every weighted field, answered or not.
  double get maxScore => sections
      .expand((s) => s.fields)
      .fold(0.0, (sum, f) => sum + (f.weight ?? 0));

  /// Live score preview: a weighted field earns its weight once answered
  /// (boolean fields only when true) and visible. Photo fields never score
  /// here — capture lands with the audit-flow integration.
  double scoreFor(Map<String, Object?> answers) {
    var total = 0.0;
    for (final section in sections) {
      for (final field in section.fields) {
        final weight = field.weight;
        if (weight == null || !field.isVisible(answers)) continue;
        final value = answers[field.id];
        final earned = switch (field.type) {
          TemplateFieldType.boolean => value == true,
          TemplateFieldType.number => value is num,
          TemplateFieldType.photo => false,
          TemplateFieldType.choice ||
          TemplateFieldType.text =>
            value is String && value.isNotEmpty,
        };
        if (earned) total += weight;
      }
    }
    return total;
  }

  factory TemplateSchema.parse(Map<String, dynamic> json) {
    final scoringWeights = <String, double>{};
    final rawScoring = json['scoring'];
    if (rawScoring is Map) {
      for (final entry in rawScoring.entries) {
        final value = entry.value;
        if (value is num) scoringWeights['${entry.key}'] = value.toDouble();
      }
    }

    final sections = <TemplateSection>[];
    final rawSections = json['sections'];
    if (rawSections is List) {
      for (final rawSection in rawSections) {
        if (rawSection is! Map) continue;
        final sectionId = rawSection['id'];
        if (sectionId is! String || sectionId.isEmpty) continue;

        final fields = <TemplateField>[];
        final rawFields = rawSection['fields'];
        if (rawFields is List) {
          for (final rawField in rawFields) {
            final field = _parseField(rawField, scoringWeights);
            if (field != null) fields.add(field);
          }
        }
        // A section with no renderable fields has nothing to step through.
        if (fields.isEmpty) continue;

        final title = rawSection['title'];
        sections.add(TemplateSection(
          id: sectionId,
          title: title is String && title.isNotEmpty ? title : sectionId,
          fields: fields,
        ));
      }
    }
    return TemplateSchema(sections: sections);
  }

  static TemplateField? _parseField(
    Object? rawField,
    Map<String, double> scoringWeights,
  ) {
    if (rawField is! Map) return null;
    final id = rawField['id'];
    if (id is! String || id.isEmpty) return null;

    final type = TemplateFieldType.values.asNameMap()[rawField['type']];
    if (type == null) return null; // unknown field type — skip, don't crash

    final options = <String>[
      if (rawField['options'] is List)
        for (final option in rawField['options'] as List)
          if (option is String) option,
    ];
    // A choice field with nothing to choose from is unrenderable.
    if (type == TemplateFieldType.choice && options.isEmpty) return null;

    final rawWeight = rawField['weight'];
    final rawVisibleIf = rawField['visibleIf'];
    TemplateFieldCondition? visibleIf;
    if (rawVisibleIf is Map && rawVisibleIf['field'] is String) {
      visibleIf = TemplateFieldCondition(
        fieldId: rawVisibleIf['field'] as String,
        equals: rawVisibleIf['equals'],
      );
    }

    final label = rawField['label'];
    return TemplateField(
      id: id,
      label: label is String && label.isNotEmpty ? label : id,
      type: type,
      options: options,
      weight: rawWeight is num ? rawWeight.toDouble() : scoringWeights[id],
      visibleIf: visibleIf,
    );
  }
}
