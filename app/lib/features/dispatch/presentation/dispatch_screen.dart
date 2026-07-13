import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/manager_scaffold.dart';
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            outlets.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Failed to load outlets: $err'),
              data: (list) => DropdownButtonFormField<String>(
                key: const ValueKey<String>('outlet-select'),
                initialValue: _selectedOutletId,
                decoration: const InputDecoration(labelText: 'Outlet'),
                items: [
                  for (final outlet in list)
                    DropdownMenuItem<String>(
                      value: outlet.id,
                      child: Text(outlet.name),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedOutletId = value),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedOutletId != null)
              ref.watch(dispatchResultProvider(_selectedOutletId!)).when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) =>
                        Text('Failed to rank agents: $err'),
                    data: (result) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (result.recommended != null)
                          Card(
                            key: const ValueKey<String>('recommended'),
                            child: ListTile(
                              leading: const Icon(Icons.star),
                              title: Text(
                                'Recommended: ${result.recommended!.email}',
                              ),
                            ),
                          ),
                        for (final candidate in result.candidates)
                          ListTile(
                            title: Text(candidate.email),
                            subtitle: Text(
                              '${candidate.inTerritory ? 'in territory · ' : ''}${candidate.distanceM != null ? '${candidate.distanceM!.toStringAsFixed(0)}m' : 'no location'}',
                            ),
                          ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
