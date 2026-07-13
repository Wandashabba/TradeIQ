import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/outlets_repository.dart';

/// Outlets as a worklist. The only state an outlet carries from GET /outlets is
/// whether it has usable coordinates — an outlet at 0,0 cannot be geofenced, so
/// a visit there cannot be verified. That is the row's status.
class OutletsListScreen extends ConsumerWidget {
  const OutletsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outlets = ref.watch(outletsListProvider);
    // Outlets is reachable by both roles, but it is still a console screen —
    // it was the only one left on a bare Scaffold, which meant a manager who
    // landed here lost the nav rail entirely.
    return ManagerScaffold(
      title: 'Outlets',
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('create-outlet'),
        onPressed: () => context.push('/outlets/create'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Create Store'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Outlets without coordinates cannot be geofenced.',
            style: TextStyle(fontSize: 12, color: AppColors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<Outlet>>(
            value: outlets,
            label: 'outlets',
            onRetry: () => ref.invalidate(outletsListProvider),
            builder: (list) {
              final located = list.where(_isLocated).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TriageStrip(
                    counts: [
                      (
                        label: 'Geocoded',
                        count: located,
                        level: StatusLevel.good,
                      ),
                      (
                        label: 'No location',
                        count: list.length - located,
                        level: StatusLevel.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _OutletList(outlets: list),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 0,0 is the API's "unset" for a required double — it is in the Gulf of
/// Guinea, so no real outlet sits there.
bool _isLocated(Outlet outlet) => outlet.lat != 0 || outlet.lng != 0;

class _OutletList extends StatelessWidget {
  const _OutletList({required this.outlets});

  final List<Outlet> outlets;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: '${outlets.length} ${outlets.length == 1 ? 'outlet' : 'outlets'}',
      subtitle: 'Code and coordinates',
      padded: false,
      child: outlets.isEmpty
          ? const EmptyState(
              message: 'No outlets yet',
              hint: 'Create a store to put it on a beat plan.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final o in outlets) _OutletRow(outlet: o)],
            ),
    );
  }
}

class _OutletRow extends StatelessWidget {
  const _OutletRow({required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    final located = _isLocated(outlet);

    return WorklistRow(
      key: ValueKey<String>('outlet-${outlet.id}'),
      title: outlet.name,
      // The code is what an agent quotes and what imports key on: mono.
      meta: Row(
        children: [
          Flexible(flex: 2, child: CodeToken(outlet.code)),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              located
                  ? '${outlet.lat.toStringAsFixed(4)}, ${outlet.lng.toStringAsFixed(4)}'
                  : 'No coordinates on file',
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      level: located ? StatusLevel.good : StatusLevel.warning,
      statusLabel: located ? 'Geocoded' : 'No location',
    );
  }
}
