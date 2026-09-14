import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/templates_repository.dart';
import '../domain/template_schema.dart';
import 'dynamic_template_form.dart';
import '../../../core/widgets/glass_page_scaffold.dart';

/// Manager-side preview of a template's dynamic form (issue #54 step 2):
/// fetches the schema via GET /templates/:id and walks it section by section
/// exactly as a field agent will during a template-driven audit. Answers are
/// not persisted yet — that lands with the audit-flow integration (step 3).
class TemplateFormScreen extends ConsumerWidget {
  const TemplateFormScreen({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(templateDetailProvider(templateId));
    return GlassPageScaffold(
      title: Text(detail.value?.template.name ?? 'Template Preview',
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load template: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(templateDetailProvider(templateId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (d) => DynamicTemplateForm(
          schema: TemplateSchema.parse(d.schema),
          submitLabel: 'Finish preview',
          onSubmit: (answers) => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Preview complete'),
              content: Text(
                '${answers.length} answer(s) collected. Saving responses '
                'against a visit arrives with the audit-flow integration.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
