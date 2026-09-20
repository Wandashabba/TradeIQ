import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/reports_screen.dart';

import '../../helpers/routed_app.dart';

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
  Future<PaginatedResponse<ReportDefinition>> listReports() async =>
      const PaginatedResponse(data: [_reportA, _reportB], nextCursor: null);

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
  }) async => _reportA;

  @override
  Future<void> deleteReport(String id) async {
    deletedId = id;
  }
}

class _FailingReportsRepository implements ReportsRepository {
  @override
  Future<PaginatedResponse<ReportDefinition>> listReports() async =>
      throw Exception('boom');

  @override
  Future<ReportResult> generate(String id) async => throw Exception('boom');

  @override
  Future<ReportDefinition> createReport({
    required String name,
    required String type,
    required Map<String, dynamic> filters,
  }) async => throw Exception('boom');

  @override
  Future<void> deleteReport(String id) async => throw Exception('boom');
}

Widget _app(ReportsRepository repo, {ThemeData? theme}) => routedApp(
  const ReportsScreen(),
  theme: theme,
  overrides: [reportsRepositoryProvider.overrideWithValue(repo)],
);

void main() {
  testWidgets('renders report names once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeReportsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Coverage by outlet'), findsOneWidget);
    expect(find.text('Sales by SKU'), findsOneWidget);
  });

  testWidgets('running a report generates it and shows the row count', (
    tester,
  ) async {
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

    expect(find.textContaining('Failed to load reports'), findsOneWidget);
  });

  testWidgets('light: rows sit on glass worklist tiles', (tester) async {
    await tester.pumpWidget(
      _app(_FakeReportsRepository(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<GlassPane>(
      find
          .ancestor(
            of: find.text('Coverage by outlet'),
            matching: find.byType(GlassPane),
          )
          .first,
    );
    expect(tile.kind, GlassKind.tile);
    expect(tile.blur, isFalse);
  });

  testWidgets('Schedules in the top bar opens report schedules', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportsRepositoryProvider.overrideWithValue(_FakeReportsRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/reports',
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
              ),
              GoRoute(
                path: '/reports/schedules',
                builder: (context, state) => const Text('schedules-page'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('reports-schedules')));
    await tester.pumpAndSettle();

    expect(find.text('schedules-page'), findsOneWidget);
  });
}
