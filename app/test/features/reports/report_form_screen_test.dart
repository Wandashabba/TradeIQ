import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/l10n/l10n.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/report_form_screen.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';
import 'reports_harness.dart';

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    String? territoryId,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse<Outlet>(
    data: <Outlet>[Outlet(id: 'ou1', name: 'Shop One', code: 'S1', lat: 0, lng: 0)],
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
  }) async => throw UnimplementedError();
}

void main() {
  /// The form is longer than a 360×720 phone, so a field past the fold has
  /// not been built and `enterText` has nothing to type into. Scroll first —
  /// which is what a manager does too.
  Future<void> type(WidgetTester tester, String key, String text) async {
    await scrollWorklistTo(tester, find.byKey(ValueKey<String>(key)));
    await tester.enterText(find.byKey(ValueKey<String>(key)), text);
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester, {
    required FakeReportsRepository repo,
    TiqSkin? skin,
    double textScale = 1.0,
  }) => pumpPushedReports(
    tester,
    const ReportFormScreen(),
    skin: skin,
    textScale: textScale,
    overrides: <Override>[
      reportsRepositoryProvider.overrideWithValue(repo),
      outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
    ],
  );

  group('the date boxes', () {
    test('an ISO date parses, anything else does not', () {
      expect(parseFilterDate('2026-09-20'), DateTime(2026, 9, 20));
      expect(parseFilterDate(''), isNull);
      expect(parseFilterDate('20/09/2026'), isNull);
      expect(parseFilterDate('2026-9-1'), isNull);
    });

    test('a day that does not exist is not a date', () {
      // `DateTime.tryParse` rolls 2026-02-31 into March; a manager cannot
      // point at it on a calendar, so it is refused rather than silently
      // moved.
      expect(parseFilterDate('2026-02-31'), isNull);
      expect(filterDateError('2026-02-31', englishLocalizations), isNotNull);
    });

    // The words come from the reader's ARB, never from the form.
    test('the reason is translated, and the FORMAT is not', () {
      final af = lookupAppLocalizations(const Locale('af'));
      expect(
        filterDateError('2026-02-31', af),
        isNot(filterDateError('2026-02-31', englishLocalizations)),
      );
      // The server stores the filter verbatim and reads it back as an ISO
      // date, so the shape it names is the same in every language.
      expect(filterDateError('2026-02-31', af), contains('2026-09-20'));
    });

    test('a blank box is a real filter value, not an error', () {
      expect(filterDateError('   ', englishLocalizations), isNull);
    });
  });

  testWidgets('creates a report with the name and the picked type', (
    tester,
  ) async {
    final repo = FakeReportsRepository();
    await pump(tester, repo: repo);

    await type(tester, 'report-name-field', 'Weekly coverage');
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('report-save-button')));
    await tester.pumpAndSettle();

    expect(repo.createdName, 'Weekly coverage');
    expect(repo.createdType, 'tasks');
    expect(repo.createdFilters, isEmpty);
  });

  testWidgets('the dates and the outlet ride along as filters', (
    tester,
  ) async {
    final repo = FakeReportsRepository();
    await pump(tester, repo: repo);

    await type(tester, 'report-name-field', 'September');
    await type(tester, 'report-from-date', '2026-09-01');
    await type(tester, 'report-to-date', '2026-09-30');

    await scrollWorklistTo(
      tester,
      find.byKey(const ValueKey<String>('report-outlet-field')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('report-outlet-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shop One'));
    await tester.pumpAndSettle();
    expect(find.text('Shop One'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('report-save-button')));
    await tester.pumpAndSettle();

    expect(repo.createdFilters, <String, dynamic>{
      'from': '2026-09-01',
      'to': '2026-09-30',
      'outletId': 'ou1',
    });
  });

  group('a form that cannot save says why on the button', () {
    // MOVED WITH THE BEHAVIOUR, NOT DELETED. The rule is unchanged — this
    // form never refuses without saying why, and it still refuses to send —
    // and only the moment it says it has moved to the press. #515's reasoning
    // on `/account/password`, applied to the console's forms.
    testWidgets('an empty name, said on the press', (tester) async {
      final repo = FakeReportsRepository();
      await pump(tester, repo: repo);

      // Silent on arrival, and live.
      expect(find.text('Give the report a name first.'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('report-save-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Give the report a name first.'), findsOneWidget);
      expect(repo.createdName, isNull);
    });

    testWidgets('a To date before the From date', (tester) async {
      await pump(tester, repo: FakeReportsRepository());

      await type(tester, 'report-name-field', 'Backwards');
      await type(tester, 'report-from-date', '2026-09-30');
      await type(tester, 'report-to-date', '2026-09-01');

      await tester.tap(
        find.byKey(const ValueKey<String>('report-save-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('The To date is before the From date.'),
        findsOneWidget,
      );
    });

    testWidgets('a date that is not a date', (tester) async {
      await pump(tester, repo: FakeReportsRepository());

      await type(tester, 'report-name-field', 'Sloppy');
      await type(tester, 'report-from-date', '20/09/2026');

      await tester.tap(
        find.byKey(const ValueKey<String>('report-save-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('The From date is not a date. Use the form 2026-09-20.'),
        findsOneWidget,
      );
    });
  });

  group('the amber census', () {
    // WAS `blocked: nothing is armed, so nothing is lit`, EXPECTING 0.
    //
    // The 0 was the ghost's signature: the primary declared no claim until
    // every required field was filled. It is pressable from the first frame
    // now, so an untouched form spends **one** object — the commit block
    // itself. Night allows two and uses one; Day allows one and this is it.
    testWidgets('Night, untouched: exactly the commit', (tester) async {
      await pump(tester, repo: FakeReportsRepository());

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'reports/new',
        phase: 'untouched',
      );
      expect(
        census.objectCount,
        1,
        reason:
            'No nav on a pushed route, and the live primary is the one '
            'claim.\n${census.describe()}',
      );
    });

    testWidgets('Night, armed: exactly the commit', (tester) async {
      await pump(tester, repo: FakeReportsRepository());
      await type(tester, 'report-name-field', 'Weekly coverage');

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'reports/new',
        phase: 'armed',
      );
      expect(census.objectCount, 1, reason: census.describe());
    });

    for (final skin in <TiqSkin>[TiqSkin.day()]) {
      // WAS `zero blocked, one armed`. It is **one either way** now: Day's
      // single grant is spent on this button from the first frame, which is
      // the trade #515 made on the auth forms and this PR carries to the
      // console's. Filling the name does not add a second object; it only
      // stops the press having anything to complain about.
      testWidgets('${skin.mode.name}: one untouched, one armed', (
        tester,
      ) async {
        await pump(tester, repo: FakeReportsRepository(), skin: skin);

        var census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'reports/new',
          phase: 'untouched',
        );
        expect(census.objectCount, 1, reason: census.describe());

        await type(tester, 'report-name-field', 'Weekly coverage');

        census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'reports/new',
          phase: 'armed',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });
    }
  });

  testWidgets('2.0x: every field is still there and nothing overflows', (
    tester,
  ) async {
    await pump(tester, repo: FakeReportsRepository(), textScale: 2.0);

    expect(
      find.byKey(const ValueKey<String>('report-name-field')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
