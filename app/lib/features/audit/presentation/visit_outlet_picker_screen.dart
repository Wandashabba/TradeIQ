import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../outlets/data/outlets_repository.dart';

class VisitOutletPickerScreen extends ConsumerWidget {
  const VisitOutletPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outlets = ref.watch(outletsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Select an Outlet')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/outlets/create');
          ref.invalidate(outletsListProvider);
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Create Store'),
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
