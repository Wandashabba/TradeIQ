import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/dispatch_repository.dart';

class DispatchScreen extends ConsumerStatefulWidget {
  const DispatchScreen({super.key});

  @override
  ConsumerState<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends ConsumerState<DispatchScreen> {
  String? _selectedOutletId;

  @override
  Widget build(BuildContext context) {
    final outlets = ref.watch(outletsListProvider);

    return ManagerScaffold(
      title: 'Dispatch',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Agents are ranked in-territory first, then by distance from their '
            'last known location.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          PanelCard(
            title: 'Outlet',
            subtitle: 'Who should take this one?',
            child: AsyncSection<List<Outlet>>(
              value: outlets,
              label: 'outlets',
              onRetry: () => ref.invalidate(outletsListProvider),
              builder: (list) => DropdownButtonFormField<String>(
                key: const ValueKey<String>('outlet-select'),
                initialValue: _selectedOutletId,
                decoration: const InputDecoration(labelText: 'Outlet'),
                dropdownColor: context.colors.surface2,
                style: TextStyle(fontSize: 13, color: context.colors.ink1),
                items: [
                  for (final outlet in list)
                    DropdownMenuItem<String>(
                      value: outlet.id,
                      child: Text(outlet.name),
                    ),
                ],
                onChanged: (value) => setState(() => _selectedOutletId = value),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedOutletId == null)
            const PanelCard(
              padded: false,
              child: EmptyState(
                message: 'Pick an outlet to rank agents',
                hint: 'Ranking needs a destination to measure distance from.',
              ),
            )
          else
            _Candidates(outletId: _selectedOutletId!),
        ],
      ),
    );
  }
}

class _Candidates extends ConsumerWidget {
  const _Candidates({required this.outletId});

  final String outletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(dispatchResultProvider(outletId));

    return PanelCard(
      title: 'Candidates',
      subtitle: 'In-territory first, then nearest',
      padded: false,
      child: AsyncSection<DispatchResult>(
        // Matches the previous copy so the failure reads the same.
        value: result,
        label: 'agents',
        onRetry: () => ref.invalidate(dispatchResultProvider(outletId)),
        builder: (data) {
          if (data.candidates.isEmpty) {
            return const EmptyState(
              message: 'No agent can be ranked',
              hint: 'Ranking needs agents assigned to a territory, or a last '
                  'known location — neither is recorded yet.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in data.candidates)
                WorklistRow(
                  key: ValueKey('candidate-${c.email}'),
                  title: c.email,
                  meta: Row(
                    children: [
                      Text(
                        c.inTerritory ? 'In territory' : 'Outside territory',
                      ),
                      const SizedBox(width: 6),
                      const Text('·'),
                      const SizedBox(width: 6),
                      // "No location" is a real state, not a zero. An agent the
                      // server cannot place must not look like one standing on
                      // the doorstep.
                      Text(
                        c.distanceM != null
                            ? '${c.distanceM!.toStringAsFixed(0)} m away'
                            : 'No last-known location',
                      ),
                    ],
                  ),
                  level: c.inTerritory ? StatusLevel.good : StatusLevel.neutral,
                  statusLabel: data.recommended?.email == c.email
                      ? 'Recommended'
                      : c.inTerritory
                          ? 'In territory'
                          : 'Available',
                ),
            ],
          );
        },
      ),
    );
  }
}
