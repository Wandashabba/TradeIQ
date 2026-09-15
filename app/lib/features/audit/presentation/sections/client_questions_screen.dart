import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/lumen_glass.dart';
import '../../../../core/theme/lumen_palette.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/lumen_kit.dart';
import '../../../../l10n/l10n.dart';
import '../../../templates/presentation/dynamic_template_form.dart';
import '../../data/template_section_repository.dart';

/// The client-questions section (#122): the client's own audit template,
/// rendered after the fixed sections. It supplements S1–S10 and never feeds
/// the perfect-store score.
///
/// Offline-first like every other section: saving writes the answers to the
/// outbox (`template_response` → `POST /template-responses`), reopening reads
/// them back from it, and the hub derives this section's state from the same
/// rows. Required questions left unanswered block the submit.
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
  bool _saving = false;
  bool _saved = false;

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
      saved = const {};
    }
    if (mounted) setState(() => _answers = Map.of(saved));
  }

  Future<void> _save() async {
    final answers = _answers;
    if (answers == null) return;
    setState(() {
      _saving = true;
      _triedSave = true;
    });
    await ref
        .read(templateSectionRepositoryProvider)
        .saveAnswers(
          visitDraftId: widget.visitDraftId,
          template: widget.template,
          answers: answers,
        );
    if (mounted) {
      setState(() {
        _saving = false;
        _saved = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final answers = _answers;
    if (answers == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final colors = context.colors;
    final l10n = context.l10n;
    final schema = widget.template.schema;
    // What saving now would record: an untouched switch counts as "off".
    final left = schema.missingRequired(schema.withSwitchDefaults(answers)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        colors.glass
            ? Kicker(l10n.visitTemplateSectionKicker, color: context.lumen.kicker)
            : Text(
                l10n.visitTemplateSectionKicker.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.9,
                  color: colors.ink3,
                ),
              ),
        const SizedBox(height: 6),
        Text(
          l10n.visitTemplateSectionIntro,
          style: TextStyle(fontSize: 13, height: 1.45, color: colors.ink2),
        ),
        const SizedBox(height: 14),
        DynamicTemplateForm.inline(
          key: const ValueKey('client-questions-form'),
          schema: schema,
          initialAnswers: answers,
          showRequiredErrors: _triedSave,
          onChanged: (next) => setState(() {
            _answers = Map.of(next);
            _saved = false;
          }),
        ),
        const SizedBox(height: 14),
        if (schema.hasRequired) ...[
          LumenStatusPill(
            key: const ValueKey('client-questions-required'),
            status: left > 0 ? LumenStatus.warn : LumenStatus.good,
            label: left > 0
                ? l10n.visitTemplateRequiredLeft(left)
                : l10n.visitTemplateAllRequiredAnswered,
          ),
          const SizedBox(height: 12),
        ],
        AgentButton(
          key: const ValueKey('client-questions-save'),
          label: l10n.visitTemplateSave,
          onPressed: _saving ? null : _save,
        ),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.visitTemplateSaved,
              key: const ValueKey('client-questions-saved'),
              style: TextStyle(
                color: colors.glass ? context.lumen.inkMuted : colors.ink2,
              ),
            ),
          ),
      ],
    );
  }
}
