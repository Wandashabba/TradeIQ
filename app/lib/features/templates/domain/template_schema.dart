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
    this.required = false,
  });

  final String id;
  final String label;
  final TemplateFieldType type;
  final List<String> options;
  final double? weight;
  final TemplateFieldCondition? visibleIf;

  /// The schema's `required: true`. A required question must be answered
  /// before the visit can be submitted — while it is visible.
  final bool required;

  bool isVisible(Map<String, Object?> answers) {
    final condition = visibleIf;
    return condition == null || answers[condition.fieldId] == condition.equals;
  }

  /// Whether [answers] holds a real answer for this field. A switch that was
  /// recorded off is an answer; an empty or whitespace text is not.
  bool isAnswered(Map<String, Object?> answers) {
    final value = answers[id];
    return switch (type) {
      TemplateFieldType.boolean => value is bool,
      TemplateFieldType.number => value is num,
      TemplateFieldType.choice ||
      TemplateFieldType.text => value is String && value.trim().isNotEmpty,
      TemplateFieldType.photo => value != null,
    };
  }

  /// Whether leaving this field unanswered blocks the submit.
  ///
  /// Photo questions cannot be captured in the form yet, so a required photo
  /// never blocks: a gate the agent has no way to open is a dead end in a shop.
  bool get blocksSubmit => required && type != TemplateFieldType.photo;
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

  Iterable<TemplateField> get fields => sections.expand((s) => s.fields);

  /// Whether any question can block a submit.
  bool get hasRequired => fields.any((f) => f.blocksSubmit);

  /// The visible required questions still unanswered. The submit gate blocks
  /// on exactly these; a required question hidden by its condition does not
  /// count, because the agent cannot see it.
  List<TemplateField> missingRequired(Map<String, Object?> answers) => [
        for (final f in fields)
          if (f.blocksSubmit && f.isVisible(answers) && !f.isAnswered(answers))
            f,
      ];

  /// Visible, answerable questions (photos cannot be captured yet).
  int questionCount(Map<String, Object?> answers) => fields
      .where((f) => f.type != TemplateFieldType.photo && f.isVisible(answers))
      .length;

  /// Visible questions that hold an answer.
  int answeredCount(Map<String, Object?> answers) => fields
      .where((f) =>
          f.type != TemplateFieldType.photo &&
          f.isVisible(answers) &&
          f.isAnswered(answers))
      .length;

  /// [answers] with every visible, untouched switch recorded as off.
  ///
  /// A switch renders off until it is flipped, so the agent who saves with it
  /// off has answered "no" — recording nothing would leave a required yes/no
  /// question blocking the submit while the screen shows it answered. Repeats
  /// until stable, because recording a switch can reveal a question that
  /// depends on it.
  Map<String, Object?> withSwitchDefaults(Map<String, Object?> answers) {
    final out = Map<String, Object?>.of(answers);
    for (var pass = 0; pass <= sections.length + fields.length; pass++) {
      var changed = false;
      for (final f in fields) {
        if (f.type == TemplateFieldType.boolean &&
            f.isVisible(out) &&
            out[f.id] is! bool) {
          out[f.id] = false;
          changed = true;
        }
      }
      if (!changed) break;
    }
    return out;
  }

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
      // Only a literal `true` makes a question required: a free-form schema
      // with "yes" or 1 there should not silently start blocking submits.
      required: rawField['required'] == true,
    );
  }
}
