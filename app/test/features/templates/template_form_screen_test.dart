import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';
import 'package:tradeiq_app/features/templates/presentation/template_form_screen.dart';

const _detail = AuditTemplateDetail(
  template: AuditTemplate(
    id: 'tpl-1',
    name: 'Grocery Audit',
    version: 2,
    active: true,
  ),
  schema: {
    'sections': [
      {
        'id': 'availability',
        'title': 'Availability',
        'fields': [
          {'id': 'onShelf', 'label': 'On shelf?', 'type': 'boolean'},
        ],
      },
    ],
  },
);

class _FakeTemplatesRepository implements TemplatesRepository {
  @override
  Future<PaginatedResponse<AuditTemplate>> listTemplates() async =>
      const PaginatedResponse(data: [], nextCursor: null);

  @override
  Future<AuditTemplateDetail> fetchTemplate(String id) async => _detail;

  @override
  Future<AuditTemplateDetail?> fetchSelected() async => null;

  @override
  Future<AuditTemplateDetail?> selectForAudits(String? templateId) async =>
      null;
}

class _FailingTemplatesRepository implements TemplatesRepository {
  @override
  Future<PaginatedResponse<AuditTemplate>> listTemplates() async =>
      const PaginatedResponse(data: [], nextCursor: null);

  @override
  Future<AuditTemplateDetail> fetchTemplate(String id) async =>
      throw Exception('boom');

  @override
  Future<AuditTemplateDetail?> fetchSelected() async => null;

  @override
  Future<AuditTemplateDetail?> selectForAudits(String? templateId) async =>
      null;
}

Widget _app(TemplatesRepository repo, {ThemeData? theme}) => ProviderScope(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: theme,
        home: const TemplateFormScreen(templateId: 'tpl-1'),
      ),
    );

void main() {
  testWidgets('fetches the schema and renders the dynamic form', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeTemplatesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Grocery Audit'), findsOneWidget);
    expect(find.textContaining('Section 1 of 1'), findsOneWidget);
    expect(find.text('On shelf?'), findsOneWidget);
  });

  testWidgets('finishing the preview shows the collected-answers dialog', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeTemplatesRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('field-onShelf')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish preview'));
    await tester.pumpAndSettle();

    expect(find.text('Preview complete'), findsOneWidget);
    expect(find.textContaining('1 answer(s) collected'), findsOneWidget);
  });

  testWidgets('shows an error message when the fetch fails', (tester) async {
    await tester.pumpWidget(_app(_FailingTemplatesRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load template'), findsOneWidget);
  });

  testWidgets('light: the preview walks the glass form to its dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeTemplatesRepository(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    expect(find.text('SECTION 1 OF 1'), findsOneWidget);
    expect(
      find.widgetWithText(GlassPrimaryButton, 'Finish preview'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('field-onShelf')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish preview'));
    await tester.pumpAndSettle();

    expect(find.text('Preview complete'), findsOneWidget);
  });
}
