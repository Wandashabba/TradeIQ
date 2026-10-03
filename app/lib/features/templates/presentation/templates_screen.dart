import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_desk.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/console_record.dart';
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
/// content grant goes unspent and Day paints zero.
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

  Widget _frame({
    required String phase,
    required List<Widget> children,
    ConsoleDeskRecords? desk,
  }) {
    final l10n = context.l10n;
    return ConsoleFrame(
      phase: phase,
      // Non-null on `loaded` only: a skeleton, an error and "no templates yet"
      // are not records, so those phases keep the rail and one column.
      desk: desk,
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
      data: (list) {
        // THE TWO BLOCKS ABOVE THE LIST, BUILT ONCE and handed to both arms.
        // `_InAudits` is the one place this screen says which template agents
        // are answering, and it carries `Stop using`; a second composition of
        // it for the desk is the one that would one day disagree.
        final inAudits = _InAudits(
          selected: selected,
          busy: _selecting == '',
          onClear: () => _select(null),
        );
        final section = SectionRule(
          l10n.templatesSection,
          count: list.isEmpty ? null : list.length,
        );

        return _frame(
          phase: list.isEmpty ? 'empty' : 'loaded',
          // ── WHAT THE DESK GETS ─────────────────────────────────────────
          //
          // The templates as records, with `_InAudits` and the section marker
          // in `lead` — the marker stays because there is no filter rail here
          // to name or count the slice, and the standalone block is about the
          // list rather than about any one row in it.
          //
          // The pane is built from the record's own fields rather than from a
          // sheet, because this screen has none: the row's tap is a **route**,
          // `/audit-templates/:id/preview`, which walks the template's form
          // and is a page rather than a pane. So the pane says what the row
          // says — the mark, the word, the version line and the id in the
          // identifier face — and keeps the push as a tertiary verb.
          desk: list.isEmpty
              ? null
              : ConsoleDeskRecords(
                  lead: <Widget>[
                    inAudits,
                    SizedBox(height: context.skin.space.blockGap),
                    section,
                    const SizedBox(height: TiqSpace.s5),
                  ],
                  records: <ConsoleDeskRecord>[
                    for (var i = 0; i < list.length; i++)
                      ConsoleDeskRecord(
                        id: list[i].id,
                        row: (context, selected) => _TemplateRow(
                          key: ValueKey<String>('template-${list[i].id}'),
                          template: list[i],
                          inAudits: list[i].id == selectedId,
                          busy: _selecting == list[i].id,
                          last: i == list.length - 1,
                          onUseInAudits: () => _select(list[i].id),
                          onDesk: true,
                        ),
                        detail: (context) => _templateDetail(
                          context,
                          list[i],
                          inAudits: list[i].id == selectedId,
                        ),
                      ),
                  ],
                ),
          children: <Widget>[
            inAudits,
            SizedBox(height: context.skin.space.blockGap),

            section,
            const SizedBox(height: TiqSpace.s5),

          if (list.isEmpty)
            EmptyState(
              scope: EmptyScope.inPanel,
              headline: l10n.templatesEmptyHeadline,
              body: l10n.templatesEmptyBody,
            )
          else
            TorchBleed(
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
        );
      },
    );
  }

  /// ── ONE TEMPLATE, IN THE DETAIL PANE ────────────────────────────────
  ///
  /// The row's own four channels — the mark, the state word, the version line
  /// and the id in the identifier face — and the row's own verb, lifted, with
  /// the preview route behind a tertiary.
  ///
  /// **No facts block, and that is a localisation decision rather than a
  /// design one.** A `label: value` pair needs a word for the label, this
  /// screen is translated into both locales, and `l10n` has no `Version` or
  /// `Identifier` in it. Printing two English labels on a translated screen
  /// would be a regression on the Afrikaans build, and inventing two keys for
  /// a pane is a change that belongs in a change about words. The id keeps the
  /// face the row gives it and reads as what it is.
  Widget _templateDetail(
    BuildContext context,
    AuditTemplate t, {
    required bool inAudits,
  }) {
    final skin = context.skin;
    final l10n = context.l10n;
    final industry = t.industry;
    final busy = _selecting == t.id;
    final word = inAudits
        ? l10n.templateWordInAudits
        : (t.active ? l10n.templateWordActive : l10n.templateWordPaused);

    return ConsoleRecordDetail(
      key: ValueKey<String>('template-detail-${t.id}'),
      kicker: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: TiqSpace.s2,
        children: <Widget>[
          TiqMark(
            shape: inAudits
                ? MarkShape.sectionTickDisc
                : t.active
                ? MarkShape.onTargetCircle
                : MarkShape.heldSquare,
            color: inAudits || t.active
                ? skin.palette.good
                : skin.palette.ink2,
            size: MarkScale.glyph(context, 16),
          ),
          Text(word, style: skin.text.meta.style(color: skin.palette.ink3)),
        ],
      ),
      title: t.name,
      lede: industry == null
          ? l10n.templateVersionShort(t.version)
          : l10n.templateVersionAndIndustry(t.version, industry),
      blocks: <Widget>[
        // The id is what the API and the agent app know this template by, so
        // it wears the identifier face here exactly as it does on the row.
        Text(t.id, style: skin.text.monoIdent.style(color: skin.palette.ink3)),
      ],
      actions: <Widget>[
        // Only an active template can be put in front of agents, and the one
        // already in use is changed from the block above the list — the same
        // two guards the row applies, so the pane offers no press the row
        // would have refused.
        if (t.active && !inAudits)
          TorchSecondaryButton(
            key: ValueKey<String>('template-use-${t.id}-pane'),
            label: busy ? l10n.templateSwitching : l10n.templateUseInAudits,
            busy: busy,
            blockedReason: busy ? l10n.templateSwitching : null,
            onPressed: busy ? null : () => _select(t.id),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: ValueKey<String>('template-preview-${t.id}-pane'),
            // The destination's own title. A tertiary that is stretched to a
            // 440dp pane centres its label, which is why it is aligned rather
            // than full width: the pane's verbs read down the leading edge.
            label: l10n.templatePreviewTitle,
            semanticLabel: '${t.name}. ${l10n.templateOpensPreview}',
            onPressed: () => context.push('/audit-templates/${t.id}/preview'),
          ),
        ),
      ],
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
    this.onDesk = false,
  });

  final AuditTemplate template;
  final bool inAudits;
  final bool busy;
  final bool last;
  final VoidCallback onUseInAudits;

  /// True in the desk's list pane, where the row's tap is the **selection**.
  ///
  /// It nulls the tap and changes nothing else — the chevron stays, because
  /// the preview is still one press away in the pane and a row that lost its
  /// trailing lane would move every other row's text column with it.
  final bool onDesk;

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
      onTap: onDesk
          ? null
          : () => context.push('/audit-templates/${t.id}/preview'),
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
