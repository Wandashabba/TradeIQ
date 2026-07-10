import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/reports_screen.dart';

const _reportA = ReportDefinition(
  id: 'r-a',
  name: 'Coverage by outlet',
  type: 'coverage',
);

const _reportB = ReportDefinition(
  id: 'r-b',
  name: 'Sales by SKU',
  type: 'sales',
);

class _FakeReportsRepository implements ReportsRepository {
  String? generatedId;
  String? deletedId;

  @override
  Future<List<ReportDefinition>> listReports() async => const [
        _reportA,
        _reportB,
      ];

  @override
  Future<ReportResult> generate(String id) async {
    generatedId = id;
    return const ReportResult(
      rowCount: 5,
      generatedAt: '2026-07-09T10:00:00.000Z',
    );
  }

  @override
  Future<ReportDefinition> createReport({
    required String name,
    required String type,
    required Map<String, dynamic> filters,
  }) async =>
      _reportA;

  @override
  Future<void> deleteReport(String id) async {
    deletedId = id;
  }
}

class _FailingReportsRepository implements ReportsRepository {
  @override
  Future<List<ReportDefinition>> listReports() async =>
      throw Exception('boom');

  @override
  Future<ReportResult> generate(String id) async =>
      throw Exception('boom');

  @override
  Future<ReportDefinition> createReport({
    required String name,
    required String type,
    required Map<String, dynamic> filters,
  }) async =>
      throw Exception('boom');

  @override
  Future<void> deleteReport(String id) async => throw Exception('boom');
}

Widget _app(ReportsRepository repo) => ProviderScope(
      overrides: [
        reportsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: ReportsScreen()),
    );

void main() {
  testWidgets('renders report names once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeReportsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Coverage by outlet'), findsOneWidget);
    expect(find.text('Sales by SKU'), findsOneWidget);
  });

  testWidgets('running a report generates it and shows the row count',
      (tester) async {
    final repo = _FakeReportsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('run-r-a')));
    await tester.pumpAndSettle();

    expect(repo.generatedId, 'r-a');
    expect(find.text('coverage · 5 rows'), findsOneWidget);
  });

  testWidgets('deleting a report calls the repository', (tester) async {
    final repo = _FakeReportsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('delete-r-a')));
    await tester.pumpAndSettle();

    expect(repo.deletedId, 'r-a');
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_FailingReportsRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load reports'),
      findsOneWidget,
    );
  });
}
