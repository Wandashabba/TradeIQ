import 'package:flutter/material.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../domain/template_schema.dart';

/// Renders a parsed TemplateSchema one section at a time (issue #54 step 2),
/// collecting answers keyed by field id. The audit-flow integration (step 3)
/// decides where the collected answers go; this widget only calls [onSubmit]
/// after the last section.
class DynamicTemplateForm extends StatefulWidget {
  const DynamicTemplateForm({
    super.key,
    required this.schema,
    required this.onSubmit,
    this.submitLabel = 'Finish',
  });

  final TemplateSchema schema;
  final ValueChanged<Map<String, Object?>> onSubmit;
  final String submitLabel;

  @override
  State<DynamicTemplateForm> createState() => _DynamicTemplateFormState();
}

class _DynamicTemplateFormState extends State<DynamicTemplateForm> {
  int _sectionIndex = 0;
  final Map<String, Object?> _answers = {};

  void _next(bool isLast) {
    if (isLast) {
      widget.onSubmit(Map.unmodifiable(_answers));
    } else {
      setState(() => _sectionIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
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

  Widget _buildField(TemplateField field) {
    switch (field.type) {
      case TemplateFieldType.boolean:
        return SwitchListTile(
          key: ValueKey('field-${field.id}'),
          title: Text(field.label),
          value: _answers[field.id] == true,
          onChanged: (v) => setState(() => _answers[field.id] = v),
        );
      case TemplateFieldType.choice:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: DropdownButtonFormField<String>(
            key: ValueKey('field-${field.id}'),
            initialValue: _answers[field.id] as String?,
            decoration: InputDecoration(labelText: field.label, isDense: true),
            items: [
              for (final option in field.options)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: (v) => setState(() => _answers[field.id] = v),
          ),
        );
      case TemplateFieldType.number:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextFormField(
            key: ValueKey('field-${field.id}'),
            initialValue: (_answers[field.id] as num?)?.toString(),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: field.label, isDense: true),
            onChanged: (v) => setState(() {
              final parsed = num.tryParse(v);
              if (parsed == null) {
                _answers.remove(field.id);
              } else {
                _answers[field.id] = parsed;
              }
            }),
          ),
        );
      case TemplateFieldType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextFormField(
            key: ValueKey('field-${field.id}'),
            initialValue: _answers[field.id] as String?,
            decoration: InputDecoration(labelText: field.label, isDense: true),
            onChanged: (v) => setState(() {
              if (v.isEmpty) {
                _answers.remove(field.id);
              } else {
                _answers[field.id] = v;
              }
            }),
          ),
        );
      case TemplateFieldType.photo:
        // Photo capture is wired up with the audit-flow integration (issue
        // #54 step 3); until then the field is shown but not fillable.
        return ListTile(
          key: ValueKey('field-${field.id}'),
          enabled: false,
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(field.label),
          subtitle: const Text('Photo capture coming with audit integration'),
        );
    }
  }

  /// 10.0 -> "10", 7.5 -> "7.5" — keeps the score preview compact.
  static String _trimmed(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';
}
