import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/console_skin.dart';
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
import '../data/sales_targets_repository.dart';
import 'sales_attainment_panel.dart';
import 'sales_target_sheet.dart';
import 'sales_import_sheet.dart';

/// MONTHLY SELL-IN TARGETS PER SKU (#119), and how the month is tracking.
///
/// ```text
///   Sales targets                                 [ ⤒ ]
///   Units ordered through TradeIQ, not what
///   shoppers bought.
///   [ ‹ ]  September 2026  [ › ]
///   ── Against target ───────────────────────
///   ┌──────────┐┌──────────┐┌──────────┐
///   │ ACCOUNT  ││ TERRITOR ││ STORES   │
///   │    54%   ││    —     ││    88%   │
///   │ Behind   ││ No targe ││ Close    │
///   └──────────┘└──────────┘└──────────┘
///   ── SKUs  12 ─────────── Set a target ────
///   ▌ Cola 2L                           54%
///   ▌ Sell-in 648 · target 1 200 units
///   ▌ [Edit the target] [Remove the target]
/// ```
///
/// ## A target that does not exist is not a target of zero (#396)
///
/// `attainmentPct` is null wherever no target was set. The old screen ran that
/// through a formatter that printed an em dash but coloured the row
/// `StatusLevel.neutral` beside rows coloured by attainment, and dropped the
/// whole level out of the grid when it had no targets — so a manager who had
/// set no territory targets saw two tiles and no reason for the third's
/// absence. Now: every level renders, a missing attainment is an em dash with
/// the unit suppressed, no band word, no severity, and the reason in words.
///
/// ## The amber, counted
///
/// A console route under Menu: Night paints the nav's active tab and nothing
/// else, Day and Veld paint zero. The commits on this route live in sheets —
/// the target sheet and the import sheet — and while a sheet is up every amber
/// beneath it goes out, so the sheet's own primary is the only light on the
/// frame.
class SalesTargetsScreen extends ConsumerWidget {
  const SalesTargetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ConsoleTorchlightRoute(child: _SalesTargets());
  }
}

/// The server's own sentence for a refusal it explained (a 400 or 404 names
/// the field or the missing SKU), otherwise the console's generic wording.
String describeSalesTargetError(Object error, [AppLocalizations? l10n]) {
  if (error is DioException) {
    final data = error.response?.data;
    final status = error.response?.statusCode ?? 0;
    if (status >= 400 && status < 500 && status != 401 && data is Map) {
      final message = data['error'];
      if (message is String && message.isNotEmpty) return message;
    }
  }
  return humanErrorMessage(error, l10n);
}

/// What a scoped target applies to, in words a person reads.
String salesScopeLabel(AppLocalizations l10n, ScopedAttainment scoped) {
  final name = scoped.territory?.name ?? scoped.outlet?.name;
  if (name == null) return l10n.salesScopeUnknown;
  final scope = switch (scoped.scope) {
    'territory' => l10n.salesScopeTerritory,
    'outlet' => l10n.salesScopeOutlet,
    _ => l10n.salesScopeAccount,
  };
  return '$name · $scope';
}

class _SalesTargets extends ConsumerWidget {
  const _SalesTargets();

  void _refresh(WidgetRef ref) {
    ref.invalidate(salesAttainmentProvider);
    ref.invalidate(currentMonthAttainmentProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final report = ref.watch(salesAttainmentProvider);

    return report.when(
      loading: () => _frame(
        context,
        ref,
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.salesTargetsTitle,
            child: const SkeletonRows(count: 5, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        context,
        ref,
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'sales-targets',
            child: ErrorState(
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.salesTargetsLoadErrorHeadline,
                body: describeSalesTargetError(error, l10n),
                offersRetry: true,
              ),
              drawing: EmptyDrawing.shelf,
              action: TorchSecondaryButton(
                key: const ValueKey<String>('sales-targets-retry'),
                label: l10n.salesTargetsRetry,
                onPressed: () => _refresh(ref),
              ),
            ),
          ),
        ],
      ),
      data: (data) => _loaded(context, ref, data),
    );
  }

  Widget _loaded(
    BuildContext context,
    WidgetRef ref,
    SalesAttainmentReport report,
  ) {
    final l10n = context.l10n;
    final month = ref.watch(salesTargetsMonthProvider);
    final gutter = context.skin.space.gutterFor(
      MediaQuery.sizeOf(context).width,
    );
    final metric = salesMetricLabel(l10n, report.metricLabel);

    return _frame(
      context,
      ref,
      phase: report.skus.isEmpty
          ? 'empty'
          : report.hasTargets
          ? 'loaded'
          : 'no-targets',
      children: <Widget>[
        if (report.timeZone.isNotEmpty) ...<Widget>[
          Text(
            l10n.salesTimeZone(report.timeZone),
            style: context.skin.text.meta.style(
              color: context.skin.palette.ink3,
            ),
          ),
          const SizedBox(height: TiqSpace.s5),
        ],

        SectionRule(l10n.salesLevelsHeading),
        const SizedBox(height: TiqSpace.s4),
        if (report.hasTargets)
          AttainmentLevels(report: report)
        else
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.salesNoTargetsHeadline(
              salesMonthLabelIn(context, month),
            ),
            body: l10n.salesNoTargetsBody,
          ),
        const SizedBox(height: TiqSpace.s7),

        SectionRule(
          l10n.salesSkusHeading,
          count: report.skus.isEmpty ? null : report.skus.length,
          action: report.skus.isEmpty
              ? null
              : SectionRuleAction(
                  l10n.salesSetTarget,
                  onTap: () => showSalesTargetSheet(
                    context,
                    ref,
                    skus: report.skus,
                    month: month,
                  ),
                ),
        ),
        const SizedBox(height: TiqSpace.s5),
        if (report.skus.isEmpty)
          EmptyState(
            headline: l10n.salesSkusEmptyHeadline,
            drawing: EmptyDrawing.shelf,
            body: l10n.salesSkusEmptyBody,
          )
        else
          TorchBleed(
            extra: gutter.left * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < report.skus.length; i++) ...<Widget>[
                  _SkuRow(
                    sku: report.skus[i],
                    skus: report.skus,
                    month: month,
                    metric: metric,
                    last:
                        i == report.skus.length - 1 &&
                        report.skus[i].scoped.isEmpty,
                  ),
                  for (var j = 0; j < report.skus[i].scoped.length; j++)
                    _ScopedRow(
                      sku: report.skus[i],
                      scoped: report.skus[i].scoped[j],
                      skus: report.skus,
                      month: month,
                      metric: metric,
                      last:
                          i == report.skus.length - 1 &&
                          j == report.skus[i].scoped.length - 1,
                    ),
                ],
              ],
            ),
          ),
        if (report.truncated) ...<Widget>[
          const SizedBox(height: TiqSpace.s6),
          TorchBleed(
            extra: gutter.left * 2,
            child: PaginationFooter(
              key: const ValueKey<String>('sales-targets-footer'),
              summary: l10n.salesSkusTruncated(
                TiqNumber.of(context).format(report.skus.length),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _frame(
    BuildContext context,
    WidgetRef ref, {
    required String phase,
    required List<Widget> children,
  }) {
    final l10n = context.l10n;
    final month = ref.watch(salesTargetsMonthProvider);

    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.salesTargetsTitle,
        facts: <String>[l10n.salesTargetsSubtitle, l10n.salesTargetsHelp],
        trailing: TorchIconButton(
          key: const ValueKey<String>('sales-targets-import'),
          icon: Icons.upload_file_outlined,
          semanticLabel: l10n.salesTargetsUpload,
          onPressed: () => showSalesImportSheet(context, ref),
        ),
      ),
      children: <Widget>[
        _MonthStepper(month: month),
        ...children,
      ],
    );
  }
}

/// Which month is being read, and the way to the ones either side.
class _MonthStepper extends ConsumerWidget {
  const _MonthStepper({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final label = salesMonthLabelIn(context, month);

    return Padding(
      padding: const EdgeInsets.only(bottom: TiqSpace.s6),
      child: Row(
        children: <Widget>[
          TorchIconButton(
            key: const ValueKey<String>('sales-month-prev'),
            icon: Icons.chevron_left,
            semanticLabel: l10n.salesMonthPrevious(label),
            onPressed: () =>
                ref.read(salesTargetsMonthProvider.notifier).previous(),
          ),
          Expanded(
            child: Text(
              label,
              key: const ValueKey<String>('sales-month-label'),
              textAlign: TextAlign.center,
              style: skin.text.titleM.style(color: skin.palette.ink1),
            ),
          ),
          TorchIconButton(
            key: const ValueKey<String>('sales-month-next'),
            icon: Icons.chevron_right,
            semanticLabel: l10n.salesMonthNext(label),
            onPressed: () =>
                ref.read(salesTargetsMonthProvider.notifier).next(),
          ),
        ],
      ),
    );
  }
}

/// One SKU's account-wide line.
class _SkuRow extends ConsumerWidget {
  const _SkuRow({
    required this.sku,
    required this.skus,
    required this.month,
    required this.metric,
    required this.last,
  });

  final SkuAttainment sku;
  final List<SkuAttainment> skus;
  final DateTime month;
  final String metric;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final targetId = sku.targetId;

    return _AttainmentRow(
      rowKey: ValueKey<String>('sku-${sku.skuId}'),
      title: sku.skuName,
      metric: metric,
      actualUnits: sku.actualUnits,
      targetUnits: sku.targetUnits,
      attainmentPct: sku.attainmentPct,
      last: last,
      actions: <Widget>[
        TorchTertiaryButton(
          key: ValueKey<String>('set-target-${sku.skuId}'),
          label: targetId == null ? l10n.salesSetTarget : l10n.salesEditTarget,
          onPressed: () => showSalesTargetSheet(
            context,
            ref,
            skus: skus,
            month: month,
            skuId: sku.skuId,
            units: sku.targetUnits,
            locked: true,
          ),
        ),
        if (targetId != null)
          TorchTertiaryButton(
            key: ValueKey<String>('delete-target-$targetId'),
            label: l10n.salesRemoveTarget,
            destructive: true,
            onPressed: () => deleteSalesTarget(context, ref, targetId),
          ),
      ],
    );
  }
}

/// One territory- or store-scoped target beneath its SKU.
class _ScopedRow extends ConsumerWidget {
  const _ScopedRow({
    required this.sku,
    required this.scoped,
    required this.skus,
    required this.month,
    required this.metric,
    required this.last,
  });

  final SkuAttainment sku;
  final ScopedAttainment scoped;
  final List<SkuAttainment> skus;
  final DateTime month;
  final String metric;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return _AttainmentRow(
      rowKey: ValueKey<String>('scoped-${scoped.targetId}'),
      title: l10n.salesScopedRowTitle(
        sku.skuName,
        salesScopeLabel(l10n, scoped),
      ),
      metric: metric,
      actualUnits: scoped.actualUnits,
      targetUnits: scoped.targetUnits,
      attainmentPct: scoped.attainmentPct,
      last: last,
      actions: <Widget>[
        TorchTertiaryButton(
          key: ValueKey<String>('edit-target-${scoped.targetId}'),
          label: l10n.salesEditTarget,
          onPressed: () => showSalesTargetSheet(
            context,
            ref,
            skus: skus,
            month: month,
            skuId: sku.skuId,
            scope: scoped.scope,
            territoryId: scoped.territory?.id,
            outletId: scoped.outlet?.id,
            units: scoped.targetUnits,
            locked: true,
          ),
        ),
        TorchTertiaryButton(
          key: ValueKey<String>('delete-target-${scoped.targetId}'),
          label: l10n.salesRemoveTarget,
          destructive: true,
          onPressed: () => deleteSalesTarget(context, ref, scoped.targetId),
        ),
      ],
    );
  }
}

/// The shape both rows wear.
class _AttainmentRow extends StatelessWidget {
  const _AttainmentRow({
    required this.rowKey,
    required this.title,
    required this.metric,
    required this.actualUnits,
    required this.targetUnits,
    required this.attainmentPct,
    required this.actions,
    required this.last,
  });

  final Key rowKey;
  final String title;
  final String metric;
  final int actualUnits;
  final int? targetUnits;
  final double? attainmentPct;
  final List<Widget> actions;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final band = salesBandWord(l10n, attainmentPct);
    final severity = salesSeverity(attainmentPct);

    final figures = targetUnits == null
        // A target that does not exist is not a target of zero (#396). The
        // row says so in words rather than printing a nought.
        ? l10n.salesRowNoTargetFigures(metric, numbers.format(actualUnits))
        : l10n.salesRowFigures(
            metric,
            numbers.format(actualUnits),
            numbers.format(targetUnits!),
          );

    // …and a target of zero is not the absence of one. The row used to print
    // "target 0 units" and then say "No target" underneath it, in the same
    // breath and to the same screen reader, because the word was chosen off a
    // null attainment. A nought-unit target is a target that asks for
    // nothing: it is named as that, and it still carries no severity, because
    // nothing is what it is being missed by.
    final word =
        band ??
        (targetUnits != null && targetUnits! <= 0
            ? l10n.salesZeroTarget
            : l10n.salesNoTarget);

    return SoftRow(
      key: rowKey,
      density: SoftRowDensity.tall,
      title: title,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: figures,
      // Crimson at two commitment levels, and only where a target exists to
      // miss. "No target" carries no severity at all.
      severity: switch (severity) {
        SeverityMarkKind.critical => SoftRowSeverity.critical,
        SeverityMarkKind.watch => SoftRowSeverity.watch,
        _ => SoftRowSeverity.none,
      },
      severityLabel:
          severity == SeverityMarkKind.critical ||
              severity == SeverityMarkKind.watch
          ? band
          : null,
      // The percentage, through the one formatter: a null renders an em dash
      // with the unit suppressed, and the reader hears the reason.
      trailing: FigureSlot(
        value: attainmentPct,
        role: skin.text.figureS,
        unit: TiqUnit.percent,
        decimals:
            attainmentPct == null ||
                attainmentPct == attainmentPct!.roundToDouble()
            ? 0
            : 1,
        // A missing figure is announced as the reason, never as "em dash".
        semanticsLabel: attainmentPct == null ? word : null,
      ),
      meta: Text(word, style: skin.text.meta.style(color: skin.palette.ink3)),
      actions: Wrap(spacing: TiqSpace.s4, children: actions),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[title, figures, word].join('. '),
    );
  }
}
