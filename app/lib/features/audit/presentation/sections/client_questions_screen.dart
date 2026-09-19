import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/torchlight/tiq_skin.dart';
import '../../../../core/widgets/torchlight/button/buttons.dart';
import '../../../../core/widgets/torchlight/input.dart';
import '../../../../core/widgets/torchlight/marks.dart';
import '../../../../core/widgets/torchlight/row/row.dart';
import '../../../../core/widgets/torchlight/sheet.dart';
import '../../../../core/widgets/torchlight/state.dart';
import '../../../../l10n/l10n.dart';
import '../../../templates/domain/template_schema.dart';
import '../../data/template_section_repository.dart';
import 'section_form.dart';

/// THE CLIENT'S QUESTIONS (#122) — the client's own audit template, rendered
/// after the fixed sections. It supplements S1–S10 and never feeds the
/// perfect-store score.
///
/// Offline-first like every other section: saving writes the answers to the
/// outbox (`template_response` → `POST /template-responses`), reopening reads
/// them back from it, and the hub derives this section's state from the same
/// rows. Required questions left unanswered block the submit.
///
/// The client writes the questions; **the app writes the controls**. Every
/// answer goes through the same eight primitives the fixed sections use, so a
/// client's template cannot introduce a ninth kind of input into the product.
///
/// **Amber:** one object, the inline Save, once something has changed.
class ClientQuestionsScreen extends ConsumerStatefulWidget {
  const ClientQuestionsScreen({
    super.key,
    required this.visitDraftId,
    required this.template,
  });

  final String visitDraftId;
  final ClientTemplate template;

  @override
  ConsumerState<ClientQuestionsScreen> createState() =>
      _ClientQuestionsScreenState();
}

class _ClientQuestionsScreenState extends ConsumerState<ClientQuestionsScreen> {
  /// Null until the saved answers are read back.
  Map<String, Object?>? _answers;
  bool _triedSave = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, Object?> saved;
    try {
      saved = await ref
          .read(templateSectionRepositoryProvider)
          .savedAnswers(
            visitDraftId: widget.visitDraftId,
            templateId: widget.template.templateId,
          );
    } catch (_) {
      // Unreadable local state is not a reason to lock the agent out of the
      // questions: start blank, and saving will write a fresh row.
      saved = const <String, Object?>{};
    }
    if (mounted) setState(() => _answers = Map<String, Object?>.of(saved));
  }

  Future<void> _save() async {
    final answers = _answers;
    if (answers == null) return;
    setState(() => _triedSave = true);
    await ref
        .read(templateSectionRepositoryProvider)
        .saveAnswers(
          visitDraftId: widget.visitDraftId,
          template: widget.template,
          answers: answers,
        );
    if (mounted) setState(() => _dirty = false);
  }

  void _set(String fieldId, Object? value) => setState(() {
    final next = Map<String, Object?>.of(_answers ?? const <String, Object?>{});
    if (value == null) {
      next.remove(fieldId);
    } else {
      next[fieldId] = value;
    }
    _answers = next;
    _dirty = true;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final answers = _answers;

    if (answers == null) {
      return SectionForm(
        title: widget.template.name,
        phase: 'client-questions-loading',
        children: const <Widget>[SkeletonRows(count: 4)],
      );
    }

    final schema = widget.template.schema;
    if (schema.sections.isEmpty) {
      return SectionForm(
        title: widget.template.name,
        phase: 'client-questions-empty',
        children: <Widget>[
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.visitTemplateNoQuestions,
          ),
        ],
      );
    }

    // What saving now would record: an untouched switch counts as "off".
    final left = schema
        .missingRequired(schema.withSwitchDefaults(answers))
        .length;

    return SectionForm(
      title: widget.template.name,
      phase: 'client-questions',
      intro: l10n.visitTemplateSectionIntro,
      dirty: _dirty,
      onSave: _save,
      savedLine: l10n.visitTemplateSaved,
      children: <Widget>[
        for (final section in schema.sections)
          SectionFieldGroup(
            key: ValueKey<String>('template-section-${section.id}'),
            title: section.title,
            children: <Widget>[
              for (final field in section.fields)
                if (field.isVisible(answers))
                  _TemplateFieldControl(
                    key: ValueKey<String>('field-${field.id}'),
                    field: field,
                    value: answers[field.id],
                    error: _errorFor(field, answers, l10n),
                    help: field.blocksSubmit
                        ? l10n.visitTemplateFieldRequired
                        : null,
                    onChanged: (v) => _set(field.id, v),
                  ),
            ],
          ),
        if (schema.hasRequired)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusChip(
              key: const ValueKey<String>('client-questions-required'),
              level: left > 0 ? StatusLevel.watch : StatusLevel.onTarget,
              label: left > 0
                  ? l10n.visitTemplateRequiredLeft(left)
                  : l10n.visitTemplateAllRequiredAnswered,
            ),
          ),
      ],
    );
  }

  /// The error on an unanswered required question, once the agent has saved.
  /// Never on a toggle: it always shows a value, and saving records an
  /// untouched one as off.
  String? _errorFor(
    TemplateField field,
    Map<String, Object?> answers,
    AppLocalizations l10n,
  ) =>
      _triedSave &&
          field.blocksSubmit &&
          field.type != TemplateFieldType.boolean &&
          !field.isAnswered(answers)
      ? l10n.visitTemplateFieldRequiredError
      : null;
}

/// ONE OF THE CLIENT'S QUESTIONS, in the app's own control.
class _TemplateFieldControl extends StatelessWidget {
  const _TemplateFieldControl({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.help,
    this.error,
  });

  final TemplateField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? help;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    switch (field.type) {
      case TemplateFieldType.boolean:
        return TorchToggle(
          label: field.label,
          value: value == true,
          onWord: l10n.wordYes,
          offWord: l10n.wordNo,
          onChanged: onChanged,
        );
      case TemplateFieldType.text:
        return _TemplateText(
          field: field,
          value: value is String ? value! as String : null,
          help: help,
          error: error,
          onChanged: (v) => onChanged(v.isEmpty ? null : v),
        );
      case TemplateFieldType.number:
        return _TemplateNumber(
          field: field,
          value: value is num ? value! as num : null,
          help: help,
          error: error,
          onChanged: (v) => onChanged(v),
        );
      case TemplateFieldType.choice:
        // An answer the options no longer offer (the template changed) reads
        // as unanswered rather than as a selection nothing matches.
        final selected = value is String && field.options.contains(value)
            ? value! as String
            : null;
        // Two to four is a choice row; five is a list, and a list is a sheet.
        if (field.options.length >= 2 && field.options.length <= 4) {
          return SectionChoice(
            label: field.label,
            child: ChoiceRow<String>(
              label: field.label,
              options: <ChoiceOption<String>>[
                for (final option in field.options)
                  ChoiceOption<String>(value: option, label: option),
              ],
              value: selected,
              notAnsweredLine: help ?? l10n.sectionNotAnsweredYet,
              error: error,
              onChanged: onChanged,
            ),
          );
        }
        return _TemplateChoiceSheet(
          field: field,
          selected: selected,
          help: help,
          error: error,
          onChanged: onChanged,
        );
      case TemplateFieldType.photo:
        // Photo capture inside a client template is not wired yet, so the
        // question is shown, stated as unanswerable, and never blocks a
        // submit — a gate an agent has no way to open is a dead end in a shop.
        return SoftRow(
          title: field.label,
          subtitle: l10n.visitTemplatePhotoUnsupported,
          leading: const SectionStateGlyph(state: SectionState.cantConfirm),
          separator: SoftRowSeparator.none,
          semanticsLabel:
              '${field.label}. ${l10n.visitTemplatePhotoUnsupported}',
        );
    }
  }
}

/// A text answer. Its own widget so the controller lives as long as the field
/// and not as long as one build.
class _TemplateText extends StatefulWidget {
  const _TemplateText({
    required this.field,
    required this.value,
    required this.onChanged,
    this.help,
    this.error,
  });

  final TemplateField field;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? help;
  final String? error;

  @override
  State<_TemplateText> createState() => _TemplateTextState();
}

class _TemplateTextState extends State<_TemplateText> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TorchTextField(
    label: widget.field.label,
    controller: _controller,
    help: widget.help,
    error: widget.error,
    onChanged: widget.onChanged,
  );
}

class _TemplateNumber extends StatefulWidget {
  const _TemplateNumber({
    required this.field,
    required this.value,
    required this.onChanged,
    this.help,
    this.error,
  });

  final TemplateField field;
  final num? value;
  final ValueChanged<num?> onChanged;
  final String? help;
  final String? error;

  @override
  State<_TemplateNumber> createState() => _TemplateNumberState();
}

class _TemplateNumberState extends State<_TemplateNumber> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TorchNumericField(
    label: widget.field.label,
    controller: _controller,
    decimals: 2,
    help: widget.help,
    error: widget.error,
    onChanged: (v) => widget.onChanged(v),
  );
}

/// Five options or more. A trough that opens a sheet of rows — never a
/// dropdown, which is a 20dp target over a shelf.
class _TemplateChoiceSheet extends StatelessWidget {
  const _TemplateChoiceSheet({
    required this.field,
    required this.selected,
    required this.onChanged,
    this.help,
    this.error,
  });

  final TemplateField field;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final String? help;
  final String? error;

  Future<void> _open(BuildContext context) async {
    final chosen = await showTorchSheet<String>(
      context,
      builder: (sheetContext) => TorchSheet(
        title: field.label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (i, option) in field.options.indexed)
              SoftRow(
                key: ValueKey<String>('choice-${field.id}-$i'),
                title: option,
                leading: option == selected
                    ? const SectionStateGlyph(state: SectionState.done)
                    : const SectionStateGlyph(state: SectionState.notStarted),
                separator: i == field.options.length - 1
                    ? SoftRowSeparator.none
                    : SoftRowSeparator.auto,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          field.label,
          style: skin.text.label.style(color: skin.palette.ink2),
        ),
        const SizedBox(height: TiqSpace.s2),
        TorchSecondaryButton(
          key: ValueKey<String>('choice-open-${field.id}'),
          label: selected ?? (help ?? l10n.sectionNotAnsweredYet),
          semanticLabel:
              '${field.label}. ${selected ?? l10n.sectionNotAnsweredYet}',
          onPressed: () => _open(context),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s2),
          Text(error!, style: skin.text.meta.style(color: skin.palette.bad)),
        ],
      ],
    );
  }
}
