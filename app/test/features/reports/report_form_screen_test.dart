import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/report_form_screen.dart';

class _RecordingReportsRepository implements ReportsRepository {
  Map<String, dynamic>? createdArgs;

  @override
  Future<List<ReportDefinition>> listReports() async => const [];

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
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'ou1', name: 'Shop One', code: 'S1', lat: 0, lng: 0),
      ];

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

Widget _app(_RecordingReportsRepository repo) => ProviderScope(
      overrides: [
        reportsRepositoryProvider.overrideWithValue(repo),
        outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      ],
      child: const MaterialApp(home: ReportFormScreen()),
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
}
