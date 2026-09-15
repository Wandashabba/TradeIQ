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

  /// Uses [templateId] in audits, or with null stops using one (#122).
  static Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    String? templateId,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final now = await ref
          .read(templatesRepositoryProvider)
          .selectForAudits(templateId);
      ref.invalidate(selectedTemplateProvider);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            now == null
                ? 'No template is used in audits now.'
                : '“${now.template.name}” is now used in audits.',
          ),
        ),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not change the audit template: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesListProvider);
    final selected = ref.watch(selectedTemplateProvider);
    // While the selection loads (or if it fails) no row claims to be in use.
    final selectedId = selected.value?.template.id;

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
          _InAuditsPanel(
            selected: selected,
            onClear: () => _select(context, ref, null),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<AuditTemplate>>(
            value: templates,
            label: 'templates',
            onRetry: () => ref.invalidate(templatesListProvider),
            builder: (list) => _TemplateList(
              templates: list,
              selectedId: selectedId,
              onSelect: (id) => _select(context, ref, id),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which template field agents answer on every visit — said once, at the top,
/// in words, so nobody has to scan the rows for a badge.
class _InAuditsPanel extends StatelessWidget {
  const _InAuditsPanel({required this.selected, required this.onClear});

  final AsyncValue<AuditTemplateDetail?> selected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = selected.value;
    final String headline;
    if (selected.isLoading && current == null) {
      headline = 'Checking which template is in use…';
    } else if (selected.hasError && current == null) {
      headline = 'Could not load the template used in audits.';
    } else if (current == null) {
      headline = 'No template is used in audits.';
    } else {
      headline = '“${current.template.name}” (v${current.template.version})';
    }

    return PanelCard(
      key: const ValueKey('templates-in-audits'),
      title: 'Used in field audits',
      subtitle: 'Client questions, added after the standard audit sections',
      trailing: current == null
          ? null
          : TextButton(
              key: const ValueKey('templates-stop-using'),
              onPressed: onClear,
              child: const Text('Stop using'),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            headline,
            key: const ValueKey('templates-in-audits-name'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.ink1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Agents answer its questions on every visit, as an extra section '
            'after the standard audit. Required questions must be answered '
            'before a visit can be submitted. It does not change the perfect '
            'store score.',
            style: TextStyle(fontSize: 12, height: 1.4, color: colors.ink3),
          ),
        ],
      ),
    );
  }
}

class _TemplateList extends StatelessWidget {
  const _TemplateList({
    required this.templates,
    required this.selectedId,
    required this.onSelect,
  });

  final List<AuditTemplate> templates;
  final String? selectedId;
  final ValueChanged<String> onSelect;

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
                for (final t in templates)
                  _TemplateRow(
                    template: t,
                    inAudits: t.id == selectedId,
                    onUseInAudits: () => onSelect(t.id),
                  ),
              ],
            ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.inAudits,
    required this.onUseInAudits,
  });

  final AuditTemplate template;
  final bool inAudits;
  final VoidCallback onUseInAudits;

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
      statusLabel: inAudits ? 'In audits' : (t.active ? 'Active' : 'Paused'),
      // A paused template is done, not broken — dim it, keep it on the page.
      resolved: !t.active,
      // Only an active template can be put in front of agents; the one already
      // in use is changed from the panel above.
      actions: [
        if (t.active && !inAudits)
          TextButton(
            key: ValueKey('template-use-${t.id}'),
            onPressed: onUseInAudits,
            child: const Text('Use in audits'),
          ),
      ],
      // Preview walks the template's dynamic form (issue #54 step 2).
      onTap: () => context.push('/audit-templates/${t.id}/preview'),
    );
  }
}
