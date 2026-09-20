import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
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
  AuditTemplate(id: 'tpl-2', name: 'Pharmacy Audit', version: 1, active: false),
  AuditTemplate(id: 'tpl-3', name: 'Promo Check', version: 4, active: true),
];

class _FakeTemplatesRepository implements TemplatesRepository {
  _FakeTemplatesRepository({this.selectedId});

  String? selectedId;
  final selections = <String?>[];

  @override
  Future<PaginatedResponse<AuditTemplate>> listTemplates() async =>
      const PaginatedResponse(data: _templates, nextCursor: null);

  @override
  Future<AuditTemplateDetail> fetchTemplate(String id) =>
      throw UnimplementedError();

  AuditTemplateDetail? _detail() {
    for (final t in _templates) {
      if (t.id == selectedId) {
        return AuditTemplateDetail(template: t, schema: const {});
      }
    }
    return null;
  }

  @override
  Future<AuditTemplateDetail?> fetchSelected() async => _detail();

  @override
  Future<AuditTemplateDetail?> selectForAudits(String? templateId) async {
    selections.add(templateId);
    selectedId = templateId;
    return _detail();
  }
}

class _FailingTemplatesRepository implements TemplatesRepository {
  @override
  Future<PaginatedResponse<AuditTemplate>> listTemplates() async =>
      throw Exception('boom');

  @override
  Future<AuditTemplateDetail> fetchTemplate(String id) =>
      throw UnimplementedError();

  @override
  Future<AuditTemplateDetail?> fetchSelected() async => null;

  @override
  Future<AuditTemplateDetail?> selectForAudits(String? templateId) async =>
      null;
}

Widget _app(TemplatesRepository repo, {ThemeData? theme}) => routedApp(
  const TemplatesScreen(),
  theme: theme,
  overrides: [templatesRepositoryProvider.overrideWithValue(repo)],
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

    expect(find.textContaining('Failed to load templates'), findsOneWidget);
  });

  testWidgets('light: rows sit on glass worklist tiles', (tester) async {
    await tester.pumpWidget(
      _app(_FakeTemplatesRepository(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<GlassPane>(
      find
          .ancestor(
            of: find.text('Grocery Audit'),
            matching: find.byType(GlassPane),
          )
          .first,
    );
    expect(tile.kind, GlassKind.tile);
    expect(tile.blur, isFalse);
  });

  group('use in audits (#122)', () {
    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('night', AppTheme.dark),
    ]) {
      testWidgets('$name: says plainly when no template is in use', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(_FakeTemplatesRepository(), theme: theme()),
        );
        await tester.pumpAndSettle();

        expect(find.text('No template is used in audits.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('templates-stop-using')),
          findsNothing,
        );
        // Only active templates can be put in front of agents.
        expect(
          find.byKey(const ValueKey('template-use-tpl-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('template-use-tpl-3')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('template-use-tpl-2')), findsNothing);
      });
    }

    testWidgets('names the active template and marks its row', (tester) async {
      await tester.pumpWidget(
        _app(_FakeTemplatesRepository(selectedId: 'tpl-3')),
      );
      await tester.pumpAndSettle();

      expect(find.text('“Promo Check” (v4)'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^in audits$', caseSensitive: false)),
        findsOneWidget,
      );
      // The one in use has no "Use in audits" of its own.
      expect(find.byKey(const ValueKey('template-use-tpl-3')), findsNothing);
      expect(
        find.byKey(const ValueKey('templates-stop-using')),
        findsOneWidget,
      );
    });

    testWidgets('"Use in audits" selects the template and says so', (
      tester,
    ) async {
      final repo = _FakeTemplatesRepository();
      await tester.pumpWidget(_app(repo, theme: AppTheme.light()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('template-use-tpl-1')));
      await tester.pumpAndSettle();

      expect(repo.selections, ['tpl-1']);
      expect(find.text('“Grocery Audit” (v2)'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^in audits$', caseSensitive: false)),
        findsOneWidget,
      );
      expect(
        find.text('“Grocery Audit” is now used in audits.'),
        findsOneWidget,
      );
    });

    testWidgets('"Stop using" clears the selection', (tester) async {
      final repo = _FakeTemplatesRepository(selectedId: 'tpl-1');
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('templates-stop-using')));
      await tester.pumpAndSettle();

      expect(repo.selections, [null]);
      expect(find.text('No template is used in audits.'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^in audits$', caseSensitive: false)),
        findsNothing,
      );
    });
  });
}
