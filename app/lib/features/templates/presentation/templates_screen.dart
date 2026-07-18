import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/templates_repository.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesListProvider);

    return ManagerScaffold(
      title: 'Audit Templates',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'A template is the form an agent fills in on a visit.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<AuditTemplate>>(
            value: templates,
            label: 'templates',
            onRetry: () => ref.invalidate(templatesListProvider),
            builder: (list) => _TemplateList(templates: list),
          ),
        ],
      ),
    );
  }
}

class _TemplateList extends StatelessWidget {
  const _TemplateList({required this.templates});

  final List<AuditTemplate> templates;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title:
          '${templates.length} ${templates.length == 1 ? 'template' : 'templates'}',
      subtitle: 'Tap a row to preview its form',
      padded: false,
      child: templates.isEmpty
          ? const EmptyState(
              message: 'No templates yet',
              hint: 'Templates published to this client appear here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in templates) _TemplateRow(template: t),
              ],
            ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.template});

  final AuditTemplate template;

  @override
  Widget build(BuildContext context) {
    final t = template;
    final industry = t.industry;

    return WorklistRow(
      key: ValueKey('template-${t.id}'),
      title: t.name,
      // The id is what the API and the agent app know this template by, so it
      // wears the mono token.
      meta: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CodeToken(t.id),
          const SizedBox(width: 6),
          const Text('·'),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              industry == null ? 'v${t.version}' : 'v${t.version} · $industry',
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      level: t.active ? StatusLevel.good : StatusLevel.neutral,
      statusLabel: t.active ? 'Active' : 'Paused',
      // A paused template is done, not broken — dim it, keep it on the page.
      resolved: !t.active,
      // Preview walks the template's dynamic form (issue #54 step 2).
      onTap: () => context.push('/audit-templates/${t.id}/preview'),
    );
  }
}
