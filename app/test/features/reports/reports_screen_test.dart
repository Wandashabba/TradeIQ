import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:tradeiq_app/core/download/file_download.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/reports_screen.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';
import 'reports_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required FakeReportsRepository repo,
    RecordingDownloader? downloader,
    TiqSkin? skin,
    double textScale = 1.0,
    bool settle = true,
  }) => pumpReports(
    tester,
    const ReportsScreen(),
    skin: skin,
    textScale: textScale,
    settle: settle,
    overrides: <Override>[
      reportsRepositoryProvider.overrideWithValue(repo),
      fileDownloaderProvider.overrideWithValue(
        downloader ?? RecordingDownloader(),
      ),
    ],
  );

  group('the list', () {
    testWidgets('names every saved definition and its slug', (tester) async {
      await pump(tester, repo: FakeReportsRepository());

      expect(find.text('Coverage by outlet'), findsOneWidget);
      expect(find.text('Sales by SKU'), findsOneWidget);
      // The slug is machine-facing, so it is on screen for a manager to quote
      // back into a definition.
      expect(find.text('outlet_coverage'), findsOneWidget);
      expect(find.text('Ready'), findsNWidgets(2));
    });

    testWidgets('an empty list is a settled answer, not a failure', (
      tester,
    ) async {
      await pump(
        tester,
        repo: FakeReportsRepository(reports: const <ReportDefinition>[]),
      );

      expect(find.text('No saved reports.'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);
    });

    testWidgets('a failure names itself and offers one retry', (tester) async {
      await pump(
        tester,
        repo: FakeReportsRepository(listFailure: networkFailure),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      // Sanitised: the host the client could not reach is not a sentence for
      // a manager to read.
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('reports-retry')),
        findsOneWidget,
      );
    });

    testWidgets('a cut list says so, and never invents a total', (
      tester,
    ) async {
      await pump(tester, repo: FakeReportsRepository(nextCursor: 'cursor-2'));
      await scrollWorklistTo(tester, find.byType(PaginationFooter));

      expect(find.text('Showing the first 2. There are more.'), findsOneWidget);
    });

    testWidgets('with a total the footer names it', (tester) async {
      await pump(
        tester,
        repo: FakeReportsRepository(nextCursor: 'cursor-2', total: 74),
      );
      await scrollWorklistTo(tester, find.byType(PaginationFooter));

      expect(find.text('Showing the first 2 of 74.'), findsOneWidget);
    });

    testWidgets('one page has no footer at all', (tester) async {
      await pump(tester, repo: FakeReportsRepository());
      expect(find.byType(PaginationFooter), findsNothing);
    });
  });

  group('Run downloads the file the server produced (#390)', () {
    testWidgets('it asks for the CSV and hands the bytes to the platform', (
      tester,
    ) async {
      final repo = FakeReportsRepository(csvRows: 5);
      final downloader = RecordingDownloader();
      await pump(tester, repo: repo, downloader: downloader);

      await tester.tap(find.byKey(const ValueKey<String>('run-r-a')));
      await tester.pumpAndSettle();

      expect(repo.generatedId, 'r-a');
      expect(repo.generatedSlug, 'outlet_coverage');
      expect(downloader.savedFilename, 'outlet_coverage-20260920.csv');
      expect(downloader.savedMimeType, startsWith('text/csv'));
      // Not a count of rows discarded: the rows themselves.
      expect(
        utf8.decode(downloader.savedBytes!),
        startsWith('outlet,visits\n'),
      );

      await settleToasts(tester);
    });

    testWidgets('the row reports the count it actually saved', (tester) async {
      await pump(tester, repo: FakeReportsRepository(csvRows: 5));

      await tester.tap(find.byKey(const ValueKey<String>('run-r-a')));
      await tester.pumpAndSettle();

      expect(find.text('Generated'), findsOneWidget);
      expect(
        find.text('5 rows · outlet_coverage-20260920.csv'),
        findsOneWidget,
      );

      await settleToasts(tester);
    });

    testWidgets('zero rows is a real answer, never an error', (tester) async {
      await pump(tester, repo: FakeReportsRepository(csvRows: 0));

      await tester.tap(find.byKey(const ValueKey<String>('run-r-a')));
      await tester.pumpAndSettle();

      expect(find.text('0 rows — the query matched nothing'), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);

      await settleToasts(tester);
    });

    testWidgets('a failed run says so and keeps the previous count', (
      tester,
    ) async {
      await pump(
        tester,
        repo: FakeReportsRepository(csvFailure: networkFailure),
      );

      await tester.tap(find.byKey(const ValueKey<String>('run-r-a')));
      await tester.pumpAndSettle();

      expect(find.text('Could not run'), findsOneWidget);
      expect(find.byType(TorchToast), findsOneWidget);

      await settleToasts(tester);
    });

    testWidgets('a refused save is reported, not swallowed', (tester) async {
      await pump(
        tester,
        repo: FakeReportsRepository(),
        downloader: RecordingDownloader(fails: true),
      );

      await tester.tap(find.byKey(const ValueKey<String>('run-r-a')));
      await tester.pumpAndSettle();

      expect(find.text('Could not run'), findsOneWidget);
      await settleToasts(tester);
    });
  });

  group('Delete confirms first', () {
    testWidgets('the confirm sheet names what will go, and cancelling keeps '
        'it', (tester) async {
      final repo = FakeReportsRepository();
      await pump(tester, repo: repo);

      await tester.tap(find.byKey(const ValueKey<String>('delete-r-a')));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmSheet), findsOneWidget);
      expect(
        find.text('Any schedule that runs it stops running.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(repo.deletedId, isNull);
    });

    testWidgets('confirming deletes', (tester) async {
      final repo = FakeReportsRepository();
      await pump(tester, repo: repo);

      await tester.tap(find.byKey(const ValueKey<String>('delete-r-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this report'));
      await tester.pumpAndSettle();

      expect(repo.deletedId, 'r-a');
    });
  });

  testWidgets('Schedules goes to the schedules route', (tester) async {
    await pump(tester, repo: FakeReportsRepository());

    await tester.tap(find.byKey(const ValueKey<String>('reports-schedules')));
    await tester.pumpAndSettle();

    expect(find.text('stub:/reports/schedules'), findsOneWidget);
  });

  group('the amber census', () {
    testWidgets('Night paints exactly one lit object: the nav tab', (
      tester,
    ) async {
      await pump(tester, repo: FakeReportsRepository());

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'reports',
        phase: 'loaded',
      );
      expect(
        census.objectCount,
        1,
        reason:
            'Nothing on a list of definitions is armed: Run is a ghost and '
            'the state marks are Oatmeal.\n${census.describe()}',
      );
    });

    testWidgets('Night, empty, still exactly the nav tab', (tester) async {
      await pump(
        tester,
        repo: FakeReportsRepository(reports: const <ReportDefinition>[]),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, loading, still exactly the nav tab', (tester) async {
      await pump(
        tester,
        repo: FakeReportsRepository(listPending: true),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, error, still exactly the nav tab', (tester) async {
      await pump(
        tester,
        repo: FakeReportsRepository(listFailure: networkFailure),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, the delete sheet, everything goes out', (tester) async {
      await pump(tester, repo: FakeReportsRepository());
      await tester.tap(find.byKey(const ValueKey<String>('delete-r-a')));
      await tester.pumpAndSettle();

      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        0,
        reason:
            'A destructive confirm is severity, and severity never touches '
            'amber — and while a sheet is up the nav tab beneath it drops to '
            'its ink form.\n${census.describe()}',
      );
    });

    for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
      for (final phase in const <String>['loaded', 'empty', 'error']) {
        testWidgets('${skin.mode.name}, $phase, paints no amber at all', (
          tester,
        ) async {
          await pump(
            tester,
            skin: skin,
            repo: FakeReportsRepository(
              reports: phase == 'empty'
                  ? const <ReportDefinition>[]
                  : const <ReportDefinition>[reportA, reportB],
              listFailure: phase == 'error' ? networkFailure : null,
            ),
          );

          final census = await amberCensus(tester);
          expectWithinAmberBudget(census, skin, route: 'reports', phase: phase);
          expect(census.objectCount, 0, reason: census.describe());
        });
      }
    }
  });

  testWidgets('2.0x: the structure survives and nothing overflows', (
    tester,
  ) async {
    await pump(tester, repo: FakeReportsRepository(), textScale: 2.0);

    expect(find.text('Coverage by outlet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Veld builds the list', (tester) async {
    await pump(tester, repo: FakeReportsRepository(), skin: TiqSkin.veld());

    expect(find.text('Coverage by outlet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
