import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/report_form_screen.dart';

class _RecordingReportsRepository implements ReportsRepository {
  Map<String, dynamic>? createdArgs;

  @override
  Future<PaginatedResponse<ReportDefinition>> listReports() async =>
      const PaginatedResponse(data: [], nextCursor: null);

  @override
  Future<ReportResult> generate(String id) async => throw UnimplementedError();

  @override
  Future<ReportDefinition> createReport({
    required String name,
    required String type,
    required Map<String, dynamic> filters,
  }) async {
    createdArgs = {'name': name, 'type': type, 'filters': filters};
    return ReportDefinition(id: 'r1', name: name, type: type);
  }

  @override
  Future<void> deleteReport(String id) async => throw UnimplementedError();
}

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse(
        data: [
          Outlet(id: 'ou1', name: 'Shop One', code: 'S1', lat: 0, lng: 0),
        ],
        nextCursor: null,
      );

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) async =>
      throw UnimplementedError();
}

Widget _app(_RecordingReportsRepository repo, {ThemeData? theme}) =>
    ProviderScope(
      overrides: [
        reportsRepositoryProvider.overrideWithValue(repo),
        outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      ],
      child: MaterialApp(theme: theme, home: const ReportFormScreen()),
    );

/// The nearest glass pane around [finder].
GlassPane _paneAround(WidgetTester tester, Finder finder) => tester.widget<GlassPane>(
      find.ancestor(of: finder, matching: find.byType(GlassPane)).first,
    );

void main() {
  testWidgets('creates a report with name and selected type', (tester) async {
    final repo = _RecordingReportsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey<String>('report-name-field')), 'Weekly visits');

    await tester.tap(find.byKey(const ValueKey<String>('report-type-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tasks').last);
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey<String>('report-save-button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repo.createdArgs, isNotNull);
    expect(repo.createdArgs!['name'], 'Weekly visits');
    expect(repo.createdArgs!['type'], 'tasks');
    expect(repo.createdArgs!['filters'], isA<Map<String, dynamic>>());
  });

  testWidgets('blocks submit when name is empty', (tester) async {
    final repo = _RecordingReportsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey<String>('report-save-button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsOneWidget);
    expect(repo.createdArgs, isNull);
  });

  testWidgets('light: report and filters are glass panels, create is glass',
      (tester) async {
    final repo = _RecordingReportsRepository();
    await tester.pumpWidget(_app(repo, theme: AppTheme.light()));
    await tester.pumpAndSettle();

    expect(_paneAround(tester, find.text('REPORT')).kind, GlassKind.panel);
    expect(_paneAround(tester, find.text('FILTERS')).kind, GlassKind.panel);
    // An open date end is a real filter value, so it is named.
    expect(find.text('Any'), findsNWidgets(2));

    await tester.enterText(
        find.byKey(const ValueKey<String>('report-name-field')), 'Weekly visits');
    final save = find.byKey(const ValueKey<String>('report-save-button'));
    expect(tester.widget(save), isA<GlassPrimaryButton>());
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repo.createdArgs!['name'], 'Weekly visits');
  });
}
