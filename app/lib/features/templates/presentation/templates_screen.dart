import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../data/templates_repository.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load templates: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(templatesListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => _TemplateCard(template: list[index]),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});

  final AuditTemplate template;

  @override
  Widget build(BuildContext context) {
    final t = template;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description),
        title: Text(t.name),
        subtitle: Text(
          'v${t.version}${t.industry != null ? ' · ${t.industry}' : ''}',
        ),
        trailing: t.active
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.pause_circle, color: Colors.grey),
      ),
    );
  }
}
