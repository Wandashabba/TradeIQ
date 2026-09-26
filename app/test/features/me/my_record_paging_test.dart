import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/me/data/my_record_repository.dart';

import 'me_harness.dart';

/// AN AGENT CAN REACH THEIR OLDER VISITS.
///
/// `GET /visits/me` is cursor-paged, `MyVisitsPage` has carried a `nextCursor`
/// since it was written, and no widget read it: My record rendered page one and
/// stopped — no footer, no action, and no sentence admitting the list had been
/// cut. An agent with more than a page of visits could not see their own
/// record, and nothing on the screen said so.
///
/// That is the same class of loss as a filter dropped in a migration, and this
/// is the test that would have caught it.
void main() {
  List<MyVisit> page(String prefix, int n) => <MyVisit>[
    for (var i = 0; i < n; i++)
      visitFixture(id: '$prefix$i', outletName: '$prefix store $i'),
  ];

  FakeMyRecordRepository paged() => FakeMyRecordRepository(
    visits: page('a', 3),
    firstCursor: 'c1',
    pages: <String, List<MyVisit>>{
      'c1': page('b', 2),
      'c2': page('c', 1),
    },
  );

  testWidgets('a cut list says so, and offers the way on', (tester) async {
    final repo = paged();
    await pumpMe(tester, repository: repo);

    expect(find.text('a store 0'), findsOneWidget);
    // Never a fabricated total: the server returns a cursor, not a count, so
    // the line says what is on screen and stops.
    expect(find.textContaining('Showing 3.'), findsOneWidget);
    expect(find.textContaining('Showing 3 of'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('me-show-older')),
      findsOneWidget,
    );
  });

  testWidgets('Show older appends the next page and keeps the first', (
    tester,
  ) async {
    final repo = paged();
    await pumpMe(tester, repository: repo);

    await tester.tap(find.byKey(const ValueKey<String>('me-show-older')));
    await tester.pumpAndSettle();

    expect(find.text('a store 0'), findsOneWidget, reason: 'page one stays');
    expect(find.text('b store 0'), findsOneWidget);
    expect(find.textContaining('Showing 5.'), findsOneWidget);
    // The cursor the server gave, not one the screen invented.
    expect(repo.cursorsAsked, <String?>[null, 'c1']);
  });

  testWidgets('the last page takes the footer away rather than looping', (
    tester,
  ) async {
    final repo = paged();
    await pumpMe(tester, repository: repo);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey<String>('me-show-older')));
      await tester.pumpAndSettle();
    }

    expect(find.text('c store 0'), findsOneWidget);
    expect(repo.cursorsAsked, <String?>[null, 'c1', 'c2']);
    // The server stopped sending a cursor. That is how the list knows it has
    // reached the end without anybody counting anything.
    expect(
      find.byKey(const ValueKey<String>('me-show-older')),
      findsNothing,
    );
    expect(find.textContaining('Showing'), findsNothing);
  });

  testWidgets('a page that will not load keeps the visits already on screen', (
    tester,
  ) async {
    await pumpMe(
      tester,
      repository: FakeMyRecordRepository(
        visits: page('a', 3),
        firstCursor: 'c1',
        olderThrows: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('me-show-older')));
    await tester.pumpAndSettle();

    // A failed *next* page is not a failed list. Throwing the loaded visits
    // away to show an error region would be the worse answer.
    expect(find.text('a store 0'), findsOneWidget);
    expect(find.text('Older visits did not load'), findsOneWidget);
  });

  testWidgets('an unpaged list shows no footer at all', (tester) async {
    await pumpMe(
      tester,
      repository: FakeMyRecordRepository(visits: page('a', 3)),
    );

    expect(find.text('a store 0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('me-show-older')),
      findsNothing,
    );
    expect(
      find.textContaining('Showing'),
      findsNothing,
      reason: 'a list that was not cut has nothing to own up to',
    );
  });

  testWidgets('Afrikaans reads in Afrikaans', (tester) async {
    await pumpMe(
      tester,
      repository: paged(),
      locale: const Locale('af'),
    );
    expect(find.text('Wys ouer besoeke'), findsOneWidget);
    expect(find.text('Show older visits'), findsNothing);
  });
}
