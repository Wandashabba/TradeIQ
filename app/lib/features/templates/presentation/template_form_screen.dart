import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/console_page.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
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

  /// The raw JSON the current walk was parsed from.
  ///
  /// Compared by **identity**, not by value: `TemplateSchema.parse` returns a
  /// fresh object every call and `TemplateSchema` has no `==`, so keying the
  /// walk on the parsed schema rebuilt it on every frame — which threw away
  /// the section the manager was on and every answer with it, the moment they
  /// pressed Next. The provider hands back the same map instance until it
  /// refetches, and that is the thing to hold on to.
  Map<String, dynamic>? _raw;

  @override
  void dispose() {
    _walk?.dispose();
    super.dispose();
  }

  TemplateWalk _walkFor(Map<String, dynamic> raw) {
    final existing = _walk;
    if (existing != null && identical(_raw, raw)) return existing;
    existing?.dispose();
    final walk = TemplateWalk(TemplateSchema.parse(raw))..addListener(_changed);
    _walk = walk;
    _raw = raw;
    return walk;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _leave() => Navigator.of(context).pop();

  Future<void> _finish(TemplateWalk walk) async {
    final l10n = context.l10n;
    final answered = walk.schema.answeredCount(walk.answers);
    final total = walk.schema.questionCount(walk.answers);
    await showTorchSheet<void>(
      context,
      builder: (sheetContext) => TorchSheet(
        key: const ValueKey<String>('template-preview-done'),
        title: l10n.templatePreviewDoneTitle,
        subtitle: l10n.templatePreviewDoneBody(answered, total),
        child: TorchSecondaryButton(
          key: const ValueKey<String>('template-preview-close'),
          label: l10n.templatePreviewBack,
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
    final l10n = context.l10n;
    final detail = ref.watch(templateDetailProvider(widget.templateId));
    final back = ConsolePage.backTo(l10n.templatePreviewBack, _leave);

    return detail.when(
      loading: () => ConsolePage(
        phase: 'loading',
        title: l10n.templatePreviewTitle,
        back: back,
        children: <Widget>[
          Skeleton(
            label: l10n.templatePreviewSkeleton,
            child: const SkeletonRows(count: 4, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => ConsolePage(
        phase: 'error',
        title: l10n.templatePreviewTitle,
        back: back,
        children: <Widget>[
          TorchErrorRegion(
            name: l10n.templatePreviewSkeleton,
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('template-retry'),
                label: l10n.torchTryAgain,
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
    final l10n = context.l10n;
    final walk = _walkFor(detail.schema);
    final missing = walk.hasSections
        ? walk.missingHere
        : const <TemplateField>[];
    final blocked = missing.isEmpty
        ? null
        : missing.length == 1
        ? l10n.templatePreviewBlockedOne(missing.first.label)
        : l10n.templatePreviewBlockedMany(missing.length);
    final armed = walk.hasSections && blocked == null;

    return ConsolePage(
      phase: walk.hasSections
          ? 'section-${walk.sectionIndex + 1}${armed ? '' : '-blocked'}'
          : 'no-sections',
      title: detail.template.name,
      facts: <String>[
        l10n.templateVersionShort(detail.template.version),
        l10n.templatePreviewFact,
        if (walk.hasSections)
          l10n.templatePreviewSection(
            walk.sectionIndex + 1,
            walk.sectionCount,
          ),
      ],
      back: back,
      primaryArmed: armed,
      primary: walk.hasSections
          ? TorchPrimaryButton(
              // Keyed by SECTION, not by role. The primary is debounced 400ms
              // against a double press, and the debounce lives on the
              // element: with one key across the walk, "Next section" and
              // "Finish preview" shared a press history, so pressing Next and
              // then Finish inside the window swallowed the second press and
              // the preview simply would not end.
              key: ValueKey<String>('form-next-${walk.sectionIndex}'),
              label: walk.isLast
                  ? l10n.templatePreviewFinish
                  : l10n.templatePreviewNext,
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
              label: l10n.templatePreviewBackSection,
              onPressed: walk.back,
            )
          : null,
      children: <Widget>[DynamicTemplateForm(walk: walk)],
    );
  }
}
