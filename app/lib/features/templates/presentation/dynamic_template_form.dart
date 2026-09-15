import 'package:flutter/material.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../../l10n/l10n.dart';
import '../domain/template_schema.dart';

/// Renders a parsed TemplateSchema, collecting answers keyed by field id.
///
/// Two layouts:
/// - the default, one section at a time with Back/Next, calling [onSubmit]
///   after the last section (the manager's template preview, #54);
/// - [DynamicTemplateForm.inline], every section stacked in one column for a
///   host that already scrolls and owns saving: the audit hub's
///   client-questions section (#122).
class DynamicTemplateForm extends StatefulWidget {
  const DynamicTemplateForm({
    super.key,
    required this.schema,
    required ValueChanged<Map<String, Object?>> this.onSubmit,
    this.submitLabel = 'Finish',
  }) : inline = false,
       initialAnswers = const {},
       onChanged = null,
       showRequiredErrors = false;

  /// Every section in one column, starting from [initialAnswers] and reporting
  /// each change through [onChanged].
  ///
  /// Agent-facing, so the form's own words (required markers, the photo note)
  /// come from l10n. The questions are the client's and are shown as written.
  /// [showRequiredErrors] marks each unanswered required question — set it
  /// once the agent has tried to save.
  const DynamicTemplateForm.inline({
    super.key,
    required this.schema,
    this.initialAnswers = const {},
    required ValueChanged<Map<String, Object?>> this.onChanged,
    this.showRequiredErrors = false,
  }) : inline = true,
       onSubmit = null,
       submitLabel = '';

  final TemplateSchema schema;
  final ValueChanged<Map<String, Object?>>? onSubmit;
  final String submitLabel;
  final bool inline;
  final Map<String, Object?> initialAnswers;
  final ValueChanged<Map<String, Object?>>? onChanged;
  final bool showRequiredErrors;

  @override
  State<DynamicTemplateForm> createState() => _DynamicTemplateFormState();
}

class _DynamicTemplateFormState extends State<DynamicTemplateForm> {
  int _sectionIndex = 0;
  final Map<String, Object?> _answers = {};

  @override
  void initState() {
    super.initState();
    _answers.addAll(widget.initialAnswers);
  }

  void _next(bool isLast) {
    if (isLast) {
      widget.onSubmit?.call(Map.unmodifiable(_answers));
    } else {
      setState(() => _sectionIndex++);
    }
  }

  void _set(String fieldId, Object? value) {
    setState(() {
      if (value == null) {
        _answers.remove(fieldId);
      } else {
        _answers[fieldId] = value;
      }
    });
    widget.onChanged?.call(Map.unmodifiable(_answers));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inline) return _inline(context);

    final sections = widget.schema.sections;
    if (sections.isEmpty) {
      return const Center(
        child: Text('This template has no form sections yet.'),
      );
    }

    final section = sections[_sectionIndex];
    final isLast = _sectionIndex == sections.length - 1;
    final visibleFields =
        section.fields.where((f) => f.isVisible(_answers)).toList();
    final maxScore = widget.schema.maxScore;

    if (context.colors.glass) {
      return _glass(context, sections.length, section, isLast, visibleFields);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Section ${_sectionIndex + 1} of ${sections.length} — ${section.title}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (maxScore > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Score preview: ${_trimmed(widget.schema.scoreFor(_answers))}'
                ' / ${_trimmed(maxScore)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [for (final field in visibleFields) _buildField(field)],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_sectionIndex > 0)
                OutlinedButton(
                  onPressed: () => setState(() => _sectionIndex--),
                  child: const Text('Back'),
                ),
              const Spacer(),
              ElevatedButton(
                key: const ValueKey('form-next'),
                onPressed: () => _next(isLast),
                child: Text(isLast ? widget.submitLabel : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Glass: the section's place as a kicker over its title, the running score
  /// as a figure, the fields on one panel, and Next as the primary action.
  Widget _glass(
    BuildContext context,
    int sectionCount,
    TemplateSection section,
    bool isLast,
    List<TemplateField> visibleFields,
  ) {
    final lumen = context.lumen;
    final maxScore = widget.schema.maxScore;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker('Section ${_sectionIndex + 1} of $sectionCount'),
          const SizedBox(height: 6),
          Text(
            section.title,
            style: LumenGlass.title(size: 22, color: lumen.ink),
          ),
          if (maxScore > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text(
                    'Score preview',
                    style: TextStyle(fontSize: 12, color: lumen.inkMuted),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_trimmed(widget.schema.scoreFor(_answers))}'
                    ' / ${_trimmed(maxScore)}',
                    style: LumenGlass.figure(size: 13, color: lumen.ink),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Expanded(
            child: GlassPane(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                children: [
                  for (final field in visibleFields) _glassField(field),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_sectionIndex > 0) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: () => setState(() => _sectionIndex--),
                  child: const Text('Back'),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: GlassPrimaryButton(
                  key: const ValueKey('form-next'),
                  label: isLast ? widget.submitLabel : 'Next',
                  onPressed: () => _next(isLast),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Inline: each of the client's sections under its own title, each question
  /// on its own no-blur glass tile (the host scrolls), as the fixed sections
  /// lay out theirs.
  Widget _inline(BuildContext context) {
    final colors = context.colors;
    final sections = widget.schema.sections;
    if (sections.isEmpty) {
      return Text(
        context.l10n.visitTemplateNoQuestions,
        style: TextStyle(fontSize: 13.5, color: colors.ink2),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, section) in sections.indexed) ...[
          if (i > 0) const SizedBox(height: 18),
          KeyedSubtree(
            key: ValueKey('template-section-${section.id}'),
            child: colors.glass
                ? Kicker(section.title, color: context.lumen.kicker)
                : Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.ink1,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          for (final field in section.fields)
            if (field.isVisible(_answers))
              colors.glass
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassPane(
                        kind: GlassKind.tile,
                        blur: false,
                        radius: LumenGlass.radiusCard,
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                        child: Material(
                          type: MaterialType.transparency,
                          child: _buildField(field),
                        ),
                      ),
                    )
                  : _buildField(field),
        ],
      ],
    );
  }

  /// The list-tile fields (a switch, the photo placeholder) become no-blur
  /// tiles on the panel, each with its own transparent Material so the ink
  /// lands on the tile; the inputs keep the theme's own field chrome.
  Widget _glassField(TemplateField field) {
    final built = _buildField(field);
    if (field.type != TemplateFieldType.boolean &&
        field.type != TemplateFieldType.photo) {
      return built;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPane(
        kind: GlassKind.tile,
        blur: false,
        shadow: false,
        radius: LumenGlass.radiusControl,
        child: Material(type: MaterialType.transparency, child: built),
      ),
    );
  }

  /// "Required" under a required question (inline only).
  String? _requiredHelper(TemplateField field) =>
      widget.inline && field.blocksSubmit
          ? context.l10n.visitTemplateFieldRequired
          : null;

  /// The error on an unanswered required question once the agent has saved.
  /// Never on a switch: it always shows a value, and saving records an
  /// untouched one as off.
  String? _requiredError(TemplateField field) =>
      widget.inline &&
          widget.showRequiredErrors &&
          field.blocksSubmit &&
          field.type != TemplateFieldType.boolean &&
          field.isVisible(_answers) &&
          !field.isAnswered(_answers)
      ? context.l10n.visitTemplateFieldRequiredError
      : null;

  /// A list tile's supporting line: the error wins over the marker, and wears
  /// the theme's error colour so it is not carried by position alone.
  Widget? _tileSubtitle(TemplateField field, {String? otherwise}) {
    final error = _requiredError(field);
    final text = error ?? _requiredHelper(field) ?? otherwise;
    if (text == null) return null;
    return Text(
      text,
      style: error == null
          ? null
          : TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }

  Widget _buildField(TemplateField field) {
    final value = _answers[field.id];
    switch (field.type) {
      case TemplateFieldType.boolean:
        return SwitchListTile(
          key: ValueKey('field-${field.id}'),
          title: Text(field.label),
          subtitle: _tileSubtitle(field),
          value: value == true,
          onChanged: (v) => _set(field.id, v),
        );
      case TemplateFieldType.choice:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: DropdownButtonFormField<String>(
            key: ValueKey('field-${field.id}'),
            // An answer the options no longer offer (the template changed) is
            // shown as unanswered rather than crashing the dropdown.
            initialValue: value is String && field.options.contains(value)
                ? value
                : null,
            decoration: InputDecoration(
              labelText: field.label,
              isDense: true,
              helperText: _requiredHelper(field),
              errorText: _requiredError(field),
            ),
            items: [
              for (final option in field.options)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: (v) => _set(field.id, v),
          ),
        );
      case TemplateFieldType.number:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextFormField(
            key: ValueKey('field-${field.id}'),
            initialValue: value is num ? value.toString() : null,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: field.label,
              isDense: true,
              helperText: _requiredHelper(field),
              errorText: _requiredError(field),
            ),
            onChanged: (v) => _set(field.id, num.tryParse(v)),
          ),
        );
      case TemplateFieldType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextFormField(
            key: ValueKey('field-${field.id}'),
            initialValue: value is String ? value : null,
            decoration: InputDecoration(
              labelText: field.label,
              isDense: true,
              helperText: _requiredHelper(field),
              errorText: _requiredError(field),
            ),
            onChanged: (v) => _set(field.id, v.isEmpty ? null : v),
          ),
        );
      case TemplateFieldType.photo:
        // Photo capture inside a template is not wired yet, so the field is
        // shown but not fillable — and never blocks a submit.
        return ListTile(
          key: ValueKey('field-${field.id}'),
          enabled: false,
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(field.label),
          subtitle: Text(
            widget.inline
                ? context.l10n.visitTemplatePhotoUnsupported
                : 'Photo capture coming with audit integration',
          ),
        );
    }
  }

  /// 10.0 -> "10", 7.5 -> "7.5" — keeps the score preview compact.
  static String _trimmed(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';
}
