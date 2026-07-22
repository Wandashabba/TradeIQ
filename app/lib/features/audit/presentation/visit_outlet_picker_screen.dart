import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../outlets/data/outlets_repository.dart';

class VisitOutletPickerScreen extends ConsumerWidget {
  const VisitOutletPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlyMine = ref.watch(onlyMyTerritoriesProvider);
    final outlets = ref.watch(assignedOutletsProvider);
    return AgentScaffold(
      title: 'Select an Outlet',
      subtitle: 'Tap a store to start a visit',
      // The primary action lives in the thumb zone, not floating over the list.
      bottomAction: AgentButton(
        label: 'Add a store',
        icon: Icons.add_location_alt_outlined,
        secondary: true,
        onPressed: () async {
          await context.push('/outlets/create');
          ref.invalidate(assignedOutletsProvider);
        },
      ),
      body: outlets.when(
        data: (list) => ListView.builder(
          // +1 for the scope row that sits above the stores.
          itemCount: list.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _ScopeRow(
                onlyMine: onlyMine,
                count: list.length,
                onChanged: (value) =>
                    ref.read(onlyMyTerritoriesProvider.notifier).set(value),
              );
            }
            final outlet = list[index - 1];
            return ListTile(
              title: Text(outlet.name),
              subtitle: Text(
                '${outlet.code} · ${outlet.lat.toStringAsFixed(5)}, ${outlet.lng.toStringAsFixed(5)}',
              ),
              trailing: ElevatedButton(
                onPressed: () => context.go('/audit/${outlet.id}'),
                child: const Text('Start Visit'),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load outlets: $err')),
      ),
    );
  }
}

/// Says which stores are being shown, and offers the way out of that.
///
/// The list defaults to the agent's own territories, so it has to say so —
/// a filtered list that looks like the whole list is how someone concludes a
/// store is missing from the system. The switch is always present, because
/// territory data is imperfect and an agent covering someone else's patch
/// needs to reach those stores without finding an administrator first.
class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.onlyMine,
    required this.count,
    required this.onChanged,
  });

  final bool onlyMine;
  final int count;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: const ValueKey<String>('only-my-territories'),
      value: onlyMine,
      onChanged: onChanged,
      title: Text(onlyMine ? 'My territories' : 'All stores'),
      subtitle: Text(
        onlyMine
            ? '$count in your territories — switch off to see every store'
            : '$count stores across this client',
      ),
    );
  }
}
