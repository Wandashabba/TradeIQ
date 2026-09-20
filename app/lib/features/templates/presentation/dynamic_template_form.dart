import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../domain/template_schema.dart';

/// THE WALK THROUGH A TEMPLATE — where it is, and what has been answered.
///
/// The state lives here rather than inside the form because the form's two
/// verbs do not: Next and Back belong in the shell's thumb zone (§12.6), and a
/// widget cannot hand its own `setState` to a button that is a sibling of the
/// scroll view. The screen owns one of these, listens to it, and renders the
/// same three facts in two places without either being able to drift.
class TemplateWalk extends ChangeNotifier {
  TemplateWalk(this.schema);

  final TemplateSchema schema;

  int _sectionIndex = 0;
  final Map<String, Object?> _answers = <String, Object?>{};

  /// One controller per typed field, kept for the life of the walk.
  ///
  /// The trough inputs are controller-driven, and a controller rebuilt on
  /// every keystroke is a caret that jumps to the end of the word. Holding
  /// them here also means an answer typed in section one is still typed when
  /// the manager walks back to it.
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  TextEditingController controllerFor(TemplateField field) =>
      _controllers.putIfAbsent(field.id, () {
        final existing = _answers[field.id];
        return TextEditingController(
          text: existing == null ? '' : '$existing',
        );
      });

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get sectionIndex => _sectionIndex;
  Map<String, Object?> get answers => Map<String, Object?>.unmodifiable(_answers);

  bool get hasSections => schema.sections.isNotEmpty;
  int get sectionCount => schema.sections.length;
  TemplateSection get section => schema.sections[_sectionIndex];
  bool get isFirst => _sectionIndex == 0;
  bool get isLast => _sectionIndex == schema.sections.length - 1;

  /// The fields on this section whose conditions are satisfied.
  List<TemplateField> get visibleFields => <TemplateField>[
    for (final f in section.fields)
      if (f.isVisible(_answers)) f,
  ];

  /// The visible required questions on THIS section that are still empty.
  ///
  /// Per-section rather than whole-schema, because that is what the button at
  /// the bottom of this section can honestly speak for. A required question
  /// three sections ahead is not a reason this section cannot be left.
  List<TemplateField> get missingHere => <TemplateField>[
    for (final f in visibleFields)
      if (f.blocksSubmit && !f.isAnswered(_answers)) f,
  ];

  void set(String fieldId, Object? value) {
    if (value == null) {
      _answers.remove(fieldId);
    } else {
      _answers[fieldId] = value;
    }
    notifyListeners();
  }

  void back() {
    if (_sectionIndex == 0) return;
    _sectionIndex--;
    notifyListeners();
  }

  void forward() {
    if (isLast) return;
    _sectionIndex++;
    notifyListeners();
  }
}

/// One section of a parsed template, as the form an agent will see.
///
/// Every input is a Phase 2 one: a yes/no question is a [ChoiceRow] rather
/// than a switch, because an unanswered binary and a binary answered "no" are
/// different facts and a toggle cannot tell them apart (unify §1.9). A choice
/// with more options than a choice row holds opens a picker sheet instead of
/// growing a fifth tile nobody can hit.
class DynamicTemplateForm extends StatelessWidget {
  const DynamicTemplateForm({super.key, required this.walk});

  final TemplateWalk walk;

  /// Beyond this many options a choice row stops being a row.
  static const int inlineChoiceLimit = 4;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    if (!walk.hasSections) {
      return EmptyState(
        key: const ValueKey<String>('template-no-sections'),
        scope: EmptyScope.inPanel,
        headline: l10n.templateFormNoSectionsHeadline,
        body: l10n.templateFormNoSectionsBody,
      );
    }

    final fields = walk.visibleFields;
    final maxScore = walk.schema.maxScore;
    final answered = walk.schema.answeredCount(walk.answers);
    final askable = walk.schema.questionCount(walk.answers);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(
          walk.section.title,
          count: fields.isEmpty ? null : fields.length,
          emptyLine: fields.isEmpty ? l10n.templateFormSectionEmpty : null,
        ),
        const SizedBox(height: TiqSpace.s3),
        Text(
          l10n.templatePreviewSection(
            walk.sectionIndex + 1,
            walk.sectionCount,
          ),
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        if (maxScore > 0) ...<Widget>[
          const SizedBox(height: TiqSpace.s5),
          StatTile(
            key: const ValueKey<String>('template-score-preview'),
            eyebrow: l10n.templateFormScoreEyebrow,
            value: walk.schema.scoreFor(walk.answers),
            decimals: 1,
            meter: MeterData(
              value: walk.schema.scoreFor(walk.answers),
              maximum: maxScore,
            ),
            // A running total over a half-walked template is not a measured
            // score. Without this the preview opens on `0.0 / 10` before a
            // single question is answered, and a manager reads a
            // not-yet-measured figure as a measured zero.
            provisional: answered < askable,
            // The tile's own state words default to English. A localised
            // screen passes its own.
            strings: StatTileStrings(
              smallSample: l10n.figureSmallSample,
              notScored: l10n.figureNotScored,
              provisional: l10n.figureProvisional,
            ),
            stateLine: l10n.templateFormScoreOutOf(_trimmed(maxScore)),
          ),
        ],
        SizedBox(height: skin.space.blockGap),
        for (final field in fields) ...<Widget>[
          _Field(walk: walk, field: field),
          const SizedBox(height: TiqSpace.s5),
        ],
      ],
    );
  }

  /// 10.0 -> "10", 7.5 -> "7.5" — keeps the score preview compact.
  static String _trimmed(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';
}

class _Field extends StatelessWidget {
  const _Field({required this.walk, required this.field});

  final TemplateWalk walk;
  final TemplateField field;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final value = walk.answers[field.id];
    final key = ValueKey<String>('field-${field.id}');
    final help = field.blocksSubmit ? l10n.templateFieldRequired : null;

    switch (field.type) {
      case TemplateFieldType.boolean:
        // Not a toggle: unanswered and "no" are different facts, and a switch
        // that renders off cannot say which one it is showing.
        return _Question(
          label: field.label,
          help: help,
          child: ChoiceRow<bool>(
            key: key,
            label: field.label,
            value: value is bool ? value : null,
            notAnsweredLine: l10n.templateFieldNotAnsweredLine,
            options: <ChoiceOption<bool>>[
              ChoiceOption<bool>(value: true, label: l10n.templateFieldYes),
              ChoiceOption<bool>(value: false, label: l10n.templateFieldNo),
            ],
            onChanged: (v) => walk.set(field.id, v),
            clear: value is bool
                ? TorchTertiaryButton(
                    key: ValueKey<String>('field-clear-${field.id}'),
                    label: l10n.templateFieldClear,
                    onPressed: () => walk.set(field.id, null),
                  )
                : null,
          ),
        );

      case TemplateFieldType.choice:
        final selected = value is String && field.options.contains(value)
            ? value
            : null;
        if (field.options.length >= 2 &&
            field.options.length <= DynamicTemplateForm.inlineChoiceLimit) {
          return _Question(
            label: field.label,
            help: help,
            child: ChoiceRow<String>(
              key: key,
              label: field.label,
              value: selected,
              notAnsweredLine: l10n.templateFieldNotAnsweredLine,
              options: <ChoiceOption<String>>[
                for (final option in field.options)
                  ChoiceOption<String>(value: option, label: option),
              ],
              onChanged: (v) => walk.set(field.id, v),
            ),
          );
        }
        return SoftRow(
          key: key,
          form: SoftRowForm.standalone,
          density: SoftRowDensity.tall,
          title: field.label,
          // An answer the options no longer offer (the template changed) reads
          // as unanswered rather than as a value nobody can pick again.
          subtitle: selected ?? l10n.templateFieldNotAnswered,
          meta: help == null
              ? null
              : Text(
                  help,
                  style: skin.text.meta.style(color: skin.palette.ink3),
                ),
          trailing: const SoftRowChevron(),
          onTap: () async {
            final picked = await showTorchSheet<String>(
              context,
              builder: (_) =>
                  _ChoiceSheet(label: field.label, options: field.options),
            );
            if (picked != null) walk.set(field.id, picked);
          },
          semanticsLabel: l10n.templateFieldChoiceSemantics(
            field.label,
            selected ?? l10n.templateFieldNotAnswered,
          ),
        );

      case TemplateFieldType.number:
        return TorchNumericField(
          key: key,
          label: field.label,
          controller: walk.controllerFor(field),
          decimals: 1,
          help: help,
          onChanged: (v) => walk.set(field.id, v),
        );

      case TemplateFieldType.text:
        return TorchTextField(
          key: key,
          label: field.label,
          help: help,
          controller: walk.controllerFor(field),
          minLines: 1,
          maximumLines: 4,
          onChanged: (v) => walk.set(field.id, v.isEmpty ? null : v),
        );

      case TemplateFieldType.photo:
        // Capture inside a template is not wired yet. The question is shown
        // with the fourth silhouette and a reason, and it never blocks a
        // submit — a question nobody can answer is not a gate.
        return SoftRow(
          key: key,
          form: SoftRowForm.standalone,
          density: SoftRowDensity.tall,
          title: field.label,
          subtitle: l10n.templateFieldPhotoSubtitle,
          leading: TiqMark(
            shape: MarkShape.sectionBarredRing,
            color: skin.palette.ink3,
            size: MarkScale.glyph(context, 16),
          ),
          meta: Text(
            l10n.templateFieldPhotoMeta,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          semanticsLabel: l10n.templateFieldPhotoSemantics(field.label),
        );
    }
  }
}

/// A CHOICE ROW'S QUESTION, ON SCREEN.
///
/// [ChoiceRow] carries its `label` as a **semantics** label and draws nothing:
/// the options are the only words it paints. Dropped into a template that way
/// it renders "Yes / No" under a section title with the question itself
/// nowhere on screen — a reader hears it and everybody else guesses. So the
/// question is drawn here, excluded from semantics so the row stays one node
/// and the reader does not hear it twice.
class _Question extends StatelessWidget {
  const _Question({required this.label, required this.child, this.help});

  final String label;
  final String? help;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            label,
            style: skin.text.label.style(color: skin.palette.ink2),
          ),
        ),
        if (help != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s1),
          ExcludeSemantics(
            child: Text(
              help!,
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ),
        ],
        const SizedBox(height: TiqSpace.s2),
        child,
      ],
    );
  }
}

/// A choice with more options than a choice row holds.
class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({required this.label, required this.options});

  final String label;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return TorchSheet(
      title: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < options.length; i++)
            SoftRow(
              key: ValueKey<String>('choice-${options[i]}'),
              density: SoftRowDensity.compact,
              title: options[i],
              onTap: () => Navigator.of(context).pop(options[i]),
              separator: i == options.length - 1
                  ? SoftRowSeparator.none
                  : SoftRowSeparator.auto,
            ),
        ],
      ),
    );
  }
}
