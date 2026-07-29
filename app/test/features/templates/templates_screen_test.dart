import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';
import 'package:tradeiq_app/features/templates/presentation/templates_screen.dart';

import '../../helpers/routed_app.dart';

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
  Future<PaginatedResponse<AuditTemplate>> listTemplates() async =>
      const PaginatedResponse(data: _templates, nextCursor: null);

  @override
  Future<AuditTemplateDetail> fetchTemplate(String id) =>
      throw UnimplementedError();
}

class _FailingTemplatesRepository implements TemplatesRepository {
  @override
  Future<PaginatedResponse<AuditTemplate>> listTemplates() async =>
      throw Exception('boom');

  @override
  Future<AuditTemplateDetail> fetchTemplate(String id) =>
      throw UnimplementedError();
}

Widget _app(TemplatesRepository repo) => routedApp(
      const TemplatesScreen(),
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repo),
      ],
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
