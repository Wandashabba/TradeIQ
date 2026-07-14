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
    final outlets = ref.watch(outletsListProvider);
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
          ref.invalidate(outletsListProvider);
        },
      ),
      body: outlets.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final outlet = list[index];
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
