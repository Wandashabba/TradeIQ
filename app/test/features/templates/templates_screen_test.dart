import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';
import 'package:tradeiq_app/features/templates/presentation/templates_screen.dart';

const _templates = [
  AuditTemplate(
    id: 'tpl-1',
    name: 'Grocery Audit',
    industry: 'retail',
    version: 2,
    active: true,
  ),
  AuditTemplate(
    id: 'tpl-2',
    name: 'Pharmacy Audit',
    version: 1,
    active: false,
  ),
];

class _FakeTemplatesRepository implements TemplatesRepository {
  @override
  Future<List<AuditTemplate>> listTemplates() async => _templates;
}

class _FailingTemplatesRepository implements TemplatesRepository {
  @override
  Future<List<AuditTemplate>> listTemplates() async =>
      throw Exception('boom');
}

Widget _app(TemplatesRepository repo) => ProviderScope(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: TemplatesScreen()),
    );

void main() {
  testWidgets('renders template names once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeTemplatesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Grocery Audit'), findsOneWidget);
    expect(find.text('Pharmacy Audit'), findsOneWidget);
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_FailingTemplatesRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load templates'),
      findsOneWidget,
    );
  });
}
