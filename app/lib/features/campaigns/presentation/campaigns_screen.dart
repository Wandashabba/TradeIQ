import 'package:flutter/material.dart' show Icons, MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/campaigns_repository.dart';
import 'campaign_form_screen.dart';
import 'campaign_return_view.dart';

/// CAMPAIGNS — the live ones first, each row carrying its status as a mark and
/// a word, and opening its compliance rollup and its return on tap.
///
/// ```text
///   Campaigns                                     [ ⟳ ]
///   Tap a row for its compliance rollup and return.
///   ── Campaigns                            4 ────
///   Spring planogram reset                  Active
///   12 outlets · 2026-09-01 → 2026-09-30
///   CMP-4821                                     ›
///   Edit
///   …
///   [ New campaign ]
///   [ nav pill ]
/// ```
///
/// ## The amber, counted
///
/// A tab root: the nav pill's active tab is slot 1 in Night whenever the nav
/// renders, and this route declines the one content grant it has left —
/// nothing on a list of campaigns is armed. Day and Veld have one rung, the
/// primary commit block, and this route has no primary, so they paint zero.
/// While the rollup sheet is up every amber beneath it goes out.
///
/// ## The rollup is a sheet, not a dialog
///
/// Unify §1.7 deleted the dialog. The compliance rollup and the return open in
/// the one modal container, and the two requests behind them still resolve
/// **independently**: a slow or failed ROI query must not hide the compliance
/// figures above it, which is the property the old dialog had and the one
/// worth keeping.
class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(campaignsListProvider);

    return campaigns.when(
      loading: () => _frame(
        ref,
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'campaigns',
            child: const SkeletonRows(count: 4, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        ref,
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'campaigns',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('campaigns-retry'),
                label: 'Try again',
                onPressed: () => ref.invalidate(campaignsListProvider),
              ),
            ),
          ),
        ],
      ),
      data: (list) => _loaded(context, ref, list),
    );
  }

  Widget _frame(
    WidgetRef ref, {
    required String phase,
    required List<Widget> children,
  }) {
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: 'Campaigns',
        facts: const <String>['Tap a row for its compliance rollup.'],
        trailing: TorchIconButton(
          key: const ValueKey<String>('campaigns-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh the campaigns list',
          onPressed: () => ref.invalidate(campaignsListProvider),
        ),
      ),
      children: children,
    );
  }

  Widget _loaded(BuildContext context, WidgetRef ref, List<Campaign> list) {
    final gutter = context.skin.space.gutter;

    return _frame(
      ref,
      phase: list.isEmpty ? 'empty' : 'loaded',
      children: <Widget>[
        SectionRule('Campaigns', count: list.isEmpty ? null : list.length),
        const SizedBox(height: TiqSpace.s5),

        if (list.isEmpty)
          const EmptyState(
            key: ValueKey<String>('campaigns-empty'),
            scope: EmptyScope.inPanel,
            headline: 'No campaigns yet.',
            body: 'Create one to track visit coverage, planogram and promo '
                'compliance against a date window.',
          )
        else
          TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < list.length; i++)
                  _CampaignRow(
                    key: ValueKey<String>('campaign-row-${list[i].id}'),
                    campaign: list[i],
                    last: i == list.length - 1,
                  ),
              ],
            ),
          ),

        const SizedBox(height: TiqSpace.s7),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchSecondaryButton(
            key: const ValueKey<String>('campaign-create'),
            label: 'New campaign',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CampaignFormScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A campaign's status as a word and a silhouette.
///
/// Two levels, and no more: a **paused** campaign wants a decision and takes
/// the outlined crimson watch; a **cancelled** one is a failure somebody has
/// to explain and takes the solid one. Active, draft and completed are not
/// degrees of wrong, so they are Oatmeal and a square with the word beside it.
/// A campaign running normally is not "good news" the system should colour.
StatusLevel campaignLevel(String status) => switch (status) {
  'paused' => StatusLevel.watch,
  'cancelled' => StatusLevel.critical,
  _ => StatusLevel.held,
};

String campaignStatusWord(String status) => switch (status) {
  'active' => 'Active',
  'draft' => 'Draft',
  'paused' => 'Paused',
  'completed' => 'Completed',
  'cancelled' => 'Cancelled',
  _ => status,
};

class _CampaignRow extends ConsumerWidget {
  const _CampaignRow({super.key, required this.campaign, required this.last});

  final Campaign campaign;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final word = campaignStatusWord(campaign.status);
    final window = '${campaign.startDate} → ${campaign.endDate}';
    final outlets =
        '${numbers.format(campaign.outletCount)} '
        '${campaign.outletCount == 1 ? 'outlet' : 'outlets'}';

    return SoftRow(
      key: ValueKey<String>('campaign-${campaign.id}'),
      density: SoftRowDensity.tall,
      title: campaign.name,
      subtitle: '$outlets · $window',
      // The campaign id is machine-facing — it is what the compliance endpoint
      // and every export key on — so it wears the identifier face. It is the
      // meta line and never the title: a row names the thing, not the record.
      meta: Text(
        campaign.id,
        style: skin.text.monoIdent.style(color: skin.palette.ink3),
      ),
      trailing: StatusChip(level: campaignLevel(campaign.status), label: word),
      actions: Wrap(
        spacing: TiqSpace.s4,
        children: <Widget>[
          TorchTertiaryButton(
            key: ValueKey<String>('campaign-edit-${campaign.id}'),
            label: 'Edit',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CampaignFormScreen(campaign: campaign),
              ),
            ),
          ),
        ],
      ),
      onTap: () => showCampaignRollupSheet(context, campaign: campaign),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        word,
        campaign.name,
        '$outlets, $window',
      ].join('. '),
    );
  }
}

/// THE ROLLUP — coverage, compliance, and the return, in the one modal
/// container.
Future<void> showCampaignRollupSheet(
  BuildContext context, {
  required Campaign campaign,
}) {
  return showTorchSheet<void>(
    context,
    builder: (_) => _RollupSheet(campaign: campaign),
  );
}

class _RollupSheet extends ConsumerStatefulWidget {
  const _RollupSheet({required this.campaign});

  final Campaign campaign;

  @override
  ConsumerState<_RollupSheet> createState() => _RollupSheetState();
}

class _RollupSheetState extends ConsumerState<_RollupSheet> {
  /// Both requests start in [initState], in the same build pass as the
  /// builders that listen to them. Started any earlier, a request that fails
  /// before the sheet's first frame is an unhandled error.
  late final Future<CampaignCompliance> _compliance;
  late final Future<CampaignRoi> _roi;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(campaignsRepositoryProvider);
    _compliance = repo.getCompliance(widget.campaign.id);
    _roi = repo.getRoi(widget.campaign.id);
  }

  @override
  Widget build(BuildContext context) {
    return TorchSheet(
      title: widget.campaign.name,
      subtitle: 'Coverage, compliance and return.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Section<CampaignCompliance>(
            name: 'compliance',
            future: _compliance,
            builder: (value) => _Compliance(
              key: ValueKey<String>('compliance-${widget.campaign.id}'),
              compliance: value,
            ),
          ),
          SizedBox(height: context.skin.space.blockGap),
          // The return loads on its own: a slow or failed ROI query must not
          // hide the compliance rollup above it.
          _Section<CampaignRoi>(
            name: 'return',
            future: _roi,
            builder: (value) => CampaignReturnView(roi: value),
          ),
        ],
      ),
    );
  }
}

/// One independently-loading region of the sheet.
class _Section<T> extends StatelessWidget {
  const _Section({
    required this.name,
    required this.future,
    required this.builder,
  });

  final String name;
  final Future<T> future;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Skeleton(
            key: ValueKey<String>('$name-loading'),
            label: name,
            child: const SkeletonRows(count: 3, rowHeight: 28),
          );
        }
        if (snapshot.hasError) {
          // One retry per region, and only where retrying is honest. There is
          // none here: the sheet has no way to re-issue the request it made in
          // initState, so it names the failure and the row behind it is still
          // there to tap again.
          return TorchErrorRegion(
            name: name,
            child: ErrorState(
              key: ValueKey<String>('$name-error'),
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(snapshot.error),
            ),
          );
        }
        return builder(snapshot.data as T);
      },
    );
  }
}

/// Coverage and compliance, as figures that line up down one edge.
class _Compliance extends StatelessWidget {
  const _Compliance({super.key, required this.compliance});

  final CampaignCompliance compliance;

  @override
  Widget build(BuildContext context) {
    final c = compliance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule('Coverage'),
        const SizedBox(height: TiqSpace.s4),
        _FigureLine('Outlets total', c.outletsTotal, decimals: 0),
        _FigureLine('Outlets visited', c.outletsVisited, decimals: 0),
        _FigureLine(
          'Visit coverage',
          c.visitCoverageRate,
          unit: TiqUnit.percent,
        ),
        SizedBox(height: context.skin.space.blockGap),
        SectionRule('Compliance'),
        const SizedBox(height: TiqSpace.s4),
        _FigureLine(
          'Avg planogram compliance',
          c.avgPlanogramCompliancePct,
          unit: TiqUnit.percent,
        ),
        _FigureLine(
          'Avg abs price deviation',
          c.avgAbsPriceDeviationPct,
          unit: TiqUnit.percent,
        ),
        _FigureLine(
          'Promo compliance',
          c.promoComplianceRate,
          unit: TiqUnit.percent,
        ),
      ],
    );
  }
}

/// One measure: the words left, the figure right, in mono so the column reads
/// down its own edge.
class _FigureLine extends StatelessWidget {
  const _FigureLine(
    this.label,
    this.value, {
    this.unit = TiqUnit.none,
    this.decimals = 1,
  });

  final String label;
  final double value;
  final TiqUnit unit;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TiqSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ),
          const SizedBox(width: TiqSpace.s3),
          // Flexible: see `_ReturnLine` — an unconstrained FigureSlot never
          // measures itself down and overflows at 2.0x.
          Flexible(
            child: FigureSlot(
              value: value,
              role: skin.text.figureS,
              unit: unit,
              decimals: decimals,
              color: skin.palette.ink1,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
