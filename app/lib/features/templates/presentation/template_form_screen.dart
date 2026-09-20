import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/console_page.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/templates_repository.dart';
import '../domain/template_schema.dart';
import 'dynamic_template_form.dart';

/// TEMPLATE PREVIEW — the manager walks a template's form exactly as a field
/// agent will (#54 step 2).
///
/// Answers are not persisted: this is a preview, and saying so is the honest
/// end of it rather than a dialog that congratulates the manager on data that
/// went nowhere.
///
/// ## Amber, counted
///
/// Untabbed and no nav, so Night has two content grants and Day and Veld one.
/// The one claim is Next / Finish preview, declared only while it can be
/// pressed — so a section with a required question still empty carries zero
/// amber, in every skin.
class TemplateFormScreen extends ConsumerStatefulWidget {
  const TemplateFormScreen({super.key, required this.templateId});

  final String templateId;

  @override
  ConsumerState<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends ConsumerState<TemplateFormScreen> {
  TemplateWalk? _walk;

  @override
  void dispose() {
    _walk?.dispose();
    super.dispose();
  }

  /// One walk per parsed schema. A refetch that hands back the same shape must
  /// not throw away where the manager had got to.
  TemplateWalk _walkFor(TemplateSchema schema) {
    final existing = _walk;
    if (existing != null && existing.schema == schema) return existing;
    existing?.dispose();
    final walk = TemplateWalk(schema)..addListener(_changed);
    _walk = walk;
    return walk;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _leave() => Navigator.of(context).pop();

  Future<void> _finish(TemplateWalk walk) async {
    final answered = walk.schema.answeredCount(walk.answers);
    final total = walk.schema.questionCount(walk.answers);
    await showTorchSheet<void>(
      context,
      builder: (sheetContext) => TorchSheet(
        key: const ValueKey<String>('template-preview-done'),
        title: 'Preview complete',
        subtitle:
            'You answered $answered of $total visible questions. Nothing was '
            'saved — a preview writes no answers, and saving them against a '
            'visit arrives with the audit-flow integration.',
        child: TorchSecondaryButton(
          key: const ValueKey<String>('template-preview-close'),
          label: 'Back to Audit templates',
          onPressed: () {
            Navigator.of(sheetContext).pop();
            _leave();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(templateDetailProvider(widget.templateId));
    final back = ConsolePage.backTo('Back to Audit templates', _leave);

    return detail.when(
      loading: () => ConsolePage(
        phase: 'loading',
        title: 'Template preview',
        back: back,
        children: <Widget>[
          Skeleton(
            label: 'the template',
            child: const SkeletonRows(count: 4, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => ConsolePage(
        phase: 'error',
        title: 'Template preview',
        back: back,
        children: <Widget>[
          TorchErrorRegion(
            name: 'the template',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('template-retry'),
                label: 'Try again',
                onPressed: () =>
                    ref.invalidate(templateDetailProvider(widget.templateId)),
              ),
            ),
          ),
        ],
      ),
      data: (d) => _loaded(d, back),
    );
  }

  Widget _loaded(AuditTemplateDetail detail, TorchIconButton back) {
    final walk = _walkFor(TemplateSchema.parse(detail.schema));
    final missing = walk.hasSections
        ? walk.missingHere
        : const <TemplateField>[];
    final blocked = missing.isEmpty
        ? null
        : missing.length == 1
        ? '“${missing.first.label}” still needs an answer.'
        : '${missing.length} required questions in this section still need '
              'answers.';
    final armed = walk.hasSections && blocked == null;

    return ConsolePage(
      phase: walk.hasSections
          ? 'section-${walk.sectionIndex + 1}${armed ? '' : '-blocked'}'
          : 'no-sections',
      title: detail.template.name,
      facts: <String>[
        'v${detail.template.version}',
        'Preview — nothing is saved',
        if (walk.hasSections)
          'Section ${walk.sectionIndex + 1} of ${walk.sectionCount}',
      ],
      back: back,
      primaryArmed: armed,
      primary: walk.hasSections
          ? TorchPrimaryButton(
              key: const ValueKey<String>('form-next'),
              label: walk.isLast ? 'Finish preview' : 'Next section',
              claimId: ConsolePage.primaryClaimId,
              blockedReason: blocked,
              onPressed: armed
                  ? () {
                      if (walk.isLast) {
                        _finish(walk);
                      } else {
                        walk.forward();
                      }
                    }
                  : null,
            )
          : null,
      secondary: walk.hasSections && !walk.isFirst
          ? TorchSecondaryButton(
              key: const ValueKey<String>('form-back'),
              label: 'Back a section',
              onPressed: walk.back,
            )
          : null,
      children: <Widget>[DynamicTemplateForm(walk: walk)],
    );
  }
}
