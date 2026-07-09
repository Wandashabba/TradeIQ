import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/outlets_repository.dart';

class OutletsListScreen extends ConsumerWidget {
  const OutletsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outlets = ref.watch(outletsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Outlets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/outlets/create'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Create Store'),
      ),
      body: outlets.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(list[index].name),
            subtitle: Text(list[index].code),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load outlets: $err')),
      ),
    );
  }
}
