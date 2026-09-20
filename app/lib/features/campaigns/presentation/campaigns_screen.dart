import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/campaigns_repository.dart';
import 'campaign_form_screen.dart';
import 'campaign_return_view.dart';

/// Campaigns as a worklist: the live ones first, each row carrying its status
/// as a mark and a word, and opening its compliance rollup and return on tap.
class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(campaignsListProvider);
    return ManagerScaffold(
      title: 'Campaigns',
      floatingActionButton: FloatingActionButton(
        key: const ValueKey<String>('campaign-create-fab'),
        tooltip: 'New campaign',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const CampaignFormScreen(),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncSection<List<Campaign>>(
            value: campaigns,
            label: 'campaigns',
            onRetry: () => ref.invalidate(campaignsListProvider),
            builder: (list) => PanelCard(
              title:
                  '${list.length} ${list.length == 1 ? 'campaign' : 'campaigns'}',
              subtitle: 'Tap a row for its compliance rollup',
              padded: false,
              child: list.isEmpty
                  ? const EmptyState(
                      message: 'No campaigns yet',
                      hint: 'Create one to track visit coverage, planogram and '
                          'promo compliance against a date window.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final campaign in list)
                          _CampaignRow(campaign: campaign),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status drives the row's level: a live campaign is what a manager acts on, a
/// paused one wants a decision, a cancelled one is a failure to explain.
StatusLevel _levelFor(String status) => switch (status) {
      'active' => StatusLevel.good,
      'paused' => StatusLevel.warning,
      'cancelled' => StatusLevel.critical,
      _ => StatusLevel.neutral,
    };

String _statusWord(String status) => switch (status) {
      'active' => 'Active',
      'draft' => 'Draft',
      'paused' => 'Paused',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status,
    };

class _CampaignRow extends ConsumerWidget {
  const _CampaignRow({required this.campaign});

  final Campaign campaign;

  Future<void> _showCompliance(BuildContext context, WidgetRef ref) {
    final repo = ref.read(campaignsRepositoryProvider);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface1,
        title: Text(campaign.name),
        content: _CampaignDialogBody(
          campaignId: campaign.id,
          repo: repo,
          complianceSection: _complianceSection,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _complianceSection(Future<CampaignCompliance> future) =>
      FutureBuilder<CampaignCompliance>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _DialogLoading();
            }
            if (snapshot.hasError) {
              return Text('Failed to load compliance: ${snapshot.error}');
            }
            final c = snapshot.data!;
            if (context.colors.glass) {
              // Glass: each measure a label and a mono figure, so the rates
              // line up down the right edge and read as a table.
              return Column(
                key: ValueKey<String>('compliance-${campaign.id}'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Coverage'),
                  const SizedBox(height: 8),
                  _FigureLine('Outlets total', c.outletsTotal.toStringAsFixed(0)),
                  _FigureLine(
                    'Outlets visited',
                    c.outletsVisited.toStringAsFixed(0),
                  ),
                  _FigureLine(
                    'Visit coverage',
                    '${c.visitCoverageRate.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 12),
                  const SectionLabel('Compliance'),
                  const SizedBox(height: 8),
                  _FigureLine(
                    'Avg planogram compliance',
                    '${c.avgPlanogramCompliancePct.toStringAsFixed(1)}%',
                  ),
                  _FigureLine(
                    'Avg abs price deviation',
                    '${c.avgAbsPriceDeviationPct.toStringAsFixed(1)}%',
                  ),
                  _FigureLine(
                    'Promo compliance',
                    '${c.promoComplianceRate.toStringAsFixed(1)}%',
                  ),
                ],
              );
            }
            return Column(
              key: ValueKey<String>('compliance-${campaign.id}'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Coverage'),
                const SizedBox(height: 6),
                Text('Outlets total: ${c.outletsTotal.toStringAsFixed(0)}'),
                Text('Outlets visited: ${c.outletsVisited.toStringAsFixed(0)}'),
                Text(
                    'Visit coverage: ${c.visitCoverageRate.toStringAsFixed(1)}%'),
                const SizedBox(height: 10),
                const SectionLabel('Compliance'),
                const SizedBox(height: 6),
                Text(
                    'Avg planogram compliance: ${c.avgPlanogramCompliancePct.toStringAsFixed(1)}%'),
                Text(
                    'Avg abs price deviation: ${c.avgAbsPriceDeviationPct.toStringAsFixed(1)}%'),
                Text(
                    'Promo compliance: ${c.promoComplianceRate.toStringAsFixed(1)}%'),
              ],
            );
          },
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WorklistRow(
      key: ValueKey<String>('campaign-${campaign.id}'),
      title: campaign.name,
      // The campaign id is machine-facing — it is what the compliance endpoint
      // and every export key on — so it wears the mono token.
      meta: Row(
        children: [
          CodeToken(campaign.id),
          const SizedBox(width: 6),
          const Text('·'),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${campaign.outletCount} outlets · ${campaign.startDate} → ${campaign.endDate}',
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      level: _levelFor(campaign.status),
      statusLabel: _statusWord(campaign.status),
      // A finished campaign is done, but still on the page: dimmed, not hidden.
      resolved: campaign.status == 'completed',
      onTap: () => _showCompliance(context, ref),
      actions: [
        RowAction(
          key: ValueKey<String>('campaign-edit-${campaign.id}'),
          label: 'Edit',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => CampaignFormScreen(campaign: campaign),
            ),
          ),
        ),
      ],
    );
  }
}

/// The campaign dialog's body: its compliance rollup, then its return.
///
/// Stateful so both requests start in [State.initState], in the same build
/// pass as the builders that listen to them. Started any earlier, a request
/// that fails before the dialog's first frame is an unhandled error.
class _CampaignDialogBody extends StatefulWidget {
  const _CampaignDialogBody({
    required this.campaignId,
    required this.repo,
    required this.complianceSection,
  });

  final String campaignId;
  final CampaignsRepository repo;
  final Widget Function(Future<CampaignCompliance> future) complianceSection;

  @override
  State<_CampaignDialogBody> createState() => _CampaignDialogBodyState();
}

class _CampaignDialogBodyState extends State<_CampaignDialogBody> {
  late final Future<CampaignCompliance> _compliance = widget.repo
      .getCompliance(widget.campaignId);
  late final Future<CampaignRoi> _roi = widget.repo.getRoi(widget.campaignId);

  @override
  void initState() {
    super.initState();
    // Touch both so each request starts now, not lazily on first read.
    _compliance;
    _roi;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.complianceSection(_compliance),
            const SizedBox(height: 16),
            // The return loads on its own: a slow or failed ROI query must not
            // hide the compliance rollup above it.
            FutureBuilder<CampaignRoi>(
              future: _roi,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _DialogLoading(
                    key: ValueKey<String>('roi-loading'),
                  );
                }
                if (snapshot.hasError) {
                  return Text('Failed to load return: ${snapshot.error}');
                }
                return CampaignReturnView(roi: snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A section of the campaign dialog still loading.
class _DialogLoading extends StatelessWidget {
  const _DialogLoading({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 64,
    child: Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

/// One measure in the glass compliance rollup: the words left, the figure
/// right.
class _FigureLine extends StatelessWidget {
  const _FigureLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final lumen = context.lumen;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: lumen.inkMuted),
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: LumenGlass.figure(color: lumen.ink)),
        ],
      ),
    );
  }
}
