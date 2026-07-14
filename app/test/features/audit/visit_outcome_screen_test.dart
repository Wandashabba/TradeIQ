import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/features/audit/data/scorecards_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outcome_screen.dart';

import '../../helpers/routed_app.dart';

const _visit = ServerScorecard(
  visitId: 'remote-1',
  weightedTotal: 72,
  ratingBand: 'amber',
  dimensionScores: {
    'availability': 83,
    'visibility': 80,
    'display': 80,
    'pricing': 61,
    'competitive': 29,
    // salesCapability is ABSENT — no staff on shift to assess. It must never
    // render as a zero.
  },
);

const _previous = ServerScorecard(
  visitId: 'remote-0',
  weightedTotal: 66,
  ratingBand: 'amber',
  dimensionScores: {},
);

Widget _app(VisitOutcome outcome) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);

  return routedApp(
    const VisitOutcomeScreen(
      visitDraftId: 'v1',
      outletId: 'o1',
      outletName: 'Sunrise Spaza',
    ),
    overrides: [
      localDbProvider.overrideWithValue(db),
      visitOutcomeProvider.overrideWith((ref, arg) async => outcome),
    ],
  );
}

void main() {
  testWidgets('shows the score the manager will see', (tester) async {
    await tester.pumpWidget(
      _app(const VisitOutcome(score: _visit, previous: null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('72'), findsOneWidget);
    expect(find.text('Amber'), findsOneWidget);
    expect(find.text('83'), findsOneWidget);
  });

  testWidgets('an unmeasurable dimension is “—”, never a zero', (tester) async {
    await tester.pumpWidget(
      _app(const VisitOutcome(score: _visit, previous: null)),
    );
    await tester.pumpAndSettle();

    // A zero here would read to the agent as "you scored nothing on this", when
    // in truth there was nothing in the store to score. Mirrors the server (#93).
    expect(find.text('Team capability'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.textContaining('not counted against you'), findsOneWidget);
  });

  testWidgets('compares against their own last visit here', (tester) async {
    await tester.pumpWidget(
      _app(const VisitOutcome(score: _visit, previous: _previous)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Up 6 points'), findsOneWidget);
    expect(find.textContaining('(66)'), findsOneWidget);
  });

  testWidgets('held on the phone: no score at all, rather than a guess', (tester) async {
    await tester.pumpWidget(
      _app(const VisitOutcome(score: null, previous: null)),
    );
    await tester.pumpAndSettle();

    // The app CAN compute a scorecard offline, but it is a proxy — showing it
    // would mean showing a number that quietly changes once the visit reaches
    // the server. An agent whose score moves overnight will not trust the next.
    expect(find.textContaining('safe on this phone'), findsOneWidget);
    expect(find.textContaining('Scored when it sends'), findsOneWidget);
    expect(find.text('/100'), findsNothing);
  });

  testWidgets('a submitted visit cannot be walked back into', (tester) async {
    await tester.pumpWidget(
      _app(const VisitOutcome(score: _visit, previous: null)),
    );
    await tester.pumpAndSettle();

    // Both ways off this screen go forward — to the next store.
    expect(find.byKey(const ValueKey('next-store')), findsOneWidget);
  });
}
