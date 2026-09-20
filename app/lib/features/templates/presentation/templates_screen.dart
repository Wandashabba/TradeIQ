import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/templates_repository.dart';

/// AUDIT TEMPLATES — the client's own questions, and which set field agents
/// answer on every visit.
///
/// ## Which one is in use is said once, in words, at the top
///
/// Not a badge to hunt for down a list of rows. The standalone block names the
/// template and its version, and the rows carry the same fact as a word so the
/// two can never disagree.
///
/// ## The one amber, counted
///
/// A tab root: the nav pill's active tab is slot 1. "Use in audits" is a
/// consequential change, but it is a row verb rather than the screen's commit
/// action — a list of templates is not a screen about one of them — so the
/// content grant goes unspent and Day and Veld paint zero.
class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  /// The id whose "Use in audits" is in flight, so two taps cannot race and
  /// the row can say what it is doing.
  String? _selecting;

  void _refresh() {
    ref.invalidate(templatesListProvider);
    ref.invalidate(selectedTemplateProvider);
  }

  /// Uses [templateId] in audits, or with null stops using one (#122).
  Future<void> _select(String? templateId) async {
    if (_selecting != null) return;
    setState(() => _selecting = templateId ?? '');
    try {
      final now = await ref
          .read(templatesRepositoryProvider)
          .selectForAudits(templateId);
      if (!mounted) return;
      setState(() => _selecting = null);
      ref.invalidate(selectedTemplateProvider);
      showTorchToast(
        context,
        message: now == null
            ? context.l10n.templatesCleared
            : context.l10n.templatesNowInAudits(now.template.name),
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _selecting = null);
      showTorchToast(
        context,
        message: context.l10n.templatesChangeFailed(
          TorchErrorMessage.sanitise(error).body,
        ),
        kind: ToastKind.failure,
      );
    }
  }

  Widget _frame({required String phase, required List<Widget> children}) {
    final l10n = context.l10n;
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.templatesTitle,
        facts: <String>[l10n.templatesFact],
        trailing: TorchIconButton(
          key: const ValueKey<String>('templates-refresh'),
          icon: Icons.refresh,
          semanticLabel: l10n.templatesRefresh,
          onPressed: _refresh,
        ),
      ),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final templates = ref.watch(templatesListProvider);
    final selected = ref.watch(selectedTemplateProvider);
    // While the selection loads (or if it fails) no row claims to be in use.
    final selectedId = selected.value?.template.id;
    final gutter = context.skin.space.gutter;

    return templates.when(
      loading: () => _frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.templatesSkeleton,
            child: const SkeletonRows(count: 3, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'templates',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('templates-retry'),
                label: l10n.torchTryAgain,
                onPressed: _refresh,
              ),
            ),
          ),
        ],
      ),
      data: (list) => _frame(
        phase: list.isEmpty ? 'empty' : 'loaded',
        children: <Widget>[
          _InAudits(
            selected: selected,
            busy: _selecting == '',
            onClear: () => _select(null),
          ),
          SizedBox(height: context.skin.space.blockGap),

          SectionRule(
            l10n.templatesSection,
            count: list.isEmpty ? null : list.length,
          ),
          const SizedBox(height: TiqSpace.s5),

          if (list.isEmpty)
            EmptyState(
              scope: EmptyScope.inPanel,
              headline: l10n.templatesEmptyHeadline,
              body: l10n.templatesEmptyBody,
            )
          else
            TorchBleed(
              extra: gutter * 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < list.length; i++)
                    _TemplateRow(
                      key: ValueKey<String>('template-${list[i].id}'),
                      template: list[i],
                      inAudits: list[i].id == selectedId,
                      busy: _selecting == list[i].id,
                      last: i == list.length - 1,
                      onUseInAudits: () => _select(list[i].id),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Which template field agents answer on every visit — said once, at the top.
class _InAudits extends StatelessWidget {
  const _InAudits({
    required this.selected,
    required this.busy,
    required this.onClear,
  });

  final AsyncValue<AuditTemplateDetail?> selected;
  final bool busy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final current = selected.value;
    final String headline;
    if (selected.isLoading && current == null) {
      headline = l10n.templatesInAuditsChecking;
    } else if (selected.hasError && current == null) {
      headline = l10n.templatesInAuditsFailed;
    } else if (current == null) {
      headline = l10n.templatesInAuditsNone;
    } else {
      headline = l10n.templatesInAuditsNamed(
        current.template.name,
        current.template.version,
      );
    }

    return Column(
      key: const ValueKey<String>('templates-in-audits'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(l10n.templatesInAuditsSection),
        const SizedBox(height: TiqSpace.s5),
        SoftRow(
          form: SoftRowForm.standalone,
          density: SoftRowDensity.tall,
          title: headline,
          subtitle: l10n.templatesInAuditsSubtitle,
          leading: TiqMark(
            shape: current == null
                ? MarkShape.sectionRing
                : MarkShape.sectionTickDisc,
            color: current == null ? skin.palette.ink3 : skin.palette.good,
            size: MarkScale.glyph(context, 16),
          ),
          meta: Text(
            l10n.templatesInAuditsMeta,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          actions: current == null
              ? null
              : TorchTertiaryButton(
                  key: const ValueKey<String>('templates-stop-using'),
                  label: busy
                      ? l10n.templatesStopping
                      : l10n.templatesStopUsing,
                  onPressed: busy ? null : onClear,
                ),
          semanticsLabel: l10n.templatesInAuditsSemantics(headline),
        ),
      ],
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    super.key,
    required this.template,
    required this.inAudits,
    required this.busy,
    required this.last,
    required this.onUseInAudits,
  });

  final AuditTemplate template;
  final bool inAudits;
  final bool busy;
  final bool last;
  final VoidCallback onUseInAudits;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final t = template;
    final industry = t.industry;
    // A paused template is done, not broken — the word carries the difference,
    // never the colour and never a fill step.
    final word = inAudits
        ? l10n.templateWordInAudits
        : (t.active ? l10n.templateWordActive : l10n.templateWordPaused);

    return SoftRow(
      key: ValueKey<String>('template-row-${t.id}'),
      density: SoftRowDensity.tall,
      title: t.name,
      subtitle: industry == null
          ? l10n.templateVersionShort(t.version)
          : l10n.templateVersionAndIndustry(t.version, industry),
      leading: TiqMark(
        shape: inAudits
            ? MarkShape.sectionTickDisc
            : t.active
            ? MarkShape.onTargetCircle
            : MarkShape.heldSquare,
        color: inAudits || t.active ? skin.palette.good : skin.palette.ink2,
        size: MarkScale.glyph(context, 16),
      ),
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The id is what the API and the agent app know this template by, so
          // it wears the identifier face.
          Text(
            t.id,
            style: skin.text.monoIdent.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s1),
          Text(word, style: skin.text.meta.style(color: skin.palette.ink3)),
        ],
      ),
      trailing: const SoftRowChevron(),
      // Only an active template can be put in front of agents; the one already
      // in use is changed from the block above.
      actions: t.active && !inAudits
          ? TorchTertiaryButton(
              key: ValueKey<String>('template-use-${t.id}'),
              label: busy ? l10n.templateSwitching : l10n.templateUseInAudits,
              onPressed: busy ? null : onUseInAudits,
            )
          : null,
      // Preview walks the template's dynamic form (issue #54 step 2).
      onTap: () => context.push('/audit-templates/${t.id}/preview'),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        t.name,
        l10n.templateVersionSpoken(t.version),
        ?industry,
        word,
        l10n.templateOpensPreview,
      ].join('. '),
    );
  }
}
