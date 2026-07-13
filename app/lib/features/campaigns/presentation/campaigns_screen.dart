import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/manager_scaffold.dart';
import '../data/campaigns_repository.dart';
import 'campaign_form_screen.dart';

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
      body: campaigns.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load campaigns: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(campaignsListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) =>
              _CampaignCard(campaign: list[index]),
        ),
      ),
    );
  }
}

class _CampaignCard extends ConsumerWidget {
  const _CampaignCard({required this.campaign});

  final Campaign campaign;

  Future<void> _showCompliance(BuildContext context, WidgetRef ref) {
    final future = ref.read(campaignsRepositoryProvider).getCompliance(campaign.id);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(campaign.name),
        content: FutureBuilder<CampaignCompliance>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 64,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Failed to load compliance: ${snapshot.error}');
            }
            final c = snapshot.data!;
            return Column(
              key: ValueKey<String>('compliance-${campaign.id}'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Outlets total: ${c.outletsTotal.toStringAsFixed(0)}'),
                Text('Outlets visited: ${c.outletsVisited.toStringAsFixed(0)}'),
                Text(
                    'Visit coverage: ${c.visitCoverageRate.toStringAsFixed(1)}%'),
                Text(
                    'Avg planogram compliance: ${c.avgPlanogramCompliancePct.toStringAsFixed(1)}%'),
                Text(
                    'Avg abs price deviation: ${c.avgAbsPriceDeviationPct.toStringAsFixed(1)}%'),
                Text(
                    'Promo compliance: ${c.promoComplianceRate.toStringAsFixed(1)}%'),
              ],
            );
          },
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        key: ValueKey<String>('campaign-${campaign.id}'),
        title: Text(campaign.name),
        subtitle: Text('${campaign.status} · ${campaign.outletCount} outlets'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey<String>('campaign-edit-${campaign.id}'),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit campaign',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => CampaignFormScreen(campaign: campaign),
                ),
              ),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        onTap: () => _showCompliance(context, ref),
      ),
    );
  }
}
